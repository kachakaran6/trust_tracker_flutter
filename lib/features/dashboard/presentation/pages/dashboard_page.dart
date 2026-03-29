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
import 'package:trust_tracker_flutter/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:trust_tracker_flutter/features/categories/data/models/category_model.dart';
import 'package:trust_tracker_flutter/generated/app_localizations.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/widgets/avatar_selection_modal.dart';
import 'package:trust_tracker_flutter/core/security/security_provider.dart';

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
      await ref.read(transactionListProvider.notifier).deleteTransaction(t.id);
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
    return SliverAppBar(
      expandedHeight: 70,
      pinned: true,
      elevation: 0,
      backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          padding: const EdgeInsets.fromLTRB(20, 54, 20, 10),
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
                final tt = Theme.of(ctx).textTheme;
                final l10n = AppLocalizations.of(ctx)!;
                return PopupMenuButton<String>(
                  offset: const Offset(0, 48), // Reduced offset to pull menu up
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                  color: cs.surface,
                  // position: PopupMenuPosition.under handles bottom-left/right, but offset 44 is safer
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
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.primary.withOpacity(0.12), width: 2),
                    ),
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
        key: ValueKey(transaction.id),
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Column(children: [
      _BalanceCardAnimationWrapper(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.08), // Sophisticated accent tint
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.primary.withOpacity(0.12)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AppLocalizations.of(context)!.netBalance,
                style: tt.bodySmall?.copyWith(
                    color: cs.primary.withOpacity(0.6), // Accent-tinted label
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1)),
            const SizedBox(height: 8),
            _AnimatedBalanceText(
              value: balance,
              currency: currency,
              style: tt.balanceAmount.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_rounded, size: 10, color: cs.primary.withOpacity(0.6)),
                  const SizedBox(width: 6),
                  Text(AppLocalizations.of(context)!.thisMonth,
                      style: tt.labelSmall?.copyWith(color: cs.primary.withOpacity(0.6))),
                ],
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: _MiniCard(
                label: AppLocalizations.of(context)!.income,
                amount: income,
                currency: currency,
                color: AppColors.success,
                icon: Icons.arrow_upward_rounded)),
        const SizedBox(width: 12),
        Expanded(
            child: _MiniCard(
                label: AppLocalizations.of(context)!.expenses,
                amount: expense,
                currency: currency,
                color: cs.error,
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
        color: cs2.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs2.outline.withOpacity(0.1)),
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
