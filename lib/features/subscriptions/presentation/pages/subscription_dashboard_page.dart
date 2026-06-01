import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trust_tracker_flutter/core/database/database_helper.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:trust_tracker_flutter/features/subscriptions/core/subscription_engine.dart';
import 'package:trust_tracker_flutter/features/subscriptions/data/models/subscription_model.dart';
import 'package:trust_tracker_flutter/features/subscriptions/data/repositories/subscription_repository.dart';
import 'package:trust_tracker_flutter/features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:trust_tracker_flutter/features/subscriptions/presentation/widgets/subscription_card.dart';
import 'package:trust_tracker_flutter/features/transactions/data/repositories/transaction_repository.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:trust_tracker_flutter/core/utils/extensions.dart';

class SubscriptionDashboardPage extends ConsumerWidget {
  const SubscriptionDashboardPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final currency = ref.watch(settingsProvider).currency;
    final state = ref.watch(subscriptionListProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Subscriptions'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Run Background Check Now',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Checking for due subscriptions...')),
              );
              final dbHelper = DatabaseHelper.instance;
              final subscriptionRepo = SubscriptionRepository(dbHelper);
              final txnRepo = TransactionRepository(dbHelper);
              await SubscriptionEngine.processDueSubscriptions(
                subscriptionRepo,
                txnRepo,
                currency,
              );

              ref.invalidate(subscriptionListProvider);
              ref.invalidate(upcomingSubscriptionsProvider);
              ref.read(transactionChangeProvider.notifier).update((value) => value + 1);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Check complete!')),
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-subscription'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 6,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      body: state.subscriptions.when(
        data: (subs) {
          if (subs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_repeat, size: 56, color: cs.surfaceContainerHighest),
                    const SizedBox(height: 14),
                    Text(
                      'No subscriptions yet',
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Track Netflix, Spotify, Gym, and more.',
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          }

          final activeSubs = subs.where((s) => !s.isPaused).toList();
          final pausedSubs = subs.where((s) => s.isPaused).toList();
          final now = DateTime.now();
          final upcomingRenewals = activeSubs
              .where((s) {
                final daysUntil = s.nextDueDate.difference(now).inDays;
                return daysUntil >= 0 && daysUntil <= 7;
              })
              .toList()
            ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));

          double monthlyTotal = 0;
          double yearlyTotal = 0;
          for (final sub in activeSubs) {
            switch (sub.billingCycle) {
              case BillingCycle.monthly:
                monthlyTotal += sub.amount;
                yearlyTotal += sub.amount * 12;
                break;
              case BillingCycle.yearly:
                monthlyTotal += sub.amount / 12;
                yearlyTotal += sub.amount;
                break;
              case BillingCycle.weekly:
                monthlyTotal += sub.amount * 4;
                yearlyTotal += sub.amount * 52;
                break;
              case BillingCycle.daily:
                monthlyTotal += sub.amount * 30;
                yearlyTotal += sub.amount * 365;
                break;
              case BillingCycle.quarterly:
                monthlyTotal += sub.amount / 3;
                yearlyTotal += sub.amount * 4;
                break;
              case BillingCycle.halfYearly:
                monthlyTotal += sub.amount / 6;
                yearlyTotal += sub.amount * 2;
                break;
              case BillingCycle.custom:
                if (sub.customDays != null && sub.customDays! > 0) {
                  monthlyTotal += sub.amount * (30 / sub.customDays!);
                  yearlyTotal += sub.amount * (365 / sub.customDays!);
                }
                break;
            }
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _SummaryCard(
                    monthlyTotal: monthlyTotal,
                    yearlyTotal: yearlyTotal,
                    activeCount: activeSubs.length,
                    dueSoonCount: upcomingRenewals.length,
                    currency: currency,
                  ),
                ),
              ),
              if (upcomingRenewals.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: Text(
                      'Upcoming Renewals',
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    itemCount: upcomingRenewals.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final sub = upcomingRenewals[index];
                      final daysUntil = sub.nextDueDate.difference(now).inDays;
                      return _UpcomingRenewalTile(
                        subscription: sub,
                        daysUntil: daysUntil,
                        currency: currency,
                      );
                    },
                  ),
                ),
              ],
              if (activeSubs.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Text(
                      'Active',
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    itemCount: activeSubs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final sub = activeSubs[index];
                      return SubscriptionCard(
                        subscription: sub,
                        currency: currency,
                        onTap: () => context.push('/add-subscription', extra: {'edit': sub}),
                        onEdit: () => context.push('/add-subscription', extra: {'edit': sub}),
                        onDelete: () => _confirmDelete(context, ref, sub),
                      );
                    },
                  ),
                ),
              ],
              if (pausedSubs.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Text(
                      'Paused',
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    itemCount: pausedSubs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final sub = pausedSubs[index];
                      return SubscriptionCard(
                        subscription: sub,
                        currency: currency,
                        onTap: () => context.push('/add-subscription', extra: {'edit': sub}),
                        onEdit: () => context.push('/add-subscription', extra: {'edit': sub}),
                        onDelete: () => _confirmDelete(context, ref, sub),
                      );
                    },
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, SubscriptionModel sub) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Subscription?'),
        content: Text('Delete ${sub.name}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && sub.id != null) {
      await ref.read(subscriptionListProvider.notifier).deleteSubscription(sub.id!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${sub.name} deleted')),
        );
      }
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final double monthlyTotal;
  final double yearlyTotal;
  final int activeCount;
  final int dueSoonCount;
  final String currency;

  const _SummaryCard({
    required this.monthlyTotal,
    required this.yearlyTotal,
    required this.activeCount,
    required this.dueSoonCount,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Spending',
            style: tt.labelLarge?.copyWith(
              color: cs.onPrimary.withOpacity(0.82),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            monthlyTotal.toCurrency(currency),
            style: tt.headlineMedium?.copyWith(
              color: cs.onPrimary,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatChip(icon: Icons.autorenew_rounded, label: '$activeCount Active', cs: cs),
              _StatChip(icon: Icons.calendar_today_rounded, label: '${yearlyTotal.toCurrencyCompact(currency)}/yr', cs: cs),
              if (dueSoonCount > 0)
                _StatChip(icon: Icons.notifications_active_rounded, label: '$dueSoonCount Due soon', cs: cs, isAlert: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpcomingRenewalTile extends StatelessWidget {
  final SubscriptionModel subscription;
  final int daysUntil;
  final String currency;

  const _UpcomingRenewalTile({
    required this.subscription,
    required this.daysUntil,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.errorContainer.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.error.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Icon(Icons.event_available_rounded, size: 18, color: cs.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              subscription.name,
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            daysUntil == 0 ? 'Today' : 'In $daysUntil days',
            style: tt.labelSmall?.copyWith(color: cs.error, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 10),
          Text(
            subscription.amount.toCurrency(currency),
            style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme cs;
  final bool isAlert;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.cs,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isAlert ? cs.errorContainer.withOpacity(0.92) : cs.onPrimary.withOpacity(0.15);
    final fgColor = isAlert ? cs.onErrorContainer : cs.onPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: isAlert ? Border.all(color: cs.error.withOpacity(0.18)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fgColor, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: fgColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
