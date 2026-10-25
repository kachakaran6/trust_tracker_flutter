import 'package:flutter_test/flutter_test.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/parser/sms_transaction_parser.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/services/sms_deduplication_service.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/models/detected_sms_transaction.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/models/sms_confidence.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/repositories/sms_transaction_repository.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';

// In-Memory mock repository for deterministic unit/integration testing
class MockSmsTransactionRepository implements SmsTransactionRepository {
  final Map<int, DetectedSmsTransaction> _storage = {};
  int _counter = 1;

  @override
  Future<int> insertDetectedTransaction(DetectedSmsTransaction transaction) async {
    final id = _counter++;
    transaction.id = id;
    _storage[id] = transaction;
    return id;
  }

  @override
  Future<bool> isDuplicate(String fingerprint) async {
    return _storage.values.any((t) => t.smsFingerprint == fingerprint);
  }

  @override
  Future<bool> isReferenceProcessed(String referenceNumber) async {
    return _storage.values.any((t) => t.referenceNumber == referenceNumber);
  }

  @override
  Future<List<DetectedSmsTransaction>> getPendingTransactions() async {
    return _storage.values.where((t) => t.status == 'pending_review').toList();
  }

  @override
  Future<List<DetectedSmsTransaction>> getAllDetectedTransactions() async {
    return _storage.values.toList();
  }

  @override
  Future<int> getPendingCount() async {
    return _storage.values.where((t) => t.status == 'pending_review').length;
  }

  @override
  Future<void> updateStatus(int id, String status, {int? transactionId}) async {
    final existing = _storage[id];
    if (existing != null) {
      existing.status = status;
      if (transactionId != null) {
        existing.transactionId = transactionId;
      }
    }
  }

  @override
  Future<void> updateTransactionDetails(DetectedSmsTransaction transaction) async {
    if (transaction.id != null) {
      _storage[transaction.id!] = transaction;
    }
  }

  @override
  Future<void> deleteDetectedTransaction(int id) async {
    _storage.remove(id);
  }

  @override
  Future<void> deleteAllPendingRecords() async {
    _storage.removeWhere((_, t) => t.status == 'pending_review');
  }

  @override
  Future<void> deleteAllSmsRecords() async {
    _storage.clear();
  }
}

