import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:trust_tracker_flutter/core/utils/extensions.dart';
import 'package:trust_tracker_flutter/features/categories/data/models/category_model.dart';
import 'package:trust_tracker_flutter/features/categories/data/repositories/category_repository.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/widgets/export_bottom_sheet.dart';
import 'package:trust_tracker_flutter/generated/app_localizations.dart';

// ── Data structures ───────────────────────────────────────────────────────────

/// Immutable group for a single day's transactions
class _DayGroup {
  final String dateKey;
  final DateTime date;
  final List<TransactionModel> txns;
  final double dayTotal;
  const _DayGroup(
      {required this.dateKey,
      required this.date,
      required this.txns,
      required this.dayTotal});
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Re-export so dashboard / other screens can also use the live list
final allTransactionsProvider =
    Provider.autoDispose<AsyncValue<List<TransactionModel>>>((ref) {
  return ref.watch(transactionListProvider);
});

// FIX Issue 9: autoDispose so it refreshes whenever this provider
// is watched fresh (e.g. after returning from categories page).
final _transactionCategoriesProvider =
    FutureProvider.autoDispose<Map<int, CategoryModel>>((ref) async {
  ref.watch(transactionListProvider);
  final cats = await ref.watch(categoryRepositoryProvider).getAll();
  return {for (final c in cats) c.id: c};
});

// ── Filter state ──────────────────────────────────────────────────────────────

class _FilterState {
  final String filter;
  final String search;
  const _FilterState({this.filter = 'all', this.search = ''});
  _FilterState copyWith({String? filter, String? search}) => _FilterState(
      filter: filter ?? this.filter, search: search ?? this.search);
}

final _txnFilterProvider =
    StateProvider.autoDispose<_FilterState>((_) => const _FilterState());

// ── Computed grouped provider ─────────────────────────────────────────────────

final _groupedTransactionsProvider = Provider.autoDispose<
    AsyncValue<({List<_DayGroup> groups, Map<int, CategoryModel> catMap})>>(
  (ref) {
    final txnsAsync = ref.watch(transactionListProvider);
    final catsAsync = ref.watch(_transactionCategoriesProvider);
    final filter = ref.watch(_txnFilterProvider);

    return txnsAsync.when(
      loading: () => const AsyncValue.loading(),
      error: (e, st) => AsyncValue.error(e, st),
      data: (allTxns) => catsAsync.when(
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
        data: (catMap) {
          // Apply filter
          var filtered = allTxns;
          if (filter.filter == 'income') {
            filtered = filtered
                .where((t) => t.type == TransactionType.income)
                .toList();
          } else if (filter.filter == 'expense') {
            filtered = filtered
                .where((t) => t.type == TransactionType.expense)
                .toList();
          }
          if (filter.search.isNotEmpty) {
            filtered = filtered
                .where(
                    (t) => t.description.toLowerCase().contains(filter.search))
                .toList();
          }

          // Group by date key
          final grouped = <String, List<TransactionModel>>{};
          for (final t in filtered) {
            final key = DateFormat('yyyy-MM-dd').format(t.date);
            grouped.putIfAbsent(key, () => []).add(t);
          }

          final groups = grouped.entries.map((e) {
            final date = DateFormat('yyyy-MM-dd').parse(e.key);
            double total = 0;
            for (final t in e.value) {
              total += t.type == TransactionType.income ? t.amount : -t.amount;
            }
            return _DayGroup(
                dateKey: e.key, date: date, txns: e.value, dayTotal: total);
          }).toList();

          // Sort groups by date descending
          groups.sort((a, b) => b.date.compareTo(a.date));

          return AsyncValue.data((groups: groups, catMap: catMap));
        },
      ),
    );
  },
);

// ── Page ──────────────────────────────────────────────────────────────────────

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _editTransaction(TransactionModel t) {
    context.push('/add-transaction', extra: {'edit': t});
  }

  void _duplicateTransaction(TransactionModel t) {
    context.push('/add-transaction', extra: {'duplicate': t});
  }

