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
import 'package:trust_tracker_flutter/core/utils/category_utils.dart';

import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_filter.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/filter_utils.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/widgets/filter_bottom_sheet.dart';
import 'package:trust_tracker_flutter/features/categories/presentation/providers/category_provider.dart';

// --- Providers & State ---

class _GroupedResult {
  final List<_DayGroup> groups;
  final Map<int?, CategoryModel> catMap;
  final double monthlyTotal;
  final String topCategory;
  final double filteredTotal;
  final int filteredCount;
  final String summaryTitle;

  _GroupedResult(this.groups, this.catMap, this.monthlyTotal, this.topCategory, this.filteredTotal, this.filteredCount, this.summaryTitle);
}

class _DayGroup {
  final DateTime date;
  final List<TransactionModel> txns;
  final double dayTotal;
  _DayGroup(this.date, this.txns, this.dayTotal);
}

final _groupedFutureProvider = FutureProvider.autoDispose<_GroupedResult>((ref) async {
  final txnsAsync = ref.watch(transactionListProvider);
  
  if (txnsAsync.isLoading && !txnsAsync.isRefreshing) return _GroupedResult([], {}, 0, '', 0, 0, 'Overall');
  final listState = txnsAsync.valueOrNull;
  if (listState == null) return _GroupedResult([], {}, 0, '', 0, 0, 'Overall');
  
  final txns = listState.transactions;
  final filter = listState.filter;

  final groupsMap = <String, List<TransactionModel>>{};
  double monthlyTotal = 0;
  final catSpendMap = <int, double>{};

  final now = DateTime.now();
  final currentMonth = now.month;
  final currentYear = now.year;

  for (final t in txns) {
    final key = t.date.toIso8601String().split('T')[0];
    groupsMap.putIfAbsent(key, () => []).add(t);
    
    if (t.type == TransactionType.expense) {
      if (t.date.month == currentMonth && t.date.year == currentYear) {
        monthlyTotal += t.amount;
        if (t.categoryId != null) {
          catSpendMap[t.categoryId!] = (catSpendMap[t.categoryId!] ?? 0) + t.amount;
        }
      }
    }
  }
  
  // Respect the filter's sort order for date groups
  final sortedKeys = groupsMap.keys.toList();
  if (filter.sortBy == TransactionSortBy.date) {
    sortedKeys.sort((a, b) => filter.isAscending ? a.compareTo(b) : b.compareTo(a));
  } else {
    sortedKeys.sort((a, b) => b.compareTo(a));
  }

  final groups = sortedKeys.map((key) {
    final groupTxns = groupsMap[key]!;
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

  // Find top category
  String topCat = '';
  if (catSpendMap.isNotEmpty) {
    final topCatId = catSpendMap.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    topCat = catMap[topCatId]?.name ?? '';
  }

  double filteredIncome = 0;
  double filteredExpense = 0;
  for (final t in txns) {
    if (t.type == TransactionType.income) {
      filteredIncome += t.amount;
    } else {
      filteredExpense += t.amount;
    }
  }
  double filteredTotal = (filteredIncome - filteredExpense).abs();
  int filteredCount = txns.length;

  String summaryTitle = 'Overall';
  if (filter.categoryIds.length == 1) {
    final catId = filter.categoryIds.first;
    final catName = catMap[catId]?.name ?? 'Category';
    summaryTitle = catName;
  } else if (!filter.isDefault) {
    summaryTitle = 'Filtered';
  }

  return _GroupedResult(groups, catMap, monthlyTotal, topCat, filteredTotal, filteredCount, summaryTitle);
});

// --- Main Page ---

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      setState(() => _isSearching = _searchFocusNode.hasFocus);
    });

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
    _scrollController.dispose();
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
          SnackBar(
            content: Text(AppLocalizations.of(context)!.transactionDeleted),
            action: SnackBarAction(label: 'UNDO', onPressed: () {}),
          ),
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
    final currency = settings.currency;
    final isTapMode = settings.transactionActionMode == TransactionActionMode.tap;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.transactions, style: tt.headlineMedium),
          actions: [
            IconButton(
              icon: Icon(Icons.file_download_outlined, color: cs.onSurface.withOpacity(0.6)),
              onPressed: _openExportBottomSheet,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            _buildSearchAndFilters(context, filter, cs, tt, theme),
            Expanded(
              child: groupedAsync.when(
                skipLoadingOnReload: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text("${AppLocalizations.of(context)!.error}: $err")),
                data: (result) {
                  if (result.groups.isEmpty && filter.isDefault) {
                    return _EmptyState(onAdd: () => context.push('/add-transaction'));
                  }

                  return CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      if (filter.isDefault)
                        SliverToBoxAdapter(
                          child: _SummaryStrip(
                            monthlyTotal: result.monthlyTotal,
                            topCategory: result.topCategory,
                            currency: currency,
                          ).animate().fadeIn().slideY(begin: -0.1, duration: 400.ms),
                        )
                      else
                        SliverToBoxAdapter(
                          child: _FilteredSummaryCard(
                            total: result.filteredTotal,
                            count: result.filteredCount,
                            title: result.summaryTitle,
                            currency: currency,
                          ).animate().fadeIn().slideY(begin: -0.1, duration: 400.ms),
                        ),
                      
                      ...result.groups.map((g) => SliverMainAxisGroup(
                            slivers: [
                              SliverPersistentHeader(
                                pinned: true,
                                delegate: _StickyDateHeaderDelegate(
                                  date: g.date,
                                  total: g.dayTotal,
                                  count: g.txns.length,
                                  currency: currency,
                                ),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final t = g.txns[index];
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: _SwipeableTransactionTile(
                                          key: ValueKey(t.id!),
                                          transaction: t,
                                          category: result.catMap[t.categoryId],
                                          currency: currency,
                                          onEdit: () => _editTransaction(t),
                                          onDuplicate: () => _duplicateTransaction(t),
                                          onDelete: () => _confirmAndDeleteTransaction(t),
                                          isTapMode: isTapMode,
                                          onTap: () => _editTransaction(t),
                                        ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.05),
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

  Widget _buildSearchAndFilters(BuildContext context, TransactionFilter filter, ColorScheme cs, TextTheme tt, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
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
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isSearching ? cs.primary.withOpacity(0.5) : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: (v) {
                       ref.read(transactionListProvider.notifier).applyFilter(filter.copyWith(searchQuery: v.toLowerCase()));
                    },
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.searchTransactions,
                      prefixIcon: Icon(Icons.search_rounded, color: _isSearching ? cs.primary : cs.onSurface.withOpacity(0.4), size: 20),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
          const SizedBox(height: 12),
          _CategoryQuickFilters(
            activeFilter: filter,
            onChanged: (newFilter) => ref.read(transactionListProvider.notifier).applyFilter(newFilter),
          ),
        ],
      ),
    );
  }
}

// --- Sub-widgets ---

class _SummaryStrip extends StatelessWidget {
  final double monthlyTotal;
  final String topCategory;
  final String currency;

  const _SummaryStrip({
    required this.monthlyTotal,
    required this.topCategory,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withBlue(200)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Spent this month',
                  style: tt.labelMedium?.copyWith(color: cs.onPrimary.withOpacity(0.7)),
                ),
                const SizedBox(height: 4),
                Text(
                  monthlyTotal.toCurrency(currency),
                  style: tt.headlineSmall?.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 40,
            width: 1,
            color: cs.onPrimary.withOpacity(0.2),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Top category',
                  style: tt.labelMedium?.copyWith(color: cs.onPrimary.withOpacity(0.7)),
                ),
                const SizedBox(height: 4),
                Text(
                  topCategory.isEmpty ? 'N/A' : topCategory,
                  style: tt.titleMedium?.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilteredSummaryCard extends StatelessWidget {
  final double total;
  final int count;
  final String title;
  final String currency;

  const _FilteredSummaryCard({
    required this.total,
    required this.count,
    required this.title,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withBlue(200)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title Total',
                  style: tt.labelMedium?.copyWith(color: cs.onPrimary.withOpacity(0.7)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  total.toCurrency(currency),
                  style: tt.headlineSmall?.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 40,
            width: 1,
            color: cs.onPrimary.withOpacity(0.2),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transactions',
                  style: tt.labelMedium?.copyWith(color: cs.onPrimary.withOpacity(0.7)),
                ),
                const SizedBox(height: 4),
                Text(
                  count.toString(),
                  style: tt.titleMedium?.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryQuickFilters extends ConsumerWidget {
  final TransactionFilter activeFilter;
  final Function(TransactionFilter) onChanged;

  const _CategoryQuickFilters({
    required this.activeFilter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final categories = ref.watch(allCategoriesProvider).valueOrNull ?? [];
    
    // Sort categories by importance or use common ones
    final commonCats = categories.where((c) => ['Food', 'Health', 'Transport', 'Shopping', 'Entertainment'].contains(c.name)).toList();
    
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildChip(
            context,
            'All',
            activeFilter.categoryIds.isEmpty,
            () => onChanged(activeFilter.copyWith(categoryIds: [])),
          ),
          ...commonCats.map((cat) {
            final isSelected = activeFilter.categoryIds.contains(cat.id);
            return _buildChip(
              context,
              cat.name,
              isSelected,
              () {
                if (isSelected) {
                  final newIds = List<int>.from(activeFilter.categoryIds)..remove(cat.id!);
                  onChanged(activeFilter.copyWith(categoryIds: newIds));
                } else {
                  onChanged(activeFilter.copyWith(categoryIds: [cat.id!]));
                }
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChip(BuildContext context, String label, bool isSelected, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? cs.primary : cs.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: tt.labelMedium?.copyWith(
                color: isSelected ? cs.onPrimary : cs.onSurface.withOpacity(0.6),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StickyDateHeaderDelegate extends SliverPersistentHeaderDelegate {
  final DateTime date;
  final double total;
  final int count;
  final String currency;

  _StickyDateHeaderDelegate({
    required this.date,
    required this.total,
    required this.count,
    required this.currency,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final isToday = date.isSameDay(DateTime.now());

    return Container(
      color: theme.scaffoldBackgroundColor.withOpacity(overlapsContent ? 0.9 : 1.0),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      alignment: Alignment.bottomCenter,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                isToday ? 'Today' : date.toDisplayShort(),
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$count txns',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurface.withOpacity(0.4),
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          Text(
            '${total >= 0 ? '+' : ''}${total.toCurrency(currency)}',
            style: (total >= 0 ? tt.positiveAmount : tt.negativeAmount).copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 50;
  @override
  double get minExtent => 50;
  @override
  bool shouldRebuild(covariant _StickyDateHeaderDelegate oldDelegate) => true;
}

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
    final tt = theme.textTheme;
    final isIncome = transaction.type == TransactionType.income;
    final catColor = category != null ? Color(category!.colorHex.toColorInt()) : cs.onSurface.withOpacity(0.3);
    final l10n = AppLocalizations.of(context)!;

    final cardContent = Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? cs.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: transaction.amount > 1000 && !isIncome 
            ? cs.error.withOpacity(0.3) 
            : cs.outline.withOpacity(0.05),
          width: transaction.amount > 1000 && !isIncome ? 1.5 : 1,
        ),
      ),
      child: Stack(
        children: [
          if (transaction.amount > 1000 && !isIncome)
            Positioned(
              top: 0,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.error,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                ),
                child: Text(
                  'HIGH',
                  style: tt.labelSmall?.copyWith(color: cs.onError, fontSize: 8, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildCategoryIcon(cs, catColor),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.description,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${category?.name ?? "Uncategorized"} · ${transaction.date.toTimeOnly()}',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurface.withOpacity(0.4),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isIncome ? '+' : '-'}${transaction.amount.toCurrency(currency)}',
                      style: (isIncome ? tt.positiveAmount : tt.negativeAmount).copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (transaction.note != null && transaction.note!.isNotEmpty)
                          Icon(Icons.sticky_note_2_outlined, size: 12, color: cs.onSurface.withOpacity(0.2)),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, size: 16, color: cs.onSurface.withOpacity(0.2)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final gestureWrapper = GestureDetector(
      onTap: onTap,
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (ctx) => _QuickActionsSheet(
            transaction: transaction,
            onEdit: onEdit,
            onDuplicate: onDuplicate,
            onDelete: onDelete,
          ),
        );
      },
      child: cardContent,
    );

    if (isTapMode) {
      return gestureWrapper;
    }

    return Slidable(
      key: ValueKey(transaction.id!),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.2,
        children: [
          SlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            icon: Icons.edit_rounded,
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(18)),
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.2,
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
            icon: Icons.delete_outline_rounded,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
          ),
        ],
      ),
      child: gestureWrapper,
    );
  }


  Widget _buildCategoryIcon(ColorScheme cs, Color catColor) {
    final iconEmoji = category != null ? CategoryUtils.getEmoji(category!.iconName) : '❓';
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: catColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          iconEmoji,
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}

class _QuickActionsSheet extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _QuickActionsSheet({
    required this.transaction,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurface.withOpacity(0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          _buildAction(context, Icons.edit_rounded, 'Edit', onEdit),
          _buildAction(context, Icons.content_copy_rounded, 'Duplicate', onDuplicate),
          _buildAction(context, Icons.delete_outline_rounded, 'Delete', onDelete, isDestructive: true),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildAction(BuildContext context, IconData icon, String label, VoidCallback onTap, {bool isDestructive = false}) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: isDestructive ? cs.error : cs.primary),
      title: Text(
        label,
        style: TextStyle(
          color: isDestructive ? cs.error : cs.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.receipt_long_rounded, size: 80, color: cs.primary.withOpacity(0.2)),
            ),
            const SizedBox(height: 24),
            Text(
              'No transactions yet',
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Start tracking your expenses by adding your first transaction.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurface.withOpacity(0.5)),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: onAdd,
              child: const Text('Add your first expense'),
            ),
          ],
        ),
      ),
    );
  }
}
