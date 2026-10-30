import 'package:flutter_test/flutter_test.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/parser/sms_transaction_parser.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/models/sms_confidence.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';

void main() {
  group('User Prompt Regression Tests', () {
    test('Example 1 — Kotak Bank Debit to BAMANIA SUNILKUMAR (Rs.10.00)', () {
      const sms = 'Sent Rs.10.00 from Kotak Bank A/c X1611 to BAMANIA SUNILKUMAR on 22-10-26. UPI Ref 006123314016. Not done by you? Tap https://kotak.bank.in/KBANKT/Fraud';
      final result = SmsTransactionParser.parse(body: sms, sender: 'VM-KOTAKB');

      expect(result.isEligible, isTrue, reason: 'Must be eligible');
      expect(result.isTransaction, isTrue, reason: 'Must be classified as transaction');
      final txn = result.transaction!;

      expect(txn.type, equals(TransactionType.expense));
      expect(txn.amount, equals(10.00));
      expect(txn.amountPaise, equals(1000));
      expect(txn.formattedAmount(), equals('₹10.00'));
      expect(txn.bankName, equals('Kotak Bank'));
      expect(txn.merchant, equals('BAMANIA SUNILKUMAR'));
      expect(txn.referenceNumber, equals('006123314016'));
      expect(txn.maskedAccount, equals('••1611'));
      expect(txn.confidenceLevel, equals(SmsConfidenceLevel.high));
    });

    test('Example 2 — Kotak Bank Debit to THAKOR MANOJ BHAI (Rs.10.00)', () {
      const sms = 'Sent Rs.10.00 from Kotak Bank A/c X1611 to THAKOR MANOJ BHAI on 22-10-26. UPI Ref 006148341447. Not done by you?';
      final result = SmsTransactionParser.parse(body: sms, sender: 'AX-KOTAKB');

      expect(result.isTransaction, isTrue);
      final txn = result.transaction!;

      expect(txn.type, equals(TransactionType.expense));
      expect(txn.amount, equals(10.00));
      expect(txn.amountPaise, equals(1000));
      expect(txn.formattedAmount(), equals('₹10.00'));
      expect(txn.bankName, equals('Kotak Bank'));
      expect(txn.merchant, equals('THAKOR MANOJ BHAI'));
      expect(txn.referenceNumber, equals('006148341447'));
      expect(txn.maskedAccount, equals('••1611'));
      expect(txn.confidenceLevel, equals(SmsConfidenceLevel.high));
    });

    test('Example 3 — Kotak Bank Railway Payment (Rs.53.35)', () {
      const sms = 'Sent Rs.53.35 from Kotak Bank A/c X1611 to Indian Railways on 23-10-26. UPI Ref 666220514462. Not done by you?';
      final result = SmsTransactionParser.parse(body: sms, sender: 'KOTAKB');

      expect(result.isTransaction, isTrue);
      final txn = result.transaction!;

      expect(txn.type, equals(TransactionType.expense));
      expect(txn.amount, equals(53.35));
      expect(txn.amountPaise, equals(5335));
      expect(txn.formattedAmount(), equals('₹53.35'));
      expect(txn.bankName, equals('Kotak Bank'));
      expect(txn.merchant, equals('Indian Railways'));
      expect(txn.referenceNumber, equals('666220514462'));
      expect(txn.maskedAccount, equals('••1611'));
      expect(txn.confidenceLevel, equals(SmsConfidenceLevel.high));
    });

    test('Example 4 — Kotak Bank NEFT Credit (Rs.35931 -> Must NOT truncate to 359!)', () {
      const sms = 'Rs.35931 credited to your Kotak Bank a/c X1611 via NEFT from beneficiary ROIMA INTELLIGENCE INDIA PVT LTD. UTR Ref. HDFCH01351853294';
      final result = SmsTransactionParser.parse(body: sms, sender: 'KOTAKB');

      expect(result.isTransaction, isTrue);
      final txn = result.transaction!;

      expect(txn.type, equals(TransactionType.income));
      expect(txn.amount, equals(35931.00));
      expect(txn.amountPaise, equals(3593100));
      expect(txn.formattedAmount(), equals('₹35,931.00'));
      expect(txn.bankName, equals('Kotak Bank'));
      expect(txn.merchant, equals('ROIMA INTELLIGENCE INDIA PVT LTD'));
      expect(txn.referenceNumber, equals('HDFCH01351853294'));
      expect(txn.maskedAccount, equals('••1611'));
      expect(txn.confidenceLevel, equals(SmsConfidenceLevel.high));
    });

    test('Critical: Dates and reference numbers are NEVER mistaken for transaction amounts', () {
      const sms = 'Sent Rs.10.00 from Kotak Bank A/c X1611 to BAMANIA SUNILKUMAR on 22-10-26. UPI Ref 006123314016.';
      final result = SmsTransactionParser.parse(body: sms, sender: 'KOTAKB');

      final txn = result.transaction!;
      expect(txn.amount, isNot(equals(22.0)));
      expect(txn.amount, isNot(equals(26.0)));
      expect(txn.amount, isNot(equals(1611.0)));
      expect(txn.amount, isNot(equals(6123314016.0)));
      expect(txn.amount, equals(10.00));
    });

    test('Critical: Balance-only notification does not create transaction', () {
      const balanceSms = 'Avail Bal in Kotak Bank A/c X1611 is Rs.45,000.00 on 22-10-26.';
      final result = SmsTransactionParser.parse(body: balanceSms, sender: 'KOTAKB');

      expect(result.isTransaction, isFalse);
    });

    test('Critical: Ambiguous message requires user verification', () {
      const ambiguousSms = 'Transaction notice: Rs. 500 or Rs. 1,000 recorded.';
      final result = SmsTransactionParser.parse(body: ambiguousSms, sender: 'BANK');

      if (result.isTransaction) {
        expect(result.transaction!.confidenceLevel, isNot(equals(SmsConfidenceLevel.high)));
        expect(result.transaction!.isAmbiguous, isTrue);
      }
    });
  });
}

