import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:trust_tracker_flutter/core/theme/app_colors.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/transactions/data/repositories/transaction_repository.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:trust_tracker_flutter/core/utils/extensions.dart';

final debtFilterTabProvider = StateProvider<int>((ref) => 0); // 0: All Active, 1: Given, 2: Taken, 3: Settled

class DebtManagerPage extends ConsumerStatefulWidget {
  const DebtManagerPage({super.key});

  @override
  ConsumerState<DebtManagerPage> createState() => _DebtManagerPageState();
}

class _DebtManagerPageState extends ConsumerState<DebtManagerPage> {
  bool _isLoading = false;
  Map<String, dynamic> _summary = {
    'totalGiven': 0.0,
    'totalTaken': 0.0,
    'netBalance': 0.0,
    'activeCount': 0,
    'overdueCount': 0,
  };
  List<TransactionModel> _debts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final tabIndex = ref.read(debtFilterTabProvider);

      final summary = await repo.getDebtSummary();

      List<TransactionModel> list = [];
      if (tabIndex == 0) {
        list = await repo.getDebts(isSettled: false);
      } else if (tabIndex == 1) {
        list = await repo.getDebts(isSettled: false, debtType: 'given');
      } else if (tabIndex == 2) {
        list = await repo.getDebts(isSettled: false, debtType: 'taken');
      } else if (tabIndex == 3) {
        list = await repo.getDebts(isSettled: true);
      }

      if (mounted) {
        setState(() {
          _summary = summary;
          _debts = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _settleDebtDialog(TransactionModel debt) async {
    bool recordSettlement = true;
    final currency = ref.read(settingsProvider).currency;
    final isGiven = (debt.debtType ?? 'given') == 'given';
    final person = debt.personName?.isNotEmpty == true ? debt.personName! : 'Person';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Settle Debt / Udhar',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isGiven
                        ? 'Mark $person\'s debt of $currency${debt.amount.toStringAsFixed(2)} as repaid?'
                        : 'Mark your debt of $currency${debt.amount.toStringAsFixed(2)} to $person as paid?',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: recordSettlement,
                          activeColor: AppColors.primary,
                          onChanged: (val) {
                            setDialogState(() {
                              recordSettlement = val ?? true;
                            });
                          },
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isGiven
                                    ? 'Add Income Entry to Balance'
                                    : 'Add Expense Entry to Balance',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              Text(
                                isGiven
                                    ? 'Automatically adds +$currency${debt.amount.toStringAsFixed(0)} back to your wallet'
                                    : 'Automatically records -$currency${debt.amount.toStringAsFixed(0)} as paid out',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Confirm Settle'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && debt.id != null) {
      final repo = ref.read(transactionRepositoryProvider);
      await repo.markDebtAsSettled(debt.id!, createSettlementTxn: recordSettlement);
      ref.read(transactionListProvider.notifier).refresh();
      _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Debt with $person marked as settled successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _clearDebtFlagDialog(TransactionModel debt) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Remove Debt Flag?'),
          content: const Text(
            'This will unmark this transaction as debt/udhar and cancel any pending reminders, keeping the transaction as a normal record.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove Flag'),
            ),
          ],
        );
      },
    );

