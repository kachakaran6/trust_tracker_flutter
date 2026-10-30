import 'package:flutter_test/flutter_test.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/parser/amount_extractor.dart';

void main() {
  group('AmountExtractor Comprehensive Tests', () {
    test('Single amount with Rs. prefix', () {
      final res = AmountExtractor.extract('Sent Rs.10.00 to BAMANIA SUNILKUMAR');
      expect(res, isNotNull);
      expect(res!.amount, equals(10.00));
      expect(res.paise, equals(1000));
      expect(res.currency, equals('INR'));
    });

    test('Single amount with INR prefix and no decimals', () {
      final res = AmountExtractor.extract('Rs.35931 credited to your account');
      expect(res, isNotNull);
      expect(res!.amount, equals(35931.00));
      expect(res.paise, equals(3593100));
    });

    test('Indian comma-separated amounts (1,25,000.00 and 35,931.00)', () {
      final res1 = AmountExtractor.extract('INR 1,25,000.00 debited from A/c 1234');
      expect(res1, isNotNull);
      expect(res1!.amount, equals(125000.00));
      expect(res1.paise, equals(12500000));

      final res2 = AmountExtractor.extract('Rs. 35,931 credited to Kotak Bank');
      expect(res2, isNotNull);
      expect(res2!.amount, equals(35931.00));
      expect(res2.paise, equals(3593100));
    });

    test('Transaction amount plus Available Balance (Must extract transaction, NOT balance)', () {
      // Balance is much larger (45,000.00 vs 1,200.00)
      const sms = 'Your account has been debited by Rs 1,200 on 22-10-2026. Avail Bal INR 45,000.00.';
      final res = AmountExtractor.extract(sms);
      expect(res, isNotNull);
      expect(res!.amount, equals(1200.00));
      expect(res.amount, isNot(equals(45000.00)));
    });

    test('Transaction amount plus Credit Limit (Must extract transaction, NOT limit)', () {
      const sms = 'Card purchase of INR 799.00 at ZARA on 22-Oct-26. Avail Limit: INR 85,000.00.';
      final res = AmountExtractor.extract(sms);
      expect(res, isNotNull);
      expect(res!.amount, equals(799.00));
      expect(res.amount, isNot(equals(85000.00)));
    });

    test('Transaction amount plus Reference Number and Date', () {
      const sms = 'Sent Rs.53.35 from Kotak Bank A/c X1611 on 23-10-26. UPI Ref 666220514462.';
      final res = AmountExtractor.extract(sms);
      expect(res, isNotNull);
      expect(res!.amount, equals(53.35));
      expect(res.paise, equals(5335));
      expect(res.amount, isNot(equals(23.0)));
      expect(res.amount, isNot(equals(26.0)));
      expect(res.amount, isNot(equals(666220514462.0)));
    });

    test('Suffixed currency formats (500 INR, 250/-)', () {
      final res1 = AmountExtractor.extract('debited 500.00 INR at Starbucks');
      expect(res1, isNotNull);
      expect(res1!.amount, equals(500.00));

      final res2 = AmountExtractor.extract('Paid 250/- for groceries');
      expect(res2, isNotNull);
      expect(res2!.amount, equals(250.00));
    });

    test('Missing amount returns null', () {
      final res = AmountExtractor.extract('Your transaction was successful at Merchant.');
      expect(res, isNull);
    });

    test('Ambiguous amounts detected when multiple competing amounts present without context', () {
      final res = AmountExtractor.extract('Notification: amounts INR 500.00 and INR 1,200.00 noted.');
      if (res != null) {
        expect(res.isAmbiguous, isTrue);
      }
    });
  });
}

