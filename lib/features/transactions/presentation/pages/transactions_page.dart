import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';
import 'package:trust_tracker_flutter/core/utils/extensions.dart';
import 'package:trust_tracker_flutter/features/categories/data/models/category_model.dart';
import 'package:trust_tracker_flutter/features/categories/data/repositories/category_repository.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/widgets/export_bottom_sheet.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:trust_tracker_flutter/generated/app_localizations.dart';

import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_filter.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/filter_utils.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/widgets/filter_bottom_sheet.dart';
import 'package:trust_tracker_flutter/features/categories/presentation/providers/category_provider.dart';

// --- Providers & State ---

class _GroupedResult {
  final List<_DayGroup> groups;
  final Map<int?, CategoryModel> catMap;
  _GroupedResult(this.groups, this.catMap);
}

class _DayGroup {
  final DateTime date;
  final List<TransactionModel> txns;
  final double dayTotal;
  _DayGroup(this.date, this.txns, this.dayTotal);
}

final _groupedFutureProvider = FutureProvider.autoDispose<_GroupedResult>((ref) async {
  final txnsAsync = ref.watch(transactionListProvider);
  
  if (txnsAsync.isLoading && !txnsAsync.isRefreshing) return _GroupedResult([], {});
  final listState = txnsAsync.valueOrNull;
  if (listState == null) return _GroupedResult([], {});
  
  final txns = listState.transactions;
  final filter = listState.filter;

  final groupsMap = <String, List<TransactionModel>>{};
  for (final t in txns) {
    final key = t.date.toIso8601String().split('T')[0];
    groupsMap.putIfAbsent(key, () => []).add(t);
  }
  
  // Respect the filter's sort order for date groups
  final sortedKeys = groupsMap.keys.toList();
  if (filter.sortBy == TransactionSortBy.date) {
    sortedKeys.sort((a, b) => filter.isAscending ? a.compareTo(b) : b.compareTo(a));
  } else {
    // Default to descending for other modes if not otherwise specified
    sortedKeys.sort((a, b) => b.compareTo(a));
  }

  final groups = sortedKeys.map((key) {
    final groupTxns = groupsMap[key]!;
    // If sorting by date, also sort within the group
    if (filter.sortBy == TransactionSortBy.date) {
       groupTxns.sort((a, b) => filter.isAscending ? a.date.compareTo(b.date) : b.date.compareTo(a.date));
    }
    double total = 0;
    for (final t in groupTxns) {
      total += (t.type == TransactionType.income ? t.amount : -t.amount);
    }
    return _DayGroup(DateTime.parse(key), groupTxns, total);
  }).toList();

  // Categories
  final catRepo = ref.watch(categoryRepositoryProvider);
  final cats = await catRepo.getAll();
  final Map<int?, CategoryModel> catMap = {for (final c in cats) c.id: c};

  return _GroupedResult(groups, catMap);
});

