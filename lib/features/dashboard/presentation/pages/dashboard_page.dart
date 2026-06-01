import 'package:flutter/material.dart';
import 'dart:io';
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
import 'package:trust_tracker_flutter/features/transactions/data/repositories/transaction_repository.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:trust_tracker_flutter/features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:trust_tracker_flutter/features/subscriptions/data/models/subscription_model.dart';
import 'package:trust_tracker_flutter/features/categories/data/models/category_model.dart';
import 'package:trust_tracker_flutter/generated/app_localizations.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/widgets/avatar_selection_modal.dart';
import 'package:trust_tracker_flutter/core/security/security_provider.dart';
import 'package:trust_tracker_flutter/core/utils/financial_utils.dart';
import 'package:intl/intl.dart' as intl;

// --- Providers ---
final dashboardSummaryProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(transactionChangeProvider); // Re-run when database changes
  final settings = ref.watch(settingsProvider);
  final repo = ref.watch(transactionRepositoryProvider);
  
  final cycleRange = FinancialUtils.getCurrentCycleRange(settings.monthStartDay);
  
  final rangeSummary = await repo.getRangeSummary(cycleRange.start, cycleRange.end);
  final txns = await repo.getTransactionsByDateRange(cycleRange.start, cycleRange.end);
  
  double income = rangeSummary['income'] ?? 0;
  double expense = rangeSummary['expense'] ?? 0;
  double balance = income - expense;
  double openingBalance = 0;

  if (settings.carryForwardEnabled) {
    openingBalance = await repo.getNetBalanceBefore(cycleRange.start);
    balance += openingBalance;
  }
  
  return {
    'income': income,
    'expense': expense,
    'balance': balance,
    'openingBalance': openingBalance,
    'startDate': cycleRange.start,
    'endDate': cycleRange.end,
    'transactionCount': txns.length,
  };
});