  Future<void> _confirmAndDeleteTransaction(TransactionModel t) async {
    // FIX Issue 1: Show confirmation dialog before deleting
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppLocalizations.of(context)!.deleteConfirmationTitle),
        content: Text(
          AppLocalizations.of(context)!.deleteConfirmationMessage(t.description),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _deleteTransaction(t);
    }
  }

  Future<void> _deleteTransaction(TransactionModel t) async {
    await ref.read(transactionListProvider.notifier).deleteTransaction(t.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.transactionDeleted),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
    }
  }

  void _openExportBottomSheet() {
    final txnsAsync = ref.read(transactionListProvider);
    txnsAsync.whenData((txns) {
      if (txns.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.noTransactionsExport)),
        );
        return;
      }
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ExportBottomSheet(transactions: txns),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final groupedAsync = ref.watch(_groupedTransactionsProvider);
    final filter = ref.watch(_txnFilterProvider);
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Issue 8: Read action mode
    final isTapMode =
        settings.transactionActionMode == TransactionActionMode.tap;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(AppLocalizations.of(context)!.transactions,
            style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: cs.onSurface)),
        actions: [
          IconButton(
            icon: Icon(Icons.file_download_outlined,
                color: cs.onSurface.withOpacity(0.65), size: 24),
            onPressed: () => _openExportBottomSheet(),
            tooltip: 'Export',
          ),
          IconButton(
            icon: Icon(Icons.add_circle_outline_rounded,
                color: cs.primary, size: 26),
            onPressed: () => context.push('/add-transaction'),
            tooltip: 'Add',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => ref
                  .read(_txnFilterProvider.notifier)
                  .update((s) => s.copyWith(search: v.toLowerCase())),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.searchTransactions,
                prefixIcon: Icon(Icons.search_rounded,
                    color: cs.onSurface.withOpacity(0.4), size: 20),
                suffixIcon: filter.search.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close,
                            size: 18, color: cs.onSurface.withOpacity(0.5)),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(_txnFilterProvider.notifier)
                              .update((s) => s.copyWith(search: ''));
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 10),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['all', 'income', 'expense'].map((f) {
                final isSelected = filter.filter == f;
                String label;
                if (f == 'all') {
                  label = AppLocalizations.of(context)!.all;
                } else if (f == 'income') {
                  label = AppLocalizations.of(context)!.income;
                } else {
                  label = AppLocalizations.of(context)!.expense;
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (_) => ref
                        .read(_txnFilterProvider.notifier)
                        .update((s) => s.copyWith(filter: f)),
                    selectedColor: cs.primary.withOpacity(0.12),
                    checkmarkColor: cs.primary,
                    labelStyle: GoogleFonts.inter(
                      color: isSelected
                          ? cs.primary
                          : cs.onSurface.withOpacity(0.6),
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? cs.primary.withOpacity(0.4)
                          : cs.outline.withOpacity(0.3),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Interaction hint ─────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Icon(
                    isTapMode
                        ? Icons.touch_app_outlined
                        : Icons.swipe_rounded,
                    size: 14,
                    color: cs.onSurface.withOpacity(0.35)),
                const SizedBox(width: 4),
                Text(
                  isTapMode
                      ? AppLocalizations.of(context)!.tapToEdit
                      : AppLocalizations.of(context)!.swipeToEdit,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: cs.onSurface.withOpacity(0.4)),
                ),
              ],
            ),
          ),

          // ── Transaction list ─────────────────────────────────────────
          Expanded(
            child: groupedAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
              data: (result) {
                final groups = result.groups;
                final catMap = result.catMap;

                if (groups.isEmpty) {
                  return _EmptyState(
                      onAdd: () => context.push('/add-transaction'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  itemCount: groups.length,
                  itemBuilder: (ctx, i) {
                    final g = groups[i];
                    return _DaySection(
                      group: g,
                      catMap: catMap,
                      currency: settings.currency,
                      onEdit: _editTransaction,
                      onDuplicate: _duplicateTransaction,
                      onDelete: _confirmAndDeleteTransaction,
                      // Animate newly added first group
                      animate: i == 0,
                      isTapMode: isTapMode,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Day Section ──────────────────────────────────────────────────────────────

class _DaySection extends StatelessWidget {
  final _DayGroup group;
  final Map<int, CategoryModel> catMap;
  final String currency;
  final void Function(TransactionModel) onEdit;
  final void Function(TransactionModel) onDuplicate;
  final Future<void> Function(TransactionModel) onDelete;
  final bool animate;
  final bool isTapMode;

  const _DaySection({
    required this.group,
    required this.catMap,
    required this.currency,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.isTapMode,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                group.date.isSameDay(DateTime.now())
                    ? AppLocalizations.of(context)!.today
                    : group.date.toDisplayShort(),
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withOpacity(0.5)),
              ),
              Text(
                '${group.dayTotal >= 0 ? '+' : ''}${group.dayTotal.toCurrency(currency)}',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: group.dayTotal >= 0
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444)),
              ),
            ],
          ),
        ),
        // Tiles for the day
        ...group.txns.asMap().entries.map((entry) {
          final idx = entry.key;
          final t = entry.value;
          Widget tile = Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SwipeableTransactionTile(
              key: ValueKey(t.id),
              transaction: t,
              category: catMap[t.categoryId],
              currency: currency,
              onEdit: () => onEdit(t),
              onDuplicate: () => onDuplicate(t),
              onDelete: () => onDelete(t),
              isTapMode: isTapMode,
              // Issue 7: In Transactions page, tap opens edit form
              onTap: () => onEdit(t),
            ),
          );

          if (animate && idx == 0) {
            tile = tile.animate().fadeIn(duration: 250.ms).slideY(
                begin: -0.15, end: 0, duration: 250.ms, curve: Curves.easeOut);
          }
          return tile;
        }),
      ],
    );
  }
}