// --- Main Page ---

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      setState(() => _isSearching = _searchFocusNode.hasFocus);
    });
    
    // Set initial search text if any
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentFilter = ref.read(transactionListProvider).valueOrNull?.filter;
      if (currentFilter != null && currentFilter.searchQuery.isNotEmpty) {
        _searchController.text = currentFilter.searchQuery;
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _editTransaction(TransactionModel transaction) {
    context.push('/add-transaction', extra: {'edit': transaction});
  }

  void _duplicateTransaction(TransactionModel transaction) {
    context.push('/add-transaction', extra: {'duplicate': transaction});
  }

  void _confirmAndDeleteTransaction(TransactionModel transaction) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteConfirmationTitle),
        content: Text(AppLocalizations.of(context)!.deleteConfirmationMessage(transaction.description)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: cs.error),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(transactionListProvider.notifier).deleteTransaction(transaction.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.transactionDeleted)),
        );
      }
    }
  }

  void _openFilterBottomSheet() {
    final currentFilter = ref.read(transactionListProvider).valueOrNull?.filter ?? const TransactionFilter();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterBottomSheet(
        initialFilter: currentFilter,
        onApply: (newFilter) {
          ref.read(transactionListProvider.notifier).applyFilter(newFilter);
          if (newFilter.searchQuery != _searchController.text) {
             _searchController.text = newFilter.searchQuery;
          }
        },
      ),
    );
  }

  void _openExportBottomSheet() {
    final listState = ref.read(transactionListProvider).valueOrNull;
    final txns = listState?.transactions ?? [];
    final filter = listState?.filter ?? const TransactionFilter();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExportBottomSheet(
        transactions: txns,
        activeFilter: filter,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupedAsync = ref.watch(_groupedFutureProvider);
    final listAsync = ref.watch(transactionListProvider);
    final listState = listAsync.valueOrNull;
    final filter = listState?.filter ?? const TransactionFilter();
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final currency = settings.currency;
    final isTapMode = settings.transactionActionMode == TransactionActionMode.tap;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.transactions, style: tt.headlineMedium),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          actions: [
            IconButton(
              icon: Icon(Icons.file_download_outlined, color: cs.onSurface.withOpacity(0.6), size: 24),
              onPressed: _openExportBottomSheet,
              tooltip: AppLocalizations.of(context)!.export,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            _buildHeader(context, filter, cs, tt, theme, isDark),
            Expanded(
              child: groupedAsync.when(
                skipLoadingOnReload: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text("${AppLocalizations.of(context)!.error}: $err")),
                data: (result) {
                  final groups = result.groups;
                  final catMap = result.catMap;

                  if (groups.isEmpty && filter.isDefault) {
                    return _EmptyState(onAdd: () => context.push('/add-transaction'));
                  }

                  if (groups.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: cs.onSurface.withOpacity(0.2)),
                          const SizedBox(height: 16),
                          Text(
                            AppLocalizations.of(context)!.noResultsFound,
                            style: tt.bodyMedium?.copyWith(color: cs.onSurface.withOpacity(0.4)),
                          ),
                        ],
                      ),
                    );
                  }

                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    cacheExtent: 1000,
                    slivers: [
                      ...groups.map((g) => SliverMainAxisGroup(
                            slivers: [
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                                sliver: SliverToBoxAdapter(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        g.date.isSameDay(DateTime.now())
                                            ? AppLocalizations.of(context)!.today
                                            : g.date.toDisplayShort(),
                                        style: tt.labelSmall!.copyWith(
                                          color: cs.onSurface.withOpacity(0.4),
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                      Text(
                                        '${g.dayTotal >= 0 ? '+' : ''}${g.dayTotal.toCurrency(currency)}',
                                        style: (g.dayTotal >= 0 ? tt.positiveAmount : tt.negativeAmount).copyWith(
                                          fontSize: 10,
                                          color: (g.dayTotal >= 0 ? AppColors.success : cs.error).withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final t = g.txns[index];
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: _SwipeableTransactionTile(
                                          key: ValueKey(t.id!),
                                          transaction: t,
                                          category: catMap[t.categoryId],
                                          currency: currency,
                                          onEdit: () => _editTransaction(t),
                                          onDuplicate: () => _duplicateTransaction(t),
                                          onDelete: () => _confirmAndDeleteTransaction(t),
                                          isTapMode: isTapMode,
                                          onTap: () => _editTransaction(t),
                                        ),
                                      );
                                    },
                                    childCount: g.txns.length,
                                  ),
                                ),
                              ),
                            ],
                          )),
                      const SliverToBoxAdapter(child: SizedBox(height: 120)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildHeader(BuildContext context, TransactionFilter filter, ColorScheme cs, TextTheme tt, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 48,
                  decoration: BoxDecoration(
                    color: _isSearching ? cs.surface : cs.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: _isSearching ? cs.primary.withOpacity(0.5) : Colors.transparent,
                      width: 1.5,
                    ),
                    boxShadow: _isSearching 
                        ? [BoxShadow(color: cs.primary.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
                        : null,
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: (v) {
                       ref.read(transactionListProvider.notifier).applyFilter(filter.copyWith(searchQuery: v.toLowerCase()));
                    },
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.searchTransactions,
                      hintStyle: tt.bodyMedium?.copyWith(color: cs.onSurface.withOpacity(0.4)),
                      prefixIcon: Icon(
                        Icons.search_rounded, 
                        color: _isSearching ? cs.primary : cs.onSurface.withOpacity(0.4), 
                        size: 20
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      suffixIcon: filter.searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.cancel_rounded, size: 18, color: cs.onSurface.withOpacity(0.4)),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(transactionListProvider.notifier).applyFilter(filter.copyWith(searchQuery: ''));
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _openFilterBottomSheet,
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: !filter.isDefault ? cs.primary : cs.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: !filter.isDefault ? cs.onPrimary : cs.onSurface.withOpacity(0.6),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Container(
          //   height: 44,
          //   padding: const EdgeInsets.all(4),
          //   decoration: BoxDecoration(
          //     color: cs.surfaceVariant.withOpacity(0.5),
          //     borderRadius: BorderRadius.circular(12),
          //   ),
          //   child: Row(
          //     children: ['all', 'income', 'expense'].map((f) {
          //       final isSelected = filter.type == f;
          //       String label;
          //       if (f == 'all') label = AppLocalizations.of(context)!.all;
          //       else if (f == 'income') label = AppLocalizations.of(context)!.income;
          //       else label = AppLocalizations.of(context)!.expense;

          //       return Expanded(
          //         child: GestureDetector(
          //           onTap: () => ref.read(_txnFilterProvider.notifier).update((s) => s.copyWith(type: f)),
          //           child: AnimatedContainer(
          //             duration: const Duration(milliseconds: 200),
          //             decoration: BoxDecoration(
          //               color: isSelected ? cs.primary : Colors.transparent,
          //               borderRadius: BorderRadius.circular(10),
          //               boxShadow: isSelected
          //                   ? [BoxShadow(color: cs.primary.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]
          //                   : null,
          //             ),
          //             child: Center(
          //               child: Text(
          //                 label,
          //                 style: tt.labelLarge?.copyWith(
          //                   color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
          //                   fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          //                 ),
          //               ),
          //             ),
          //           ),
          //         ),
          //       );
          //     }).toList(),
          //   ),
          // ),
          if (!filter.isDefault) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    // --- Type Chip ---
                    if (filter.type != 'all')
                      _FilterChip(
                        label: filter.type.toUpperCase(),
                        icon: filter.type == 'income' ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        onRemove: () => ref.read(transactionListProvider.notifier).applyFilter(filter.copyWith(type: 'all')),
                      ).animate().scale(duration: 200.ms).fadeIn(),

                    // --- Date Chip ---
                    if (filter.dateRange != null)
                      _FilterChip(
                        label: '${DateFormat('MMM d').format(filter.dateRange!.start)} - ${DateFormat('MMM d').format(filter.dateRange!.end)}',
                        icon: Icons.calendar_today_rounded,
                        onRemove: () => ref.read(transactionListProvider.notifier).applyFilter(filter.copyWith(clearDateRange: true)),
                      ).animate().scale(duration: 200.ms).fadeIn(),

                    // --- Category Chips ---
                    if (filter.categoryIds.isNotEmpty)
                      ...ref.watch(allCategoriesProvider).when(
                        data: (cats) {
                          return filter.categoryIds.map((id) {
                            final cat = cats.firstWhere((c) => c.id == id, orElse: () => CategoryModel()..name = 'Unknown'..colorHex = '#808080');
                            return _FilterChip(
                              key: ValueKey('cat_$id'),
                              label: cat.name,
                              onRemove: () {
                                final newIds = List<int>.from(filter.categoryIds)..remove(id!);
                                ref.read(transactionListProvider.notifier).applyFilter(filter.copyWith(categoryIds: newIds));
                              },
                            ).animate().scale(duration: 200.ms).fadeIn();
                          });
                        },
                        loading: () => [],
                        error: (_, __) => [],
                      ),

                    // --- Sort Chip ---
                    if (filter.sortBy != TransactionSortBy.date || filter.isAscending)
                      _FilterChip(
                        label: '${filter.sortBy.name.toUpperCase()} ${filter.isAscending ? "↑" : "↓"}',
                        icon: Icons.sort_rounded,
                        onRemove: () => ref.read(transactionListProvider.notifier).applyFilter(filter.copyWith(sortBy: TransactionSortBy.date, isAscending: false)),
                      ).animate().scale(duration: 200.ms).fadeIn(),

                    // --- Clear All Chip ---
                    _FilterChip(
                      label: 'Clear All',
                      icon: Icons.refresh_rounded,
                      onRemove: () {
                        _searchController.clear();
                        ref.read(transactionListProvider.notifier).applyFilter(const TransactionFilter());
                      },
                    ).animate().scale(duration: 200.ms).fadeIn(),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// --- Sub-widgets ---

class _SwipeableTransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final CategoryModel? category;
  final String currency;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final bool isTapMode;

  const _SwipeableTransactionTile({
    super.key,
    required this.transaction,
    this.category,
    required this.currency,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.onTap,
    required this.isTapMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isIncome = transaction.type == TransactionType.income;
    final catColor = category != null ? Color(category!.colorHex.toColorInt()) : cs.onSurface.withOpacity(0.3);

    final innerContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(child: _buildTileContent(context, cs, catColor, isIncome)),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onDuplicate,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: cs.primary.withOpacity(0.08), shape: BoxShape.circle),
              child: Icon(Icons.content_copy_rounded, size: 14, color: cs.primary),
            ),
          ),
          if (isTapMode) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDelete,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: cs.error.withOpacity(0.08), shape: BoxShape.circle),
              child: Icon(Icons.close, size: 14, color: cs.error),
            ),
            ),
          ],
        ],
      ),
    );

    if (isTapMode) {
      return Container(
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outline.withOpacity(0.1)),
        ),
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: innerContent),
      );
    }

    return Slidable(
      key: ValueKey(transaction.id!),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
            icon: Icons.delete_outline_rounded,
            borderRadius: BorderRadius.circular(14),
          ),
        ],
      ),
      startActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            icon: Icons.edit_rounded,
            borderRadius: BorderRadius.circular(14),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outline.withOpacity(0.1)),
        ),
        child: innerContent,
      ),
    );
  }

  Widget _buildTileContent(BuildContext context, ColorScheme cs, Color catColor, bool isIncome) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final hasNote = transaction.note != null && transaction.note!.isNotEmpty;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: catColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Center(
            child: Text(
              transaction.description.isNotEmpty ? transaction.description[0].toUpperCase() : '?',
              style: tt.titleMedium?.copyWith(color: catColor, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transaction.description,
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${category?.name ?? AppLocalizations.of(context)!.uncategorized} · ${transaction.date.toTimeOnly()}',
                style: tt.labelSmall?.copyWith(color: cs.onSurface.withOpacity(0.4)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isIncome ? '+' : '-'}${transaction.amount.toCurrency(currency)}',
              style: (isIncome ? tt.positiveAmount : tt.negativeAmount).copyWith(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            if (hasNote)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.sticky_note_2_outlined, size: 10, color: cs.onSurface.withOpacity(0.2)),
              ),
          ],
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final cs = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: cs.onSurface.withOpacity(0.15)),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context)!.noTransactionsYet, style: tt.titleMedium?.copyWith(color: cs.onSurface.withOpacity(0.4))),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.of(context)!.addTransaction),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  final IconData? icon;

  const _FilterChip({super.key, required this.label, required this.onRemove, this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onRemove,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.primary.withOpacity(0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: cs.primary),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.close_rounded, size: 14, color: cs.primary.withOpacity(0.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
