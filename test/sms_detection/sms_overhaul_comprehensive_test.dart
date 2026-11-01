import 'package:flutter_test/flutter_test.dart';
import 'package:trust_tracker_flutter/core/utils/money.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/parser/amount_extractor.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/parser/sms_transaction_parser.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';

void main() {
  group('Comprehensive SMS Overhaul & Accuracy Verification', () {
    test('1. Mandatory Amount Extraction Test Matrix (Phase 9 Table)', () {
      final matrix = {
        'Debited Rs 15000.00 from account': 15000.0,
        'Debited Rs 15000 from account': 15000.0,
        'Debited Rs 15,000.00 from account': 15000.0,
        'Debited Rs 8300.00 from account': 8300.0,
        'Debited Rs 16000.00 from account': 16000.0,
        'Paid INR 500.00 to Grocery': 500.0,
        'Sent ₹1,250.50 via UPI': 1250.50,
        'Spent Rs 0.50 on Card': 0.50,
      };

      for (final entry in matrix.entries) {
        final res = AmountExtractor.extract(entry.key);
        expect(res, isNotNull, reason: 'Failed to extract from "${entry.key}"');
        expect(res!.amount, equals(entry.value), reason: 'Amount mismatch for "${entry.key}"');
      }
    });

    test('2. Exact Federal Bank Regression Suite (Phase 1 & Phase 9)', () {
      // Example 1
      const sms1 =
          'Debited Rs 15000.00 from a/c X7181 on 29Oct26 13:08 via UPI to CHANDANI JAY. Ref 630249477227. Bal Rs 8327.22.';
      final res1 = SmsTransactionParser.parse(body: sms1, sender: 'FEDBNK');
      expect(res1.isTransaction, isTrue);
      final txn1 = res1.transaction!;
      expect(txn1.amount, equals(15000.0));
      expect(txn1.availableBalance, equals(8327.22));
      expect(txn1.type, equals(TransactionType.expense));
      expect(txn1.bankName, equals('Federal Bank'));
      expect(txn1.merchant, equals('CHANDANI JAY'));
      expect(txn1.referenceNumber, equals('630249477227'));
      expect(txn1.maskedAccount, equals('••7181'));
      expect(txn1.date.year, equals(2026));
      expect(txn1.date.month, equals(10));
      expect(txn1.date.day, equals(29));
      expect(txn1.date.hour, equals(13));
      expect(txn1.date.minute, equals(8));
      // Sign convention: Expense must display with minus sign, NEVER plus sign
      expect(txn1.formattedAmount(showSign: true), equals('−₹15,000.00'));
      expect(txn1.formattedBalance(), equals('₹8,327.22'));

      // Example 2
      const sms2 =
          'Debited Rs 8300.00 from a/c X7181 on 29Oct26 13:09 via UPI to Mr KARAN CHA. Ref 630243969147. Bal Rs 27.22.';
      final res2 = SmsTransactionParser.parse(body: sms2, sender: 'FEDBNK');
      expect(res2.isTransaction, isTrue);
      final txn2 = res2.transaction!;
      expect(txn2.amount, equals(8300.0));
      expect(txn2.availableBalance, equals(27.22));
      expect(txn2.type, equals(TransactionType.expense));
      expect(txn2.bankName, equals('Federal Bank'));
      expect(txn2.merchant, equals('Mr KARAN CHA'));
      expect(txn2.referenceNumber, equals('630243969147'));
      expect(txn2.formattedAmount(showSign: true), equals('−₹8,300.00'));
      expect(txn2.formattedBalance(), equals('₹27.22'));

      // Example 3
      const sms3 =
          'Debited Rs 16000.00 from a/c X6214 on 29Oct26 13:15 via UPI to Mr KARAN CHA. Ref 630256293846. Bal Rs 246.54.';
      final res3 = SmsTransactionParser.parse(body: sms3, sender: 'FEDBNK');
      expect(res3.isTransaction, isTrue);
      final txn3 = res3.transaction!;
      expect(txn3.amount, equals(16000.0));
      expect(txn3.availableBalance, equals(246.54));
      expect(txn3.type, equals(TransactionType.expense));
      expect(txn3.bankName, equals('Federal Bank'));
      expect(txn3.merchant, equals('Mr KARAN CHA'));
      expect(txn3.referenceNumber, equals('630256293846'));
      expect(txn3.formattedAmount(showSign: true), equals('−₹16,000.00'));
      expect(txn3.formattedBalance(), equals('₹246.54'));
    });

    test('3. Balance-only and Limit notifications never create transactions', () {
      const balanceSms1 = 'Your A/c balance for X7181 is Rs 8327.22 as of 29-Oct-26.';
      final res1 = SmsTransactionParser.parse(body: balanceSms1, sender: 'FEDBNK');
      expect(res1.isTransaction, isFalse);

      const balanceSms2 = 'Available balance in Kotak Bank a/c X1611 is INR 45,210.00.';
      final res2 = SmsTransactionParser.parse(body: balanceSms2, sender: 'KOTAKB');
      expect(res2.isTransaction, isFalse);

      const limitSms = 'Your available credit limit on card 1234 is Rs. 1,50,000.00.';
      final res3 = SmsTransactionParser.parse(body: limitSms, sender: 'HDFCBK');
      expect(res3.isTransaction, isFalse);
    });

    test('4. Income Sign Convention (Phase 2)', () {
      const creditSms = 'INR 5000.00 credited to your Federal Bank account on 29-10-26.';
      final res = SmsTransactionParser.parse(body: creditSms, sender: 'FEDBNK');
      expect(res.isTransaction, isTrue);
      final txn = res.transaction!;
      expect(txn.type, equals(TransactionType.income));
      expect(txn.formattedAmount(showSign: true), equals('+₹5,000.00'));
    });

    test('5. Non-floating point precision preserved (Phase 1)', () {
      final m1 = Money.fromRupees(15000.00);
      expect(m1.paise, equals(1500000));
      expect(m1.formatIndian(), equals('₹15,000.00'));

      final m2 = Money.fromRupees(53.35);
      expect(m2.paise, equals(5335));
      expect(m2.formatIndian(), equals('₹53.35'));

      final m3 = Money.fromRupees(35931.00);
      expect(m3.paise, equals(3593100));
      expect(m3.formatIndian(), equals('₹35,931.00'));
    });
  });
}
