import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Transaction Amount Validation Tests (TT_026)', () {
    String? validateTransactionAmount(String? input) {
      final text = input?.trim() ?? '';
      if (text.isEmpty) {
        return 'Please enter an amount';
      }
      final amt = double.tryParse(text.replaceAll(',', ''));
      if (amt == null) {
        return 'Please enter a valid amount';
      }
      if (amt <= 0) {
        return 'Amount must be greater than 0';
      }
      return null;
    }

    test('TT_026: Negative expense amount (-200) is rejected', () {
      final error = validateTransactionAmount('-200');
      expect(error, 'Amount must be greater than 0');
    });

    test('Zero amount (0) is rejected', () {
      final error = validateTransactionAmount('0');
      expect(error, 'Amount must be greater than 0');
    });

    test('Empty amount is rejected', () {
      final error = validateTransactionAmount('');
      expect(error, 'Please enter an amount');
    });

    test('Valid positive expense (200, 1500.50) is accepted', () {
      expect(validateTransactionAmount('200'), isNull);
      expect(validateTransactionAmount('1,500.50'), isNull);
    });
  });
}
