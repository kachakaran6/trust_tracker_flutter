import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:trust_tracker_flutter/core/router/app_router.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';
import 'package:trust_tracker_flutter/core/utils/extensions.dart';
import 'package:trust_tracker_flutter/core/utils/greeting_helper.dart';
import 'package:trust_tracker_flutter/features/categories/data/repositories/category_repository.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:trust_tracker_flutter/features/categories/data/models/category_model.dart';
import 'package:trust_tracker_flutter/generated/app_localizations.dart';

// --- Providers ---
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
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final summary = ref.watch(dashboardSummaryProvider);
    final recentAsync = ref.watch(recentTransactionsProvider);
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final now = DateTime.now();
    final theme = Theme.of(context);
    final tt = theme.textTheme;

    final isTapMode =
        settings.transactionActionMode == TransactionActionMode.tap;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, settings, now),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                summary.isEmpty
                    ? _SummarySectionSkeleton()
                    : _SummarySection(
                        income: summary['income'] ?? 0,
                        expense: summary['expense'] ?? 0,
                        balance: summary['balance'] ?? 0,
                        currency: settings.currency,
                      ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.recentTransactions,
                        style: tt.headlineSmall),
                    TextButton(
                      onPressed: () => context.go('/transactions'),
                      child: Text(l10n.seeAll, style: tt.labelLarge?.copyWith(color: theme.colorScheme.primary)),
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

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, TransactionModel t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppLocalizations.of(context)!.deleteConfirmationTitle, style: Theme.of(context).textTheme.headlineSmall),
        content: Text(
          AppLocalizations.of(context)!.deleteConfirmationMessage(t.description),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.cancel, style: Theme.of(context).textTheme.labelLarge),
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
                  _GreetingText(userName: settings.userName),
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
}

class _GreetingText extends StatelessWidget {
  final String userName;
  const _GreetingText({required this.userName});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hour = DateTime.now().hour;
    final name = userName.isNotEmpty ? userName.split(' ').first : 'there';
    final tt = Theme.of(context).textTheme;

    String greeting;
    if (hour >= 5 && hour < 12) {
      greeting = l10n.goodMorning(name);
    } else if (hour >= 12 && hour < 17) {
      greeting = l10n.goodAfternoon(name);
    } else {
      greeting = l10n.goodEvening(name);
    }

    return Text(
      greeting,
      style: tt.headlineMedium,
    );
  }
}

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
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final color = isIncome ? AppColors.success500 : AppColors.danger500;
    final bgColor = category != null
        ? Color(category!.colorHex.toColorInt()).withOpacity(0.12)
        : AppColors.gray100;
    final iconColor = category != null
        ? Color(category!.colorHex.toColorInt())
        : AppColors.gray400;

    final cs3 = theme.colorScheme;

    final innerContent = Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: _buildContent(
                context, isIncome, color, bgColor, iconColor, cs3),
          ),
          const SizedBox(width: 8),
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
          color: theme.cardTheme.color ?? cs3.surface,
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
              label: AppLocalizations.of(context)!.edit,
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
              label: AppLocalizations.of(context)!.delete,
              borderRadius: BorderRadius.circular(14),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardTheme.color ?? cs3.surface,
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
    final theme = Theme.of(context);
    final tt = theme.textTheme;
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
            style: tt.titleLarge?.copyWith(color: iconColor),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(transaction.description,
              style: tt.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(
            '${category?.name ?? AppLocalizations.of(context)!.uncategorized} · ${transaction.date.toDisplayShort()}',
            style: tt.bodySmall,
          ),
        ]),
      ),
      Text(
        '${isIncome ? '+' : '-'}${transaction.amount.toCurrency(currency)}',
        style: isIncome ? tt.positiveAmount : tt.negativeAmount,
      ),
    ]);
  }
}

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
    final tt = Theme.of(context).textTheme;
    return Column(children: [
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
          Text(AppLocalizations.of(context)!.netBalance,
              style: tt.bodySmall?.copyWith(color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(balance.toCurrency(currency),
              style: tt.balanceAmount.copyWith(color: Colors.white)),
          const SizedBox(height: 4),
          Text(AppLocalizations.of(context)!.thisMonth,
              style: tt.labelSmall?.copyWith(color: Colors.white.withOpacity(0.6))),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: _MiniCard(
                label: AppLocalizations.of(context)!.income,
                amount: income,
                currency: currency,
                color: AppColors.success500,
                icon: Icons.arrow_upward_rounded)),
        const SizedBox(width: 12),
        Expanded(
            child: _MiniCard(
                label: AppLocalizations.of(context)!.expenses,
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
    final theme = Theme.of(context);
    final cs2 = theme.colorScheme;
    final tt = theme.textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? cs2.surface,
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
                style: tt.labelSmall),
            Text(amount.toCurrencyCompact(currency),
                style: tt.titleSmall),
          ]),
        ),
      ]),
    );
  }
}

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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(children: [
          Icon(Icons.receipt_long_outlined,
              size: 56, color: cs.onSurface.withOpacity(0.2)),
          const SizedBox(height: 12),
          Text(l10n.noTransactionsYet,
              style: tt.bodyMedium?.copyWith(color: cs.onSurface.withOpacity(0.45))),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(l10n.addFirstTransaction),
          ),
        ]),
      ),
    );
  }
}
