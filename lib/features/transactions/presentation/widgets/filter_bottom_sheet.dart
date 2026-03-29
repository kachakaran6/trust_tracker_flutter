import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';
import 'package:trust_tracker_flutter/features/categories/data/models/category_model.dart';
import 'package:trust_tracker_flutter/features/categories/presentation/providers/category_provider.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_filter.dart';
import 'package:trust_tracker_flutter/core/utils/extensions.dart';

import 'package:trust_tracker_flutter/generated/app_localizations.dart';

class FilterBottomSheet extends ConsumerStatefulWidget {
  final TransactionFilter initialFilter;
  final Function(TransactionFilter) onApply;

  const FilterBottomSheet({
    super.key,
    required this.initialFilter,
    required this.onApply,
  });

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> {
  late TransactionFilter _currentFilter;

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.initialFilter;
  }

  void _reset() {
    setState(() {
      _currentFilter = const TransactionFilter();
    });
  }

  void _apply() {
    widget.onApply(_currentFilter);
    Navigator.pop(context);
  }

  Future<void> _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _currentFilter.dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Theme.of(context).colorScheme.primary,
                  onPrimary: Theme.of(context).colorScheme.onPrimary,
                  surface: Theme.of(context).colorScheme.surface,
                  onSurface: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          child: child!,
        );
      },
    );

    if (range != null) {
      setState(() {
        _currentFilter = _currentFilter.copyWith(dateRange: range);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final categoriesAsync = ref.watch(allCategoriesProvider);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.filterTransactions,
                        style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: _reset,
                      child: Text(l10n.reset,
                          style: TextStyle(color: cs.error, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- Transaction Type ---
                        Text(l10n.type, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          children: ['all', 'income', 'expense'].map((type) {
                            final isSelected = _currentFilter.type == type;
                            String label;
                            if (type == 'all')
                              label = l10n.all;
                            else if (type == 'income')
                              label = l10n.income;
                            else
                              label = l10n.expense;

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(label),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() => _currentFilter = _currentFilter.copyWith(type: type));
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),

                        // --- Sort By ---
                        Text(l10n.sortBy, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: TransactionSortBy.values.map((sort) {
                              final isSelected = _currentFilter.sortBy == sort;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(_getSortLabel(sort, l10n)),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() => _currentFilter = _currentFilter.copyWith(sortBy: sort));
                                    }
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _buildOrderChip(l10n, l10n.ascending, true),
                            const SizedBox(width: 8),
                            _buildOrderChip(l10n, l10n.descending, false),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // --- Date Range ---
                        Text(l10n.date, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: _selectDateRange,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: cs.outline.withOpacity(0.1)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 18, color: cs.primary),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _currentFilter.dateRange == null
                                        ? l10n.selectDateRange
                                        : '${DateFormat('MMM d, y').format(_currentFilter.dateRange!.start)} - ${DateFormat('MMM d, y').format(_currentFilter.dateRange!.end)}',
                                    style: tt.bodyMedium?.copyWith(
                                      color: _currentFilter.dateRange == null
                                          ? cs.onSurface.withOpacity(0.4)
                                          : cs.onSurface,
                                    ),
                                  ),
                                ),
                                if (_currentFilter.dateRange != null)
                                  GestureDetector(
                                    onTap: () => setState(() =>
                                        _currentFilter = _currentFilter.copyWith(clearDateRange: true)),
                                    child: Icon(Icons.close, size: 18, color: cs.onSurface.withOpacity(0.4)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // --- Categories ---
                        Text(l10n.categories, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        categoriesAsync.when(
                          data: (categories) {
                            return Wrap(
                              spacing: 8,
                              runSpacing: 0,
                              children: categories.map((cat) {
                                final isSelected = _currentFilter.categoryIds.contains(cat.id);
                                final color = Color(int.parse(cat.colorHex.replaceFirst('#', '0xFF')));
                                return FilterChip(
                                  label: Text(cat.name,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: isSelected ? cs.onSurface : cs.onSurface.withOpacity(0.7))),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      final newIds = List<int>.from(_currentFilter.categoryIds);
                                      if (selected) {
                                        newIds.add(cat.id);
                                      } else {
                                        newIds.remove(cat.id);
                                      }
                                      _currentFilter = _currentFilter.copyWith(categoryIds: newIds);
                                    });
                                  },
                                  selectedColor: color.withOpacity(0.2),
                                  checkmarkColor: color,
                                  avatar: Icon(Icons.circle, size: 10, color: color),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                );
                              }).toList(),
                            );
                          },
                          loading: () => const Center(child: LinearProgressIndicator()),
                          error: (_, __) => Text(l10n.errorLoadingCategories),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // --- Apply Button ---
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(l10n.applyFilter,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderChip(AppLocalizations l10n, String label, bool isAsc) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isSelected = _currentFilter.isAscending == isAsc;

    return ChoiceChip(
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _currentFilter = _currentFilter.copyWith(isAscending: isAsc));
        }
      },
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 16,
            color: isSelected ? cs.onPrimary : cs.primary,
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
    );
  }

  String _getSortLabel(TransactionSortBy sort, AppLocalizations l10n) {
    switch (sort) {
      case TransactionSortBy.date:
        return l10n.date;
      case TransactionSortBy.amount:
        return l10n.amount;
      case TransactionSortBy.description:
        return l10n.description;
    }
  }
}