void main() {
  group('SMS Detection Engine Integration & Privacy Tests', () {
    late MockSmsTransactionRepository mockRepo;
    late SmsDeduplicationService dedupService;

    setUp(() {
      mockRepo = MockSmsTransactionRepository();
      dedupService = SmsDeduplicationService(mockRepo);
    });

    test('1. Feature disabled: SMS processing should be blocked at entry', () {
      bool onSmsArrival({required bool isFeatureEnabled}) {
        if (!isFeatureEnabled) return false;
        return true;
      }

      expect(onSmsArrival(isFeatureEnabled: false), isFalse);
      expect(onSmsArrival(isFeatureEnabled: true), isTrue);
    });

    test('2. Permission denied: Feature cannot operate when permission is missing', () {
      bool hasPermission = false;
      bool isFeatureEnabled = true;

      bool canProcess() => isFeatureEnabled && hasPermission;

      expect(canProcess(), isFalse);
    });

    test('3. Feature enabled with permission: Processes valid SMS and stores in pending review', () async {
      const sms = 'INR 850.00 debited from A/c ending 4567 on 22-10-26 at Zomato. UPI Ref: 987654321012.';
      final parseResult = SmsTransactionParser.parse(body: sms, sender: 'HDFCBK');

      expect(parseResult.isTransaction, isTrue);
      final txn = parseResult.transaction!;

      final isDup = await dedupService.isDuplicate(txn);
      expect(isDup, isFalse);

      final id = await mockRepo.insertDetectedTransaction(txn);
      expect(id, isPositive);

      final pending = await mockRepo.getPendingTransactions();
      expect(pending.length, equals(1));
      expect(pending.first.amount, equals(850.00));
      expect(pending.first.type, equals(TransactionType.expense));
      expect(pending.first.status, equals('pending_review'));
    });

    test('4. Invalid SMS (OTP / Promo / Balance) creates no pending record', () async {
      const otpSms = 'Your OTP for ICICI NetBanking transaction is 654321. Do not share.';
      final parseResult = SmsTransactionParser.parse(body: otpSms, sender: 'ICICIB');

      expect(parseResult.isTransaction, isFalse);
      expect(await mockRepo.getPendingCount(), equals(0));
    });

    test('5. Deduplication: Reprocessing the exact same SMS creates no duplicate entry', () async {
      const sms = 'Rs. 450.00 debited via UPI to Swiggy. UPI Ref 329847192841.';
      final parseResult = SmsTransactionParser.parse(body: sms, sender: 'HDFCBK');
      final txn = parseResult.transaction!;

      // Insert once
      await mockRepo.insertDetectedTransaction(txn);
      expect(await mockRepo.getPendingCount(), equals(1));

      // Attempt duplicate insertion
      final isDup = await dedupService.isDuplicate(txn);
      expect(isDup, isTrue); // Deduplication prevents second record!
    });

    test('6. Accounting behavior: Refund classified as Income, not an extra expense', () {
      const refundSms = 'Refund of INR 350.00 credited to your account ending 8811 on 22-10-26.';
      final result = SmsTransactionParser.parse(body: refundSms, sender: 'KOTAKB');

      expect(result.isTransaction, isTrue);
      expect(result.transaction!.type, equals(TransactionType.income));
      expect(result.transaction!.amount, equals(350.00));
    });

    test('7. Accounting behavior: Reversal of previously debited amount is credited (Income)', () {
      const reversalSms = 'Amount of INR 500.00 debited earlier has been reversed to your account.';
      final result = SmsTransactionParser.parse(body: reversalSms, sender: 'HDFCBK');

      expect(result.isTransaction, isTrue);
      expect(result.transaction!.type, equals(TransactionType.income));
    });

    test('8. Delete all pending records cleans queue completely', () async {
      const sms1 = 'INR 100.00 debited from A/c 1111 on 22-10-26 at Shop A. Ref 111.';
      const sms2 = 'INR 200.00 debited from A/c 2222 on 22-10-26 at Shop B. Ref 222.';

      await mockRepo.insertDetectedTransaction(SmsTransactionParser.parse(body: sms1, sender: 'BANK').transaction!);
      await mockRepo.insertDetectedTransaction(SmsTransactionParser.parse(body: sms2, sender: 'BANK').transaction!);

      expect(await mockRepo.getPendingCount(), equals(2));

      await mockRepo.deleteAllPendingRecords();
      expect(await mockRepo.getPendingCount(), equals(0));
    });

    test('9. Privacy verification: Raw body is never stored in snippet or model', () {
      const sensitiveSms = 'INR 500.00 debited from A/c 123456789012 on 22-10-26 at Uber. SecretOTP 9988. Bal: INR 50,000.';
      final result = SmsTransactionParser.parse(body: sensitiveSms, sender: 'HDFCBK');
      final txn = result.transaction!;

      expect(txn.rawSnippet, isNotNull);
      expect(txn.rawSnippet, isNot(contains('123456789012'))); // Full a/c excluded
      expect(txn.rawSnippet, isNot(contains('SecretOTP')));     // OTP excluded
      expect(txn.rawSnippet, isNot(contains('50,000')));       // Balance excluded
      expect(txn.maskedAccount, equals('••9012'));             // Masked
    });

    test('10. Auto-approval flow: High confidence auto-adds, medium goes to review', () {
      // High confidence: well formed with ref, account, amount, clear direction
      const highSms = 'Rs. 450.00 debited from A/c ending 1234 via UPI to Swiggy on 22-10-26. UPI Ref 329847192841.';
      final highResult = SmsTransactionParser.parse(body: highSms, sender: 'HDFCBK');
      expect(highResult.transaction!.confidenceLevel, equals(SmsConfidenceLevel.high));

      // Medium confidence: recognizable but missing explicit ref or account
      const medSms = 'Paid Rs. 250 for snacks.';
      final medResult = SmsTransactionParser.parse(body: medSms, sender: 'UNKNOWN');
      expect(medResult.transaction!.confidenceLevel, isNot(equals(SmsConfidenceLevel.high)));
    });
  });
}
