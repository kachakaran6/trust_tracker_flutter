import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/categories/data/models/category_model.dart';
import 'package:trust_tracker_flutter/core/utils/extensions.dart';
import 'package:intl/intl.dart';

final _pdfFormatter = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

class ReportService {
  Future<void> generateAndShareReport({
    required List<TransactionModel> transactions,
    required List<CategoryModel> categories,
    required String currency,
    required DateTimeRange dateRange,
    required String reportType, // 'All', 'Income', 'Expense'
    bool includeGraphs = true,
    bool includeSummary = true,
    Uint8List? pieChartImage,
    Uint8List? barChartImage,
  }) async {
    final pdf = pw.Document();

    // Load fonts for Unicode support
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    // 1. Calculations
    double totalIncome = 0;
    double totalExpense = 0;
    final categoryTotals = <int, double>{};

    for (final t in transactions) {
      if (t.type == TransactionType.income) {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
        final catId = t.categoryId ?? 0;
        categoryTotals[catId] = (categoryTotals[catId] ?? 0) + t.amount;
      }
    }

    final netBalance = totalIncome - totalExpense;

    // 2. Build PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        build: (context) => [
          _buildHeader(dateRange),
          pw.SizedBox(height: 24),
          if (includeSummary) _buildSummary(totalIncome, totalExpense, netBalance, currency),
          if (includeGraphs && (pieChartImage != null || barChartImage != null)) ...[
            pw.SizedBox(height: 24),
            _buildGraphs(pieChartImage, barChartImage),
          ],
          pw.SizedBox(height: 32),
          pw.Text('TRANSACTION LOG', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          pw.SizedBox(height: 12),
          _buildTransactionTable(transactions, categories, currency),
        ],
        footer: (context) => _buildFooter(context),
      ),
    );

    // 3. Save and Share
    final bytes = await pdf.save();
    final fileName = "trust_tracker_report_${DateTime.now().millisecondsSinceEpoch}.pdf";
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles([XFile(file.path)], subject: 'Trust Tracker Financial Report');
  }

  pw.Widget _buildHeader(DateTimeRange range) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Trust Tracker', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.Text('Financial Activity Report', style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('GENERATED ON', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
            pw.Text(DateFormat('dd MMM yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 4),
            pw.Text('PERIOD', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
            pw.Text('${DateFormat('dd MMM').format(range.start)} - ${DateFormat('dd MMM yyyy').format(range.end)}', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildSummary(double income, double expense, double balance, String currency) {
    return pw.Row(
      children: [
        _summaryItem('Total Income', _pdfFormatter.format(income), PdfColors.green800, PdfColors.green50),
        pw.SizedBox(width: 12),
        _summaryItem('Total Expense', _pdfFormatter.format(-expense), PdfColors.red800, PdfColors.red50),
        pw.SizedBox(width: 12),
        _summaryItem('Net Balance', _pdfFormatter.format(balance), balance >= 0 ? PdfColors.blue800 : PdfColors.red800, balance >= 0 ? PdfColors.blue50 : PdfColors.red50),
      ],
    );
  }

  pw.Widget _summaryItem(String label, String value, PdfColor textColor, PdfColor bgColor) {
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
            pw.Text(label, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: textColor)),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildGraphs(Uint8List? pie, Uint8List? bar) {
    return pw.Row(
      children: [
        if (pie != null)
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey200),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
              ),
              child: pw.Column(
                children: [
                  pw.Text('Spending Breakdown', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  pw.SizedBox(height: 12),
                  pw.Image(pw.MemoryImage(pie), height: 160),
                ],
              ),
            ),
          ),
        if (pie != null && bar != null) pw.SizedBox(width: 12),
        if (bar != null)
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey200),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
              ),
              child: pw.Column(
                children: [
                  pw.Text('Monthly Performance', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  pw.SizedBox(height: 12),
                  pw.Image(pw.MemoryImage(bar), height: 160),
                ],
              ),
            ),
          ),
      ],
    );
  }

  pw.Widget _buildTransactionTable(List<TransactionModel> txns, List<CategoryModel> categories, String currency) {
    final headers = ['Date', 'Description', 'Category', 'Amount'];
    final data = txns.map((t) {
      final category = categories.where((c) => c.id == t.categoryId).firstOrNull;
      return [
        DateFormat('dd MMM').format(t.date),
        t.description,
        category?.name ?? 'Uncategorized',
        pw.Text(
          _pdfFormatter.format(t.type == TransactionType.income ? t.amount : -t.amount),
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: t.type == TransactionType.income ? PdfColors.green800 : PdfColors.red800,
          ),
        ),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: null,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.blue800,
        borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(6)),
      ),
      cellHeight: 32,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
      },
      cellStyle: const pw.TextStyle(fontSize: 10),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 32),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount} | Generated via Trust Tracker',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
      ),
    );
  }
}

final reportServiceProvider = Provider<ReportService>((ref) {
  return ReportService();
});