    if (result == true && debt.id != null) {
      final repo = ref.read(transactionRepositoryProvider);
      await repo.clearDebtFlag(debt.id!);
      ref.read(transactionListProvider.notifier).refresh();
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = getCurrencySymbol(ref.watch(settingsProvider).currency);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeTab = ref.watch(debtFilterTabProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Debt & Lent Manager',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Overview Summary Cards
                    _buildSummarySection(currency, isDark),
                    const SizedBox(height: 16),
                    // Filter Chips
                    _buildFilterTabs(isDark),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_debts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.handshake_outlined,
                          size: 48,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        activeTab == 3 ? 'No Settled History' : 'No Active Debts (ઉધારી)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          activeTab == 3
                              ? 'Settled debts history will appear here.'
                              : 'Flag any transaction as Debt / Lent (ઉધારી) with a due date duration to track money lent or borrowed!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final debt = _debts[index];
                      return _buildDebtCard(debt, currency, isDark, index);
                    },
                    childCount: _debts.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/add-transaction');
          _loadData();
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Debt / Lent', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSummarySection(String currency, bool isDark) {
    final activeDebts = _debts.where((d) => !d.isSettled).toList();
    double totalGiven = 0;
    double totalTaken = 0;
    int overdueCount = 0;
    final now = DateTime.now();

    for (final d in activeDebts) {
      if ((d.debtType ?? 'given') == 'given') {
        totalGiven += d.amount;
      } else {
        totalTaken += d.amount;
      }

      if (d.dueDate != null && d.dueDate!.isBefore(now)) {
        overdueCount++;
      }
    }

    return Column(
      children: [
        if (overdueCount > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$overdueCount debt reminder(s) are overdue today!',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().shake(duration: 400.ms),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Lent (ઉધારી આપેલ)',
                            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$currency${totalGiven.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Money to receive',
                      style: TextStyle(color: Colors.white60, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Borrowed (ઉધારી લીધેલ)',
                            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$currency${totalTaken.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Money to pay',
                      style: TextStyle(color: Colors.white60, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterTabs(bool isDark) {
    final activeTab = ref.watch(debtFilterTabProvider);

    final tabs = [
      {'label': 'All Active', 'icon': Icons.all_inbox_rounded},
      {'label': 'Given (આપેલ)', 'icon': Icons.call_made_rounded},
      {'label': 'Taken (લીધેલ)', 'icon': Icons.call_received_rounded},
      {'label': 'Settled History', 'icon': Icons.history_rounded},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = activeTab == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              showCheckmark: false,
              avatar: Icon(
                tabs[index]['icon'] as IconData,
                size: 16,
                color: isSelected ? Colors.white : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              ),
              label: Text(
                tabs[index]['label'] as String,
                style: TextStyle(
                  color: isSelected ? Colors.white : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
              onSelected: (selected) {
                if (selected) {
                  ref.read(debtFilterTabProvider.notifier).state = index;
                  _loadData();
                }
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDebtCard(TransactionModel debt, String currency, bool isDark, int index) {
    final isGiven = (debt.debtType ?? 'given') == 'given';
    final person = debt.personName?.isNotEmpty == true ? debt.personName! : 'Unnamed';
    final now = DateTime.now();

    Widget statusBadge;
    if (debt.isSettled) {
      statusBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          '✓ Settled',
          style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );
    } else if (debt.dueDate != null) {
      final diffDays = debt.dueDate!.difference(DateTime(now.year, now.month, now.day)).inDays;
      if (diffDays < 0) {
        statusBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '⚠️ Overdue by ${diffDays.abs()} day(s)',
            style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        );
      } else if (diffDays == 0) {
        statusBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            '⏰ Due Today',
            style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        );
      } else {
        statusBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.info.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'In $diffDays day(s)',
            style: const TextStyle(color: AppColors.info, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        );
      }
    } else {
      statusBadge = const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGiven ? const Color(0xFF10B981).withOpacity(0.3) : const Color(0xFFEF4444).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isGiven ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFEF4444).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isGiven ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: isGiven ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            person,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isGiven ? const Color(0xFF10B981).withOpacity(0.1) : const Color(0xFFEF4444).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isGiven ? 'Lent (આપેલ)' : 'Borrowed (લીધેલ)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isGiven ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      debt.description.isNotEmpty ? debt.description : 'Transaction #${debt.id}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$currency${debt.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isGiven ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(height: 4),
                  statusBadge,
                ],
              ),
            ],
          ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  debt.dueDate != null
                      ? 'Due: ${DateFormat('MMM dd, yyyy').format(debt.dueDate!)}'
                      : 'Date: ${DateFormat('MMM dd, yyyy').format(debt.date)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                Row(
                  children: [
                    if (!debt.isSettled) ...[
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _settleDebtDialog(debt),
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('Mark Settled', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded, size: 18, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                        onSelected: (value) async {
                          if (value == 'clear_flag') {
                            _clearDebtFlagDialog(debt);
                          } else if (value == 'delete' && debt.id != null) {
                            await ref.read(transactionRepositoryProvider).deleteTransaction(debt.id!);
                            ref.read(transactionListProvider.notifier).refresh();
                            _loadData();
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'clear_flag',
                            child: Row(
                              children: [
                                Icon(Icons.flag_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('Remove Debt Flag'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                                SizedBox(width: 8),
                                Text('Delete Transaction', style: TextStyle(color: AppColors.error)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        'Settled on ${debt.settledAt != null ? DateFormat('MMM dd').format(debt.settledAt!) : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms, delay: (index * 40).ms);
  }
}
