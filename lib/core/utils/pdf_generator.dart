import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
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

    // Load fonts for Unicode support (Rupee symbols, etc)
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

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
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Trust Tracker',
                      style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900)),
                  pw.Text('Financial Activity Report',
                      style:
                          pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                ],
              ),
              if (logo != null)
                pw.Container(
                  width: 60,
                  height: 60,
                  child: pw.Image(logo),
                ),
            ],
          ),
          pw.SizedBox(height: 32),

          // Info bar
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('PERIOD', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                    pw.Text(dateRange, style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('GENERATED ON', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                    pw.Text(now.toTimestamp(), style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('ENTRIES', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                    pw.Text('${rows.length} transactions', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // Summary Section
          pw.Row(
            children: [
              _buildSummaryCard(
                  'Total Income',
                  '$currency ${totalIncome.toStringAsFixed(2)}',
                  PdfColors.green800,
                  PdfColors.green50),
              pw.SizedBox(width: 12),
              _buildSummaryCard(
                  'Total Expense',
                  '$currency ${totalExpense.toStringAsFixed(2)}',
                  PdfColors.red800,
                  PdfColors.red50),
              pw.SizedBox(width: 12),
              _buildSummaryCard(
                  'Net Balance',
                  '$currency ${balance.toStringAsFixed(2)}',
                  balance >= 0 ? PdfColors.blue800 : PdfColors.red800,
                  balance >= 0 ? PdfColors.blue50 : PdfColors.red50),
            ],
          ),
          pw.SizedBox(height: 32),

          // Table Header
          pw.Text('TRANSACTION DETAILS',
              style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900)),
          pw.SizedBox(height: 12),

          // Table
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blue800,
              borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(6)),
            ),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
            ),
            oddRowDecoration: const pw.BoxDecoration(
              color: PdfColors.white,
            ),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.0), // Date
              1: pw.FlexColumnWidth(2.0), // Transaction
              2: pw.FlexColumnWidth(1.2), // Category
              3: pw.FlexColumnWidth(1.5), // Notes
              4: pw.FlexColumnWidth(1.5), // Amount
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
              'Description',
              'Category',
              'Notes',
              'Amount'
            ],
            data: rows.map((row) {
              final amountStr = '${row.isIncome ? '+' : '-'}$currency ${row.amount.toStringAsFixed(2)}';
              return [
                row.timestampLabel,
                row.title,
                row.category,
                row.notes.isEmpty ? '-' : row.notes,
                pw.Text(
                  amountStr,
                  style: pw.TextStyle(
                    color: row.isIncome ? PdfColors.green800 : PdfColors.red800,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ];
            }).toList(),
          ),

          pw.SizedBox(height: 48),
          pw.Divider(color: PdfColors.grey200),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Trust Tracker - Privacy-first Finance Management',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
              pw.Text('Page 1 of 1',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            ],
          ),
        ],
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 20),
          child: pw.Text(
            'Generated via Trust Tracker App',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey400),
          ),
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/trust_tracker_report_${now.millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _buildSummaryCard(
      String title, String value, PdfColor textColor, PdfColor bgColor) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: bgColor,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
          border: pw.Border.all(color: textColor, width: 1),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title,
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: textColor)),
          ],
        ),
      ),
    );
  }
}
