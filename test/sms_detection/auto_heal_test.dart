import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trust_tracker_flutter/core/database/database_helper.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/repositories/sms_transaction_repository_impl.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/services/sms_processing_service.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/models/detected_sms_transaction.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/models/sms_confidence.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/transactions/data/repositories/transaction_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SMS Auto-Heal & Precision Regression Tests', () {
    late DatabaseHelper dbHelper;
    late SmsTransactionRepositoryImpl smsRepo;
    late TransactionRepository txnRepo;
    late SmsProcessingService processingService;

    setUp(() async {
      dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;
      await db.delete('sms_detected_transactions');
      await db.delete('transactions');

      smsRepo = SmsTransactionRepositoryImpl(dbHelper);
      txnRepo = TransactionRepository(dbHelper);
      processingService = SmsProcessingService(
        smsRepository: smsRepo,
        transactionRepository: txnRepo,
        dbHelper: dbHelper,
      );
    });

    test('1. Auto-heals legacy corrupted 15000 showing as 150 in pending review', () async {
      // Simulate legacy row stored by old parser with amount: 150.0
      const rawSms = 'Sent Rs.15000 from Kotak Bank A/c X1611 to John on 22-10-26. UPI Ref 006123314016.';
      final legacyTxn = DetectedSmsTransaction(
        smsFingerprint: 'legacy_kotak_15000',
        referenceNumber: '006123314016',
        sender: 'KOTAKB',
        amount: 150.0, // Legacy truncated amount!
        type: TransactionType.expense,
        date: DateTime(2026, 10, 22),
        confidenceScore: 0.5,
        confidenceLevel: SmsConfidenceLevel.medium,
        status: 'pending_review',
        rawSnippet: rawSms,
      );

      final insertedId = await smsRepo.insertDetectedTransaction(legacyTxn);
      expect(insertedId, isPositive);

      // Verify it was stored as 150 in raw SQLite
      final db = await dbHelper.database;
      final rawRowBefore = await db.query('sms_detected_transactions', where: 'id = ?', whereArgs: [insertedId]);
      expect(rawRowBefore.first['amount'], equals(150.0));

      // Now query through getPendingTransactions() - auto-heal must trigger
      final pendingList = await smsRepo.getPendingTransactions();
      expect(pendingList.length, equals(1));
      expect(pendingList.first.amount, equals(15000.0));
      expect(pendingList.first.amountPaise, equals(1500000));
      expect(pendingList.first.formattedAmount(), equals('₹15,000.00'));

      // Verify database row was permanently healed
      final rawRowAfter = await db.query('sms_detected_transactions', where: 'id = ?', whereArgs: [insertedId]);
      expect(rawRowAfter.first['amount'], equals(15000.0));
    });

    test('2. Auto-heals legacy corrupted 35931 showing as 359 in pending review', () async {
      const rawSms = 'Rs.35931 credited to your Kotak Bank a/c X1611 via NEFT from beneficiary ROIMA INTELLIGENCE INDIA PVT LTD. UTR Ref. HDFCH01351853294';
      final legacyTxn = DetectedSmsTransaction(
        smsFingerprint: 'legacy_kotak_35931',
        referenceNumber: 'HDFCH01351853294',
        sender: 'KOTAKB',
        amount: 359.0, // Legacy truncated amount!
        type: TransactionType.income,
        date: DateTime(2026, 10, 26),
        confidenceScore: 0.5,
        confidenceLevel: SmsConfidenceLevel.medium,
        status: 'pending_review',
        rawSnippet: rawSms,
      );

      final insertedId = await smsRepo.insertDetectedTransaction(legacyTxn);

      final pendingList = await smsRepo.getPendingTransactions();
      expect(pendingList.first.amount, equals(35931.0));
      expect(pendingList.first.amountPaise, equals(3593100));
      expect(pendingList.first.formattedAmount(), equals('₹35,931.00'));
    });

    test('3. Historical sync re-scan updates existing pending row if amount was wrong', () async {
      const rawSms = 'Sent Rs.15000 from Kotak Bank A/c X1611 to John on 22-10-26. UPI Ref 006123314016.';
      final legacyTxn = DetectedSmsTransaction(
        smsFingerprint: 'legacy_kotak_15000_sync',
        referenceNumber: '006123314016',
        sender: 'KOTAKB',
        amount: 150.0,
        type: TransactionType.expense,
        date: DateTime(2026, 10, 22),
        confidenceScore: 0.5,
        confidenceLevel: SmsConfidenceLevel.medium,
        status: 'pending_review',
        rawSnippet: rawSms,
      );
      await smsRepo.insertDetectedTransaction(legacyTxn);

      // Re-scan same SMS via processingService
      final syncResult = await processingService.processSms(
        body: rawSms,
        sender: 'KOTAKB',
      );

      expect(syncResult.isTransaction, isTrue);
      expect(syncResult.transaction?.amount, equals(15000.0));

      final pending = await smsRepo.getPendingTransactions();
      expect(pending.length, equals(1));
      expect(pending.first.amount, equals(15000.0));
    });
  });
}
