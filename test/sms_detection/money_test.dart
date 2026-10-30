import 'package:flutter_test/flutter_test.dart';
import 'package:trust_tracker_flutter/core/utils/money.dart';

void main() {
  group('Money Value Object Tests', () {
    test('Exact paise conversion from string', () {
      final m1 = Money.tryParse('Rs.10.00');
      expect(m1, isNotNull);
      expect(m1!.paise, equals(1000));
      expect(m1.toRupeesDouble(), equals(10.00));
      expect(m1.formatIndian(), equals('₹10.00'));

      final m2 = Money.tryParse('Rs.53.35');
      expect(m2, isNotNull);
      expect(m2!.paise, equals(5335));
      expect(m2.toRupeesDouble(), equals(53.35));
      expect(m2.formatIndian(), equals('₹53.35'));

      final m3 = Money.tryParse('Rs.35931');
      expect(m3, isNotNull);
      expect(m3!.paise, equals(3593100));
      expect(m3.toRupeesDouble(), equals(35931.00));
      expect(m3.formatIndian(), equals('₹35,931.00'));

      final m4 = Money.tryParse('INR 1,25,000.50');
      expect(m4, isNotNull);
      expect(m4!.paise, equals(12500050));
      expect(m4.toRupeesDouble(), equals(125000.50));
      expect(m4.formatIndian(), equals('₹1,25,000.50'));
    });

    test('Arithmetic operations preserve exact integer paise', () {
      final a = Money.fromRupees(10.25);
      final b = Money.fromRupees(20.50);
      final c = a + b;
      expect(c.paise, equals(3075));
      expect(c.toRupeesDouble(), equals(30.75));

      final diff = b - a;
      expect(diff.paise, equals(1025));
      expect(diff.toRupeesDouble(), equals(10.25));
    });

    test('Negative and signed formatting', () {
      final m = const Money.fromPaise(-1000);
      expect(m.formatIndian(), equals('−₹10.00'));

      final positive = const Money.fromPaise(3593100);
      expect(positive.formatIndian(showSign: true), equals('+₹35,931.00'));
    });
  });
}
