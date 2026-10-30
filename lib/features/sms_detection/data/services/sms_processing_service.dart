import 'package:trust_tracker_flutter/core/database/database_helper.dart';
import 'package:trust_tracker_flutter/features/categories/data/models/category_model.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/parser/sms_transaction_parser.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/services/sms_deduplication_service.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/models/detected_sms_transaction.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/models/sms_confidence.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/models/sms_parse_result.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/repositories/sms_transaction_repository.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/transactions/data/repositories/transaction_repository.dart';

class BulkApprovalResult {
  final int approvedCount;
  final int skippedUncertainCount;
  final List<String> errors;

  const BulkApprovalResult({
    required this.approvedCount,
    required this.skippedUncertainCount,
    this.errors = const [],
  });
}

class SmsProcessingService {
  final SmsTransactionRepository _smsRepository;
  final TransactionRepository _transactionRepository;
  final DatabaseHelper _dbHelper;
  final SmsDeduplicationService _dedupService;

  SmsProcessingService({
    required SmsTransactionRepository smsRepository,
    required TransactionRepository transactionRepository,
    required DatabaseHelper dbHelper,
  })  : _smsRepository = smsRepository,
        _transactionRepository = transactionRepository,
        _dbHelper = dbHelper,
        _dedupService = SmsDeduplicationService(smsRepository);

  Future<SmsParseResult> processSms({
    required String body,
    required String sender,
    DateTime? receivedTime,
    bool autoApproveHighConfidence = false,
  }) async {
    // 1. Parse SMS
    final parseResult = SmsTransactionParser.parse(
      body: body,
      sender: sender,
      smsReceivedTime: receivedTime,
    );

    if (!parseResult.isEligible || !parseResult.isTransaction || parseResult.transaction == null) {
      return parseResult;
    }

    final detected = parseResult.transaction!;

    // 2. Check for duplicate (idempotency guard)
    final isDup = await _dedupService.isDuplicate(detected);
    if (isDup) {
      // Auto-heal check: if an existing record in pending_review has an older/truncated amount, heal it!
      if (detected.referenceNumber != null && detected.referenceNumber!.isNotEmpty) {
        final db = await _dbHelper.database;
        final rows = await db.query(
          'sms_detected_transactions',
          where: 'referenceNumber = ? AND status = ?',
          whereArgs: [detected.referenceNumber, 'pending_review'],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          final existing = DetectedSmsTransaction.fromMap(rows.first);
          if (existing.amount != detected.amount && detected.amount > 0) {
            existing.amount = detected.amount;
            existing.confidenceScore = detected.confidenceScore;
            existing.isAmbiguous = detected.isAmbiguous;
            existing.parsingWarning = detected.parsingWarning;
            await _smsRepository.updateTransactionDetails(existing);
            return SmsParseResult.success(existing);
          }
        }
      }
      return SmsParseResult.duplicate('Transaction already processed (duplicate detected)');
    }

    // 3. Match category ID from database
    final categoryId = await _findCategoryId(
      categoryName: detected.categoryName,
      type: detected.type,
    );

    final resolvedTxn = detected.copyWith(categoryId: categoryId);

    // 4. Check if auto-approval applies
    if (autoApproveHighConfidence && resolvedTxn.confidenceLevel == SmsConfidenceLevel.high && !resolvedTxn.isAmbiguous) {
      // Build safe note
      final noteParts = <String>[];
      if (resolvedTxn.bankName != null && resolvedTxn.bankName!.isNotEmpty) {
        noteParts.add(resolvedTxn.bankName!);
      }
      if (resolvedTxn.maskedAccount != null) {
        noteParts.add(resolvedTxn.maskedAccount!);
      }
      if (resolvedTxn.referenceNumber != null) {
        noteParts.add('Ref: ${resolvedTxn.referenceNumber}');
      }
      final note = noteParts.isNotEmpty
          ? 'Auto-detected via SMS (${noteParts.join(', ')})'
          : 'Auto-detected via SMS';

      // Create actual transaction directly
      final actualTxn = TransactionModel.create(
        amount: resolvedTxn.amount,
        description: resolvedTxn.merchant ?? resolvedTxn.sender,
        date: resolvedTxn.date,
        type: resolvedTxn.type,
        categoryId: resolvedTxn.categoryId,
        note: note,
      );

      final txnId = await _transactionRepository.addTransaction(actualTxn);
      resolvedTxn.status = 'approved';
      resolvedTxn.transactionId = txnId;

      final insertedId = await _smsRepository.insertDetectedTransaction(resolvedTxn);
      resolvedTxn.id = insertedId;
      return SmsParseResult.success(resolvedTxn);
    } else {
      // Store in pending review queue
      resolvedTxn.status = 'pending_review';
      final insertedId = await _smsRepository.insertDetectedTransaction(resolvedTxn);
      resolvedTxn.id = insertedId;
      return SmsParseResult.success(resolvedTxn);
    }
  }

