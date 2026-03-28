import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:trust_tracker_flutter/core/utils/pdf_generator.dart';
import 'package:trust_tracker_flutter/core/utils/excel_generator.dart';
import 'package:trust_tracker_flutter/core/utils/extensions.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/export_transaction_row.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/categories/data/models/category_model.dart';
import 'package:trust_tracker_flutter/features/categories/data/repositories/category_repository.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';

enum ExportFormat { pdf, excel }

enum ExportTimeRange {
  thisMonth,
  lastMonth,
  last3Months,
  all,
  custom,
}

class ExportDateRange {
  final DateTime start;
  final DateTime end;
  ExportDateRange({required this.start, required this.end});
}

class ExportService {
  final Ref _ref;
  ExportService(this._ref);

  Future<void> exportData({
    required ExportFormat format,
    required List<TransactionModel> filteredTransactions,
    required String filterSummary,
  }) async {
    // 1. Resolve categories
    final categories = await _ref.read(categoryRepositoryProvider).getAll();
    final categoryMap = {for (var c in categories) c.id: c};
    final rows = _buildExportRows(filteredTransactions, categoryMap);

    // 2. Get currency
    final settings = _ref.read(settingsProvider);
    final currency = settings.currency;

    // 3. Generate file
    File file;
    if (format == ExportFormat.pdf) {
      file = await PdfGenerator.generate(
        rows: rows,
        currency: currency,
        dateRange: filterSummary,
      );
    } else {
      file = await ExcelGenerator.generate(
        rows: rows,
        currency: currency,
      );
    }

    // 4. Share file
    final xFile = XFile(file.path);
    await Share.shareXFiles([xFile], text: 'Trust Tracker Transaction Report');
  }

  List<TransactionModel> _filterTransactions(
    List<TransactionModel> all,
    ExportTimeRange range,
    ExportDateRange? custom,
  ) {
    final now = DateTime.now();
    late DateTime start;
    late DateTime end;

    switch (range) {
      case ExportTimeRange.thisMonth:
        start = DateTime(now.year, now.month, 1);
        end = now;
        break;
      case ExportTimeRange.lastMonth:
        start = DateTime(now.year, now.month - 1, 1);
        end = DateTime(now.year, now.month, 0);
        break;
      case ExportTimeRange.last3Months:
        start = DateTime(now.year, now.month - 3, 1);
        end = now;
        break;
      case ExportTimeRange.all:
        return all;
      case ExportTimeRange.custom:
        if (custom == null) return all;
        start = custom.start;
        end = custom.end;
        break;
    }

    return all.where((t) {
      return t.date.isAfter(start.subtract(const Duration(seconds: 1))) &&
          t.date.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  List<ExportTransactionRow> _buildExportRows(
    List<TransactionModel> transactions,
    Map<int, CategoryModel> categoryMap,
  ) {
    return transactions.map((transaction) {
      final category = categoryMap[transaction.categoryId];
      final isIncome = transaction.type == TransactionType.income;
      return ExportTransactionRow(
        timestamp: transaction.date,
        title: transaction.description,
        category: category?.name ?? 'Uncategorized',
        typeLabel: isIncome ? 'Income' : 'Expense',
        notes: transaction.note?.trim() ?? '',
        amount: transaction.amount,
        isIncome: isIncome,
      );
    }).toList();
  }

  String _getTimeRangeString(ExportTimeRange range, ExportDateRange? custom) {
    switch (range) {
      case ExportTimeRange.thisMonth:
        return 'Current Month';
      case ExportTimeRange.lastMonth:
        return 'Previous Month';
      case ExportTimeRange.last3Months:
        return 'Last 3 Months';
      case ExportTimeRange.all:
        return 'Full History';
      case ExportTimeRange.custom:
        if (custom == null) return 'Custom Range';
        return '${custom.start.toDisplayShort()} - ${custom.end.toDisplayShort()}';
    }
  }
}

final exportServiceProvider = Provider((ref) => ExportService(ref));
