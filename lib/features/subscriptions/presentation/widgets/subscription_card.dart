import 'package:flutter/material.dart';
import 'package:trust_tracker_flutter/core/theme/app_colors.dart';
import 'package:trust_tracker_flutter/features/subscriptions/data/models/subscription_model.dart';
import 'package:trust_tracker_flutter/core/utils/extensions.dart';
import 'package:intl/intl.dart';

class SubscriptionCard extends StatelessWidget {
  final SubscriptionModel subscription;
  final String currency;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const SubscriptionCard({
    Key? key,
    required this.subscription,
    required this.currency,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  String _formatCycle(BillingCycle cycle) {
    switch (cycle) {
      case BillingCycle.daily: return "Daily";
      case BillingCycle.weekly: return "Weekly";
      case BillingCycle.monthly: return "Monthly";
      case BillingCycle.quarterly: return "Quarterly";
      case BillingCycle.halfYearly: return "Half Yearly";
      case BillingCycle.yearly: return "Yearly";
      case BillingCycle.custom: return "Every ${subscription.customDays} days";
    }
  }

  int _daysUntilDue() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(subscription.nextDueDate.year, subscription.nextDueDate.month, subscription.nextDueDate.day);
    return due.difference(today).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final daysDue = _daysUntilDue();
    final isOverdue = daysDue < 0;
    
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withOpacity(0.34),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: subscription.isPaused ? cs.outlineVariant : cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    subscription.isPaused ? Icons.pause : Icons.autorenew_rounded,
                    size: 20,
                    color: subscription.isPaused ? cs.onSurfaceVariant : cs.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subscription.name,
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_formatCycle(subscription.billingCycle)} • ${DateFormat.yMMMd().format(subscription.nextDueDate)}',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
                    subscription.amount.toCurrency(currency),
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: subscription.isPaused ? cs.onSurfaceVariant : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (!subscription.isPaused)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOverdue ? cs.errorContainer : (daysDue <= 3 ? AppColors.warning.withOpacity(0.2) : cs.tertiaryContainer),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isOverdue ? 'Overdue' : (daysDue == 0 ? 'Today' : 'In $daysDue days'),
                        style: tt.labelSmall?.copyWith(
                          color: isOverdue ? cs.onErrorContainer : (daysDue <= 3 ? AppColors.warning : cs.onTertiaryContainer),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Paused',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: onEdit,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Edit'),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: onDelete,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: const Size(0, 0),
                          foregroundColor: Colors.red,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