final recentTransactionsProvider =
    FutureProvider.autoDispose<List<TransactionModel>>((ref) async {
  ref.watch(transactionChangeProvider); // Re-run when database changes
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getRecent(5);
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
    final security = ref.watch(securityProvider);
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
          _buildAppBar(context, ref, settings, security, now),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),
                summary.when(
                  data: (data) => _SummarySection(
                    income: data['income'] ?? 0,
                    expense: data['expense'] ?? 0,
                    balance: data['balance'] ?? 0,
                    openingBalance: (data['openingBalance'] as double?) ?? 0,
                    transactionCount: data['transactionCount'] as int? ?? 0,
                    startDate: data['startDate'] as DateTime,
                    endDate: data['endDate'] as DateTime,
                    currency: settings.currency,
                    carryForwardEnabled: settings.carryForwardEnabled,
                  ),
                  loading: () => _SummarySectionSkeleton(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 20),
                const _UpcomingRenewalsWidget(),
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
    final theme = Theme.of(context);
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
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(transactionListProvider.notifier).deleteTransaction(t.id!);
    }
  }

  Widget _buildPopupItem(BuildContext context, IconData icon, String label) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  SliverAppBar _buildAppBar(
      BuildContext context, WidgetRef ref, SettingsState settings, SecurityState security, DateTime now) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: cs.surface.withOpacity(0.95),
      toolbarHeight: 90,
      titleSpacing: 16,
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _GreetingText(userName: settings.userName),
                const SizedBox(height: 2),
                Text(now.toDisplayShort(),
                    style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          Builder(builder: (ctx) {
            final l10n = AppLocalizations.of(ctx)!;
            return PopupMenuButton<String>(
              offset: const Offset(0, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 6,
              color: cs.surface,
              onSelected: (value) {
                if (value == 'avatar') {
                  showAvatarSelectionModal(context: context, ref: ref, settings: settings);
                } else if (value == 'pin') {
                  context.push('/set-pin', extra: {'changing': true});
                } else if (value == 'budget') {
                  context.push('/budget');
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: false,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: cs.primaryContainer,
                        backgroundImage: settings.userAvatar != null
                            ? (settings.userAvatar!.startsWith('assets/')
                                ? AssetImage(settings.userAvatar!)
                                : FileImage(File(settings.userAvatar!)) as ImageProvider)
                            : null,
                        child: settings.userAvatar == null
                            ? Text(
                                settings.userName.isNotEmpty
                                    ? settings.userName[0].toUpperCase()
                                    : '?',
                                style: tt.labelMedium?.copyWith(
                                    color: cs.onPrimaryContainer,
                                    fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              settings.userName.isEmpty ? l10n.user : settings.userName,
                              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold, height: 1.1),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              l10n.trustTrackerUser,
                              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant, height: 1.1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(height: 1),
                PopupMenuItem(
                  value: 'avatar',
                  height: 44,
                  child: _buildPopupItem(ctx, Icons.person_outline_rounded, l10n.chooseAvatar),
                ),
                PopupMenuItem(
                  value: 'pin',
                  height: 44,
                  child: _buildPopupItem(ctx, Icons.lock_outline_rounded, 
                      security.isPinEnabled ? l10n.changePin : l10n.setPin),
                ),
                PopupMenuItem(
                  value: 'budget',
                  height: 44,
                  child: _buildPopupItem(ctx, Icons.account_balance_wallet_outlined, l10n.setBudget),
                ),
              ],
              child: CircleAvatar(
                radius: 20,
                backgroundColor: cs.primaryContainer,
                backgroundImage: settings.userAvatar != null
                    ? (settings.userAvatar!.startsWith('assets/')
                        ? AssetImage(settings.userAvatar!)
                        : FileImage(File(settings.userAvatar!)) as ImageProvider)
                    : null,
                child: settings.userAvatar == null
                    ? Text(
                        settings.userName.isNotEmpty
                            ? settings.userName[0].toUpperCase()
                            : '?',
                        style: tt.titleLarge?.copyWith(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
            );
          }),
        ],
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
    final name = userName.isNotEmpty ? userName.split(' ').first : l10n.user;
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
    final cs = theme.colorScheme;
    final color = isIncome ? AppColors.success : cs.error;
    final bgColor = category != null
        ? Color(category!.colorHex.toColorInt()).withOpacity(0.12)
        : cs.surfaceVariant;
    final iconColor = category != null
        ? Color(category!.colorHex.toColorInt())
        : cs.onSurfaceVariant;

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
                  color: theme.colorScheme.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.close,
                    size: 18, color: theme.colorScheme.error),
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
          color: cs3.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs3.outline.withOpacity(0.1)),
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
        key: ValueKey(transaction.id!),
        startActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.25,
          children: [
            SlidableAction(
              onPressed: (_) => onEdit(),
              backgroundColor: cs3.primary,
              foregroundColor: cs3.onPrimary,
              icon: Icons.edit_rounded,
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
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
              icon: Icons.delete_outline_rounded,
              borderRadius: BorderRadius.circular(14),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: cs3.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs3.outline.withOpacity(0.1)),
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

// ─────────────────────────────────────────────────────────────────────────────
// PREMIUM MICRO-COMPONENTS (DASHBOARD SUMMARY)
// ─────────────────────────────────────────────────────────────────────────────

class _SummarySection extends StatelessWidget {
  final double income, expense, balance, openingBalance;
  final int transactionCount;
  final String currency;
  final DateTime startDate, endDate;
  final bool carryForwardEnabled;

  const _SummarySection({
    required this.income,
    required this.expense,
    required this.balance,
    required this.openingBalance,
    required this.transactionCount,
    required this.startDate,
    required this.endDate,
    required this.currency,
    required this.carryForwardEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FintechHeaderRow(balance: balance),
        const SizedBox(height: 16),
        _FintechHeroBalance(
          balance: balance,
          openingBalance: openingBalance,
          currency: currency,
          carryForwardEnabled: carryForwardEnabled,
          startDate: startDate,
          endDate: endDate,
        ),
        const SizedBox(height: 20),
        _CompactIncomeExpenseRow(
          income: income,
          expense: expense,
          currency: currency,
        ),
      ],
    );
  }
}

class _FintechHeaderRow extends StatelessWidget {
  final double balance;
  const _FintechHeaderRow({required this.balance});
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final isPositive = balance >= 0;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.netBalance, style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
            Text("Monthly Summary", style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isPositive ? AppColors.success.withOpacity(0.12) : AppColors.error.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, 
                   size: 14, color: isPositive ? AppColors.success : AppColors.error),
              const SizedBox(width: 4),
              Text(
                "Health", 
                style: tt.labelMedium?.copyWith(
                  color: isPositive ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FintechHeroBalance extends StatelessWidget {
  final double balance, openingBalance;
  final String currency;
  final bool carryForwardEnabled;
  final DateTime startDate, endDate;

  const _FintechHeroBalance({
    required this.balance,
    required this.openingBalance,
    required this.currency,
    required this.carryForwardEnabled,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withOpacity(0.15),
            cs.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.primary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.surface.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outline.withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 12, color: cs.primary),
                    const SizedBox(width: 6),
                    Text('${intl.DateFormat('d MMM').format(startDate)} — ${intl.DateFormat('d MMM').format(endDate)}', 
                      style: tt.labelSmall?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _AnimatedBalanceText(
                value: balance,
                currency: currency,
                style: tt.displaySmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                  fontSize: 34,
                ) ?? const TextStyle(),
              ),
              if (carryForwardEnabled && openingBalance != 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Opening Balance • ${openingBalance.toCurrency(currency)}',
                  style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactIncomeExpenseRow extends StatelessWidget {
  final double income;
  final double expense;
  final String currency;

  const _CompactIncomeExpenseRow({
    required this.income,
    required this.expense,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildItem(context, AppLocalizations.of(context)!.income, income, currency, AppColors.success, Icons.arrow_upward_rounded),
          ),
          Container(
            width: 1,
            height: 40,
            color: cs.outline.withOpacity(0.1),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          Expanded(
            child: _buildItem(context, AppLocalizations.of(context)!.expenses, expense, currency, AppColors.error, Icons.arrow_downward_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, String label, double value, String currency, Color color, IconData icon) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(value.toCurrencyCompact(currency), style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
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

// ─────────────────────────────────────────────────────────────────────────────
// PREMIUM MICRO-INTERACTIONS
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedBalanceText extends StatelessWidget {
  final double value;
  final String currency;
  final TextStyle style;

  const _AnimatedBalanceText({
    required this.value,
    required this.currency,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutExpo,
      builder: (context, val, child) {
        return Text(
          val.toCurrency(currency),
          style: style,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PREMIUM MICRO-INTERACTIONS (Refined for Professional Look)
// ─────────────────────────────────────────────────────────────────────────────

class _BalanceCardAnimationWrapper extends StatefulWidget {
  final Widget child;
  const _BalanceCardAnimationWrapper({required this.child});

  @override
  State<_BalanceCardAnimationWrapper> createState() =>
      _BalanceCardAnimationWrapperState();
}

class _BalanceCardAnimationWrapperState
    extends State<_BalanceCardAnimationWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.3, curve: Curves.easeOutCubic)),
    );

    _slideAnimation = Tween<double>(begin: 16, end: 0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.3, curve: Curves.easeOutCubic)),
    );

    _shimmerAnimation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.4, 0.9, curve: Curves.easeInOutExpo)),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0),
                        // Very subtle shimmer (0.05 for premium feel)
                        (isDark ? Colors.white : Colors.blue.shade200).withOpacity(0.05),
                        Colors.white.withOpacity(0),
                      ],
                      stops: const [0.35, 0.5, 0.65],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      transform: _GradientRotation(_shimmerAnimation.value),
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.srcOver,
                  child: widget.child,
                ),
              ),
            ),
            // Refined Floating particles (Subtle hints of motion)
            ..._buildParticles(),
          ],
        );
      },
    );
  }

  List<Widget> _buildParticles() {
    final cs = Theme.of(context).colorScheme;
    return List.generate(3, (i) {
      final delay = i * 0.12;
      final progress = (_controller.value - delay).clamp(0.0, 0.4) * 2.5;
      if (progress <= 0 || progress >= 1) return const SizedBox.shrink();

      return Positioned(
        left: 80.0 + (i * 100),
        bottom: 20 + (progress * 40),
        child: Opacity(
          opacity: (1 - progress) * 0.2, // Significantly reduced opacity
          child: Icon(Icons.circle,
              size: 4 + i.toDouble(), color: cs.primary.withOpacity(0.3)),
        ),
      );
    });
  }
}

class _GradientRotation extends GradientTransform {
  final double progress;
  const _GradientRotation(this.progress);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * progress * 2, 0, 0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UPCOMING RENEWALS WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _UpcomingRenewalsWidget extends ConsumerWidget {
  const _UpcomingRenewalsWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSubs = ref.watch(upcomingSubscriptionsProvider);
    final currency = ref.watch(settingsProvider).currency;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return asyncSubs.when(
      data: (subs) {
        final topSubs = subs.isEmpty ? <SubscriptionModel>[] : subs.take(2).toList();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Upcoming Payments', style: tt.headlineSmall),
                TextButton(
                  onPressed: () => context.push('/subscriptions'),
                  child: Text('Manage', style: tt.labelLarge?.copyWith(color: cs.primary)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.outline.withOpacity(0.1)),
              ),
              child: topSubs.isEmpty
                  ? Center(
                      child: Column(
                        children: [
                          Icon(Icons.event_repeat, color: cs.onSurfaceVariant.withOpacity(0.5), size: 32),
                          const SizedBox(height: 8),
                          Text('No upcoming payments', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                          const SizedBox(height: 8),
                          FilledButton.tonal(
                            onPressed: () => context.push('/add-subscription'),
                            child: const Text('Add Subscription'),
                          ),
                        ],
                      ),
                    )
                  : Column(
                children: [
                  for (int i = 0; i < topSubs.length; i++) ...[
                    Builder(
                      builder: (context) {
                        final sub = topSubs[i];
                        final due = DateTime(sub.nextDueDate.year, sub.nextDueDate.month, sub.nextDueDate.day);
                        final daysDue = due.difference(today).inDays;
                        
                        String dueText;
                        if (daysDue < 0) dueText = 'Overdue';
                        else if (daysDue == 0) dueText = 'Today';
                        else if (daysDue == 1) dueText = 'Tomorrow';
                        else dueText = '$daysDue Days';

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.event_repeat, size: 16, color: cs.primary),
                                const SizedBox(width: 8),
                                Text('${sub.name} — $dueText', style: tt.bodyMedium),
                              ],
                            ),
                            Text(sub.amount.toCurrency(currency), style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        );
                      }
                    ),
                    if (i < topSubs.length - 1)
                      Divider(color: cs.outline.withOpacity(0.1), height: 16),
                  ]
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
