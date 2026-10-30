import 'package:flutter_test/flutter_test.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/parser/sms_transaction_parser.dart';

void main() {
  test('Test 43 Indian Bank SMS patterns with 15000', () {
    final testMessages = [
      // Kotak Bank
      'Sent Rs.15000.00 from Kotak Bank A/c X1611 to John on 22-10-26.',
      'Sent Rs.15000 from Kotak Bank A/c X1611 to John on 22-10-26.',
      'Sent Rs.15,000.00 from Kotak Bank A/c X1611 to John on 22-10-26.',
      'Sent Rs.15,000 from Kotak Bank A/c X1611 to John on 22-10-26.',
      'Rs.15000 credited to your Kotak Bank a/c X1611 via NEFT from beneficiary ABC.',
      'Rs. 15000 credited to your Kotak Bank a/c X1611.',
      'Rs 15000.00 credited to your Kotak Bank a/c X1611.',
      'Rs 15,000.00 credited to your Kotak Bank a/c X1611.',
      // HDFC Bank
      'HDFC Bank: Rs 15000.00 debited from a/c **1234 on 28-10-26 to VPA abc@upi. Bal: Rs 45000.00',
      'HDFC Bank: Rs. 15,000 debited from a/c **1234 on 28-10-26 to VPA abc@upi. Bal: Rs. 500.00',
      'HDFC Bank: Rs 15000 debited from a/c **1234.',
      'UPDATE: INR 15,000.00 deposited to HDFC Bank A/c ending 1234 on 28-OCT-26.',
      'UPDATE: INR 15000 deposited to HDFC Bank A/c ending 1234 on 28-OCT-26.',
      // SBI
      'Dear SBI User, your A/c ending 1234 debited by Rs 15000.00 on 28Oct26 by transfer to VPA ... Avl Bal Rs 5,432.10',
      'Dear SBI User, your A/c ending 1234 debited by Rs 15000 on 28Oct26. Avl Bal Rs 5,432.10',
      'Dear SBI User, your A/c ending 1234 debited by Rs 15,000.00 on 28Oct26.',
      'Dear SBI User, your A/c ending 1234 credited by Rs 15000.00 on 28Oct26.',
      'Dear SBI User, your A/c ending 1234 credited by Rs 15000 on 28Oct26.',
      // ICICI Bank
      'Dear Customer, your Account ending 1234 has been debited with INR 15,000.00 on 28-Oct-26.',
      'Dear Customer, your Account ending 1234 has been debited with INR 15000.00 on 28-Oct-26.',
      'Dear Customer, your Account ending 1234 has been debited with INR 15000 on 28-Oct-26.',
      'Dear Customer, your Account ending 1234 has been credited with INR 15000.00 on 28-Oct-26.',
      'Dear Customer, your Account ending 1234 has been credited with INR 15000 on 28-Oct-26.',
      // Axis Bank
      'Axis Bank: INR 15,000.00 debited from A/c no. XX1234 on 28-10-26. Info: UPI/12345/John. Bal: INR 50,000.00.',
      'Axis Bank: INR 15000 debited from A/c no. XX1234 on 28-10-26.',
      'Axis Bank: INR 15,000 credited to A/c no. XX1234 on 28-10-26.',
      // UPI Apps (PhonePe, Paytm, GPay)
      'Paid Rs.15000 on PhonePe to Store. UPI Ref: 123456789012',
      'Paid Rs. 15,000 on PhonePe to Store. UPI Ref: 123456789012',
      'Paid 15000.00 INR on PhonePe to Store',
      'Paid 15000/- to Store on 28-10-26',
      'Received 15000/- from Store on 28-10-26',
      // Card alerts
      'Alert: You have spent INR 15,000.00 on Credit Card ending 1234 at RELIANCE on 28-Oct-26.',
      'Alert: You have spent INR 15000 on Credit Card ending 1234 at RELIANCE on 28-Oct-26.',
      'Spent Rs.15000 on Credit Card ending 1234.',
      'Transaction of Rs 15000.00 made on ICICI Bank Card 1234.',
      'Transaction of Rs 15000 made on ICICI Bank Card 1234.',
      'Txn of INR 15000.00 done on your Kotak Bank card.',
      // Common variants
      'Your A/c 1611 is debited for Rs 15000 on 28-10-26.',
      'Your a/c 1611 debited for INR 15,000.00 on 28-10-26.',
      'A/c X1611 debited by 15000.00 on 28-10-26.',
      'A/c X1611 debited by 15000 on 28-10-26.',
      'A/c X1611 credited with 15000 on 28-10-26.',
      'A/c X1611 credited by 15000.00 on 28-10-26.',
    ];

    for (final msg in testMessages) {
      final parsed = SmsTransactionParser.parse(body: msg, sender: 'BANK-ALERT');
      final amt = parsed.transaction?.amount;
      expect(amt, equals(15000.0), reason: 'Failed for message: "$msg"');
    }
  });
}
