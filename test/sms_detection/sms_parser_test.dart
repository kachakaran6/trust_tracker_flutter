import 'package:flutter_test/flutter_test.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/parser/sms_transaction_parser.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/models/sms_confidence.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';

void main() {
  group('SmsTransactionParser Unit Tests', () {
    // 1. Valid UPI debit
    test('1. Valid UPI debit (GPay / PhonePe / Paytm format)', () {
      const sms = 'Rs. 450.00 debited from A/c ending 1234 via UPI to Swiggy on 22-10-26. UPI Ref 329847192841. Avail Bal: INR 12,450.00.';
      final result = SmsTransactionParser.parse(body: sms, sender: 'AX-HDFCBK');

      expect(result.isEligible, isTrue);
      expect(result.isTransaction, isTrue);
      final txn = result.transaction!;
      expect(txn.amount, equals(450.00));
      expect(txn.currency, equals('INR'));
      expect(txn.type, equals(TransactionType.expense));
      expect(txn.merchant, equals('Swiggy'));
      expect(txn.referenceNumber, equals('329847192841'));
      expect(txn.maskedAccount, equals('••1234'));
      expect(txn.confidenceLevel, equals(SmsConfidenceLevel.high));
      expect(txn.categoryName, equals('Food & Dining'));
    });

    // 2. Valid UPI credit
    test('2. Valid UPI credit', () {
      const sms = 'INR 2,500.00 credited to your A/c XX5678 on 22-10-26 by user@okaxis. UPI Ref: 849201928374.';
      final result = SmsTransactionParser.parse(body: sms, sender: 'VM-SBIINB');

      expect(result.isEligible, isTrue);
      expect(result.isTransaction, isTrue);
      final txn = result.transaction!;
      expect(txn.amount, equals(2500.00));
      expect(txn.currency, equals('INR'));
      expect(txn.type, equals(TransactionType.income));
      expect(txn.referenceNumber, equals('849201928374'));
      expect(txn.confidenceLevel, equals(SmsConfidenceLevel.high));
    });

    // 3. Bank debit
    test('3. Bank account debit', () {
      const sms = 'Your account ending 4321 has been debited by Rs 1,200 on 22-10-2026. Avail Bal INR 45,000.';
      final result = SmsTransactionParser.parse(body: sms, sender: 'AD-ICICIB');

      expect(result.isTransaction, isTrue);
      expect(result.transaction!.amount, equals(1200.00));
      expect(result.transaction!.type, equals(TransactionType.expense));
      expect(result.transaction!.maskedAccount, equals('••4321'));
    });

    // 4. Bank credit
    test('4. Bank account credit', () {
      const sms = 'INR 5,000.00 credited to your account XX9988 on 22-10-2026. Avail Bal: INR 65,000.';
      final result = SmsTransactionParser.parse(body: sms, sender: 'AXISBK');

      expect(result.isTransaction, isTrue);
      expect(result.transaction!.amount, equals(5000.00));
      expect(result.transaction!.type, equals(TransactionType.income));
    });

    // 5. ATM withdrawal
    test('5. ATM cash withdrawal', () {
      const sms = 'INR 2,000.00 withdrawn at Axis Bank ATM on 22-10-26 from A/c ••4321. Avail Bal: INR 15,300.00.';
      final result = SmsTransactionParser.parse(body: sms, sender: 'AXISBK');

      expect(result.isTransaction, isTrue);
      expect(result.transaction!.amount, equals(2000.00));
      expect(result.transaction!.type, equals(TransactionType.expense));
    });

    // 6. Card purchase
    test('6. Card purchase (Credit / Debit POS)', () {
      const sms = 'Card purchase of INR 799.00 on ICICI Bank Card ending 9900 at ZARA on 22-Oct-26. Avail Limit: INR 85,000.';
      final result = SmsTransactionParser.parse(body: sms, sender: 'ICICIB');

      expect(result.isTransaction, isTrue);
      expect(result.transaction!.amount, equals(799.00));
      expect(result.transaction!.type, equals(TransactionType.expense));
      expect(result.transaction!.merchant, equals('ZARA'));
      expect(result.transaction!.categoryName, equals('Shopping'));
    });

    // 7. IMPS, NEFT, and RTGS transfers
    test('7. IMPS, NEFT, and RTGS transfers', () {
      const impsSms = 'A/c 1122 debited with INR 8,400.00 on 22-10-26 towards NEFT transfer to Rohit. Ref: N102938475.';
      final result = SmsTransactionParser.parse(body: impsSms, sender: 'KOTAKB');

      expect(result.isTransaction, isTrue);
      expect(result.transaction!.amount, equals(8400.00));
      expect(result.transaction!.type, equals(TransactionType.expense));
      expect(result.transaction!.referenceNumber, equals('N102938475'));
    });

    // 8. Refund
    test('8. Refund notification', () {
      const sms = 'Refund of INR 350.00 credited to your Kotak Bank A/c ending 8811 on 22-10-26. Ref: RFD938472.';
      final result = SmsTransactionParser.parse(body: sms, sender: 'KOTAKB');

      expect(result.isTransaction, isTrue);
      expect(result.transaction!.amount, equals(350.00));
      expect(result.transaction!.type, equals(TransactionType.income));
    });

    // 9. Reversal
    test('9. Transaction Reversal', () {
      const sms = 'Amount of INR 500.00 debited earlier has been reversed to your a/c ending 3344 on 22-10-26.';
      final result = SmsTransactionParser.parse(body: sms, sender: 'HDFCBK');

      expect(result.isTransaction, isTrue);
      expect(result.transaction!.amount, equals(500.00));
      expect(result.transaction!.type, equals(TransactionType.income)); // Reversal returns funds to user
    });

    // 10. Failed payment
    test('10. Failed payment (must not create transaction)', () {
      const sms = 'Transaction of INR 1,200.00 on Card ending 1234 declined due to insufficient funds.';
      final result = SmsTransactionParser.parse(body: sms, sender: 'HDFCBK');

      expect(result.isTransaction, isFalse);
      expect(result.rejectionReason, contains('Failed'));
    });

    // 11. Pending payment
    test('11. Pending payment (unsettled, must not create entry)', () {
      const sms = 'Your payment of INR 850.00 is pending with merchant. Amount will be credited within 24 hours if failed.';
      final result = SmsTransactionParser.parse(body: sms, sender: 'PAYTMB');

      expect(result.isTransaction, isFalse);
      expect(result.rejectionReason, contains('Pending'));
    });

    // 12. OTP message
    test('12. OTP message (must be rejected as non-transaction)', () {
      const sms = '492019 is your One Time Password (OTP) for transaction of INR 1,500.00 at Swiggy. Never share your OTP.';
      final result = SmsTransactionParser.parse(body: sms, sender: 'HDFCBK');

      expect(result.isTransaction, isFalse);
      expect(result.rejectionReason, contains('OTP'));
    });

    // 13. Promotional message
    test('13. Promotional message (must be rejected)', () {
      const sms = 'Congratulations! Pre-approved personal loan up to INR 5,00,000 is ready for you. Apply now at zero fee.';
      final result = SmsTransactionParser.parse(body: sms, sender: 'BAJAJF');

      expect(result.isTransaction, isFalse);
      expect(result.rejectionReason, contains('Promotional'));
    });

    // 14. Balance-only notification
    test('14. Balance-only notification (must not treat balance as transaction)', () {
      const sms = 'Dear Customer, Avail Bal in your SBI A/c ending 5678 is INR 24,500.50. Thank you.';
      final result = SmsTransactionParser.parse(body: sms, sender: 'SBIINB');

      expect(result.isTransaction, isFalse);
      expect(result.rejectionReason, contains('Balance'));
    });

    // 15. Credit-card limit notification
    test('15. Credit-card limit notification (must not treat limit as transaction)', () {
      const sms = 'Your credit limit has been increased to INR 1,50,000.00 on your HDFC Bank Card.';
      final result = SmsTransactionParser.parse(body: sms, sender: 'HDFCBK');

      expect(result.isTransaction, isFalse);
      expect(result.rejectionReason, contains('limit'));
    });

    // 16. Multiple amounts in one message
    test('16. Multiple amounts (extract transaction amount, ignore balance)', () {
      const sms = 'INR 500.00 debited from a/c **1234 on 22-10-26. Avail Bal is INR 14,890.00.';
      final result = SmsTransactionParser.parse(body: sms, sender: 'HDFCBK');

      expect(result.isTransaction, isTrue);
      expect(result.transaction!.amount, equals(500.00));
      expect(result.transaction!.amount, isNot(equals(14890.00)));
    });

    // 17. Missing amount
    test('17. Missing amount (rejected safely)', () {
      const sms = 'Your account has been debited for monthly maintenance fee. Contact branch for details.';
      final result = SmsTransactionParser.parse(body: sms, sender: 'SBIINB');

      expect(result.isTransaction, isFalse);
      expect(result.rejectionReason, contains('amount'));
    });

    // 18. Indian currency formats
    test('18. Indian currency formats (Rs, Rs., INR, ₹, comma notation like 1,20,500.00)', () {
      const sms1 = 'Rs. 1,20,500.00 credited to account 9999.';
      final res1 = SmsTransactionParser.parse(body: sms1, sender: 'HDFCBK');
      expect(res1.transaction!.amount, equals(120500.00));

      const sms2 = '₹450 debited for order.';
      final res2 = SmsTransactionParser.parse(body: sms2, sender: 'PAYTM');
      expect(res2.transaction!.amount, equals(450.00));

      const sms3 = 'Rs 250 paid via UPI.';
      final res3 = SmsTransactionParser.parse(body: sms3, sender: 'GPAY');
      expect(res3.transaction!.amount, equals(250.00));
    });

    // 19. Sender variations
    test('19. Sender variations (AD-HDFCBK, BZ-PAYTM, AX-SBIINB)', () {
      const sms = 'INR 100.00 debited from A/c XX1234.';
      final res1 = SmsTransactionParser.parse(body: sms, sender: 'AD-HDFCBK');
      final res2 = SmsTransactionParser.parse(body: sms, sender: 'BZ-PAYTM');
      final res3 = SmsTransactionParser.parse(body: sms, sender: 'AX-SBIINB');

      expect(res1.isTransaction, isTrue);
      expect(res2.isTransaction, isTrue);
      expect(res3.isTransaction, isTrue);
    });

    // 20. Malformed SMS
    test('20. Malformed SMS handling', () {
      const sms = r'Random gibberish text without any bank patterns #$%@#^';
      final result = SmsTransactionParser.parse(body: sms, sender: 'UNKNOWN');

      expect(result.isTransaction, isFalse);
    });

    // 21. Ambiguous transaction direction
    test('21. Ambiguous transaction direction (safeguard: request received vs debited)', () {
      const sms = 'Request received for Rs 500.00 debited from your A/c ending 1234.';
      final result = SmsTransactionParser.parse(body: sms, sender: 'HDFCBK');

      expect(result.isTransaction, isTrue);
      expect(result.transaction!.type, equals(TransactionType.expense)); // Must be expense, NOT income
    });

    // 22. Duplicate transaction reference
    test('22. Duplicate transaction reference produces identical fingerprint', () {
      const sms1 = 'INR 500.00 debited via UPI. UPI Ref: 123456789012.';
      const sms2 = 'INR 500.00 debited via UPI. Ref: 123456789012.';

      final res1 = SmsTransactionParser.parse(body: sms1, sender: 'HDFCBK');
      final res2 = SmsTransactionParser.parse(body: sms2, sender: 'HDFCBK');

      expect(res1.transaction!.referenceNumber, equals('123456789012'));
      expect(res2.transaction!.referenceNumber, equals('123456789012'));
      expect(res1.transaction!.smsFingerprint, equals(res2.transaction!.smsFingerprint));
    });

    // 23. Two legitimate same-amount transactions at different times
    test('23. Two legitimate same-amount transactions at different times receive different fingerprints', () {
      const sms1 = 'INR 250.00 debited from A/c 1234.';
      const sms2 = 'INR 250.00 debited from A/c 1234.';

      final time1 = DateTime(2026, 10, 22, 10, 30);
      final time2 = DateTime(2026, 10, 22, 14, 45);

      final res1 = SmsTransactionParser.parse(body: sms1, sender: 'HDFCBK', smsReceivedTime: time1);
      final res2 = SmsTransactionParser.parse(body: sms2, sender: 'HDFCBK', smsReceivedTime: time2);

      expect(res1.transaction!.amount, equals(res2.transaction!.amount));
      expect(res1.transaction!.smsFingerprint, isNot(equals(res2.transaction!.smsFingerprint)));
    });

    // 24. Multipart message handling
    test('24. Multipart message handling (concatenated segments)', () {
      const part1 = 'INR 1,450.00 debited from your A/c XX9988 on 22-10-26';
      const part2 = ' towards purchase at Croma. UPI Ref 992817263541. Avail Bal: INR 35,000.';
      const fullBody = '$part1$part2';

      final result = SmsTransactionParser.parse(body: fullBody, sender: 'HDFCBK');

      expect(result.isTransaction, isTrue);
      expect(result.transaction!.amount, equals(1450.00));
      expect(result.transaction!.merchant, equals('Croma'));
      expect(result.transaction!.categoryName, equals('Shopping'));
    });
  });
}
