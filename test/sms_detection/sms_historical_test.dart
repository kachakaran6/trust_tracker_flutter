import 'package:flutter_test/flutter_test.dart';
import 'package:trust_tracker_flutter/core/database/database_helper.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/services/sms_processing_service.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/models/detected_sms_transaction.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/repositories/sms_transaction_repository.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/transactions/data/repositories/transaction_repository.dart';

class MockHistoricalSmsRepo implements SmsTransactionRepository {
  final Map<int, DetectedSmsTransaction> storage = {};
  int _counter = 1;

  @override
  Future<int> insertDetectedTransaction(DetectedSmsTransaction transaction) async {
    final id = _counter++;
    transaction.id = id;
    storage[id] = transaction;
    return id;
  }

  @override
  Future<bool> isDuplicate(String fingerprint) async {
    return storage.values.any((t) => t.smsFingerprint == fingerprint);
  }

  @override
  Future<bool> isReferenceProcessed(String referenceNumber) async {
    return storage.values.any((t) => t.referenceNumber == referenceNumber);
  }

  @override
  Future<List<DetectedSmsTransaction>> getPendingTransactions() async {
    return storage.values.where((t) => t.status == 'pending_review').toList();
  }

  @override
  Future<List<DetectedSmsTransaction>> getAllDetectedTransactions() async {
    return storage.values.toList();
  }

  @override
  Future<int> getPendingCount() async {
    return storage.values.where((t) => t.status == 'pending_review').length;
  }

  @override
  Future<void> updateStatus(int id, String status, {int? transactionId}) async {
    final existing = storage[id];
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
      storage[transaction.id!] = transaction;
    }
  }

  @override
  Future<void> deleteDetectedTransaction(int id) async {
    storage.remove(id);
  }

  @override
  Future<void> deleteAllPendingRecords() async {
    storage.removeWhere((_, t) => t.status == 'pending_review');
  }

  @override
  Future<void> deleteAllSmsRecords() async {
    storage.clear();
  }
}

class FakeHistoricalTxnRepo extends TransactionRepository {
  FakeHistoricalTxnRepo() : super(DatabaseHelper.instance);

  @override
  Future<int> addTransaction(TransactionModel t) async {
    return 1;
  }
}

void main() {
  group('Historical SMS Sync & Batch Processing Tests', () {
    late MockHistoricalSmsRepo mockSmsRepo;
    late FakeHistoricalTxnRepo fakeTxnRepo;
    late SmsProcessingService processingService;

    setUp(() {
      mockSmsRepo = MockHistoricalSmsRepo();
      fakeTxnRepo = FakeHistoricalTxnRepo();
      processingService = SmsProcessingService(
        smsRepository: mockSmsRepo,
        transactionRepository: fakeTxnRepo,
        dbHelper: DatabaseHelper.instance,
      );
    });

    test('Batch scan processes legitimate transactions and discards spam/OTPs', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final mockMessages = [
        {
          'sender': 'AD-HDFCBK',
          'body': 'INR 1,200.00 debited from A/c XX1234 on 22-10-26 to Swiggy. UPI Ref: 1001.',
          'timestamp': now - 86400000,
        },
        {
          'sender': 'VK-ICICIB',
          'body': '452109 is your secret OTP for login. Do not share it with anyone.',
          'timestamp': now - 80000000,
        },
        {
          'sender': 'BZ-PAYTM',
          'body': 'Received Rs. 400.00 in your account via UPI from friend@okhdfc. Ref: 1002.',
          'timestamp': now - 70000000,
        },
        {
          'sender': 'PROMO',
          'body': 'Get an instant pre-approved personal loan of Rs 5,00,000 today!',
          'timestamp': now - 60000000,
        },
        {
          'sender': 'AD-HDFCBK',
          'body': 'INR 350.00 debited from A/c XX1234 to Uber. UPI Ref: 1003.',
          'timestamp': now - 50000000,
        },
      ];

      int progressCount = 0;
      final result = await processingService.processHistoricalMessages(
        messages: mockMessages,
        autoApproveHighConfidence: false,
        onProgress: (cur, tot) {
          progressCount = cur;
        },
      );

      expect(progressCount, equals(5));
      expect(result.totalScanned, equals(5));
      expect(result.transactionsFound, equals(3)); // Swiggy, Paytm, Uber
      expect(result.newPending, equals(3));
      expect(result.duplicatesSkipped, equals(0));
      expect(mockSmsRepo.storage.length, equals(3));
    });

    test('Historical scan is idempotent: Re-scanning produces duplicates and skips them', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final mockMessages = [
        {
          'sender': 'AD-HDFCBK',
          'body': 'INR 500.00 debited from A/c XX9999 to Cafe. UPI Ref: 5555.',
          'timestamp': now - 10000,
        },
      ];

      // Run 1
      final res1 = await processingService.processHistoricalMessages(
        messages: mockMessages,
      );
      expect(res1.newPending, equals(1));
      expect(res1.duplicatesSkipped, equals(0));

      // Run 2 with same messages
      final res2 = await processingService.processHistoricalMessages(
        messages: mockMessages,
      );
      expect(res2.newPending, equals(0));
      expect(res2.duplicatesSkipped, equals(1));
      expect(mockSmsRepo.storage.length, equals(1));
    });
  });
}
