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
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';

enum SmsFilterStatus { all, pending, approved, rejected, verification }

class SmsActivityPage extends ConsumerStatefulWidget {
  const SmsActivityPage({super.key});

  @override
  ConsumerState<SmsActivityPage> createState() => _SmsActivityPageState();
}

class _SmsActivityPageState extends ConsumerState<SmsActivityPage> {
  SmsFilterStatus _statusFilter = SmsFilterStatus.all;
  String _searchQuery = '';
  String? _selectedBank;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(smsDetectionProvider.notifier).loadAllHistory();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(smsDetectionProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    final allItems = state.allHistoryList;

    // Calculate overview statistics
    final pendingCount = allItems.where((e) => e.status == 'pending_review').length;
    final approvedCount = allItems.where((e) => e.status == 'approved').length;
    final rejectedCount = allItems.where((e) => e.status == 'rejected').length;
    final verifyCount = allItems.where((e) => e.isAmbiguous || e.confidenceLevel == SmsConfidenceLevel.low).length;

    // Apply filters and search
    final filteredItems = allItems.where((item) {
      // 1. Status Filter
      if (_statusFilter == SmsFilterStatus.pending && item.status != 'pending_review') return false;
      if (_statusFilter == SmsFilterStatus.approved && item.status != 'approved') return false;
      if (_statusFilter == SmsFilterStatus.rejected && item.status != 'rejected') return false;
      if (_statusFilter == SmsFilterStatus.verification &&
          (!item.isAmbiguous && item.confidenceLevel != SmsConfidenceLevel.low)) {
        return false;
      }

      // 2. Bank Filter
      if (_selectedBank != null && item.bankName != _selectedBank) return false;

      // 3. Search Query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final merchantMatch = item.merchant?.toLowerCase().contains(q) ?? false;
        final senderMatch = item.sender.toLowerCase().contains(q);
        final bankMatch = item.bankName?.toLowerCase().contains(q) ?? false;
        final refMatch = item.referenceNumber?.toLowerCase().contains(q) ?? false;
        final amountMatch = item.amount.toString().contains(q);
        final snippetMatch = item.rawSnippet?.toLowerCase().contains(q) ?? false;
        if (!merchantMatch && !senderMatch && !bankMatch && !refMatch && !amountMatch && !snippetMatch) {
          return false;
        }
      }

      return true;
    }).toList();

    // Unique banks for bank filter dropdown
    final availableBanks = allItems
        .map((e) => e.bankName)
        .whereType<String>()
        .where((b) => b.isNotEmpty)
        .toSet()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Activity Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.read(smsDetectionProvider.notifier).loadAllHistory(),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Activity Summary Bar
                _buildOverviewMetrics(
                  context,
                  pendingCount: pendingCount,
                  approvedCount: approvedCount,
                  rejectedCount: rejectedCount,
                  verifyCount: verifyCount,
                  cs: cs,
                  tt: tt,
                ),

