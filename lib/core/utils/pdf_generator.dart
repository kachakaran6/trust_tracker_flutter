import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:trust_tracker_flutter/core/utils/extensions.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/export_transaction_row.dart';

import 'package:trust_tracker_flutter/core/utils/pdf_font_helper.dart';

class PdfGenerator {
  static Future<File> generate({
    required List<ExportTransactionRow> rows,
    required String currency,
    required String dateRange,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();

    // Load fonts for Unicode support (offline-first from bundled assets)
    final fontRegular = await PdfFontHelper.loadRegularFont();
    final fontBold = await PdfFontHelper.loadBoldFont();

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

    // Split rows into chunks of 40 to prevent TooManyPagesException
    final chunks = <List<ExportTransactionRow>>[];
    for (var i = 0; i < rows.length; i += 40) {
      chunks.add(rows.sublist(i, i + 40 > rows.length ? rows.length : i + 40));
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        header: (context) => _buildHeader(logo, now, dateRange, rows.length),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildSummarySection(currency, totalIncome, totalExpense, balance, fontRegular),
          pw.SizedBox(height: 32),

          pw.Text('TRANSACTION DETAILS',
              style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900)),
          pw.SizedBox(height: 12),

          // Render tables in chunks to avoid single massive table logic failures
          ...chunks.map((chunk) => _buildTransactionTable(chunk, currency, fontRegular)),

          pw.SizedBox(height: 48),
          pw.Divider(color: PdfColors.grey200),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Trust Tracker - Privacy-first Finance Management',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            ],
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

  static pw.Widget _buildHeader(pw.MemoryImage? logo, DateTime now, String dateRange, int count) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Trust Tracker',
                    style: const pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900)),
                pw.Text('Financial Activity Report',
                    style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
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
                  pw.Text('PERIOD',
                      style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey600,
                          fontWeight: pw.FontWeight.bold)),
                  pw.Text(dateRange, style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('GENERATED ON',
                      style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey600,
                          fontWeight: pw.FontWeight.bold)),
                  pw.Text(now.toTimestamp(),
                      style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('ENTRIES',
                      style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey600,
                          fontWeight: pw.FontWeight.bold)),
                  pw.Text('$count transactions',
                      style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 24),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated via Trust Tracker App',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey400),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey400),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummarySection(
      String currency, double income, double expense, double balance, pw.Font font) {
    return pw.Row(
      children: [
        _buildSummaryCard(
            'Total Income',
            PdfFontHelper.safeCurrencyText(income.toCurrency(currency), font),
            PdfColors.green800,
            PdfColors.green50),
        pw.SizedBox(width: 12),
        _buildSummaryCard(
            'Total Expense',
            PdfFontHelper.safeCurrencyText(expense.toCurrency(currency), font),
            PdfColors.red800,
            PdfColors.red50),
        pw.SizedBox(width: 12),
        _buildSummaryCard(
            'Net Balance',
            PdfFontHelper.safeCurrencyText(balance.toCurrency(currency), font),
            balance >= 0 ? PdfColors.blue800 : PdfColors.red800,
            balance >= 0 ? PdfColors.blue50 : PdfColors.red50),
      ],
    );
  }

  static pw.Widget _buildTransactionTable(
      List<ExportTransactionRow> chunk, String currency, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.TableHelper.fromTextArray(
        headerStyle: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(
          color: PdfColors.blue800,
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        rowDecoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
          ),
        ),
        cellPadding: const pw.EdgeInsets.all(6),
        columnWidths: const {
          0: pw.FlexColumnWidth(2.0), // Date
          1: pw.FlexColumnWidth(2.0), // Transaction
          2: pw.FlexColumnWidth(1.2), // Category
          3: pw.FlexColumnWidth(1.5), // Notes
          4: pw.FlexColumnWidth(1.5), // Amount
        },
        headers: ['Date & Time', 'Description', 'Category', 'Notes', 'Amount'],
        data: chunk.map((row) {
          final rawAmount =
              '${row.isIncome ? '+' : '-'}${row.amount.toCurrency(currency)}';
          final amountStr = PdfFontHelper.safeCurrencyText(rawAmount, font);
          return [
            row.timestampLabel,
            row.title,
            row.category,
            row.notes.isEmpty ? '-' : row.notes,
            amountStr,
          ];
        }).toList(),
      ),
    );
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
                style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                    fontWeight: pw.FontWeight.bold)),
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
