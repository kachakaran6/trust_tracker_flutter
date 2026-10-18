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
    bool recordSettlement = debt.affectsBalance;
    final currency = ref.read(settingsProvider).currency;
    final isGiven = (debt.debtType ?? 'given') == 'given';
    final person = debt.personName?.isNotEmpty == true ? debt.personName! : 'Person';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final cs = theme.colorScheme;
            final tt = theme.textTheme;
            final isDark = theme.brightness == Brightness.dark;
            final successColor = AppColors.getSuccess(context);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: successColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_circle_rounded, color: successColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Settle Debt',
                      style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
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
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cs.outline.withOpacity(0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: recordSettlement,
                          activeColor: cs.primary,
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
                                style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              Text(
                                isGiven
                                    ? 'Automatically adds +$currency${debt.amount.toStringAsFixed(0)} back to your wallet'
                                    : 'Automatically records -$currency${debt.amount.toStringAsFixed(0)} as paid out',
                                style: tt.bodySmall?.copyWith(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant,
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
                  child: Text('Cancel', style: TextStyle(color: cs.onSurfaceVariant)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: successColor,
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
        final successColor = AppColors.getSuccess(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Debt with $person marked as settled successfully!'),
            backgroundColor: successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _clearDebtFlagDialog(TransactionModel debt) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Remove Debt Flag?'),
          content: const Text(
            'This will unmark this transaction as debt and cancel any pending reminders, keeping the transaction as a normal record.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: cs.onSurfaceVariant)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final activeTab = ref.watch(debtFilterTabProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Debt & Lent Manager',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
                    _buildSummarySection(context, currency, isDark, cs, tt),
                    const SizedBox(height: 16),
                    // Filter Chips
                    _buildFilterTabs(context, isDark, cs, tt),
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
                          color: cs.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.handshake_outlined,
                          size: 48,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        activeTab == 3 ? 'No Settled History' : 'No Active Debts',
                        style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          activeTab == 3
                              ? 'Settled debts history will appear here for your reference.'
                              : 'Flag any transaction as Debt or Lent with a due date to keep track of money lent or borrowed.',
                          textAlign: TextAlign.center,
                          style: tt.bodyMedium?.copyWith(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
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
                      return _buildDebtCard(debt, currency, isDark, cs, tt, index);
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
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Debt / Lent', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context, String currency, bool isDark, ColorScheme cs, TextTheme tt) {
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

    final successColor = AppColors.getSuccess(context);
    final errorColor = AppColors.getError(context);
    final netDiff = totalGiven - totalTaken;
    final isNetPositive = netDiff >= 0;

    return Column(
      children: [
        if (overdueCount > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: errorColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: errorColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: errorColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$overdueCount debt reminder(s) are overdue today!',
                    style: TextStyle(
                      color: errorColor,
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: cs.outline.withOpacity(0.12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: successColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.arrow_upward_rounded, color: successColor, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lent',
                            style: tt.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$currency${totalGiven.toStringAsFixed(0)}',
                        style: tt.headlineSmall?.copyWith(
                          color: successColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Money to receive',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: cs.outline.withOpacity(0.12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: errorColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.arrow_downward_rounded, color: errorColor, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Borrowed',
                            style: tt.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$currency${totalTaken.toStringAsFixed(0)}',
                        style: tt.headlineSmall?.copyWith(
                          color: errorColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Money to pay',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (totalGiven > 0 || totalTaken > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outline.withOpacity(0.08)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isNetPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      size: 16,
                      color: isNetPositive ? successColor : errorColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Net Balance',
                      style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Text(
                  '${isNetPositive ? '+' : '-'}$currency${netDiff.abs().toStringAsFixed(0)} (${isNetPositive ? 'to receive' : 'to pay'})',
                  style: tt.labelSmall?.copyWith(
                    color: isNetPositive ? successColor : errorColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFilterTabs(BuildContext context, bool isDark, ColorScheme cs, TextTheme tt) {
    final activeTab = ref.watch(debtFilterTabProvider);

    final tabs = [
      {'label': 'All Active', 'icon': Icons.all_inbox_rounded},
      {'label': 'Given', 'icon': Icons.call_made_rounded},
      {'label': 'Taken', 'icon': Icons.call_received_rounded},
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
                color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
              ),
              label: Text(
                tabs[index]['label'] as String,
                style: TextStyle(
                  color: isSelected ? cs.onPrimary : cs.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              selected: isSelected,
              selectedColor: cs.primary,
              backgroundColor: cs.surface,
              side: BorderSide(
                color: isSelected ? cs.primary : cs.outline.withOpacity(0.15),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Widget _buildDebtCard(TransactionModel debt, String currency, bool isDark, ColorScheme cs, TextTheme tt, int index) {
    final isGiven = (debt.debtType ?? 'given') == 'given';
    final person = debt.personName?.isNotEmpty == true ? debt.personName! : 'Unnamed';
    final now = DateTime.now();
    final successColor = AppColors.getSuccess(context);
    final errorColor = AppColors.getError(context);
    final warningColor = AppColors.getWarning(context);
    final infoColor = AppColors.getInfo(context);

    final hasNote = (debt.note != null && debt.note!.trim().isNotEmpty);
    final hasCustomDesc = debt.description.isNotEmpty &&
        debt.description.toLowerCase() != 'lent money' &&
        debt.description.toLowerCase() != 'borrowed money' &&
        !debt.description.startsWith('Transaction #');
    final subtitleText = hasNote ? debt.note!.trim() : (hasCustomDesc ? debt.description : null);

    String dueStatusText;
    Color dueStatusColor;
    if (debt.isSettled) {
      dueStatusText = 'Settled on ${debt.settledAt != null ? DateFormat('MMM dd').format(debt.settledAt!) : DateFormat('MMM dd').format(debt.date)}';
      dueStatusColor = successColor;
    } else if (debt.dueDate != null) {
      final diffDays = debt.dueDate!.difference(DateTime(now.year, now.month, now.day)).inDays;
      final dueFmt = DateFormat('MMM dd').format(debt.dueDate!);
      if (diffDays < 0) {
        dueStatusText = 'Due $dueFmt · ⚠️ ${diffDays.abs()}d overdue';
        dueStatusColor = errorColor;
      } else if (diffDays == 0) {
        dueStatusText = 'Due $dueFmt · ⏰ Due today';
        dueStatusColor = warningColor;
      } else if (diffDays == 1) {
        dueStatusText = 'Due $dueFmt · In 1 day';
        dueStatusColor = infoColor;
      } else {
        dueStatusText = 'Due $dueFmt · In $diffDays days';
        dueStatusColor = infoColor;
      }
    } else {
      dueStatusText = DateFormat('MMM dd, yyyy').format(debt.date);
      dueStatusColor = cs.onSurfaceVariant.withOpacity(0.75);
    }

    final typeColor = isGiven ? successColor : errorColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cs.outline.withOpacity(isDark ? 0.12 : 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.18) : cs.shadow.withOpacity(0.025),
            blurRadius: 6,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: !debt.isSettled ? () => _settleDebtDialog(debt) : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Leading Direction Avatar
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      isGiven ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      color: typeColor,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // 2. Middle Content (Name, badges, due date)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Line: Person + Badges
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              person,
                              style: tt.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isGiven ? 'Lent' : 'Borrowed',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: typeColor,
                              ),
                            ),
                          ),
                          if (!debt.affectsBalance) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: cs.onSurfaceVariant.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bookmark_border_rounded, size: 9, color: cs.onSurfaceVariant),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Book',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),

                      if (subtitleText != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitleText,
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant.withOpacity(0.75),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      const SizedBox(height: 4),

                      // Bottom Line: Due date / Urgency
                      Row(
                        children: [
                          Icon(
                            debt.dueDate != null ? Icons.event_available_rounded : Icons.calendar_today_rounded,
                            size: 11.5,
                            color: dueStatusColor,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              dueStatusText,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: dueStatusColor,
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
                const SizedBox(width: 8),

                // 3. Right Column: Amount (Top) + Actions (Bottom)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$currency${debt.amount.toStringAsFixed(2)}',
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: typeColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!debt.isSettled) ...[
                          InkWell(
                            onTap: () => _settleDebtDialog(debt),
                            borderRadius: BorderRadius.circular(5),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: successColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: successColor.withOpacity(0.25),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_rounded, size: 11, color: successColor),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Mark Settled',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10.5,
                                      color: successColor,
                                      letterSpacing: -0.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                        ] else ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.done_all_rounded, size: 11, color: successColor),
                              const SizedBox(width: 3),
                              Text(
                                'Settled',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: successColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 2),
                        ],
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            iconSize: 15,
                            splashRadius: 12,
                            icon: Icon(Icons.more_vert_rounded, size: 15, color: cs.onSurfaceVariant.withOpacity(0.55)),
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
                              if (!debt.isSettled)
                                const PopupMenuItem(
                                  value: 'clear_flag',
                                  height: 36,
                                  child: Row(
                                    children: [
                                      Icon(Icons.flag_outlined, size: 15),
                                      SizedBox(width: 8),
                                      Text('Remove Debt Flag', style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                              PopupMenuItem(
                                value: 'delete',
                                height: 36,
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded, color: errorColor, size: 15),
                                    const SizedBox(width: 8),
                                    Text('Delete Transaction', style: TextStyle(color: errorColor, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms, delay: (index * 30).ms);
  }
}
