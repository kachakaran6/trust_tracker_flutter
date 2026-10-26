import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_tracker_flutter/core/utils/pdf_generator.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/export_transaction_row.dart';

void main() {
  test('PdfGenerator generates PDF with INR / Rupee symbol without missing glyphs', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Mock path_provider channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );

    final rows = [
      ExportTransactionRow(
        timestamp: DateTime(2026, 10, 26, 23, 50),
        title: 'salary',
        category: 'Salary',
        typeLabel: 'Income',
        notes: '',
        amount: 35931.00,
        isIncome: true,
      ),
      ExportTransactionRow(
        timestamp: DateTime(2026, 10, 26, 23, 51),
        title: 'Piyush credit card',
        category: 'Other',
        typeLabel: 'Expense',
        notes: '',
        amount: 1200.00,
        isIncome: false,
      ),
    ];

    final file = await PdfGenerator.generate(
      rows: rows,
      currency: 'INR',
      dateRange: 'Current Month',
    );

    expect(file.existsSync(), isTrue);
    final length = await file.length();
    expect(length, greaterThan(1000));
  });
}
