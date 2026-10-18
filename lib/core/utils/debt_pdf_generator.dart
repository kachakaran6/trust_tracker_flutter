import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';

class DebtPdfResult {
  final File file;
  final Uint8List bytes;
  final String fileName;

  DebtPdfResult({
    required this.file,
    required this.bytes,
    required this.fileName,
  });
}

class DebtPdfGenerator {
  /// Robust string sanitizer that strips emojis and unsupported Unicode characters
  /// that would otherwise crash the PDF font renderer or print tofu/unrecognized boxes.
  static String sanitizeText(String? input, {String fallback = '-'}) {
    if (input == null || input.trim().isEmpty) return fallback;
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      // Allow standard printable ASCII (letters, digits, punctuation, spaces)
      if (rune >= 32 && rune <= 126) {
        buffer.writeCharCode(rune);
      }
      // Allow Devanagari script (Hindi, Marathi, etc.)
      else if (rune >= 0x0900 && rune <= 0x097F) {
        buffer.writeCharCode(rune);
      }
      // Allow Latin-1 Supplement (common accents like é, ñ, etc.)
      else if (rune >= 0x00A0 && rune <= 0x00FF) {
        buffer.writeCharCode(rune);
      }
      // Allow common Currency Symbols
      else if (rune == 0x20B9 || rune == 0x20AC || rune == 0x00A3 || rune == 0x00A5) {
        buffer.writeCharCode(rune);
      }
      // Allow typographical dashes / bullets
      else if (rune == 0x2013 || rune == 0x2014 || rune == 0x2022) {
        buffer.writeCharCode(rune);
      }
      // Silently omit emojis (0x1F300-0x1FAFF), dingbats (0x2700-0x27BF), misc symbols (0x2600-0x26FF)
    }
    final cleaned = buffer.toString().trim();
    return cleaned.isEmpty ? fallback : cleaned;
  }

  static String _formatAmount(double amount, String currency) {
    final isRupee = currency.contains('₹') || currency.toUpperCase().contains('INR');
    final formatter = NumberFormat(isRupee ? '#,##,##0.00' : '#,##0.00', isRupee ? 'en_IN' : 'en_US');
    return formatter.format(amount);
  }

  static Future<DebtPdfResult> generate({
    required List<TransactionModel> transactions,
    required String currency,
    String? specificPerson,
    String filterTitle = 'All Records',
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();

    // 1. Robust font loading with safe fallbacks
    pw.Font fontRegular;
    pw.Font fontBold;
    bool isFallbackHelvetica = false;

    try {
      fontRegular = await PdfGoogleFonts.hindRegular();
      fontBold = await PdfGoogleFonts.hindBold();
    } catch (_) {
      try {
        fontRegular = await PdfGoogleFonts.robotoRegular();
        fontBold = await PdfGoogleFonts.robotoBold();
      } catch (_) {
        fontRegular = pw.Font.helvetica();
        fontBold = pw.Font.helveticaBold();
        isFallbackHelvetica = true;
      }
    }

    // In Helvetica, the Rupee glyph (U+20B9) is not supported and will throw an unhandled exception.
    // When using the fallback Helvetica font, safely represent ₹ as 'Rs. ' to prevent PDF crashes.
    final safeCurrency = (isFallbackHelvetica && currency.contains('₹'))
        ? currency.replaceAll('₹', 'Rs. ')
        : currency;

    // 2. Load logo if available
    pw.MemoryImage? logo;
    try {
      final logoData = await rootBundle.load('assets/images/2.png');
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    // 3. Filter transactions
    final filtered = specificPerson != null && specificPerson.trim().isNotEmpty
        ? transactions
            .where((t) => (t.personName ?? '').trim().toLowerCase() == specificPerson.trim().toLowerCase())
            .toList()
        : List<TransactionModel>.from(transactions);

    // Sort descending by date (newest first)
    filtered.sort((a, b) => b.date.compareTo(a.date));

    // 4. Financial Calculations
    double totalLent = 0;
    double totalBorrowed = 0;
    int activeCount = 0;
    int settledCount = 0;
    int overdueCount = 0;

    for (final t in filtered) {
      final isGiven = (t.debtType ?? 'given') == 'given';
      if (!t.isSettled) {
        activeCount++;
        if (isGiven) {
          totalLent += t.amount;
        } else {
          totalBorrowed += t.amount;
        }
        if (t.dueDate != null && t.dueDate!.isBefore(now)) {
          overdueCount++;
        }
      } else {
        settledCount++;
      }
    }

    final netBalance = totalLent - totalBorrowed;
    final isNetPositive = netBalance >= 0;

    // Contact group map for master summary
    final contactMap = <String, List<TransactionModel>>{};
    for (final t in filtered) {
      final rawName = sanitizeText(t.personName, fallback: 'Unnamed');
      contactMap.putIfAbsent(rawName, () => []).add(t);
    }

    // Colors
    final primaryBlue = PdfColor.fromHex('#1E40AF');
    final secondaryBlue = PdfColor.fromHex('#2563EB');
    final amberDark = PdfColor.fromHex('#B45309');
    final greenDark = PdfColor.fromHex('#047857');
    final borderGrey = PdfColor.fromHex('#E2E8F0');
    final bgLight = PdfColor.fromHex('#F8FAFC');

    // Chunks for transactions table to avoid page overflow
    final chunks = <List<TransactionModel>>[];
    const chunkSize = 25;
    for (var i = 0; i < filtered.length; i += chunkSize) {
      chunks.add(filtered.sublist(i, i + chunkSize > filtered.length ? filtered.length : i + chunkSize));
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 26),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        header: (context) => _buildHeader(
          logo: logo,
          now: now,
          specificPerson: specificPerson != null ? sanitizeText(specificPerson) : null,
          filterTitle: filterTitle,
          totalRecords: filtered.length,
          primaryBlue: primaryBlue,
          borderGrey: borderGrey,
          bgLight: bgLight,
        ),
        footer: (context) => _buildFooter(context, borderGrey),
        build: (context) => [
          // Executive Financial Metrics Cards
          _buildExecutiveSummary(
            currency: safeCurrency,
            totalLent: totalLent,
            totalBorrowed: totalBorrowed,
            netBalance: netBalance,
            isNetPositive: isNetPositive,
            activeCount: activeCount,
            settledCount: settledCount,
            overdueCount: overdueCount,
            primaryBlue: primaryBlue,
            amberDark: amberDark,
            greenDark: greenDark,
            borderGrey: borderGrey,
          ),
          pw.SizedBox(height: 18),

          // Master Contacts Summary (shown when multiple contacts exist)
          if (specificPerson == null && contactMap.length > 1) ...[
            pw.Text(
              'CONTACT BREAKDOWN SUMMARY',
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: primaryBlue,
                letterSpacing: 0.5,
              ),
            ),
            pw.SizedBox(height: 8),
            _buildContactsTable(
              contactMap: contactMap,
              currency: safeCurrency,
              borderGrey: borderGrey,
              bgLight: bgLight,
              primaryBlue: primaryBlue,
              amberDark: amberDark,
              greenDark: greenDark,
            ),
            pw.SizedBox(height: 20),
          ],

          // Detailed Ledger Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                specificPerson != null
                    ? 'TRANSACTION HISTORY WITH ${sanitizeText(specificPerson).toUpperCase()}'
                    : 'DETAILED TRANSACTION LEDGER',
                style: pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryBlue,
                  letterSpacing: 0.5,
                ),
              ),
              pw.Text(
                'Showing ${filtered.length} record(s)',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),

          if (filtered.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(24),
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                color: bgLight,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: borderGrey),
              ),
              child: pw.Text(
                'No transactions found for the selected filter.',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            )
          else
            ...chunks.map((chunk) => _buildLedgerTable(
                  chunk: chunk,
                  currency: safeCurrency,
                  showContact: specificPerson == null,
                  borderGrey: borderGrey,
                  bgLight: bgLight,
                  primaryBlue: secondaryBlue,
                  amberDark: amberDark,
                  greenDark: greenDark,
                )),

          pw.SizedBox(height: 20),

          // Statement Confirmation & Privacy Notice
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: bgLight,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: borderGrey),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 5,
                  height: 30,
                  decoration: pw.BoxDecoration(
                    color: primaryBlue,
                    borderRadius: pw.BorderRadius.circular(2.5),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'STATEMENT CONFIRMATION & INTEGRITY NOTICE',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'This document serves as an authentic financial ledger generated directly from the user\'s local encrypted device database via Trust Tracker. All entries reflect personal debt and lent transactions subject to mutual verification.',
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final pdfBytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final sanitizedPerson = (specificPerson ?? 'All')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
        .toLowerCase();
    final fileName = 'trust_tracker_debt_statement_${sanitizedPerson}_${now.millisecondsSinceEpoch}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(pdfBytes);

    return DebtPdfResult(
      file: file,
      bytes: pdfBytes,
      fileName: fileName,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildHeader({
    required pw.MemoryImage? logo,
    required DateTime now,
    required String? specificPerson,
    required String filterTitle,
    required int totalRecords,
    required PdfColor primaryBlue,
    required PdfColor borderGrey,
    required PdfColor bgLight,
  }) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Row(
              children: [
                if (logo != null) ...[
                  pw.Container(
                    width: 40,
                    height: 40,
                    margin: const pw.EdgeInsets.only(right: 12),
                    child: pw.Image(logo),
                  ),
                ],
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'TRUST TRACKER',
                      style: pw.TextStyle(
                        fontSize: 17,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryBlue,
                        letterSpacing: 0.8,
                      ),
                    ),
                    pw.Text(
                      specificPerson != null
                          ? 'ACCOUNT STATEMENT: ${specificPerson.toUpperCase()}'
                          : 'DEBT & LENT MASTER STATEMENT',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#EFF6FF'),
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColor.fromHex('#BFDBFE')),
              ),
              child: pw.Text(
                'OFFICIAL STATEMENT',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryBlue,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),

        // Metadata Strip
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: pw.BoxDecoration(
            color: bgLight,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: borderGrey),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildMetaItem('GENERATED ON', dateFormat.format(now)),
              _buildMetaItem('CONTACT SCOPE', specificPerson ?? 'All Contacts'),
              _buildMetaItem('FILTER SCOPE', filterTitle),
              _buildMetaItem('RECORDS', '$totalRecords items'),
            ],
          ),
        ),
        pw.SizedBox(height: 14),
      ],
    );
  }

  static pw.Widget _buildMetaItem(String title, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: const pw.TextStyle(
            fontSize: 7,
            color: PdfColors.grey600,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 8.5,
            color: PdfColors.grey900,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EXECUTIVE SUMMARY
  // ─────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildExecutiveSummary({
    required String currency,
    required double totalLent,
    required double totalBorrowed,
    required double netBalance,
    required bool isNetPositive,
    required int activeCount,
    required int settledCount,
    required int overdueCount,
    required PdfColor primaryBlue,
    required PdfColor amberDark,
    required PdfColor greenDark,
    required PdfColor borderGrey,
  }) {
    return pw.Row(
      children: [
        // Card 1: Lent (Asset)
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(11),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#EFF6FF'),
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColor.fromHex('#BFDBFE')),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL LENT OUT',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryBlue,
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: pw.BoxDecoration(
                        color: primaryBlue,
                        borderRadius: pw.BorderRadius.circular(3),
                      ),
                      child: pw.Text(
                        'ASSET',
                        style: pw.TextStyle(
                          fontSize: 6.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '$currency${_formatAmount(totalLent, currency)}',
                  style: pw.TextStyle(
                    fontSize: 14.5,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryBlue,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Money to receive from others',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 9),

        // Card 2: Borrowed (Liability)
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(11),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#FFFBEB'),
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColor.fromHex('#FDE68A')),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL BORROWED',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: amberDark,
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: pw.BoxDecoration(
                        color: amberDark,
                        borderRadius: pw.BorderRadius.circular(3),
                      ),
                      child: pw.Text(
                        'LIABILITY',
                        style: pw.TextStyle(
                          fontSize: 6.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '$currency${_formatAmount(totalBorrowed, currency)}',
                  style: pw.TextStyle(
                    fontSize: 14.5,
                    fontWeight: pw.FontWeight.bold,
                    color: amberDark,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Money to repay to others',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 9),

        // Card 3: Net Position
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(11),
            decoration: pw.BoxDecoration(
              color: isNetPositive
                  ? PdfColor.fromHex('#ECFDF5')
                  : PdfColor.fromHex('#FEF2F2'),
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(
                color: isNetPositive
                    ? PdfColor.fromHex('#A7F3D0')
                    : PdfColor.fromHex('#FECDD3'),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'NET BALANCE',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: isNetPositive ? greenDark : PdfColor.fromHex('#BE123C'),
                      ),
                    ),
                    if (overdueCount > 0)
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#FEE2E2'),
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                        child: pw.Text(
                          '$overdueCount OVERDUE',
                          style: pw.TextStyle(
                            fontSize: 6.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#B91C1C'),
                          ),
                        ),
                      ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '${isNetPositive ? '+' : '-'}$currency${_formatAmount(netBalance.abs(), currency)}',
                  style: pw.TextStyle(
                    fontSize: 14.5,
                    fontWeight: pw.FontWeight.bold,
                    color: isNetPositive ? greenDark : PdfColor.fromHex('#BE123C'),
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  isNetPositive
                      ? 'Net receivable from contacts'
                      : 'Net payable to contacts',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONTACTS BREAKDOWN TABLE
  // ─────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildContactsTable({
    required Map<String, List<TransactionModel>> contactMap,
    required String currency,
    required PdfColor borderGrey,
    required PdfColor bgLight,
    required PdfColor primaryBlue,
    required PdfColor amberDark,
    required PdfColor greenDark,
  }) {
    final entries = contactMap.entries.toList();

    return pw.Table(
      border: pw.TableBorder.all(color: borderGrey, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.6),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(1.8),
        3: pw.FlexColumnWidth(1.8),
        4: pw.FlexColumnWidth(2.0),
        5: pw.FlexColumnWidth(1.8),
      },
      children: [
        // Table Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _th('CONTACT NAME', align: pw.TextAlign.left),
            _th('TXNS', align: pw.TextAlign.center),
            _th('LENT OUT', align: pw.TextAlign.right),
            _th('BORROWED', align: pw.TextAlign.right),
            _th('NET BALANCE', align: pw.TextAlign.right),
            _th('STATUS', align: pw.TextAlign.center),
          ],
        ),
        // Rows
        ...entries.map((entry) {
          final person = entry.key;
          final txns = entry.value;

          double given = 0;
          double taken = 0;
          int active = 0;

          for (final t in txns) {
            if (!t.isSettled) {
              active++;
              if ((t.debtType ?? 'given') == 'given') {
                given += t.amount;
              } else {
                taken += t.amount;
              }
            }
          }

          final net = given - taken;
          final isPos = net >= 0;

          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: entry.key.hashCode % 2 == 0 ? PdfColors.white : bgLight,
            ),
            children: [
              _td(person, bold: true, align: pw.TextAlign.left),
              _td('${txns.length} (${active} active)', align: pw.TextAlign.center),
              _td('$currency${_formatAmount(given, currency)}', align: pw.TextAlign.right, color: primaryBlue),
              _td('$currency${_formatAmount(taken, currency)}', align: pw.TextAlign.right, color: amberDark),
              _td(
                '${isPos ? '+' : '-'}$currency${_formatAmount(net.abs(), currency)}',
                bold: true,
                align: pw.TextAlign.right,
                color: isPos ? greenDark : PdfColor.fromHex('#B91C1C'),
              ),
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: active == 0
                        ? PdfColor.fromHex('#F1F5F9')
                        : (isPos ? PdfColor.fromHex('#ECFDF5') : PdfColor.fromHex('#FEF2F2')),
                    borderRadius: pw.BorderRadius.circular(3),
                    border: pw.Border.all(
                      color: active == 0
                          ? borderGrey
                          : (isPos ? PdfColor.fromHex('#A7F3D0') : PdfColor.fromHex('#FECDD3')),
                      width: 0.5,
                    ),
                  ),
                  child: pw.Text(
                    active == 0
                        ? 'SETTLED'
                        : (isPos ? 'TO RECEIVE' : 'TO PAY'),
                    style: pw.TextStyle(
                      fontSize: 6.5,
                      fontWeight: pw.FontWeight.bold,
                      color: active == 0
                          ? PdfColors.grey700
                          : (isPos ? greenDark : PdfColor.fromHex('#B91C1C')),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DETAILED LEDGER TABLE
  // ─────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildLedgerTable({
    required List<TransactionModel> chunk,
    required String currency,
    required bool showContact,
    required PdfColor borderGrey,
    required PdfColor bgLight,
    required PdfColor primaryBlue,
    required PdfColor amberDark,
    required PdfColor greenDark,
  }) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final dueFormat = DateFormat('dd MMM yyyy');
    final now = DateTime.now();

    return pw.Table(
      border: pw.TableBorder.all(color: borderGrey, width: 0.5),
      columnWidths: showContact
          ? const {
              0: pw.FlexColumnWidth(2.0), // Date
              1: pw.FlexColumnWidth(1.8), // Contact
              2: pw.FlexColumnWidth(1.2), // Type
              3: pw.FlexColumnWidth(2.6), // Note/Desc
              4: pw.FlexColumnWidth(1.4), // Due Date
              5: pw.FlexColumnWidth(1.3), // Status
              6: pw.FlexColumnWidth(1.8), // Amount
            }
          : const {
              0: pw.FlexColumnWidth(2.2), // Date
              1: pw.FlexColumnWidth(1.2), // Type
              2: pw.FlexColumnWidth(3.2), // Note/Desc
              3: pw.FlexColumnWidth(1.5), // Due Date
              4: pw.FlexColumnWidth(1.4), // Status
              5: pw.FlexColumnWidth(2.0), // Amount
            },
      children: [
        // Table Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _th('DATE & TIME', align: pw.TextAlign.left),
            if (showContact) _th('CONTACT', align: pw.TextAlign.left),
            _th('TYPE', align: pw.TextAlign.center),
            _th('DESCRIPTION / NOTE', align: pw.TextAlign.left),
            _th('DUE DATE', align: pw.TextAlign.center),
            _th('STATUS', align: pw.TextAlign.center),
            _th('AMOUNT', align: pw.TextAlign.right),
          ],
        ),
        // Rows
        ...chunk.asMap().entries.map((entry) {
          final idx = entry.key;
          final t = entry.value;
          final isGiven = (t.debtType ?? 'given') == 'given';
          final isOverdue = !t.isSettled && t.dueDate != null && t.dueDate!.isBefore(now);

          final cleanDesc = t.description.isNotEmpty
              ? sanitizeText(t.description)
              : sanitizeText(t.note, fallback: '-');
          final cleanPerson = sanitizeText(t.personName, fallback: 'Unnamed');

          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: idx % 2 == 0 ? PdfColors.white : bgLight,
            ),
            children: [
              _td(dateFormat.format(t.date), align: pw.TextAlign.left),
              if (showContact)
                _td(cleanPerson, bold: true, align: pw.TextAlign.left),
              // Type Badge
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: pw.BoxDecoration(
                    color: isGiven ? PdfColor.fromHex('#EFF6FF') : PdfColor.fromHex('#FFFBEB'),
                    borderRadius: pw.BorderRadius.circular(3),
                    border: pw.Border.all(
                      color: isGiven ? PdfColor.fromHex('#BFDBFE') : PdfColor.fromHex('#FDE68A'),
                      width: 0.5,
                    ),
                  ),
                  child: pw.Text(
                    isGiven ? 'LENT' : 'BORROWED',
                    style: pw.TextStyle(
                      fontSize: 6.5,
                      fontWeight: pw.FontWeight.bold,
                      color: isGiven ? primaryBlue : amberDark,
                    ),
                  ),
                ),
              ),
              _td(cleanDesc, align: pw.TextAlign.left),
              // Due Date
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  t.dueDate != null ? dueFormat.format(t.dueDate!) : '-',
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: isOverdue ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: isOverdue ? PdfColor.fromHex('#B91C1C') : PdfColors.grey800,
                  ),
                ),
              ),
              // Status Badge
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: pw.BoxDecoration(
                    color: t.isSettled
                        ? PdfColor.fromHex('#ECFDF5')
                        : (isOverdue ? PdfColor.fromHex('#FEF2F2') : PdfColor.fromHex('#EFF6FF')),
                    borderRadius: pw.BorderRadius.circular(3),
                    border: pw.Border.all(
                      color: t.isSettled
                          ? PdfColor.fromHex('#A7F3D0')
                          : (isOverdue ? PdfColor.fromHex('#FECDD3') : PdfColor.fromHex('#BFDBFE')),
                      width: 0.5,
                    ),
                  ),
                  child: pw.Text(
                    t.isSettled ? 'SETTLED' : (isOverdue ? 'OVERDUE' : 'ACTIVE'),
                    style: pw.TextStyle(
                      fontSize: 6.5,
                      fontWeight: pw.FontWeight.bold,
                      color: t.isSettled
                          ? greenDark
                          : (isOverdue ? PdfColor.fromHex('#B91C1C') : primaryBlue),
                    ),
                  ),
                ),
              ),
              // Amount
              _td(
                '${isGiven ? '-' : '+'}$currency${_formatAmount(t.amount, currency)}',
                bold: true,
                align: pw.TextAlign.right,
                color: isGiven ? primaryBlue : amberDark,
              ),
            ],
          );
        }),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FOOTER
  // ─────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildFooter(pw.Context context, PdfColor borderGrey) {
    return pw.Column(
      children: [
        pw.Divider(color: borderGrey, thickness: 0.5),
        pw.SizedBox(height: 5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Trust Tracker - Debt & Lent Ledger Statement - Confidential',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────
  static pw.Widget _th(String title, {pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 5),
      child: pw.Text(
        title,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey800,
        ),
      ),
    );
  }

  static pw.Widget _td(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? color,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColors.grey900,
        ),
      ),
    );
  }
}
