import 'package:flutter_test/flutter_test.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/parser/sms_transaction_parser.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';

void main() {
  test('Federal Bank Exact User Prompt Tests', () {
    // Example 1
    const sms1 = 'Debited Rs 15000.00 from a/c X7181 on 29Oct26 13:08 via UPI to CHANDANI JAY. Ref 630249477227. Bal Rs 8327.22.';
    final res1 = SmsTransactionParser.parse(body: sms1, sender: 'FEDBNK');
    
    // Example 2
    const sms2 = 'Debited Rs 8300.00 from a/c X7181 on 29Oct26 13:09 via UPI to Mr KARAN CHA. Ref 630243969147. Bal Rs 27.22.';
    final res2 = SmsTransactionParser.parse(body: sms2, sender: 'FEDBNK');

    // Example 3
    const sms3 = 'Debited Rs 16000.00 from a/c X6214 on 29Oct26 13:15 via UPI to Mr KARAN CHA. Ref 630256293846. Bal Rs 246.54.';
    final res3 = SmsTransactionParser.parse(body: sms3, sender: 'FEDBNK');

    expect(res1.isTransaction, isTrue);
    expect(res1.transaction?.amount, 15000.0);
    expect(res1.transaction?.availableBalance, 8327.22);
    expect(res1.transaction?.type, TransactionType.expense);
    expect(res1.transaction?.bankName, 'Federal Bank');
    expect(res1.transaction?.merchant, 'CHANDANI JAY');
    expect(res1.transaction?.referenceNumber, '630249477227');
    expect(res1.transaction?.maskedAccount, contains('7181'));
    expect(res1.transaction?.date.year, 2026);
    expect(res1.transaction?.date.month, 10);
    expect(res1.transaction?.date.day, 29);
    expect(res1.transaction?.date.hour, 13);
    expect(res1.transaction?.date.minute, 8);

    expect(res2.isTransaction, isTrue);
    expect(res2.transaction?.amount, 8300.0);
    expect(res2.transaction?.availableBalance, 27.22);
    expect(res2.transaction?.type, TransactionType.expense);
    expect(res2.transaction?.bankName, 'Federal Bank');
    expect(res2.transaction?.merchant, 'Mr KARAN CHA');
    expect(res2.transaction?.referenceNumber, '630243969147');
    expect(res2.transaction?.maskedAccount, contains('7181'));
    expect(res2.transaction?.date.hour, 13);
    expect(res2.transaction?.date.minute, 9);

    expect(res3.isTransaction, isTrue);
    expect(res3.transaction?.amount, 16000.0);
    expect(res3.transaction?.availableBalance, 246.54);
    expect(res3.transaction?.type, TransactionType.expense);
    expect(res3.transaction?.bankName, 'Federal Bank');
    expect(res3.transaction?.merchant, 'Mr KARAN CHA');
    expect(res3.transaction?.referenceNumber, '630256293846');
    expect(res3.transaction?.maskedAccount, contains('6214'));
    expect(res3.transaction?.date.hour, 13);
    expect(res3.transaction?.date.minute, 15);
  });
}
