import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:trust_tracker_flutter/core/router/app_router.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';
import 'package:trust_tracker_flutter/core/utils/extensions.dart';
import 'package:trust_tracker_flutter/features/categories/data/repositories/category_repository.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:trust_tracker_flutter/features/categories/data/models/category_model.dart';
import 'package:google_fonts/google_fonts.dart';

// --- Providers ---
// Derives live summary directly from the in-memory transaction list — instant updates
final dashboardSummaryProvider =
    Provider.autoDispose<Map<String, double>>((ref) {
  final txnsAsync = ref.watch(transactionListProvider);
  final now = DateTime.now();
  final monthKey = now.toMonthKey();
  return txnsAsync.when(
    data: (txns) {
      final monthly = txns.where((t) => t.monthKey == monthKey).toList();
      double income = 0, expense = 0;
      for (final t in monthly) {
        if (t.type == TransactionType.income) {
          income += t.amount;
        } else {
          expense += t.amount;
        }
      }
      return {
        'income': income,
        'expense': expense,
        'balance': income - expense
      };
    },
    loading: () => {},
    error: (_, __) => {},
  );
});

// Shows live recent 5 from in-memory list — no separate DB query
final recentTransactionsProvider =
    Provider.autoDispose<AsyncValue<List<TransactionModel>>>((ref) {
  return ref.watch(transactionListProvider).whenData(
        (all) => all.take(5).toList(),
      );
});

final allCategoriesProvider =
    FutureProvider.autoDispose<List<CategoryModel>>((ref) {
  ref.watch(transactionListProvider);
  return ref.watch(categoryRepositoryProvider).getAll();
});

// --- Page ---
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final summary = ref.watch(dashboardSummaryProvider);
    final recentAsync = ref.watch(recentTransactionsProvider);
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final now = DateTime.now();

    // Issue 8: Read action mode for dashboard tiles too
    final isTapMode =
        settings.transactionActionMode == TransactionActionMode.tap;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, settings, now),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Summary Cards — derived live from in-memory list
                summary.isEmpty
                    ? _SummarySectionSkeleton()
                    : _SummarySection(
                        income: summary['income'] ?? 0,
                        expense: summary['expense'] ?? 0,
                        balance: summary['balance'] ?? 0,
                        currency: settings.currency,
                      ),
                const SizedBox(height: 24),

                // Recent Transactions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Transactions',
                        style: Theme.of(context).textTheme.titleLarge),
                    TextButton(
                      onPressed: () => context.go('/transactions'),
                      child: const Text('See all'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                recentAsync.when(
                  data: (txns) => categoriesAsync.when(
                    data: (cats) {
                      if (txns.isEmpty)
                        return _EmptyTransactions(
                            onAdd: () => context.push('/add-transaction'));
                      return Column(
                        children: txns.map((t) {
                          final cat = cats
                              .where((c) => c.id == t.categoryId)
                              .firstOrNull;
                          // FIX Issue 1 & 7: Swipeable tiles on dashboard
                          return _DashboardTransactionTile(
                            transaction: t,
                            category: cat,
                            currency: settings.currency,
                            isTapMode: isTapMode,
                            onEdit: () => context
                                .push('/add-transaction', extra: {'edit': t}),
                            onDuplicate: () => context.push('/add-transaction',
                                extra: {'duplicate': t}),
                            onDelete: () => _confirmDelete(context, ref, t),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const _TransactionSkeleton(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  loading: () => const _TransactionSkeleton(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
}

  /// FIX Issue 1: Confirm before deleting from dashboard
  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, TransactionModel t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Transaction?'),
        content: Text(
          'Are you sure you want to delete "${t.description}"?\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(transactionListProvider.notifier).deleteTransaction(t.id);
    }
  }

  SliverAppBar _buildAppBar(
      BuildContext context, SettingsState settings, DateTime now) {
    return SliverAppBar(
      expandedHeight: 100,
      pinned: true,
      elevation: 0,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Good ${_greeting()}, ${settings.userName.isNotEmpty ? settings.userName.split(' ').first : 'there'} 👋',
                      style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.color)),
                  Text(now.toDisplayShort(),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Builder(builder: (ctx) {
                final cs = Theme.of(ctx).colorScheme;
                return GestureDetector(
                  onTap: () => context.push('/budget'),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.account_balance_wallet_outlined,
                        color: cs.onPrimaryContainer),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }
}

// --- Dashboard Transaction Tile with swipe (Issue 1) ---
class _DashboardTransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final CategoryModel? category;
  final String currency;
  final bool isTapMode;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _DashboardTransactionTile({
    required this.transaction,
    this.category,
    required this.currency,
    required this.isTapMode,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final color = isIncome ? AppColors.success500 : AppColors.danger500;
    final bgColor = category != null
        ? Color(category!.colorHex.toColorInt()).withOpacity(0.12)
        : AppColors.gray100;
    final iconColor = category != null
        ? Color(category!.colorHex.toColorInt())
        : AppColors.gray400;

    final cs3 = Theme.of(context).colorScheme;

    // The shared core content of the tile
    final innerContent = Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: _buildContent(
                context, isIncome, color, bgColor, iconColor, cs3),
          ),
          const SizedBox(width: 8),
          // --- Persistent Duplicate Action ---
          GestureDetector(
            onTap: onDuplicate,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs3.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.content_copy_rounded,
                  size: 18, color: cs3.primary),
            ),
          ),
          if (isTapMode) ...[
            const SizedBox(width: 8),
            // Persistent Delete in Tap Mode
            GestureDetector(
              onTap: onDelete,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.close, size: 18, color: Color(0xFFEF4444)),
              ),
            ),
          ],
        ],
      ),
    );

    if (isTapMode) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ?? cs3.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs3.outlineVariant.withOpacity(0.5)),
        ),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(14),
          child: innerContent,
        ),
      );
    }

    // Swipe Mode
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Slidable(
        key: ValueKey(transaction.id),
        startActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.25,
          children: [
            SlidableAction(
              onPressed: (_) => onEdit(),
              backgroundColor: cs3.primary,
              foregroundColor: cs3.onPrimary,
              icon: Icons.edit_outlined,
              label: 'Edit',
              borderRadius: BorderRadius.circular(14),
            ),
          ],
        ),
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.25,
          children: [
            SlidableAction(
              onPressed: (_) => onDelete(),
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              icon: Icons.delete_outline,
              label: 'Delete',
              borderRadius: BorderRadius.circular(14),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color ?? cs3.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs3.outlineVariant.withOpacity(0.5)),
          ),
          child: innerContent,
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isIncome, Color color,
      Color bgColor, Color iconColor, ColorScheme cs3) {
    return Row(children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
            color: bgColor, borderRadius: BorderRadius.circular(12)),
        child: Center(
          child: Text(
            transaction.description.isNotEmpty
                ? transaction.description[0].toUpperCase()
                : '?',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700, color: iconColor),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(transaction.description,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(
            '${category?.name ?? 'Uncategorized'} · ${transaction.date.toDisplayShort()}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ]),
      ),
      Text(
        '${isIncome ? '+' : '-'}${transaction.amount.toCurrency(currency)}',
        style: GoogleFonts.inter(
            fontWeight: FontWeight.w700, fontSize: 14, color: color),
      ),
    ]);
  }
}

