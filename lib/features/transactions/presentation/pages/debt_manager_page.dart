import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:trust_tracker_flutter/features/transactions/presentation/widgets/add_debt_bottom_sheet.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/widgets/debt_export_pdf_sheet.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/pages/person_debt_detail_page.dart';

final debtFilterTabProvider = StateProvider<int>((ref) => 0); // 0: All Active, 1: Given, 2: Taken, 3: Settled

class _PersonDebtGroup {
  final String personName;
  final List<TransactionModel> transactions;
  final double totalGiven;
  final double totalTaken;
  final double netBalance;
  final int activeCount;
  final int settledCount;
  final int overdueCount;

  _PersonDebtGroup({
    required this.personName,
    required this.transactions,
    required this.totalGiven,
    required this.totalTaken,
    required this.netBalance,
    required this.activeCount,
    required this.settledCount,
    required this.overdueCount,
  });
}

class _SettleDialogResult {
  final double amount;
  final bool recordSettlement;
  _SettleDialogResult({required this.amount, required this.recordSettlement});
}

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
  List<TransactionModel> _allActiveDebts = [];

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
      final allActive = await repo.getDebts(isSettled: false);

      List<TransactionModel> list = [];
      if (tabIndex == 0) {
        list = allActive;
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
          _allActiveDebts = allActive;
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

  List<_PersonDebtGroup> _groupDebts(List<TransactionModel> debts) {
    final Map<String, List<TransactionModel>> map = {};
    for (final debt in debts) {
      final rawName = debt.personName?.trim();
      final name = (rawName != null && rawName.isNotEmpty) ? rawName : 'Unnamed';
      final key = name.toLowerCase();
      map.putIfAbsent(key, () => []).add(debt);
    }

    final now = DateTime.now();
    final groups = <_PersonDebtGroup>[];

    for (final entry in map.entries) {
      final txns = entry.value;
      // Sort transactions by date descending (newest first)
      txns.sort((a, b) => b.date.compareTo(a.date));

      final displayName = txns.first.personName?.trim();
      final effectiveName = (displayName != null && displayName.isNotEmpty) ? displayName : 'Unnamed';

      double totalGiven = 0;
      double totalTaken = 0;
      int activeCount = 0;
      int settledCount = 0;
      int overdueCount = 0;

      for (final t in txns) {
        final isGiven = (t.debtType ?? 'given') == 'given';
        if (!t.isSettled) {
          if (isGiven) {
            totalGiven += t.amount;
          } else {
            totalTaken += t.amount;
          }
          activeCount++;
          if (t.dueDate != null && t.dueDate!.isBefore(now)) {
            overdueCount++;
          }
        } else {
          settledCount++;
        }
      }

      groups.add(_PersonDebtGroup(
        personName: effectiveName,
        transactions: txns,
        totalGiven: totalGiven,
        totalTaken: totalTaken,
        netBalance: totalGiven - totalTaken,
        activeCount: activeCount,
        settledCount: settledCount,
        overdueCount: overdueCount,
      ));
    }

    // Sort groups: overdue first, then by latest transaction date
    groups.sort((a, b) {
      if (a.overdueCount > 0 && b.overdueCount == 0) return -1;
      if (b.overdueCount > 0 && a.overdueCount == 0) return 1;
      final aDate = a.transactions.isNotEmpty ? a.transactions.first.date : DateTime(2000);
      final bDate = b.transactions.isNotEmpty ? b.transactions.first.date : DateTime(2000);
      return bDate.compareTo(aDate);
    });

    return groups;
  }

  Widget _buildQuickChip(
    double fraction,
    String label,
    double total,
    TextEditingController controller,
    ValueChanged<double> onSelected,
    ColorScheme cs,
  ) {
    final amt = (total * fraction).roundToDouble();
    return Expanded(
      child: InkWell(
        onTap: () {
          controller.text = amt.toStringAsFixed(0);
          onSelected(amt);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.primary.withOpacity(0.2)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _settlePersonGroupDialog(_PersonDebtGroup group) async {
    final activeDebts = group.transactions.where((d) => !d.isSettled).toList();
    if (activeDebts.isEmpty) return;

    final currency = getCurrencySymbol(ref.read(settingsProvider).currency);
    final person = group.personName.isNotEmpty ? group.personName : 'Person';
    final isNetPositive = group.netBalance >= 0;
    final totalToSettle = group.netBalance.abs() > 0
        ? group.netBalance.abs()
        : activeDebts.fold<double>(0.0, (sum, d) => sum + d.amount);

    bool recordSettlement = activeDebts.any((d) => d.affectsBalance);
    bool isPartial = false;
    final amountController = TextEditingController(text: totalToSettle.toStringAsFixed(0));
    double settleAmount = totalToSettle;

    final result = await showModalBottomSheet<_SettleDialogResult>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            final cs = theme.colorScheme;
            final tt = theme.textTheme;
            final isDark = theme.brightness == Brightness.dark;
            final warningColor = AppColors.getWarning(context);
            final errorColor = AppColors.getError(context);

            final remaining = (totalToSettle - settleAmount);
            final isValid = settleAmount > 0 && settleAmount <= totalToSettle;
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Drag Handle
                          Center(
                            child: Container(
                              width: 42,
                              height: 4.5,
                              decoration: BoxDecoration(
                                color: cs.onSurface.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Header Row: Avatar + Title + Close Button
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      cs.primary,
                                      cs.primary.withOpacity(0.8),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: cs.primary.withOpacity(0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    person.isNotEmpty ? person[0].toUpperCase() : '?',
                                    style: TextStyle(
                                      color: cs.onPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 19,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Settle with $person',
                                      style: tt.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$currency${totalToSettle.toStringAsFixed(2)} balance · ${activeDebts.length} active record(s)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context, null),
                                icon: const Icon(Icons.close_rounded),
                                style: IconButton.styleFrom(
                                  backgroundColor: cs.onSurface.withOpacity(0.06),
                                  foregroundColor: cs.onSurfaceVariant,
                                  padding: const EdgeInsets.all(8),
                                  minimumSize: const Size(36, 36),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Segmented Mode Selector: Full Settle vs Partial Payment
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.cardDark : cs.surfaceContainerHighest.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cs.outline.withOpacity(0.12)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setSheetState(() {
                                        isPartial = false;
                                        settleAmount = totalToSettle;
                                        amountController.text = totalToSettle.toStringAsFixed(0);
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.symmetric(vertical: 9),
                                      decoration: BoxDecoration(
                                        color: !isPartial
                                            ? cs.primary
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: !isPartial
                                            ? [
                                                BoxShadow(
                                                  color: cs.primary.withOpacity(0.3),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Full Settle',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: !isPartial ? cs.onPrimary : cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setSheetState(() {
                                        isPartial = true;
                                        final half = (totalToSettle / 2).roundToDouble();
                                        settleAmount = half > 0 ? half : totalToSettle;
                                        amountController.text = settleAmount.toStringAsFixed(0);
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.symmetric(vertical: 9),
                                      decoration: BoxDecoration(
                                        color: isPartial
                                            ? cs.primary
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: isPartial
                                            ? [
                                                BoxShadow(
                                                  color: cs.primary.withOpacity(0.3),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Partial Payment',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: isPartial ? cs.onPrimary : cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Amount Breakdown Card
                          if (!isPartial)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: cs.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cs.primary.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                          color: cs.primary.withOpacity(0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isNetPositive ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                          color: cs.primary,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isNetPositive ? 'Total to Receive' : 'Total to Pay',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                          Text(
                                            'Clears all $currency${totalToSettle.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: cs.onSurfaceVariant.withOpacity(0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '$currency${totalToSettle.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 20,
                                      color: cs.primary,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Partial Input & Chips
                          if (isPartial) ...[
                            Text(
                              isNetPositive ? 'Amount Received Now:' : 'Amount Paid Now:',
                              style: tt.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              decoration: InputDecoration(
                                prefixText: '$currency ',
                                prefixStyle: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: cs.primary,
                                ),
                                hintText: '0.00',
                                filled: true,
                                fillColor: isDark ? AppColors.cardDark : AppColors.backgroundLight,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: cs.outline.withOpacity(0.18)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: cs.primary, width: 2.0),
                                ),
                              ),
                              onChanged: (val) {
                                setSheetState(() {
                                  settleAmount = double.tryParse(val.trim()) ?? 0.0;
                                });
                              },
                            ),
                            const SizedBox(height: 8),

                            // Quick preset chips: 25%, 50%, 75%, Max
                            Row(
                              children: [
                                _buildQuickChip(0.25, '25%', totalToSettle, amountController, (val) {
                                  setSheetState(() => settleAmount = val);
                                }, cs),
                                const SizedBox(width: 8),
                                _buildQuickChip(0.50, '50%', totalToSettle, amountController, (val) {
                                  setSheetState(() => settleAmount = val);
                                }, cs),
                                const SizedBox(width: 8),
                                _buildQuickChip(0.75, '75%', totalToSettle, amountController, (val) {
                                  setSheetState(() => settleAmount = val);
                                }, cs),
                                const SizedBox(width: 8),
                                _buildQuickChip(1.0, 'Max', totalToSettle, amountController, (val) {
                                  setSheetState(() => settleAmount = val);
                                }, cs),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Split summary card
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isValid
                                    ? cs.primary.withOpacity(0.06)
                                    : errorColor.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isValid
                                      ? cs.primary.withOpacity(0.2)
                                      : errorColor.withOpacity(0.25),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        isNetPositive ? 'Settling Now:' : 'Paying Now:',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: cs.onSurface,
                                        ),
                                      ),
                                      Text(
                                        '$currency${settleAmount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: isValid ? cs.primary : errorColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isValid && remaining > 0) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Remaining Debt:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                        Text(
                                          '$currency${remaining.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: warningColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'ℹ️ $currency${remaining.toStringAsFixed(2)} stays active under $person',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurfaceVariant.withOpacity(0.8),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (settleAmount > totalToSettle)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '⚠️ Amount cannot exceed $currency${totalToSettle.toStringAsFixed(2)}',
                                        style: TextStyle(fontSize: 11, color: errorColor, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  if (settleAmount <= 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '⚠️ Enter an amount greater than 0',
                                        style: TextStyle(fontSize: 11, color: errorColor, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),

                          // Wallet Balance Toggle Card
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.cardDark : AppColors.backgroundLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cs.outline.withOpacity(0.12)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: cs.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.account_balance_wallet_rounded,
                                    color: cs.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isNetPositive
                                            ? 'Record in Wallet Balance'
                                            : 'Deduct from Wallet Balance',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        isNetPositive
                                            ? '+$currency${settleAmount.toStringAsFixed(0)} cashflow back to wallet'
                                            : '-$currency${settleAmount.toStringAsFixed(0)} paid out of wallet',
                                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: recordSettlement,
                                  thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return Colors.white;
                                    }
                                    return isDark ? Colors.grey.shade400 : Colors.white;
                                  }),
                                  trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return cs.primary;
                                    }
                                    return isDark ? Colors.white24 : Colors.grey.shade300;
                                  }),
                                  trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                                  onChanged: (val) {
                                    setSheetState(() => recordSettlement = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Bottom Action Buttons
                          Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: SizedBox(
                                  height: 48,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: cs.onSurfaceVariant,
                                      side: BorderSide(color: cs.outline.withOpacity(0.2)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: () => Navigator.pop(context, null),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isValid ? cs.primary : cs.surfaceContainerHighest,
                                      foregroundColor: cs.onPrimary,
                                      elevation: isValid ? 2 : 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: isValid
                                        ? () => Navigator.pop(
                                              context,
                                              _SettleDialogResult(
                                                amount: settleAmount,
                                                recordSettlement: recordSettlement,
                                              ),
                                            )
                                        : null,
                                    icon: const Icon(Icons.check_rounded, size: 18),
                                    label: Text(
                                      isPartial && remaining > 0
                                          ? 'Settle $currency${settleAmount.toStringAsFixed(0)}'
                                          : 'Confirm Settle',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      final repo = ref.read(transactionRepositoryProvider);
      if (result.amount >= totalToSettle) {
        for (final debt in activeDebts) {
          if (debt.id != null) {
            await repo.markDebtAsSettled(debt.id!, createSettlementTxn: result.recordSettlement);
          }
        }
      } else {
        double remainingToDeduct = result.amount;
        final sortedDebts = [...activeDebts]..sort((a, b) => a.date.compareTo(b.date));
        for (final debt in sortedDebts) {
          if (debt.id == null || remainingToDeduct <= 0) break;
          if (remainingToDeduct >= debt.amount) {
            await repo.markDebtAsSettled(debt.id!, createSettlementTxn: result.recordSettlement);
            remainingToDeduct -= debt.amount;
          } else {
            await repo.settlePartialDebt(
              transactionId: debt.id!,
              settledAmount: remainingToDeduct,
              createSettlementTxn: result.recordSettlement,
            );
            remainingToDeduct = 0;
          }
        }
      }

      ref.read(transactionListProvider.notifier).refresh();
      _loadData();

      if (mounted) {
        final isPartialDone = result.amount < totalToSettle;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPartialDone
                  ? '🎉 Payment of $currency${result.amount.toStringAsFixed(2)} recorded for $person! Remaining: $currency${(totalToSettle - result.amount).toStringAsFixed(2)}'
                  : '🎉 All debt with $person settled successfully!',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _settleDebtDialog(TransactionModel debt) async {
    bool recordSettlement = debt.affectsBalance;
    final currency = getCurrencySymbol(ref.read(settingsProvider).currency);
    final isGiven = (debt.debtType ?? 'given') == 'given';
    final person = debt.personName?.isNotEmpty == true ? debt.personName! : 'Person';

    bool isPartial = false;
    final amountController = TextEditingController(text: debt.amount.toStringAsFixed(0));
    double settleAmount = debt.amount;

    final result = await showModalBottomSheet<_SettleDialogResult>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            final cs = theme.colorScheme;
            final tt = theme.textTheme;
            final isDark = theme.brightness == Brightness.dark;
            final warningColor = AppColors.getWarning(context);
            final errorColor = AppColors.getError(context);

            final remaining = (debt.amount - settleAmount);
            final isValid = settleAmount > 0 && settleAmount <= debt.amount;
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Drag Handle
                          Center(
                            child: Container(
                              width: 42,
                              height: 4.5,
                              decoration: BoxDecoration(
                                color: cs.onSurface.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Header Row: Avatar + Title + Close Button
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      cs.primary,
                                      cs.primary.withOpacity(0.8),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: cs.primary.withOpacity(0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    person.isNotEmpty ? person[0].toUpperCase() : '?',
                                    style: TextStyle(
                                      color: cs.onPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 19,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Settle with $person',
                                      style: tt.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$currency${debt.amount.toStringAsFixed(2)} total · ${isGiven ? 'You Lent' : 'You Borrowed'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context, null),
                                icon: const Icon(Icons.close_rounded),
                                style: IconButton.styleFrom(
                                  backgroundColor: cs.onSurface.withOpacity(0.06),
                                  foregroundColor: cs.onSurfaceVariant,
                                  padding: const EdgeInsets.all(8),
                                  minimumSize: const Size(36, 36),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Segmented Mode Selector: Full Settle vs Partial Payment
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.cardDark : cs.surfaceContainerHighest.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cs.outline.withOpacity(0.12)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setSheetState(() {
                                        isPartial = false;
                                        settleAmount = debt.amount;
                                        amountController.text = debt.amount.toStringAsFixed(0);
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.symmetric(vertical: 9),
                                      decoration: BoxDecoration(
                                        color: !isPartial
                                            ? cs.primary
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: !isPartial
                                            ? [
                                                BoxShadow(
                                                  color: cs.primary.withOpacity(0.3),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Full Settle',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: !isPartial ? cs.onPrimary : cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setSheetState(() {
                                        isPartial = true;
                                        final half = (debt.amount / 2).roundToDouble();
                                        settleAmount = half > 0 ? half : debt.amount;
                                        amountController.text = settleAmount.toStringAsFixed(0);
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.symmetric(vertical: 9),
                                      decoration: BoxDecoration(
                                        color: isPartial
                                            ? cs.primary
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: isPartial
                                            ? [
                                                BoxShadow(
                                                  color: cs.primary.withOpacity(0.3),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Partial Payment',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: isPartial ? cs.onPrimary : cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Full Settle Summary Card
                          if (!isPartial)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cs.primary.withOpacity(0.07),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cs.primary.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                          color: cs.primary.withOpacity(0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.check_rounded, color: cs.primary, size: 16),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isGiven ? 'Total to Receive' : 'Total to Pay',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                          Text(
                                            'Clears all $currency${debt.amount.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: cs.onSurfaceVariant.withOpacity(0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '$currency${debt.amount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 20,
                                      color: cs.primary,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Partial Input & Chips
                          if (isPartial) ...[
                            Text(
                              isGiven ? 'Amount Received Now:' : 'Amount Paid Now:',
                              style: tt.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              decoration: InputDecoration(
                                prefixText: '$currency ',
                                prefixStyle: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                                hintText: '0',
                                filled: true,
                                fillColor: isDark ? AppColors.cardDark : cs.surfaceContainerHighest.withOpacity(0.25),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: cs.outline.withOpacity(0.2)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: cs.outline.withOpacity(0.2)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: cs.primary, width: 2),
                                ),
                              ),
                              onChanged: (val) {
                                setSheetState(() {
                                  settleAmount = double.tryParse(val.trim()) ?? 0.0;
                                });
                              },
                            ),
                            const SizedBox(height: 8),

                            // Quick percentage chips (25%, 50%, 75%, Max)
                            Row(
                              children: [
                                _buildQuickChip(0.25, '25%', debt.amount, amountController, (val) {
                                  setSheetState(() => settleAmount = val);
                                }, cs),
                                const SizedBox(width: 8),
                                _buildQuickChip(0.50, '50%', debt.amount, amountController, (val) {
                                  setSheetState(() => settleAmount = val);
                                }, cs),
                                const SizedBox(width: 8),
                                _buildQuickChip(0.75, '75%', debt.amount, amountController, (val) {
                                  setSheetState(() => settleAmount = val);
                                }, cs),
                                const SizedBox(width: 8),
                                _buildQuickChip(1.0, 'Max', debt.amount, amountController, (val) {
                                  setSheetState(() => settleAmount = val);
                                }, cs),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Breakdown Card
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isValid
                                    ? (remaining > 0 ? warningColor.withOpacity(0.08) : cs.primary.withOpacity(0.08))
                                    : errorColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isValid
                                      ? (remaining > 0 ? warningColor.withOpacity(0.3) : cs.primary.withOpacity(0.3))
                                      : errorColor.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        isGiven ? 'Settling Now:' : 'Paying Now:',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                      Text(
                                        '$currency${settleAmount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: isValid ? cs.primary : errorColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (remaining > 0 && isValid) ...[
                                    const Divider(height: 14),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Remaining Balance:',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                        Text(
                                          '$currency${remaining.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: warningColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'ℹ️ $currency${remaining.toStringAsFixed(2)} stays active under $person',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurfaceVariant.withOpacity(0.8),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (settleAmount > debt.amount)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '⚠️ Amount cannot exceed $currency${debt.amount.toStringAsFixed(2)}',
                                        style: TextStyle(fontSize: 11, color: errorColor, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  if (settleAmount <= 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '⚠️ Enter an amount greater than 0',
                                        style: TextStyle(fontSize: 11, color: errorColor, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),

                          // Wallet Balance Switch Card
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.cardDark : cs.surfaceContainerHighest.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cs.outline.withOpacity(0.12)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: (recordSettlement ? cs.primary : cs.onSurfaceVariant).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.account_balance_wallet_rounded,
                                    size: 18,
                                    color: recordSettlement ? cs.primary : cs.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isGiven ? 'Add Income Entry to Balance' : 'Add Expense Entry to Balance',
                                        style: tt.labelMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                      Text(
                                        isGiven
                                            ? '+$currency${settleAmount.toStringAsFixed(0)} cashflow back to wallet'
                                            : '-$currency${settleAmount.toStringAsFixed(0)} cashflow paid out',
                                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: recordSettlement,
                                  thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return Colors.white;
                                    }
                                    return isDark ? Colors.grey.shade400 : Colors.white;
                                  }),
                                  trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return cs.primary;
                                    }
                                    return isDark ? Colors.white24 : Colors.grey.shade300;
                                  }),
                                  trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                                  onChanged: (val) {
                                    setSheetState(() => recordSettlement = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Bottom Action Buttons
                          Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: SizedBox(
                                  height: 48,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: cs.onSurfaceVariant,
                                      side: BorderSide(color: cs.outline.withOpacity(0.2)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: () => Navigator.pop(context, null),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isValid ? cs.primary : cs.surfaceContainerHighest,
                                      foregroundColor: cs.onPrimary,
                                      elevation: isValid ? 2 : 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: isValid
                                        ? () => Navigator.pop(
                                              context,
                                              _SettleDialogResult(
                                                amount: settleAmount,
                                                recordSettlement: recordSettlement,
                                              ),
                                            )
                                        : null,
                                    icon: const Icon(Icons.check_rounded, size: 18),
                                    label: Text(
                                      isPartial && remaining > 0
                                          ? 'Settle $currency${settleAmount.toStringAsFixed(0)}'
                                          : 'Confirm Settle',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null && debt.id != null) {
      final repo = ref.read(transactionRepositoryProvider);
      if (result.amount >= debt.amount) {
        await repo.markDebtAsSettled(debt.id!, createSettlementTxn: result.recordSettlement);
      } else {
        await repo.settlePartialDebt(
          transactionId: debt.id!,
          settledAmount: result.amount,
          createSettlementTxn: result.recordSettlement,
        );
      }
      ref.read(transactionListProvider.notifier).refresh();
      _loadData();

      if (mounted) {
        final successColor = AppColors.getSuccess(context);
        final isPartialDone = result.amount < debt.amount;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPartialDone
                  ? '🎉 Partial recovery of $currency${result.amount.toStringAsFixed(2)} recorded for $person! Remaining: $currency${(debt.amount - result.amount).toStringAsFixed(2)}'
                  : '🎉 Debt with $person settled successfully!',
            ),
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

  Future<void> _confirmDeleteDebtTransaction(TransactionModel debt) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currency = getCurrencySymbol(ref.read(settingsProvider).currency);
    final errorColor = AppColors.getError(context);
    final isGiven = (debt.debtType ?? 'given') == 'given';
    final person = debt.personName?.isNotEmpty == true ? debt.personName! : 'contact';

    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: errorColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline_rounded, color: errorColor, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Delete Transaction?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 14, color: cs.onSurface, height: 1.4),
                  children: [
                    const TextSpan(text: 'Are you sure you want to delete this '),
                    TextSpan(
                      text: '${isGiven ? "lent" : "borrowed"} record of $currency${debt.amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: ' with $person?'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'This transaction will be permanently removed.',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: cs.onSurfaceVariant,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: errorColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed == true && debt.id != null) {
      await ref.read(transactionRepositoryProvider).deleteTransaction(debt.id!);
      ref.read(transactionListProvider.notifier).refresh();
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction of $currency${debt.amount.toStringAsFixed(0)} deleted'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _openExportPdfSheet(BuildContext context, {String? initialPerson}) async {
    HapticFeedback.lightImpact();
    final repo = ref.read(transactionRepositoryProvider);
    final allDebts = await repo.getDebts();
    final currency = getCurrencySymbol(ref.read(settingsProvider).currency);
    if (!mounted) return;
    DebtExportPdfSheet.show(
      context,
      allTransactions: allDebts.isNotEmpty ? allDebts : _debts,
      currency: currency,
      initialPerson: initialPerson,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(transactionChangeProvider, (_, __) => _loadData());
    final currency = getCurrencySymbol(ref.watch(settingsProvider).currency);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final activeTab = ref.watch(debtFilterTabProvider);

    final groups = _groupDebts(_debts);

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
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: () => _openExportPdfSheet(context),
            tooltip: 'Export Statement PDF',
          ),
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
                      if (activeTab != 3) ...[
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () => AddDebtBottomSheet.show(context, onSaved: _loadData),
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: const Text(
                            'Add Debt / Lent Record',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ],
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
                      final group = groups[index];
                      return _buildPersonGroupCard(
                        group,
                        currency,
                        isDark,
                        cs,
                        tt,
                        index,
                        groups.length,
                      );
                    },
                    childCount: groups.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context, String currency, bool isDark, ColorScheme cs, TextTheme tt) {
    final activeDebts = _allActiveDebts.isNotEmpty ? _allActiveDebts : _debts.where((d) => !d.isSettled).toList();
    double totalGiven = 0;
    double totalTaken = 0;
    int overdueCount = 0;
    final now = DateTime.now();

    // Group active debts by person first to compute real calculated net balance per person
    // (e.g., if ₹6000 given to Karan and ₹800 borrowed from Karan, net is +₹5200 given, not raw totals)
    final Map<String, List<TransactionModel>> personMap = {};
    for (final d in activeDebts) {
      final name = (d.personName?.trim().isNotEmpty == true)
          ? d.personName!.trim()
          : 'Unknown';
      personMap.putIfAbsent(name.toLowerCase(), () => []).add(d);

      if (d.dueDate != null && d.dueDate!.isBefore(now)) {
        overdueCount++;
      }
    }

    for (final entry in personMap.entries) {
      double personGiven = 0;
      double personTaken = 0;
      for (final d in entry.value) {
        if ((d.debtType ?? 'given') == 'given') {
          personGiven += d.amount;
        } else {
          personTaken += d.amount;
        }
      }
      final net = personGiven - personTaken;
      if (net > 0) {
        totalGiven += net;
      } else if (net < 0) {
        totalTaken += net.abs();
      }
    }

    final positiveColor = cs.primary;
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
                            color: positiveColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.arrow_upward_rounded, color: positiveColor, size: 16),
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
                          color: positiveColor,
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
                      color: isNetPositive ? positiveColor : errorColor,
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
                    color: isNetPositive ? positiveColor : errorColor,
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


  Widget _buildPersonGroupCard(
    _PersonDebtGroup group,
    String currency,
    bool isDark,
    ColorScheme cs,
    TextTheme tt,
    int index,
    int totalGroups,
  ) {
    final positiveColor = cs.primary;
    final errorColor = AppColors.getError(context);
    final isNetPositive = group.netBalance >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outline.withOpacity(isDark ? 0.12 : 0.08),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.2) : cs.shadow.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              HapticFeedback.lightImpact();
              await Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => PersonDebtDetailPage(personName: group.personName),
                ),
              );
              _loadData();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          cs.primary,
                          cs.primary.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withOpacity(0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        group.personName.isNotEmpty ? group.personName[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 19,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Name + Transaction Count + Overdue Badge
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.personName,
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              '${group.transactions.length} ${group.transactions.length == 1 ? 'transaction' : 'transactions'}',
                              style: tt.bodySmall?.copyWith(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            if (group.overdueCount > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: errorColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '⚠️ ${group.overdueCount} overdue',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: errorColor,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Net Balance & Subtext
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (group.activeCount == 0) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 14, color: positiveColor),
                            const SizedBox(width: 4),
                            Text(
                              'All Settled',
                              style: TextStyle(
                                color: positiveColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(
                          '${isNetPositive ? '+' : '-'}$currency${group.netBalance.abs().toStringAsFixed(0)}',
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: isNetPositive ? positiveColor : errorColor,
                          ),
                        ),
                        Text(
                          isNetPositive ? 'To receive' : 'To pay',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: (isNetPositive ? positiveColor : errorColor).withOpacity(0.85),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Settle Button
                  if (group.activeCount > 0) ...[
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () => _settlePersonGroupDialog(group),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: cs.primary.withValues(alpha: 0.35),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, size: 14, color: cs.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Settle',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: cs.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms, delay: (index * 30).ms);
  }
}

