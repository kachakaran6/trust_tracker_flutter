import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:trust_tracker_flutter/core/utils/extensions.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/export_transaction_row.dart';

class PdfGenerator {
  static Future<File> generate({
    required List<ExportTransactionRow> rows,
    required String currency,
    required String dateRange,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();

    // Summary data
    double totalIncome = 0;
    double totalExpense = 0;
    for (final row in rows) {
      if (row.isIncome) {
        totalIncome += row.amount;
      } else {
        totalExpense += row.amount;
      }
    }
    final balance = totalIncome - totalExpense;

    // Load logo if exists
    pw.MemoryImage? logo;
    try {
      final logoData = await rootBundle.load('assets/images/2.png');
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Trust Tracker',
                      style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue700)),
                  pw.Text('Financial Report',
                      style:
                          pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                ],
              ),
              if (logo != null)
                pw.Container(
                  width: 50,
                  height: 50,
                  child: pw.Image(logo),
                ),
            ],
          ),
          pw.SizedBox(height: 24),

          // Info section
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Period: $dateRange',
                      style: pw.TextStyle(fontSize: 10)),
                  pw.Text('Generated: ${now.toTimestamp()}',
                      style: pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Transactions: ${rows.length}',
                      style: pw.TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
          pw.Divider(thickness: 1, color: PdfColors.grey300),
          pw.SizedBox(height: 16),

          // Summary Cards
          pw.Row(
            children: [
              _buildSummaryCard(
                  'Income',
                  '$currency ${totalIncome.toStringAsFixed(2)}',
                  PdfColors.green700),
              pw.SizedBox(width: 12),
              _buildSummaryCard(
                  'Expense',
                  '$currency ${totalExpense.toStringAsFixed(2)}',
                  PdfColors.red700),
              pw.SizedBox(width: 12),
              _buildSummaryCard('Balance',
                  '$currency ${balance.toStringAsFixed(2)}', PdfColors.blue700),
            ],
          ),
          pw.SizedBox(height: 24),

          // Table
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
            ),
            oddRowDecoration: const pw.BoxDecoration(
              color: PdfColors.grey100,
            ),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 8,
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.0),
              1: pw.FlexColumnWidth(1.7),
              2: pw.FlexColumnWidth(1.3),
              3: pw.FlexColumnWidth(1.7),
              4: pw.FlexColumnWidth(1.1),
            },
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerRight,
            },
            headers: [
              'Date & Time',
              'Transaction',
              'Category',
              'Notes',
              'Amount'
            ],
            data: rows.map((row) {
              return [
                row.timestampLabel,
                '${row.title}\n${row.typeLabel}',
                row.category,
                row.notes.isEmpty ? '-' : row.notes,
                '${row.isIncome ? '+' : '-'}$currency ${row.amount.toStringAsFixed(2)}',
              ];
            }).toList(),
          ),

          pw.SizedBox(height: 48),
          pw.Center(
            child: pw.Text('Trust Tracker - Privacy-first Finance Management',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/trust_tracker_report_${now.millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _buildSummaryCard(
      String title, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(color: PdfColors.grey200),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title,
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }
}
