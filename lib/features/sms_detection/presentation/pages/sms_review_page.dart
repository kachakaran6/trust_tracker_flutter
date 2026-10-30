import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/parser/bank_detector.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/models/detected_sms_transaction.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/models/sms_confidence.dart';
import 'package:trust_tracker_flutter/features/sms_detection/presentation/providers/sms_detection_provider.dart';
import 'package:trust_tracker_flutter/features/sms_detection/presentation/widgets/sms_review_sheet.dart';
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

    final selectedCount = state.selectedIds.length;
    final hasSelection = selectedCount > 0;
    final allSelected = state.pendingList.isNotEmpty && selectedCount == state.pendingList.length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pending SMS'),
            if (state.pendingList.isNotEmpty)
              Text(
                '${state.pendingList.length} transaction${state.pendingList.length > 1 ? 's' : ''} to review',
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'SMS Activity & History',
            onPressed: () => context.push('/sms-activity'),
          ),
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Sync Past Bank SMS',
            onPressed: () => SmsSyncHistorySheet.show(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'More actions',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (value) {
              if (value == 'select_all') {
                if (allSelected) {
                  ref.read(smsDetectionProvider.notifier).deselectAll();
                } else {
                  ref.read(smsDetectionProvider.notifier).selectAll();
                }
              } else if (value == 'discard_all') {
                _confirmDiscardAll(context, ref, state.pendingList.length);
              } else if (value == 'clear_all') {
                _confirmClearAll(context, ref);
              } else if (value == 'activity') {
                context.push('/sms-activity');
              }
            },
            itemBuilder: (context) => [
              if (state.pendingList.isNotEmpty)
                PopupMenuItem(
                  value: 'select_all',
                  child: Row(
                    children: [
                      Icon(
                        allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                        color: cs.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(allSelected ? 'Deselect All' : 'Select All'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'activity',
                child: Row(
                  children: [
                    Icon(Icons.manage_history_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('SMS Activity Log'),
                  ],
                ),
              ),
              if (state.pendingList.isNotEmpty) ...[
                const PopupMenuDivider(),
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
                PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_outlined, color: cs.error, size: 20),
                      const SizedBox(width: 12),
                      const Text('Clear Pending Queue'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.pendingList.isEmpty
              ? _buildEmptyState(context, cs, tt)
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    14,
                    16,
                    // Extra padding at bottom to avoid floating action bar overlay
                    MediaQuery.of(context).padding.bottom + 90,
                  ),
                  itemCount: state.pendingList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = state.pendingList[index];
                    final isSelected = item.id != null && state.selectedIds.contains(item.id);
                    return _buildTransactionCard(context, ref, item, isSelected, cs, tt);
                  },
                ),
      bottomNavigationBar: state.pendingList.isEmpty
          ? null
          : _buildBulkActionBar(context, ref, state, cs, tt),
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
                size: 68,
                color: cs.primary.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Pending SMS',
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'New incoming bank SMS messages will appear here for review and ledger approval.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.manage_history_rounded, size: 18),
                  label: const Text('Activity Log'),
                  onPressed: () => context.push('/sms-activity'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.sync_rounded, size: 18),
                  label: const Text('Sync Past SMS'),
                  onPressed: () => SmsSyncHistorySheet.show(context),
                ),
              ],
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
    bool isSelected,
    ColorScheme cs,
    TextTheme tt,
  ) {
    final theme = Theme.of(context);
    final isExpense = item.type == TransactionType.expense;
    final dateFormat = DateFormat('d MMM yyyy · h:mm a');
    final merchantName = item.merchant?.trim().isNotEmpty == true
        ? item.merchant!.trim()
        : item.sender;

    final bankInfo = BankDetector.detect(sender: item.sender, body: item.rawSnippet);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => SmsReviewSheet.show(context, item),
      child: Container(
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
            color: isSelected
                ? cs.primary
                : (item.isAmbiguous
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                    : cs.outline.withValues(alpha: 0.1)),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Bank Info + Masked Account + Selection Checkbox
            Row(
              children: [
                // Bank Avatar with initials
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: bankInfo.brandColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      bankInfo.initials,
                      style: TextStyle(
                        color: bankInfo.brandColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Bank Name & Account Suffix
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bankInfo.name,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        item.maskedAccount != null
                            ? 'A/c ${item.maskedAccount}'
                            : item.sender,
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                // Confidence badge
                _buildConfidenceBadge(item, cs),

                // Multi-select checkbox
                if (item.id != null)
                  Checkbox(
                    value: isSelected,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    onChanged: (_) {
                      ref.read(smsDetectionProvider.notifier).toggleSelection(item.id!);
                    },
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Middle: Amount & Merchant
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                // Accurately formatted amount with Indian grouping
                Text(
                  item.formattedAmount(showSign: true),
                  style: (isExpense ? tt.negativeAmount : tt.positiveAmount).copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isExpense
                        ? AppColors.getError(context).withValues(alpha: 0.08)
                        : AppColors.getSuccess(context).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    isExpense ? 'Expense' : 'Income',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isExpense
                          ? AppColors.getError(context)
                          : AppColors.getSuccess(context),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Counterparty / Merchant name
            Text(
              merchantName,
              style: tt.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 6),

            // Date & Reference Row
            Row(
              children: [
                Text(
                  dateFormat.format(item.date),
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.45),
                    fontSize: 11.5,
                  ),
                ),
                if (item.referenceNumber != null && item.referenceNumber!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '·',
                    style: TextStyle(color: cs.onSurface.withValues(alpha: 0.3)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ref: ${item.referenceNumber}',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.45),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),
            Divider(height: 1, color: cs.outline.withValues(alpha: 0.08)),
            const SizedBox(height: 10),

            // Action Buttons: Reject & Review & Approve
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      side: BorderSide(color: cs.error.withValues(alpha: 0.35)),
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Reject', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    onPressed: () {
                      if (item.id != null) {
                        ref.read(smsDetectionProvider.notifier).rejectTransaction(item.id!);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.primary,
                      side: BorderSide(color: cs.primary.withValues(alpha: 0.4)),
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.edit_note_rounded, size: 17),
                    label: const Text('Review & Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    onPressed: () => SmsReviewSheet.show(context, item),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.getSuccess(context),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Approve', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      ref.read(smsDetectionProvider.notifier).approveTransaction(item);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Added $merchantName (${item.formattedAmount()})'),
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
      ),
    );
  }

  Widget _buildConfidenceBadge(DetectedSmsTransaction item, ColorScheme cs) {
    Color bg;
    Color fg;
    String label;

    if (item.isAmbiguous) {
      bg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
      fg = const Color(0xFFD97706);
      label = 'Verify Amount';
    } else {
      switch (item.confidenceLevel) {
        case SmsConfidenceLevel.high:
          bg = const Color(0xFF22C55E).withValues(alpha: 0.12);
          fg = const Color(0xFF16A34A);
          label = 'Verified';
          break;
        case SmsConfidenceLevel.medium:
          bg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
          fg = const Color(0xFFD97706);
          label = 'Needs Review';
          break;
        case SmsConfidenceLevel.low:
          bg = cs.error.withValues(alpha: 0.12);
          fg = cs.error;
          label = 'Uncertain';
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _buildBulkActionBar(
    BuildContext context,
    WidgetRef ref,
    SmsDetectionState state,
    ColorScheme cs,
    TextTheme tt,
  ) {
    final theme = Theme.of(context);
    final count = state.selectedIds.isNotEmpty ? state.selectedIds.length : state.pendingList.length;
    final isSelectedOnly = state.selectedIds.isNotEmpty;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom + 8
            : 14,
      ),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? cs.surface,
        border: Border(
          top: BorderSide(
            color: cs.outline.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
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
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.close_rounded, size: 17),
              label: Text(
                isSelectedOnly ? 'Discard ($count)' : 'Discard All ($count)',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: () {
                if (isSelectedOnly) {
                  ref.read(smsDetectionProvider.notifier).discardSelected();
                } else {
                  _confirmDiscardAll(context, ref, count);
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
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
                isSelectedOnly
                    ? 'Approve Selected ($count)'
                    : 'Approve Verified (${state.pendingList.where((e) => !e.isAmbiguous && e.confidenceLevel == SmsConfidenceLevel.high).length})',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: () async {
                if (isSelectedOnly) {
                  final res = await ref.read(smsDetectionProvider.notifier).approveSelected();
                  if (context.mounted) {
                    final msg = res.skippedUncertainCount > 0
                        ? 'Approved ${res.approvedCount}. Skipped ${res.skippedUncertainCount} uncertain (needs manual review).'
                        : 'Approved and added ${res.approvedCount} transactions.';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
                    );
                  }
                } else {
                  _confirmApproveAll(context, ref, state.pendingList.length);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmApproveAll(BuildContext context, WidgetRef ref, int count) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Approve All ($count)?'),
        content: const Text(
          'Verified high-confidence transactions will be added to your ledger. Any ambiguous transactions will remain in pending review for your verification.',
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
              final res = await ref.read(smsDetectionProvider.notifier).approveAllPending();
              if (context.mounted) {
                final msg = res.skippedUncertainCount > 0
                    ? 'Approved ${res.approvedCount}. Kept ${res.skippedUncertainCount} uncertain transactions for manual review.'
                    : 'Approved and added ${res.approvedCount} transactions.';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
                );
              }
            },
            child: const Text('Approve Verified'),
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
          'Are you sure you want to discard all $count pending SMS transactions? They will be removed from your review queue.',
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
          'This will remove all pending SMS records from review. Recorded transactions in your ledger will not be affected.',
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
