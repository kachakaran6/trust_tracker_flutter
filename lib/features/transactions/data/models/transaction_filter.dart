import 'package:flutter/material.dart';

enum TransactionSortBy { date, amount, description }

class TransactionFilter {
  final String type; // 'all', 'income', 'expense'
  final List<int> categoryIds;
  final DateTimeRange? dateRange;
  final String searchQuery;
  final TransactionSortBy sortBy;
  final bool isAscending;

  const TransactionFilter({
    this.type = 'all',
    this.categoryIds = const [],
    this.dateRange,
    this.searchQuery = '',
    this.sortBy = TransactionSortBy.date,
    this.isAscending = false, // Default to newest first
  });

  TransactionFilter copyWith({
    String? type,
    List<int>? categoryIds,
    DateTimeRange? dateRange,
    String? searchQuery,
    TransactionSortBy? sortBy,
    bool? isAscending,
    bool clearDateRange = false,
  }) {
    return TransactionFilter(
      type: type ?? this.type,
      categoryIds: categoryIds ?? this.categoryIds,
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      isAscending: isAscending ?? this.isAscending,
    );
  }

  bool get isDefault =>
      type == 'all' &&
      categoryIds.isEmpty &&
      dateRange == null &&
      searchQuery.isEmpty &&
      sortBy == TransactionSortBy.date &&
      isAscending == false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionFilter &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          categoryIds == other.categoryIds &&
          dateRange == other.dateRange &&
          searchQuery == other.searchQuery &&
          sortBy == other.sortBy &&
          isAscending == other.isAscending;

  @override
  int get hashCode =>
      type.hashCode ^
      categoryIds.hashCode ^
      dateRange.hashCode ^
      searchQuery.hashCode ^
      sortBy.hashCode ^
      isAscending.hashCode;
}
