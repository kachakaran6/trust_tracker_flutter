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

    // 2. Check for duplicate
    final isDup = await _dedupService.isDuplicate(detected);
    if (isDup) {
      return SmsParseResult.duplicate('Transaction already processed (duplicate detected)');
    }

    // 3. Match category ID from database
    final categoryId = await _findCategoryId(
      categoryName: detected.categoryName,
      type: detected.type,
    );

    final resolvedTxn = detected.copyWith(categoryId: categoryId);

    // 4. Check if auto-approval applies
    if (autoApproveHighConfidence && resolvedTxn.confidenceLevel == SmsConfidenceLevel.high) {
      // Create actual transaction directly
      final actualTxn = TransactionModel.create(
        amount: resolvedTxn.amount,
        description: resolvedTxn.merchant ?? resolvedTxn.sender,
        date: resolvedTxn.date,
        type: resolvedTxn.type,
        categoryId: resolvedTxn.categoryId,
        note: resolvedTxn.maskedAccount != null
            ? 'Auto-detected via SMS (${resolvedTxn.maskedAccount})'
            : 'Auto-detected via SMS',
      );

      final txnId = await _transactionRepository.addTransaction(actualTxn);
      resolvedTxn.status = 'approved';
      resolvedTxn.transactionId = txnId;

      await _smsRepository.insertDetectedTransaction(resolvedTxn);
      return SmsParseResult.success(resolvedTxn);
    } else {
      // Store in pending review queue
      resolvedTxn.status = 'pending_review';
      final insertedId = await _smsRepository.insertDetectedTransaction(resolvedTxn);
      resolvedTxn.id = insertedId;
      return SmsParseResult.success(resolvedTxn);
    }
  }

  Future<void> approveDetectedTransaction({
    required DetectedSmsTransaction detected,
    int? customCategoryId,
    String? customDescription,
    double? customAmount,
    DateTime? customDate,
  }) async {
    if (detected.id == null) return;

    final actualTxn = TransactionModel.create(
      amount: customAmount ?? detected.amount,
      description: customDescription ?? detected.merchant ?? detected.sender,
      date: customDate ?? detected.date,
      type: detected.type,
      categoryId: customCategoryId ?? detected.categoryId,
      note: detected.maskedAccount != null
          ? 'Imported via SMS (${detected.maskedAccount})'
          : 'Imported via SMS',
    );

    final txnId = await _transactionRepository.addTransaction(actualTxn);
    await _smsRepository.updateStatus(detected.id!, 'approved', transactionId: txnId);
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
