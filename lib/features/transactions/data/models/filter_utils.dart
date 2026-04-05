import 'package:flutter/material.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_filter.dart';

class FilterUtils {
  static List<TransactionModel> applyFilter(
    List<TransactionModel> data,
    TransactionFilter filter,
  ) {
    final filtered = data.where((t) {
      // 1. Transaction Type
      bool matchesType = true;
      if (filter.type == 'income') {
        matchesType = t.type == TransactionType.income;
      } else if (filter.type == 'expense') {
        matchesType = t.type == TransactionType.expense;
      }

      // 2. Search Query
      bool matchesSearch = true;
      if (filter.searchQuery.isNotEmpty) {
        final query = filter.searchQuery.toLowerCase();
        matchesSearch = t.description.toLowerCase().contains(query) ||
            (t.note?.toLowerCase().contains(query) ?? false);
      }

      // 3. Category IDs
      bool matchesCategory = true;
      if (filter.categoryIds.isNotEmpty) {
        matchesCategory = t.categoryId != null && filter.categoryIds.contains(t.categoryId!);
      }

      // 4. Date Range
      bool matchesDate = true;
      if (filter.dateRange != null) {
        final date = DateTime(t.date.year, t.date.month, t.date.day);
        final start = DateTime(
          filter.dateRange!.start.year,
          filter.dateRange!.start.month,
          filter.dateRange!.start.day,
        );
        final end = DateTime(
          filter.dateRange!.end.year,
          filter.dateRange!.end.month,
          filter.dateRange!.end.day,
        );
        matchesDate = (date.isAtSameMomentAs(start) || date.isAfter(start)) &&
            (date.isAtSameMomentAs(end) || date.isBefore(end));
      }

      return matchesType && matchesSearch && matchesCategory && matchesDate;
    }).toList();

    // 5. Sorting
    filtered.sort((a, b) {
      int comparison = 0;
      switch (filter.sortBy) {
        case TransactionSortBy.date:
          comparison = a.date.compareTo(b.date);
          break;
        case TransactionSortBy.amount:
          comparison = a.amount.compareTo(b.amount);
          break;
        case TransactionSortBy.description:
          comparison = a.description.toLowerCase().compareTo(b.description.toLowerCase());
          break;
      }
      return filter.isAscending ? comparison : -comparison;
    });

    return filtered;
  }

  static String getFilterSummary(TransactionFilter filter, BuildContext context) {
    if (filter.isDefault) return 'All Transactions';
    
    final List<String> parts = [];
    
    if (filter.type != 'all') {
      parts.add(filter.type[0].toUpperCase() + filter.type.substring(1));
    }
    
    if (filter.categoryIds.isNotEmpty) {
      parts.add('${filter.categoryIds.length} Categories');
    }
    
    if (filter.dateRange != null) {
      parts.add('Custom Date Range');
    }
    
    if (filter.searchQuery.isNotEmpty) {
      parts.add('"${filter.searchQuery}"');
    }
    
    return parts.join(' • ');
  }
}
