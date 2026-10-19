import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:trust_tracker_flutter/core/theme/app_colors.dart';
import 'package:trust_tracker_flutter/core/utils/extensions.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/transactions/data/repositories/transaction_repository.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/widgets/add_debt_bottom_sheet.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/widgets/debt_export_pdf_sheet.dart';

class _SettleDialogResult {
  final double amount;
  final bool recordSettlement;
  _SettleDialogResult({required this.amount, required this.recordSettlement});
}

class PersonDebtDetailPage extends ConsumerStatefulWidget {
  final String personName;

  const PersonDebtDetailPage({
    super.key,
    required this.personName,
  });

  @override
  ConsumerState<PersonDebtDetailPage> createState() => _PersonDebtDetailPageState();
}

class _PersonDebtDetailPageState extends ConsumerState<PersonDebtDetailPage> {
  bool _isLoading = true;
  List<TransactionModel> _allPersonDebts = [];
  int _selectedFilterIndex = 0; // 0: All, 1: Active, 2: Lent, 3: Borrowed, 4: Settled

  @override
  void initState() {
    super.initState();
    _loadPersonData();
  }

  Future<void> _loadPersonData() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final list = await repo.getDebtsForPerson(widget.personName);
      if (mounted) {
        setState(() {
          _allPersonDebts = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<TransactionModel> get _filteredTransactions {
    switch (_selectedFilterIndex) {
      case 1: // Active only
        return _allPersonDebts.where((t) => !t.isSettled).toList();
      case 2: // Lent (Given)
        return _allPersonDebts.where((t) => (t.debtType ?? 'given') == 'given').toList();
      case 3: // Borrowed (Taken)
        return _allPersonDebts.where((t) => (t.debtType ?? 'given') == 'taken').toList();
      case 4: // Settled
        return _allPersonDebts.where((t) => t.isSettled).toList();
      default: // All
        return _allPersonDebts;
    }
  }

  double get _totalGiven {
    return _allPersonDebts
        .where((t) => !t.isSettled && (t.debtType ?? 'given') == 'given')
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get _totalTaken {
    return _allPersonDebts
        .where((t) => !t.isSettled && (t.debtType ?? 'given') == 'taken')
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get _netBalance => _totalGiven - _totalTaken;

  int get _activeCount => _allPersonDebts.where((t) => !t.isSettled).length;
  int get _settledCount => _allPersonDebts.where((t) => t.isSettled).length;
  int get _overdueCount {
    final now = DateTime.now();
    return _allPersonDebts.where((t) => !t.isSettled && t.dueDate != null && t.dueDate!.isBefore(now)).length;
  }

  void _openPdfExport() {
    HapticFeedback.lightImpact();
    final currency = getCurrencySymbol(ref.read(settingsProvider).currency);
    DebtExportPdfSheet.show(
      context,
      allTransactions: _allPersonDebts,
      currency: currency,
      initialPerson: widget.personName,
    );
  }

  Future<void> _openAddTransaction({String? debtType}) async {
    final added = await AddDebtBottomSheet.show(
      context,
      initialPersonName: widget.personName,
      initialDebtType: debtType,
    );
    if (added == true) {
      ref.read(transactionListProvider.notifier).refresh();
      _loadPersonData();
    }
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
            color: cs.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
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

  Future<void> _settlePersonDialog() async {
    final activeDebts = _allPersonDebts.where((d) => !d.isSettled).toList();
    if (activeDebts.isEmpty) return;

    final currency = getCurrencySymbol(ref.read(settingsProvider).currency);
    final person = widget.personName.isNotEmpty ? widget.personName : 'Person';
    final isNetPositive = _netBalance >= 0;
    final totalToSettle = _netBalance.abs() > 0
        ? _netBalance.abs()
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
                    color: Colors.black.withValues(alpha: 0.2),
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
                          Center(
                            child: Container(
                              width: 42,
                              height: 4.5,
                              decoration: BoxDecoration(
                                color: cs.onSurface.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Header Row
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      cs.primary,
                                      cs.primary.withValues(alpha: 0.8),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: cs.primary.withValues(alpha: 0.25),
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
                                  backgroundColor: cs.onSurface.withValues(alpha: 0.06),
                                  foregroundColor: cs.onSurfaceVariant,
                                  padding: const EdgeInsets.all(8),
                                  minimumSize: const Size(36, 36),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Mode Selector
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.cardDark : cs.surfaceContainerHighest.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
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
                                        color: !isPartial ? cs.primary : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: !isPartial
                                            ? [
                                                BoxShadow(
                                                  color: cs.primary.withValues(alpha: 0.3),
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
                                        color: isPartial ? cs.primary : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: isPartial
                                            ? [
                                                BoxShadow(
                                                  color: cs.primary.withValues(alpha: 0.3),
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

                          // Amount display or partial inputs
                          if (!isPartial)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                          color: cs.primary.withValues(alpha: 0.15),
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
                                              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
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
                                  borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.18)),
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
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isValid ? cs.primary.withValues(alpha: 0.06) : errorColor.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isValid ? cs.primary.withValues(alpha: 0.2) : errorColor.withValues(alpha: 0.25),
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
                                  ],
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),

                          // Wallet Balance Switch
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.cardDark : AppColors.backgroundLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: cs.primary.withValues(alpha: 0.12),
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
                                        isNetPositive ? 'Record in Wallet Balance' : 'Deduct from Wallet Balance',
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

                          // Settle & Cancel buttons
                          Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: SizedBox(
                                  height: 48,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: cs.onSurfaceVariant,
                                      side: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
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
      _loadPersonData();

      if (mounted) {
        final isPartialDone = result.amount < totalToSettle;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPartialDone
                  ? '🎉 Payment of $currency${result.amount.toStringAsFixed(2)} recorded! Remaining: $currency${(totalToSettle - result.amount).toStringAsFixed(2)}'
                  : '🎉 All debt with $person settled successfully!',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _settleSingleDebt(TransactionModel debt) async {
    final repo = ref.read(transactionRepositoryProvider);
    if (debt.id == null) return;
    await repo.markDebtAsSettled(debt.id!, createSettlementTxn: debt.affectsBalance);
    ref.read(transactionListProvider.notifier).refresh();
    _loadPersonData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction marked as settled'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _clearDebtFlag(TransactionModel debt) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Remove Debt Flag?'),
          content: const Text(
            'This unmarks this transaction as debt and cancels pending reminders, keeping it as a regular transaction.',
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
      _loadPersonData();
    }
  }

  Future<void> _deleteDebtTransaction(TransactionModel debt) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currency = getCurrencySymbol(ref.read(settingsProvider).currency);
    final errorColor = AppColors.getError(context);

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
                  'Delete Record?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Text(
            'Permanently delete this transaction of $currency${debt.amount.toStringAsFixed(2)}?',
            style: TextStyle(fontSize: 14, color: cs.onSurface),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: cs.onSurfaceVariant)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: errorColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && debt.id != null) {
      await ref.read(transactionRepositoryProvider).deleteTransaction(debt.id!);
      ref.read(transactionListProvider.notifier).refresh();
      _loadPersonData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final currency = getCurrencySymbol(ref.watch(settingsProvider).currency);
    final positiveColor = cs.primary;
    final errorColor = AppColors.getError(context);
    final warningColor = AppColors.getWarning(context);
    final infoColor = AppColors.getInfo(context);
    final isNetPositive = _netBalance >= 0;

    final filteredList = _filteredTransactions;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.primary.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  widget.personName.isNotEmpty ? widget.personName[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.personName,
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 16.5,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${_allPersonDebts.length} total · $_activeCount active',
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
        actions: [
          // PDF Statement Action Button
          IconButton(
            tooltip: 'Export Statement PDF',
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.picture_as_pdf_rounded, size: 16, color: cs.primary),
                  const SizedBox(width: 4),
                  Text(
                    'PDF',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ),
            onPressed: _openPdfExport,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (val) {
              if (val == 'pdf') {
                _openPdfExport();
              } else if (val == 'settle') {
                _settlePersonDialog();
              } else if (val == 'add_lent') {
                _openAddTransaction(debtType: 'given');
              } else if (val == 'add_borrowed') {
                _openAddTransaction(debtType: 'taken');
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Export PDF Statement'),
                  ],
                ),
              ),
              if (_activeCount > 0)
                const PopupMenuItem(
                  value: 'settle',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Settle All Debts'),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'add_lent',
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward_rounded, size: 18, color: Colors.teal),
                    SizedBox(width: 10),
                    Text('Record Lent (Given)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'add_borrowed',
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward_rounded, size: 18, color: Colors.orange),
                    SizedBox(width: 10),
                    Text('Record Borrowed (Taken)'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPersonData,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  // 1. Balance Summary Header Card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: cs.outline.withValues(alpha: isDark ? 0.12 : 0.08)),
                          boxShadow: [
                            BoxShadow(
                              color: isDark ? Colors.black.withValues(alpha: 0.25) : cs.shadow.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Net Balance Hero
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'NET BALANCE',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (_activeCount == 0) ...[
                                      Row(
                                        children: [
                                          Icon(Icons.check_circle_rounded, color: positiveColor, size: 24),
                                          const SizedBox(width: 6),
                                          Text(
                                            'All Settled',
                                            style: tt.headlineSmall?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              color: positiveColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'No outstanding money',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ] else ...[
                                      Text(
                                        '${isNetPositive ? '+' : '-'}$currency${_netBalance.abs().toStringAsFixed(0)}',
                                        style: tt.headlineMedium?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: isNetPositive ? positiveColor : errorColor,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isNetPositive
                                            ? 'You are owed money (To receive)'
                                            : 'You owe money (To pay)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: (isNetPositive ? positiveColor : errorColor).withValues(alpha: 0.9),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (_overdueCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: errorColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.warning_amber_rounded, size: 14, color: errorColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$_overdueCount Overdue',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: errorColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Breakdown Pills: Lent vs Borrowed
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.cardDark : AppColors.backgroundLight,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: cs.outline.withValues(alpha: 0.06)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: positiveColor.withValues(alpha: 0.12),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(Icons.arrow_upward_rounded, size: 12, color: positiveColor),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'Lent (Given)',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: cs.onSurfaceVariant,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '$currency${_totalGiven.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: cs.onSurface,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.cardDark : AppColors.backgroundLight,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: cs.outline.withValues(alpha: 0.06)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: errorColor.withValues(alpha: 0.12),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(Icons.arrow_downward_rounded, size: 12, color: errorColor),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'Borrowed (Taken)',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: cs.onSurfaceVariant,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '$currency${_totalTaken.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: cs.onSurface,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Quick Action Buttons
                            Row(
                              children: [
                                // Settle Button (if active debts exist)
                                if (_activeCount > 0) ...[
                                  Expanded(
                                    flex: 3,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: cs.primary,
                                        foregroundColor: cs.onPrimary,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 0,
                                      ),
                                      onPressed: _settlePersonDialog,
                                      icon: const Icon(Icons.check_rounded, size: 17),
                                      label: const Text(
                                        'Settle',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                // Add Entry Button
                                Expanded(
                                  flex: 3,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: cs.primary,
                                      side: BorderSide(color: cs.primary.withValues(alpha: 0.4)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () => _openAddTransaction(),
                                    icon: const Icon(Icons.add_rounded, size: 17),
                                    label: const Text(
                                      'Add Entry',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Statement PDF Button
                                InkWell(
                                  onTap: _openPdfExport,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: cs.primary.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                                    ),
                                    child: Icon(Icons.picture_as_pdf_rounded, size: 19, color: cs.primary),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 2. Filter Selector Chips
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildFilterChip(0, 'All (${_allPersonDebts.length})'),
                            const SizedBox(width: 8),
                            _buildFilterChip(1, 'Active ($_activeCount)'),
                            const SizedBox(width: 8),
                            _buildFilterChip(2, 'Lent (${_allPersonDebts.where((t) => (t.debtType ?? 'given') == 'given').length})'),
                            const SizedBox(width: 8),
                            _buildFilterChip(3, 'Borrowed (${_allPersonDebts.where((t) => (t.debtType ?? 'given') == 'taken').length})'),
                            const SizedBox(width: 8),
                            _buildFilterChip(4, 'Settled ($_settledCount)'),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 3. Section Title
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TRANSACTION HISTORY (${filteredList.length})',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            'Sorted Newest First',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 4. Empty State or List of Transactions
                  if (filteredList.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: cs.primary.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.receipt_long_rounded,
                                  size: 48,
                                  color: cs.primary.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No transactions found',
                                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'There are no records matching the selected filter.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                              ),
                              const SizedBox(height: 18),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: cs.primary,
                                  foregroundColor: cs.onPrimary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _openAddTransaction(),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Add Transaction'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final txn = filteredList[index];
                            return _buildTransactionCard(
                              txn: txn,
                              currency: currency,
                              isDark: isDark,
                              cs: cs,
                              tt: tt,
                              positiveColor: positiveColor,
                              errorColor: errorColor,
                              warningColor: warningColor,
                              infoColor: infoColor,
                            );
                          },
                          childCount: filteredList.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 3,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Entry', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () => _openAddTransaction(),
      ),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isSelected = _selectedFilterIndex == index;

    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? cs.onPrimary : cs.onSurface,
      ),
      selectedColor: cs.primary,
      backgroundColor: cs.surface,
      side: BorderSide(
        color: isSelected ? cs.primary : cs.outline.withValues(alpha: 0.15),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (selected) {
        if (selected) {
          HapticFeedback.selectionClick();
          setState(() => _selectedFilterIndex = index);
        }
      },
    );
  }

  Widget _buildTransactionCard({
    required TransactionModel txn,
    required String currency,
    required bool isDark,
    required ColorScheme cs,
    required TextTheme tt,
    required Color positiveColor,
    required Color errorColor,
    required Color warningColor,
    required Color infoColor,
  }) {
    final isGiven = (txn.debtType ?? 'given') == 'given';
    final typeColor = isGiven ? positiveColor : errorColor;
    final now = DateTime.now();

    // Custom Note check
    String? customNote;
    if (txn.note != null && txn.note!.trim().isNotEmpty) {
      final n = txn.note!.trim();
      final lower = n.toLowerCase();
      if (!lower.startsWith('lent to') &&
          !lower.startsWith('borrowed from') &&
          !lower.startsWith('settlement for')) {
        customNote = n;
      }
    }

    final hasTime = txn.date.hour != 0 || txn.date.minute != 0;
    final timestampText = hasTime
        ? DateFormat('MMM dd, yyyy · h:mm a').format(txn.date)
        : DateFormat('MMM dd, yyyy').format(txn.date);

    String? dueStatusText;
    Color dueStatusColor = cs.onSurfaceVariant;
    if (txn.isSettled) {
      dueStatusText = 'Settled ${txn.settledAt != null ? DateFormat('MMM dd').format(txn.settledAt!) : DateFormat('MMM dd').format(txn.date)}';
      dueStatusColor = positiveColor;
    } else if (txn.dueDate != null) {
      final diffDays = txn.dueDate!.difference(DateTime(now.year, now.month, now.day)).inDays;
      final dueFmt = DateFormat('MMM dd').format(txn.dueDate!);
      if (diffDays < 0) {
        dueStatusText = 'Due $dueFmt · ⚠️ ${diffDays.abs()}d overdue';
        dueStatusColor = errorColor;
      } else if (diffDays == 0) {
        dueStatusText = 'Due $dueFmt · ⏰ Due today';
        dueStatusColor = warningColor;
      } else if (diffDays == 1) {
        dueStatusText = 'Due $dueFmt · In 1d';
        dueStatusColor = infoColor;
      } else {
        dueStatusText = 'Due $dueFmt · In ${diffDays}d';
        dueStatusColor = infoColor;
      }
    }

    final hasExtraDetails = dueStatusText != null || customNote != null || txn.isSettled;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: txn.isSettled
              ? cs.outline.withValues(alpha: 0.06)
              : typeColor.withValues(alpha: 0.18),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.18) : cs.shadow.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Direction Chip + Date/Time + Amount + Menu Button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isGiven ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      size: 12,
                      color: typeColor,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      isGiven ? 'Lent' : 'Borrowed',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: typeColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  timestampText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${isGiven ? '+' : '-'}$currency${txn.amount.toStringAsFixed(2)}',
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 15.5,
                  color: typeColor,
                  decoration: txn.isSettled ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(width: 2),
              SizedBox(
                width: 24,
                height: 24,
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  splashRadius: 14,
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (val) async {
                    if (val == 'settle') {
                      _settleSingleDebt(txn);
                    } else if (val == 'edit') {
                      final updated = await AddDebtBottomSheet.show(
                        context,
                        editTransaction: txn,
                        initialAmount: txn.amount,
                        initialDebtType: txn.debtType,
                        initialPersonName: (txn.personName != null && txn.personName!.isNotEmpty)
                            ? txn.personName!
                            : widget.personName,
                      );
                      if (updated == true || mounted) {
                        ref.read(transactionListProvider.notifier).refresh();
                        _loadPersonData();
                      }
                    } else if (val == 'clear_flag') {
                      _clearDebtFlag(txn);
                    } else if (val == 'delete') {
                      _deleteDebtTransaction(txn);
                    }
                  },
                  itemBuilder: (context) => [
                    if (!txn.isSettled)
                      const PopupMenuItem(
                        value: 'settle',
                        height: 36,
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline_rounded, size: 16),
                            SizedBox(width: 8),
                            Text('Mark Settled', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'edit',
                      height: 36,
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 16),
                          SizedBox(width: 8),
                          Text('Edit Transaction', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    if (!txn.isSettled)
                      const PopupMenuItem(
                        value: 'clear_flag',
                        height: 36,
                        child: Row(
                          children: [
                            Icon(Icons.flag_outlined, size: 16),
                            SizedBox(width: 8),
                            Text('Remove Debt Flag', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      height: 36,
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: errorColor, size: 16),
                          const SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: errorColor, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Row 2: Status Pill / Note (Only displayed if details exist)
          if (hasExtraDetails) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (txn.isSettled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: positiveColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Settled',
                      style: TextStyle(
                        fontSize: 11,
                        color: positiveColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (dueStatusText != null)
                        Row(
                          children: [
                            Icon(
                              txn.isSettled
                                  ? Icons.done_all_rounded
                                  : (txn.dueDate != null ? Icons.event_available_rounded : Icons.schedule_rounded),
                              size: 13,
                              color: dueStatusColor,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                dueStatusText,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: dueStatusColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      if (customNote != null) ...[
                        if (dueStatusText != null) const SizedBox(height: 3),
                        Text(
                          customNote,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