// --- Summary Section ---
class _SummarySection extends StatelessWidget {
  final double income, expense, balance;
  final String currency;
  const _SummarySection(
      {required this.income,
      required this.expense,
      required this.balance,
      required this.currency});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Balance Hero Card
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary600, AppColors.primary500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary500.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Net Balance',
              style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.8), fontSize: 13)),
          const SizedBox(height: 4),
          Text(balance.toCurrency(currency),
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('This month',
              style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.6), fontSize: 12)),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: _MiniCard(
                label: 'Income',
                amount: income,
                currency: currency,
                color: AppColors.success500,
                icon: Icons.arrow_upward_rounded)),
        const SizedBox(width: 12),
        Expanded(
            child: _MiniCard(
                label: 'Expenses',
                amount: expense,
                currency: currency,
                color: AppColors.danger500,
                icon: Icons.arrow_downward_rounded)),
      ]),
    ]);
  }
}

class _MiniCard extends StatelessWidget {
  final String label, currency;
  final double amount;
  final Color color;
  final IconData icon;
  const _MiniCard(
      {required this.label,
      required this.amount,
      required this.currency,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs2 = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? cs2.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs2.outlineVariant.withOpacity(0.5)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: GoogleFonts.inter(
                    color: cs2.onSurface.withOpacity(0.5), fontSize: 11)),
            Text(amount.toCurrencyCompact(currency),
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: cs2.onSurface)),
          ]),
        ),
      ]),
    );
  }
}

// --- Skeletons & Empty States ---
class _SummarySectionSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _TransactionSkeleton extends StatelessWidget {
  const _TransactionSkeleton();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: List.generate(
          3,
          (i) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                height: 68,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
              )),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyTransactions({required this.onAdd});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(children: [
          Icon(Icons.receipt_long_outlined,
              size: 56, color: cs.onSurface.withOpacity(0.2)),
          const SizedBox(height: 12),
          Text('No transactions yet',
              style: GoogleFonts.inter(
                  color: cs.onSurface.withOpacity(0.45),
                  fontWeight: FontWeight.w500,
                  fontSize: 15)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add First Transaction'),
          ),
        ]),
      ),
    );
  }
}
