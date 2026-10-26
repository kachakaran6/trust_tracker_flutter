import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';
import 'package:trust_tracker_flutter/features/categories/data/models/category_model.dart';
import 'package:trust_tracker_flutter/features/categories/data/repositories/category_repository.dart';
import 'package:trust_tracker_flutter/features/categories/presentation/providers/category_provider.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/transactions/data/repositories/transaction_repository.dart';
import 'package:trust_tracker_flutter/features/transactions/data/services/export_service.dart';
import 'package:trust_tracker_flutter/generated/app_localizations.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_filter.dart';

class ExportBottomSheet extends ConsumerStatefulWidget {
  final List<TransactionModel> transactions;
  final TransactionFilter activeFilter;
  const ExportBottomSheet({super.key, required this.transactions, required this.activeFilter});

  @override
  ConsumerState<ExportBottomSheet> createState() => _ExportBottomSheetState();
}

class _ExportBottomSheetState extends ConsumerState<ExportBottomSheet> {
  ExportFormat _selectedFormat = ExportFormat.pdf;
  ExportTimeRange _selectedRange = ExportTimeRange.thisMonth;
  ExportDateRange? _customRange;
  late String _selectedType;
  late List<int> _selectedCategoryIds;
  int? _matchingCount;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.activeFilter.type;
    _selectedCategoryIds = List<int>.from(widget.activeFilter.categoryIds);
    if (widget.activeFilter.dateRange != null) {
      _selectedRange = ExportTimeRange.custom;
      _customRange = ExportDateRange(
        start: widget.activeFilter.dateRange!.start,
        end: widget.activeFilter.dateRange!.end,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateMatchingCount();
    });
  }

  TransactionFilter _buildExportFilter() {
    final range = _getPresetRange(_selectedRange);
    return widget.activeFilter.copyWith(
      type: _selectedType,
      categoryIds: _selectedCategoryIds,
      dateRange: range,
      clearDateRange: range == null,
      isAscending: true,
      sortBy: TransactionSortBy.date,
    );
  }

  Future<void> _updateMatchingCount() async {
    final filter = _buildExportFilter();
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final list = await repo.getFilteredForExport(filter);
      if (mounted) {
        setState(() {
          _matchingCount = list.length;
        });
      }
    } catch (_) {}
  }

  void _resetFilters() {
    setState(() {
      _selectedRange = ExportTimeRange.thisMonth;
      _customRange = null;
      _selectedType = 'all';
      _selectedCategoryIds.clear();
    });
    _updateMatchingCount();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final categoriesAsync = ref.watch(allCategoriesProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(cs, tt, l10n),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. SELECT FORMAT
                  Text(l10n.selectFormat, style: tt.sectionLabel),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _ExportFormatCard(
                        format: ExportFormat.pdf,
                        title: l10n.pdfReport,
                        description: l10n.pdfReportDesc,
                        icon: Icons.picture_as_pdf_outlined,
                        isSelected: _selectedFormat == ExportFormat.pdf,
                        onTap: () => setState(() => _selectedFormat = ExportFormat.pdf),
                        activeColor: cs.error,
                        cs: cs,
                        tt: tt,
                      ),
                      const SizedBox(width: 12),
                      _ExportFormatCard(
                        format: ExportFormat.excel,
                        title: l10n.excelExport,
                        description: l10n.excelExportDesc,
                        icon: Icons.table_chart_outlined,
                        isSelected: _selectedFormat == ExportFormat.excel,
                        onTap: () => setState(() => _selectedFormat = ExportFormat.excel),
                        activeColor: AppColors.success,
                        cs: cs,
                        tt: tt,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // 2. DATE RANGE
                  Text(l10n.dateRangeCaps, style: tt.sectionLabel),
                  const SizedBox(height: 10),
                  _buildRangeSelector(cs, tt, l10n),
                  if (_selectedRange == ExportTimeRange.custom) ...[
                    const SizedBox(height: 10),
                    _CustomRangePicker(
                      range: _customRange != null
                          ? DateTimeRange(start: _customRange!.start, end: _customRange!.end)
                          : null,
                      onTap: _pickCustomRange,
                      l10n: l10n,
                      cs: cs,
                      tt: tt,
                    ),
                  ],
                  const SizedBox(height: 22),

                  // 3. TRANSACTION TYPE
                  Text(l10n.type.toUpperCase(), style: tt.sectionLabel),
                  const SizedBox(height: 10),
                  _buildTypeSelector(cs, tt, l10n),
                  const SizedBox(height: 22),

                  // 4. CATEGORIES
                  Text(l10n.categoriesCaps, style: tt.sectionLabel),
                  const SizedBox(height: 10),
                  categoriesAsync.when(
                    data: (categories) => _buildCategorySelector(cs, tt, l10n, categories),
                    loading: () => const SizedBox(
                      height: 38,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    error: (_, __) => Text(
                      l10n.errorLoadingCategories,
                      style: tt.bodySmall?.copyWith(color: cs.error),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 5. LIVE MATCH COUNTER BADGE
          _buildMatchCountBadge(cs, tt, l10n),
          const SizedBox(height: 14),

          // 6. GENERATE EXPORT BUTTON
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: (_isExporting || (_matchingCount != null && _matchingCount == 0))
                  ? null
                  : _handleExport,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isExporting
                  ? SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(color: cs.onPrimary, strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.file_download_outlined, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          _matchingCount != null && _matchingCount! > 0
                              ? '${l10n.generateExport} ($_matchingCount)'
                              : l10n.generateExport,
                          style: tt.titleMedium?.copyWith(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs, TextTheme tt, AppLocalizations l10n) {
    final hasActiveCustomFilter = _selectedRange != ExportTimeRange.thisMonth ||
        _selectedType != 'all' ||
        _selectedCategoryIds.isNotEmpty;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.exportTransactions, style: tt.headlineSmall),
            const SizedBox(height: 4),
            Text(l10n.exportDesc, style: tt.bodySmall),
          ],
        ),
        Row(
          children: [
            if (hasActiveCustomFilter)
              TextButton(
                onPressed: _resetFilters,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  l10n.reset,
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close, color: cs.onSurfaceVariant),
              style: IconButton.styleFrom(backgroundColor: cs.surfaceContainerHighest),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeSelector(ColorScheme cs, TextTheme tt, AppLocalizations l10n) {
    final types = [
      {'key': 'all', 'label': l10n.all, 'color': cs.primary, 'icon': Icons.swap_horiz_rounded},
      {'key': 'income', 'label': l10n.income, 'color': AppColors.success, 'icon': Icons.arrow_downward_rounded},
      {'key': 'expense', 'label': l10n.expense, 'color': cs.error, 'icon': Icons.arrow_upward_rounded},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: types.map((item) {
          final key = item['key'] as String;
          final label = item['label'] as String;
          final color = item['color'] as Color;
          final icon = item['icon'] as IconData;
          final selected = _selectedType == key;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedType != key) {
                  setState(() {
                    _selectedType = key;
                    _selectedCategoryIds.clear();
                  });
                  _updateMatchingCount();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 40,
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: selected ? cs.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: selected ? Border.all(color: color.withValues(alpha: 0.4), width: 1.5) : null,
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: cs.shadow.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: selected ? color : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: tt.labelLarge?.copyWith(
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                        color: selected ? color : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategorySelector(
    ColorScheme cs,
    TextTheme tt,
    AppLocalizations l10n,
    List<CategoryModel> allCategories,
  ) {
    final filteredCategories = allCategories.where((c) {
      if (_selectedType == 'income') {
        return c.type == CategoryType.income;
      } else if (_selectedType == 'expense') {
        return c.type == CategoryType.expense;
      }
      return true;
    }).toList();

    final isAllSelected = _selectedCategoryIds.isEmpty;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          label: Text(
            l10n.all,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isAllSelected ? FontWeight.w700 : FontWeight.w500,
              color: isAllSelected ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
          selected: isAllSelected,
          onSelected: (_) {
            if (!isAllSelected) {
              setState(() => _selectedCategoryIds.clear());
              _updateMatchingCount();
            }
          },
          backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          selectedColor: cs.primary.withValues(alpha: 0.18),
          checkmarkColor: cs.primary,
          showCheckmark: isAllSelected,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isAllSelected ? cs.primary : Colors.transparent,
              width: 1,
            ),
          ),
        ),
        ...filteredCategories.map((cat) {
          final isSelected = _selectedCategoryIds.contains(cat.id);
          Color catColor = cs.primary;
          try {
            catColor = Color(int.parse(cat.colorHex.replaceFirst('#', '0xFF')));
          } catch (_) {}

          return FilterChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (cat.iconName.isNotEmpty) ...[
                  Text(cat.iconName, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                ],
                Text(
                  cat.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? catColor : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                if (selected) {
                  _selectedCategoryIds.add(cat.id!);
                } else {
                  _selectedCategoryIds.remove(cat.id!);
                }
              });
              _updateMatchingCount();
            },
            backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
            selectedColor: catColor.withValues(alpha: 0.18),
            checkmarkColor: catColor,
            showCheckmark: isSelected,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isSelected ? catColor : Colors.transparent,
                width: 1,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMatchCountBadge(ColorScheme cs, TextTheme tt, AppLocalizations l10n) {
    final count = _matchingCount;
    final isNone = count == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isNone
            ? cs.error.withValues(alpha: 0.08)
            : cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isNone
              ? cs.error.withValues(alpha: 0.3)
              : cs.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isNone ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
            size: 18,
            color: isNone ? cs.error : cs.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              count == null
                  ? 'Calculating matching transactions...'
                  : isNone
                      ? 'No transactions found matching this filter.'
                      : '$count transaction${count == 1 ? '' : 's'} ready to export',
              style: tt.bodySmall?.copyWith(
                color: isNone ? cs.error : cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeSelector(ColorScheme cs, TextTheme tt, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _RangeButton(
                label: l10n.thisMonth,
                selected: _selectedRange == ExportTimeRange.thisMonth,
                onTap: () {
                  setState(() => _selectedRange = ExportTimeRange.thisMonth);
                  _updateMatchingCount();
                },
                cs: cs,
                tt: tt,
              ),
              _RangeButton(
                label: l10n.lastMonth,
                selected: _selectedRange == ExportTimeRange.lastMonth,
                onTap: () {
                  setState(() => _selectedRange = ExportTimeRange.lastMonth);
                  _updateMatchingCount();
                },
                cs: cs,
                tt: tt,
              ),
            ],
          ),
          Row(
            children: [
              _RangeButton(
                label: l10n.threeMonths,
                selected: _selectedRange == ExportTimeRange.last3Months,
                onTap: () {
                  setState(() => _selectedRange = ExportTimeRange.last3Months);
                  _updateMatchingCount();
                },
                cs: cs,
                tt: tt,
              ),
              _RangeButton(
                label: l10n.allHistory,
                selected: _selectedRange == ExportTimeRange.all,
                onTap: () {
                  setState(() => _selectedRange = ExportTimeRange.all);
                  _updateMatchingCount();
                },
                cs: cs,
                tt: tt,
              ),
              _RangeButton(
                label: l10n.custom,
                selected: _selectedRange == ExportTimeRange.custom,
                onTap: () {
                  setState(() => _selectedRange = ExportTimeRange.custom);
                  if (_customRange == null) {
                    _pickCustomRange();
                  } else {
                    _updateMatchingCount();
                  }
                },
                cs: cs,
                tt: tt,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _customRange != null
          ? DateTimeRange(start: _customRange!.start, end: _customRange!.end)
          : null,
      builder: (context, child) {
        final cs = Theme.of(context).colorScheme;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: cs.copyWith(
              primary: cs.primary,
              onPrimary: cs.onPrimary,
              surface: cs.surface,
              onSurface: cs.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _customRange = ExportDateRange(start: picked.start, end: picked.end));
      _updateMatchingCount();
    }
  }

  DateTimeRange? _getPresetRange(ExportTimeRange range) {
    final now = DateTime.now();
    switch (range) {
      case ExportTimeRange.thisMonth:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
      case ExportTimeRange.lastMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month - 1, 1),
          end: DateTime(now.year, now.month, 0, 23, 59, 59),
        );
      case ExportTimeRange.last3Months:
        return DateTimeRange(start: DateTime(now.year, now.month - 3, 1), end: now);
      case ExportTimeRange.custom:
        return _customRange != null
            ? DateTimeRange(start: _customRange!.start, end: _customRange!.end)
            : null;
      case ExportTimeRange.all:
        return null;
    }
  }

  String _generateFilterSummary(List<CategoryModel> categories) {
    final List<String> parts = [];

    // 1. Date Range
    switch (_selectedRange) {
      case ExportTimeRange.thisMonth:
        parts.add('This Month');
        break;
      case ExportTimeRange.lastMonth:
        parts.add('Last Month');
        break;
      case ExportTimeRange.last3Months:
        parts.add('Last 3 Months');
        break;
      case ExportTimeRange.all:
        parts.add('All History');
        break;
      case ExportTimeRange.custom:
        if (_customRange != null) {
          final fmt = DateFormat('dd MMM yyyy');
          parts.add('${fmt.format(_customRange!.start)} - ${fmt.format(_customRange!.end)}');
        } else {
          parts.add('Custom Date Range');
        }
        break;
    }

    // 2. Type
    if (_selectedType == 'income') {
      parts.add('Income Only');
    } else if (_selectedType == 'expense') {
      parts.add('Expense Only');
    }

    // 3. Category
    if (_selectedCategoryIds.isNotEmpty) {
      if (_selectedCategoryIds.length == 1) {
        final cat = categories.where((c) => c.id == _selectedCategoryIds.first).firstOrNull;
        if (cat != null) {
          parts.add(cat.name);
        } else {
          parts.add('1 Category');
        }
      } else {
        parts.add('${_selectedCategoryIds.length} Categories');
      }
    }

    return parts.isEmpty ? 'All Transactions' : parts.join(' • ');
  }

  Future<void> _handleExport() async {
    if (_selectedRange == ExportTimeRange.custom && _customRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseSelectDateRange)),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final exportFilter = _buildExportFilter();
      final repo = ref.read(transactionRepositoryProvider);
      final filteredTxns = await repo.getFilteredForExport(exportFilter);

      if (filteredTxns.isEmpty) {
        throw 'No transactions found for the selected filter and range';
      }

      final categories = await ref.read(categoryRepositoryProvider).getAll();
      final filterSummary = _generateFilterSummary(categories);

      await ref.read(exportServiceProvider).exportData(
        format: _selectedFormat,
        filteredTransactions: filteredTxns,
        filterSummary: filterSummary,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}

class _ExportFormatCard extends StatelessWidget {
  final ExportFormat format;
  final String title, description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeColor;
  final ColorScheme cs;
  final TextTheme tt;

  const _ExportFormatCard({
    required this.format,
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.activeColor,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.1) : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? activeColor : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: isSelected ? activeColor : cs.onSurfaceVariant, size: 30),
              const SizedBox(height: 16),
              Text(title, style: tt.titleSmall),
              const SizedBox(height: 4),
              Text(description, style: tt.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _RangeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;

  const _RangeButton({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: selected ? cs.surface : cs.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: tt.labelLarge?.copyWith(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomRangePicker extends StatelessWidget {
  final DateTimeRange? range;
  final VoidCallback onTap;
  final AppLocalizations l10n;
  final ColorScheme cs;
  final TextTheme tt;

  const _CustomRangePicker({
    this.range,
    required this.onTap,
    required this.l10n,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.date_range_outlined, size: 20, color: cs.primary),
            const SizedBox(width: 12),
            Text(
              range == null
                  ? l10n.selectDateRange
                  : '${dateFormat.format(range!.start)} - ${dateFormat.format(range!.end)}',
              style: tt.titleSmall,
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, size: 20, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
