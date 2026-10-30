import 'package:flutter_test/flutter_test.dart';
import 'package:trust_tracker_flutter/core/database/database_helper.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/parser/sms_transaction_parser.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/services/sms_processing_service.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/models/detected_sms_transaction.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/models/sms_confidence.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/repositories/sms_transaction_repository.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/transactions/data/repositories/transaction_repository.dart';

// In-Memory Mock Transaction Repository
class MockTransactionRepository implements TransactionRepository {
  final List<TransactionModel> transactions = [];
  int _nextId = 1;

  @override
  Future<int> addTransaction(TransactionModel transaction) async {
    transaction.id = _nextId++;
    transactions.add(transaction);
    return transaction.id!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// In-Memory Mock SMS Transaction Repository
class InMemorySmsRepository implements SmsTransactionRepository {
  final Map<int, DetectedSmsTransaction> store = {};
  int _nextId = 1;

  @override
  Future<int> insertDetectedTransaction(DetectedSmsTransaction transaction) async {
    final id = _nextId++;
    transaction.id = id;
    store[id] = transaction;
    return id;
  }

  @override
  Future<List<DetectedSmsTransaction>> getPendingTransactions() async {
    return store.values.where((e) => e.status == 'pending_review').toList();
  }

  @override
  Future<List<DetectedSmsTransaction>> getAllDetectedTransactions() async {
    return store.values.toList();
  }

  @override
  Future<int> getPendingCount() async {
    return store.values.where((e) => e.status == 'pending_review').length;
  }

  @override
  Future<void> updateStatus(int id, String status, {int? transactionId}) async {
    if (store.containsKey(id)) {
      final current = store[id]!;
      store[id] = current.copyWith(
        status: status,
        transactionId: transactionId ?? current.transactionId,
      );
    }
  }

  @override
  Future<void> updateTransactionDetails(DetectedSmsTransaction transaction) async {
    if (transaction.id != null) {
      store[transaction.id!] = transaction;
    }
  }

  @override
  Future<bool> isDuplicate(String fingerprint) async {
    return store.values.any((e) => e.smsFingerprint == fingerprint);
  }

  @override
  Future<bool> isReferenceProcessed(String referenceNumber) async {
    return store.values.any((e) => e.referenceNumber == referenceNumber);
  }

  @override
  Future<void> deleteDetectedTransaction(int id) async {
    store.remove(id);
  }

  @override
  Future<void> deleteAllPendingRecords() async {
    store.removeWhere((key, value) => value.status == 'pending_review');
  }

  @override
  Future<void> deleteAllSmsRecords() async {
    store.clear();
  }
}

void main() {
  group('SMS Approval and Persistence Tests', () {
    late InMemorySmsRepository smsRepo;
    late MockTransactionRepository txnRepo;
    late SmsProcessingService service;

    setUp(() {
      smsRepo = InMemorySmsRepository();
      txnRepo = MockTransactionRepository();
      service = SmsProcessingService(
        smsRepository: smsRepo,
        transactionRepository: txnRepo,
        dbHelper: DatabaseHelper.instance,
      );
    });

    test('1. Approving detected transaction creates ledger entry and updates status', () async {
      const sms = 'Sent Rs.10.00 from Kotak Bank A/c X1611 to BAMANIA SUNILKUMAR on 22-10-26. UPI Ref 006123314016.';
      final parsed = SmsTransactionParser.parse(body: sms, sender: 'KOTAKB').transaction!;
      final id = await smsRepo.insertDetectedTransaction(parsed);
      parsed.id = id;

      expect(await smsRepo.getPendingCount(), equals(1));

      // Approve
      final txnId = await service.approveDetectedTransaction(detected: parsed);
      expect(txnId, isNotNull);

      // Verify in ledger
      expect(txnRepo.transactions.length, equals(1));
      expect(txnRepo.transactions.first.amount, equals(10.00));
      expect(txnRepo.transactions.first.description, equals('BAMANIA SUNILKUMAR'));
      expect(txnRepo.transactions.first.type, equals(TransactionType.expense));

      // Verify pending queue updated
      expect(await smsRepo.getPendingCount(), equals(0));
      final stored = smsRepo.store[id]!;
      expect(stored.status, equals('approved'));
      expect(stored.transactionId, equals(txnId));
    });

    test('2. Editing amount before approval persists user-corrected value, NOT parser output', () async {
      const sms = 'Sent Rs.10.00 from Kotak Bank A/c X1611 to BAMANIA SUNILKUMAR on 22-10-26. UPI Ref 006123314016.';
      final parsed = SmsTransactionParser.parse(body: sms, sender: 'KOTAKB').transaction!;
      final id = await smsRepo.insertDetectedTransaction(parsed);
      parsed.id = id;

      // User corrects amount to 15.50 and description to 'Sunil Bamania - Lunch'
      await service.approveDetectedTransaction(
        detected: parsed,
        customAmount: 15.50,
        customDescription: 'Sunil Bamania - Lunch',
      );

      // Verify ledger has corrected values
      expect(txnRepo.transactions.first.amount, equals(15.50));
      expect(txnRepo.transactions.first.description, equals('Sunil Bamania - Lunch'));

      // Verify SMS audit record stored the user-corrected amount
      final audit = smsRepo.store[id]!;
      expect(audit.amount, equals(15.50));
      expect(audit.merchant, equals('Sunil Bamania - Lunch'));
      expect(audit.status, equals('approved'));
    });

    test('3. Idempotency: Duplicate approval does not create duplicate ledger records', () async {
      const sms = 'Rs.35931 credited to your Kotak Bank a/c X1611 via NEFT from beneficiary ROIMA INTELLIGENCE INDIA PVT LTD. UTR Ref. HDFCH01351853294';
      final parsed = SmsTransactionParser.parse(body: sms, sender: 'KOTAKB').transaction!;
      final id = await smsRepo.insertDetectedTransaction(parsed);
      parsed.id = id;

      // First approval
      final txnId1 = await service.approveDetectedTransaction(detected: parsed);
      expect(txnRepo.transactions.length, equals(1));

      // Attempt second approval on already approved item
      final approvedItem = smsRepo.store[id]!;
      final txnId2 = await service.approveDetectedTransaction(detected: approvedItem);

      // Must return existing ID and NOT insert a second ledger transaction
      expect(txnId2, equals(txnId1));
      expect(txnRepo.transactions.length, equals(1));
    });

    test('4. Rejecting transaction persists status "rejected" and removes from pending', () async {
      const sms = 'Sent Rs.53.35 from Kotak Bank A/c X1611 to Indian Railways on 23-10-26. UPI Ref 666220514462.';
      final parsed = SmsTransactionParser.parse(body: sms, sender: 'KOTAKB').transaction!;
      final id = await smsRepo.insertDetectedTransaction(parsed);

      expect(await smsRepo.getPendingCount(), equals(1));

      await service.rejectDetectedTransaction(id);

      expect(await smsRepo.getPendingCount(), equals(0));
      expect(smsRepo.store[id]!.status, equals('rejected'));
      expect(txnRepo.transactions.isEmpty, isTrue); // No ledger transaction created
    });

    test('5. Bulk approval skips ambiguous and low-confidence transactions safely', () async {
      final highItem = DetectedSmsTransaction(
        id: 1,
        smsFingerprint: 'fp1',
        sender: 'KOTAKB',
        amount: 10.00,
        type: TransactionType.expense,
        date: DateTime.now(),
        confidenceScore: 0.95,
        confidenceLevel: SmsConfidenceLevel.high,
        isAmbiguous: false,
      );
      final ambiguousItem = DetectedSmsTransaction(
        id: 2,
        smsFingerprint: 'fp2',
        sender: 'KOTAKB',
        amount: 500.00,
        type: TransactionType.expense,
        date: DateTime.now(),
        confidenceScore: 0.50,
        confidenceLevel: SmsConfidenceLevel.low,
        isAmbiguous: true,
      );

      await smsRepo.insertDetectedTransaction(highItem);
      await smsRepo.insertDetectedTransaction(ambiguousItem);

      final result = await service.bulkApprovePending([highItem, ambiguousItem]);

      expect(result.approvedCount, equals(1));
      expect(result.skippedUncertainCount, equals(1));
      expect(txnRepo.transactions.length, equals(1));
      expect(txnRepo.transactions.first.amount, equals(10.00));
    });
  });
}
