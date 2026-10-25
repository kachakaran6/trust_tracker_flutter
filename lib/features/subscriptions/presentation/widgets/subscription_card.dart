import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trust_tracker_flutter/core/utils/extensions.dart';
import 'package:trust_tracker_flutter/features/subscriptions/data/models/subscription_model.dart';

class SubscriptionCard extends StatelessWidget {
  final SubscriptionModel subscription;
  final String currency;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const SubscriptionCard({
    super.key,
    required this.subscription,
    required this.currency,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatCycle(BillingCycle cycle) {
    switch (cycle) {
      case BillingCycle.daily:
        return "Daily";
      case BillingCycle.weekly:
        return "Weekly";
      case BillingCycle.monthly:
        return "Monthly";
      case BillingCycle.quarterly:
        return "Quarterly";
      case BillingCycle.halfYearly:
        return "Half Yearly";
      case BillingCycle.yearly:
        return "Yearly";
      case BillingCycle.custom:
        return "Every ${subscription.customDays}d";
    }
  }

  int _daysUntilDue() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
      subscription.nextDueDate.year,
      subscription.nextDueDate.month,
      subscription.nextDueDate.day,
    );
    return due.difference(today).inDays;
  }

  static (IconData, Color) _getBrandStyle(String name, String? type) {
    final lower = name.toLowerCase();
    if (lower.contains('spotify')) {
      return (Icons.music_note_rounded, const Color(0xFF1DB954));
    }
    if (lower.contains('netflix')) {
      return (Icons.movie_rounded, const Color(0xFFE50914));
    }
    if (lower.contains('youtube')) {
      return (Icons.play_arrow_rounded, const Color(0xFFFF0000));
    }
    if (lower.contains('prime') || lower.contains('amazon')) {
      return (Icons.shopping_bag_rounded, const Color(0xFF00A8E1));
    }
    if (lower.contains('apple') || lower.contains('icloud')) {
      return (Icons.apple_rounded, const Color(0xFF64748B));
    }
    if (lower.contains('gym') || lower.contains('fitness')) {
      return (Icons.fitness_center_rounded, const Color(0xFFF97316));
    }
    if (lower.contains('disney') || lower.contains('hotstar')) {
      return (Icons.tv_rounded, const Color(0xFF113CCF));
    }
    if (lower.contains('wifi') || lower.contains('internet') || lower.contains('broadband')) {
      return (Icons.wifi_rounded, const Color(0xFF06B6D4));
    }
    if (lower.contains('jio') || lower.contains('airtel') || lower.contains('vi ') || lower.contains('recharge')) {
      return (Icons.phone_android_rounded, const Color(0xFF6366F1));
    }
    if (lower.contains('cloud') || lower.contains('drive') || lower.contains('dropbox')) {
      return (Icons.cloud_queue_rounded, const Color(0xFF3B82F6));
    }
    if (lower.contains('code') || lower.contains('github') || lower.contains('chatgpt') || lower.contains('ai')) {
      return (Icons.terminal_rounded, const Color(0xFF10B981));
    }

    if (type != null) {
      if (type.contains('Music')) return (Icons.music_note_rounded, const Color(0xFFEC4899));
      if (type.contains('OTT')) return (Icons.tv_rounded, const Color(0xFF8B5CF6));
      if (type.contains('Mobile')) return (Icons.phone_android_rounded, const Color(0xFF6366F1));
      if (type.contains('Cloud')) return (Icons.cloud_rounded, const Color(0xFF3B82F6));
      if (type.contains('Software')) return (Icons.laptop_rounded, const Color(0xFF10B981));
      if (type.contains('Insurance')) return (Icons.shield_rounded, const Color(0xFFF59E0B));
      if (type.contains('Internet')) return (Icons.wifi_rounded, const Color(0xFF06B6D4));
    }

    return (Icons.autorenew_rounded, const Color(0xFF3B82F6));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final daysDue = _daysUntilDue();
    final isOverdue = daysDue < 0;

    final (brandIcon, brandColor) = _getBrandStyle(
      subscription.name,
      subscription.subscriptionType,
    );

    final activeColor = subscription.isPaused ? cs.outline : brandColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? (isDark ? const Color(0xFF1C1C20) : cs.surface),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.45),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Brand Avatar Squircle
                Stack(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: activeColor.withValues(alpha: isDark ? 0.18 : 0.12),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: activeColor.withValues(alpha: isDark ? 0.35 : 0.25),
                          width: 1.2,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          brandIcon,
                          color: activeColor,
                          size: 24,
                        ),
                      ),
                    ),
                    if (subscription.isPaused)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: cs.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.pause_circle_filled_rounded,
                            size: 14,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                // Center Info: Name, Cycle & Renewal date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        subscription.name,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: -0.2,
                          color: subscription.isPaused
                              ? cs.onSurface.withValues(alpha: 0.6)
                              : cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.repeat_rounded,
                            size: 13,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${_formatCycle(subscription.billingCycle)} · Next: ${DateFormat("d MMM yyyy").format(subscription.nextDueDate)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Right Column: Amount + Status Badge + 3-dots Menu
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          subscription.amount.toCurrency(currency),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: subscription.isPaused
                                ? cs.onSurfaceVariant
                                : cs.onSurface,
                          ),
                        ),
                        const SizedBox(width: 2),
                        // 3-dots Actions Menu
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            splashRadius: 16,
                            icon: Icon(
                              Icons.more_vert_rounded,
                              size: 18,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            onSelected: (val) {
                              if (val == 'edit') {
                                onEdit();
                              } else if (val == 'delete') {
                                onDelete();
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                height: 40,
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined,
                                        size: 16, color: cs.onSurface),
                                    const SizedBox(width: 10),
                                    const Text('Edit Subscription',
                                        style: TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(height: 1),
                              const PopupMenuItem(
                                value: 'delete',
                                height: 40,
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded,
                                        size: 16, color: Colors.red),
                                    const SizedBox(width: 10),
                                    Text('Delete',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.red,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    _buildDueBadge(daysDue, isOverdue, subscription.isPaused, cs),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDueBadge(int daysDue, bool isOverdue, bool isPaused, ColorScheme cs) {
    if (isPaused) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Paused',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: cs.onSurfaceVariant,
          ),
        ),
      );
    }

    if (isOverdue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Overdue (${daysDue.abs()}d)',
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFFDC2626),
          ),
        ),
      );
    }

    if (daysDue == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Renews Today',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFFD97706),
          ),
        ),
      );
    }

    if (daysDue <= 3) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Due in $daysDue days',
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFFD97706),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      child: Text(
        'In $daysDue days',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: cs.primary,
        ),
      ),
    );
  }
}