// ── Swipeable Tile ────────────────────────────────────────────────────────────

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
    final amtColor =
        isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final catColor = category != null
        ? Color(category!.colorHex.toColorInt())
        : cs.onSurface.withOpacity(0.3);

    // Shared inner layout
    final innerContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _buildTileContent(context, cs, catColor, amtColor, isIncome),
          ),
          const SizedBox(width: 8),
          // --- Persistent Duplicate Action ---
          _ActionButton(
            icon: Icons.content_copy_rounded,
            color: cs.primary.withOpacity(0.8),
            onTap: onDuplicate,
          ),
          if (isTapMode) ...[
            const SizedBox(width: 8),
            _ActionButton(
              icon: Icons.edit_outlined,
              color: cs.primary,
              onTap: onEdit,
            ),
            const SizedBox(width: 8),
            _ActionButton(
              icon: Icons.delete_outline,
              color: const Color(0xFFEF4444),
              onTap: onDelete,
            ),
          ],
        ],
      ),
    );

    if (isTapMode) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cs.outlineVariant.withOpacity(0.5),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: innerContent,
        ),
      );
    }

    // Swipe Mode
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Slidable(
        key: ValueKey(transaction.id),
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.25,
          children: [
            SlidableAction(
              onPressed: (_) => onDelete(),
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              icon: Icons.delete_outline,
              label: AppLocalizations.of(context)!.delete,
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
              icon: Icons.edit_outlined,
              label: AppLocalizations.of(context)!.edit,
              borderRadius: BorderRadius.circular(14),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardTheme.color ?? cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cs.outlineVariant.withOpacity(0.5),
            ),
          ),
          child: innerContent,
        ),
      ),
    );
  }

  Widget _buildTileContent(BuildContext context, ColorScheme cs, Color catColor,
      Color amtColor, bool isIncome) {
    // Issue 6: Show notes in Transactions page
    final hasNote = transaction.note != null && transaction.note!.isNotEmpty;

    return Row(
      children: [
        // Category avatar
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: catColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              transaction.description.isNotEmpty
                  ? transaction.description[0].toUpperCase()
                  : '?',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, color: catColor, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transaction.description,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: cs.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${category?.name ?? AppLocalizations.of(context)!.uncategorized} · ${transaction.createdAt.toTimestamp()}',
                style: GoogleFonts.inter(
                    fontSize: 11, color: cs.onSurface.withOpacity(0.45)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // FIX Issue 6: Show note below in Transactions page only
              if (hasNote) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.sticky_note_2_outlined,
                        size: 11, color: cs.onSurface.withOpacity(0.3)),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        transaction.note!,
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: cs.onSurface.withOpacity(0.4),
                            fontStyle: FontStyle.italic),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Amount
        Text(
          '${isIncome ? '+' : '-'}${transaction.amount.toCurrency(currency)}',
          style: GoogleFonts.inter(
              fontWeight: FontWeight.w700, fontSize: 14, color: amtColor),
        ),
      ],
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 64, color: cs.onSurface.withOpacity(0.2)),
          const SizedBox(height: 12),
          Text(AppLocalizations.of(context)!.noTransactions,
              style: GoogleFonts.inter(
                  color: cs.onSurface.withOpacity(0.45), fontSize: 15)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.of(context)!.addTransaction),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