  Future<int?> approveDetectedTransaction({
    required DetectedSmsTransaction detected,
    int? customCategoryId,
    String? customCategoryName,
    String? customDescription,
    double? customAmount,
    TransactionType? customType,
    DateTime? customDate,
  }) async {
    if (detected.id == null) return null;

    // Idempotency: Avoid double approvals
    if (detected.status == 'approved' && detected.transactionId != null) {
      return detected.transactionId;
    }

    final finalAmount = customAmount ?? detected.amount;
    final finalType = customType ?? detected.type;
    final finalMerchant = customDescription ?? detected.merchant ?? detected.sender;
    final finalDate = customDate ?? detected.date;
    final finalCatId = customCategoryId ?? detected.categoryId;

    final noteParts = <String>[];
    if (detected.bankName != null && detected.bankName!.isNotEmpty) {
      noteParts.add(detected.bankName!);
    }
    if (detected.maskedAccount != null) {
      noteParts.add(detected.maskedAccount!);
    }
    if (detected.referenceNumber != null) {
      noteParts.add('Ref: ${detected.referenceNumber}');
    }
    final note = noteParts.isNotEmpty
        ? 'Imported via SMS (${noteParts.join(', ')})'
        : 'Imported via SMS';

    final actualTxn = TransactionModel.create(
      amount: finalAmount,
      description: finalMerchant,
      date: finalDate,
      type: finalType,
      categoryId: finalCatId,
      note: note,
    );

    final txnId = await _transactionRepository.addTransaction(actualTxn);

    // Persist confirmed and corrected values into audit trail
    final updatedRecord = detected.copyWith(
      amount: finalAmount,
      type: finalType,
      merchant: finalMerchant,
      date: finalDate,
      categoryId: finalCatId,
      categoryName: customCategoryName ?? detected.categoryName,
      status: 'approved',
      transactionId: txnId,
    );
    await _smsRepository.updateTransactionDetails(updatedRecord);

    return txnId;
  }

  Future<BulkApprovalResult> bulkApprovePending(List<DetectedSmsTransaction> items) async {
    int approved = 0;
    int skippedUncertain = 0;
    final List<String> errors = [];

    for (final item in items) {
      // High financial integrity rule: never bulk-approve ambiguous or low-confidence entries
      if (item.isAmbiguous || item.confidenceLevel == SmsConfidenceLevel.low) {
        skippedUncertain++;
        continue;
      }
      try {
        await approveDetectedTransaction(detected: item);
        approved++;
      } catch (e) {
        errors.add('Failed to approve ${item.merchant ?? item.sender}: $e');
      }
    }

    return BulkApprovalResult(
      approvedCount: approved,
      skippedUncertainCount: skippedUncertain,
      errors: errors,
    );
  }

  Future<void> rejectDetectedTransaction(int id) async {
    await _smsRepository.updateStatus(id, 'rejected');
  }

  Future<int?> _findCategoryId({
    String? categoryName,
    required TransactionType type,
  }) async {
    if (categoryName == null) return null;
    try {
      final db = await _dbHelper.database;
      final categoryType = type == TransactionType.income
          ? CategoryType.income.index
          : CategoryType.expense.index;

      final results = await db.query(
        'categories',
        where: 'name LIKE ? AND type = ?',
        whereArgs: ['%$categoryName%', categoryType],
        limit: 1,
      );

      if (results.isNotEmpty) {
        return results.first['id'] as int?;
      }

      // Fallback: match any category of same type
      final fallbackResults = await db.query(
        'categories',
        where: 'type = ?',
        whereArgs: [categoryType],
        limit: 1,
      );
      if (fallbackResults.isNotEmpty) {
        return fallbackResults.first['id'] as int?;
      }
    } catch (_) {}
    return null;
  }

  Future<HistoricalScanResult> processHistoricalMessages({
    required List<Map<String, dynamic>> messages,
    bool autoApproveHighConfidence = false,
    void Function(int current, int total)? onProgress,
  }) async {
    final total = messages.length;
    int txnsFound = 0;
    int newPending = 0;
    int autoApproved = 0;
    int dups = 0;

    for (int i = 0; i < messages.length; i++) {
      onProgress?.call(i + 1, total);
      final m = messages[i];
      final sender = m['sender'] as String? ?? 'UNKNOWN';
      final body = m['body'] as String? ?? '';
      final ts = m['timestamp'] as int?;
      final dt = ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : null;

      final result = await processSms(
        body: body,
        sender: sender,
        receivedTime: dt,
        autoApproveHighConfidence: autoApproveHighConfidence,
      );

      if (result.isTransaction) {
        txnsFound++;
        if (result.isDuplicate) {
          dups++;
        } else if (result.transaction?.status == 'approved') {
          autoApproved++;
        } else if (result.transaction != null) {
          newPending++;
        }
      }
    }

    return HistoricalScanResult(
      totalScanned: total,
      transactionsFound: txnsFound,
      newPending: newPending,
      autoApproved: autoApproved,
      duplicatesSkipped: dups,
    );
  }
}

class HistoricalScanResult {
  final int totalScanned;
  final int transactionsFound;
  final int newPending;
  final int autoApproved;
  final int duplicatesSkipped;

  const HistoricalScanResult({
    this.totalScanned = 0,
    this.transactionsFound = 0,
    this.newPending = 0,
    this.autoApproved = 0,
    this.duplicatesSkipped = 0,
  });
}