                // Search Bar & Bank Filter
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search merchant, bank, ref, or amount...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        ),
                      ),
                      if (availableBanks.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        PopupMenuButton<String?>(
                          icon: Icon(
                            Icons.filter_list_rounded,
                            color: _selectedBank != null ? cs.primary : cs.onSurface,
                          ),
                          tooltip: 'Filter by bank',
                          onSelected: (bank) => setState(() => _selectedBank = bank),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: null,
                              child: Text('All Banks'),
                            ),
                            const PopupMenuDivider(),
                            ...availableBanks.map(
                              (b) => PopupMenuItem(
                                value: b,
                                child: Text(b),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Filter Status Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: 'All (${allItems.length})',
                        isSelected: _statusFilter == SmsFilterStatus.all,
                        onTap: () => setState(() => _statusFilter = SmsFilterStatus.all),
                        cs: cs,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Pending ($pendingCount)',
                        isSelected: _statusFilter == SmsFilterStatus.pending,
                        onTap: () => setState(() => _statusFilter = SmsFilterStatus.pending),
                        cs: cs,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Approved ($approvedCount)',
                        isSelected: _statusFilter == SmsFilterStatus.approved,
                        onTap: () => setState(() => _statusFilter = SmsFilterStatus.approved),
                        cs: cs,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Rejected ($rejectedCount)',
                        isSelected: _statusFilter == SmsFilterStatus.rejected,
                        onTap: () => setState(() => _statusFilter = SmsFilterStatus.rejected),
                        cs: cs,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Needs Verification ($verifyCount)',
                        isSelected: _statusFilter == SmsFilterStatus.verification,
                        onTap: () => setState(() => _statusFilter = SmsFilterStatus.verification),
                        cs: cs,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // List of Activity Items
                Expanded(
                  child: filteredItems.isEmpty
                      ? _buildEmptyState(context, cs, tt)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: filteredItems.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            return _buildActivityTile(context, item, cs, tt);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildOverviewMetrics(
    BuildContext context, {
    required int pendingCount,
    required int approvedCount,
    required int rejectedCount,
    required int verifyCount,
    required ColorScheme cs,
    required TextTheme tt,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetricColumn('Pending', pendingCount.toString(), cs.primary, tt),
          _buildMetricDivider(cs),
          _buildMetricColumn('Approved', approvedCount.toString(), AppColors.getSuccess(context), tt),
          _buildMetricDivider(cs),
          _buildMetricColumn('Rejected', rejectedCount.toString(), cs.error, tt),
          _buildMetricDivider(cs),
          _buildMetricColumn('Verify', verifyCount.toString(), const Color(0xFFD97706), tt),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, Color color, TextTheme tt) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: tt.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: tt.labelSmall?.copyWith(fontSize: 10.5, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildMetricDivider(ColorScheme cs) {
    return Container(
      width: 1,
      height: 28,
      color: cs.outline.withValues(alpha: 0.15),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ColorScheme cs,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: cs.surface,
      selectedColor: cs.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? cs.primary : cs.onSurface.withValues(alpha: 0.75),
      ),
      side: BorderSide(
        color: isSelected ? cs.primary : cs.outline.withValues(alpha: 0.15),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildActivityTile(
    BuildContext context,
    DetectedSmsTransaction item,
    ColorScheme cs,
    TextTheme tt,
  ) {
    final theme = Theme.of(context);
    final isExpense = item.type == TransactionType.expense;
    final bankInfo = BankDetector.detect(sender: item.sender, body: item.rawSnippet);
    final dateFormat = DateFormat('d MMM yyyy, h:mm a');

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (item.status) {
      case 'approved':
        statusColor = AppColors.getSuccess(context);
        statusLabel = 'Approved';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        statusColor = cs.error;
        statusLabel = 'Rejected';
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = cs.primary;
        statusLabel = 'Pending Review';
        statusIcon = Icons.pending_rounded;
        break;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showTransactionDetailsModal(context, item),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            // Bank Initials Badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bankInfo.brandColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  bankInfo.initials,
                  style: TextStyle(
                    color: bankInfo.brandColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Middle: Merchant & Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.merchant ?? item.sender,
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${bankInfo.name}${item.maskedAccount != null ? ' · ${item.maskedAccount}' : ''}',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.55),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateFormat.format(item.date),
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.4),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),

            // Right: Amount & Status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.formattedAmount(showSign: true),
                  style: (isExpense ? tt.negativeAmount : tt.positiveAmount).copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetailsModal(BuildContext context, DetectedSmsTransaction item) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bankInfo = BankDetector.detect(sender: item.sender, body: item.rawSnippet);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Text(
                  'SMS Transaction Details',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: item.status == 'approved'
                        ? AppColors.getSuccess(context).withValues(alpha: 0.12)
                        : (item.status == 'rejected'
                            ? cs.error.withValues(alpha: 0.12)
                            : cs.primary.withValues(alpha: 0.12)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: item.status == 'approved'
                          ? AppColors.getSuccess(context)
                          : (item.status == 'rejected' ? cs.error : cs.primary),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            _buildDetailRow('Amount', item.formattedAmount(showSign: true), isBold: true),
            _buildDetailRow('Type', item.type == TransactionType.expense ? 'Expense (Debit)' : 'Income (Credit)'),
            _buildDetailRow('Bank', bankInfo.name),
            _buildDetailRow('Account', item.maskedAccount ?? 'Not specified'),
            _buildDetailRow('Merchant / Source', item.merchant ?? item.sender),
            _buildDetailRow('Reference Number', item.referenceNumber ?? 'None'),
            _buildDetailRow('Transaction Date', DateFormat('d MMMM yyyy, h:mm a').format(item.date)),
            _buildDetailRow('Created At', DateFormat('d MMMM yyyy, h:mm a').format(item.createdAt)),

            if (item.rawSnippet != null && item.rawSnippet!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'ORIGINAL MESSAGE SNIPPET',
                style: tt.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  item.rawSnippet!,
                  style: tt.bodySmall?.copyWith(fontFamily: 'monospace', height: 1.3),
                ),
              ),
            ],

            const SizedBox(height: 20),
            if (item.status == 'pending_review') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Review & Approve'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    SmsReviewSheet.show(context, item);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
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
            Icon(Icons.inbox_rounded, size: 54, color: cs.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 14),
            Text(
              'No Matching SMS Records',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting your search terms or filters.',
              style: tt.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }
}

