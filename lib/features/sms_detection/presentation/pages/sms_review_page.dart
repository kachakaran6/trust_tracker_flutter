import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/models/detected_sms_transaction.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/models/sms_confidence.dart';
import 'package:trust_tracker_flutter/features/sms_detection/presentation/providers/sms_detection_provider.dart';
import 'package:trust_tracker_flutter/features/sms_detection/presentation/widgets/sms_sync_history_sheet.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';

class SmsReviewPage extends ConsumerWidget {
  const SmsReviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(smsDetectionProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending SMS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_toggle_off_rounded),
            tooltip: 'Sync Past Bank SMS',
            onPressed: () => SmsSyncHistorySheet.show(context),
          ),
          if (state.pendingList.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: 'Batch actions',
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onSelected: (value) {
                if (value == 'approve_all') {
                  _confirmApproveAll(context, ref, state.pendingList.length);
                } else if (value == 'discard_all') {
                  _confirmDiscardAll(context, ref, state.pendingList.length);
                } else if (value == 'clear_all') {
                  _confirmClearAll(context, ref);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'approve_all',
                  child: Row(
                    children: [
                      Icon(Icons.done_all_rounded, color: AppColors.getSuccess(context), size: 20),
                      const SizedBox(width: 12),
                      Text('Approve All (${state.pendingList.length})'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'discard_all',
                  child: Row(
                    children: [
                      Icon(Icons.close_rounded, color: cs.error, size: 20),
                      const SizedBox(width: 12),
                      Text('Discard All (${state.pendingList.length})'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_outlined, color: cs.error, size: 20),
                      const SizedBox(width: 12),
                      const Text('Clear Records'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.pendingList.isEmpty
              ? _buildEmptyState(context, cs, tt)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  itemCount: state.pendingList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = state.pendingList[index];
                    return _buildTransactionCard(context, ref, item, cs, tt);
                  },
                ),
      bottomNavigationBar: state.pendingList.isEmpty
          ? null
          : Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 10,
                bottom: MediaQuery.of(context).padding.bottom > 0
                    ? MediaQuery.of(context).padding.bottom + 6
                    : 14,
              ),
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? cs.surface,
                border: Border(
                  top: BorderSide(
                    color: cs.outline.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: cs.shadow.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.error,
                        side: BorderSide(color: cs.error.withValues(alpha: 0.35)),
                        minimumSize: const Size(0, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 17),
                      label: Text(
                        'Discard All (${state.pendingList.length})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () => _confirmDiscardAll(
                        context,
                        ref,
                        state.pendingList.length,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.getSuccess(context),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.done_all_rounded, size: 17),
                      label: Text(
                        'Approve All (${state.pendingList.length})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () => _confirmApproveAll(
                        context,
                        ref,
                        state.pendingList.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme cs, TextTheme tt) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mark_email_read_rounded,
                size: 72,
                color: cs.primary.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Pending SMS',
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'When you receive bank or payment SMS messages, they will appear here for your review.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              icon: const Icon(Icons.history_toggle_off_rounded, size: 20),
              label: const Text('Sync Past Bank SMS'),
              onPressed: () => SmsSyncHistorySheet.show(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(
    BuildContext context,
    WidgetRef ref,
    DetectedSmsTransaction item,
    ColorScheme cs,
    TextTheme tt,
  ) {
    final theme = Theme.of(context);
    final isExpense = item.type == TransactionType.expense;
    final dateFormat = DateFormat('d MMM yyyy, h:mm a');
    final merchantName = item.merchant?.trim().isNotEmpty == true
        ? item.merchant!.trim()
        : item.sender;
    final initialLetter = merchantName.isNotEmpty
        ? merchantName[0].toUpperCase()
        : (isExpense ? 'E' : 'I');

    final accentTypeColor = isExpense
        ? AppColors.getError(context)
        : AppColors.getSuccess(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? cs.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Info Row: Avatar + Title/Details + Amount/Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar circle matching Trust Tracker dashboard transactions
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isExpense
                      ? AppColors.getError(context).withValues(alpha: 0.1)
                      : AppColors.getSuccess(context).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    initialLetter,
                    style: tt.titleMedium?.copyWith(
                      color: accentTypeColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title and category / account metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      merchantName,
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
                      '${item.categoryName ?? "General"}${item.maskedAccount != null ? " · ${item.maskedAccount}" : ""}',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      dateFormat.format(item.date),
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Amount and Confidence Indicator
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isExpense ? '-' : '+'}${item.currency} ${item.amount.toStringAsFixed(2)}',
                    style: (isExpense ? tt.negativeAmount : tt.positiveAmount).copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildConfidenceBadge(item.confidenceLevel, cs),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: cs.outline.withValues(alpha: 0.08)),
          const SizedBox(height: 10),

          // Actions Row: Reject (outlined) & Approve (filled/elevated)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.error,
                    side: BorderSide(color: cs.error.withValues(alpha: 0.35)),
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Reject', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  onPressed: () {
                    if (item.id != null) {
                      ref.read(smsDetectionProvider.notifier).rejectTransaction(item.id!);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.getSuccess(context),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Approve', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    ref.read(smsDetectionProvider.notifier).approveTransaction(item);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added $merchantName (${item.currency} ${item.amount.toStringAsFixed(2)})'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceBadge(SmsConfidenceLevel level, ColorScheme cs) {
    Color bg;
    Color fg;
    String label;

    switch (level) {
      case SmsConfidenceLevel.high:
        bg = const Color(0xFF22C55E).withValues(alpha: 0.12);
        fg = const Color(0xFF22C55E);
        label = 'Auto-detected';
        break;
      case SmsConfidenceLevel.medium:
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
        fg = const Color(0xFFF59E0B);
        label = 'Needs Review';
        break;
      case SmsConfidenceLevel.low:
        bg = cs.error.withValues(alpha: 0.12);
        fg = cs.error;
        label = 'Low Match';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  void _confirmApproveAll(BuildContext context, WidgetRef ref, int count) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Approve All ($count)?'),
        content: Text(
          'Are you sure you want to approve all $count pending SMS transactions? They will be added to your ledger as individual entries.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.getSuccess(context),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(smsDetectionProvider.notifier).approveAllPending();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Approved and added $count transactions to your ledger.'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            child: const Text('Approve All'),
          ),
        ],
      ),
    );
  }

  void _confirmDiscardAll(BuildContext context, WidgetRef ref, int count) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Discard All ($count)?'),
        content: Text(
          'Are you sure you want to discard all $count pending SMS transactions? They will be removed from your review list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: cs.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(smsDetectionProvider.notifier).rejectAllPending();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Discarded $count pending transactions.'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            child: const Text('Discard All'),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Pending?'),
        content: const Text(
          'This will remove all pending SMS transactions from review. Recorded transactions in your ledger will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: cs.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(smsDetectionProvider.notifier).clearAllPending();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pending SMS records cleared.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
