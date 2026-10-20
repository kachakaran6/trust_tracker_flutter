import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trust_tracker_flutter/core/utils/extensions.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/transactions/data/repositories/transaction_repository.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/providers/transaction_provider.dart';

class AddDebtBottomSheet extends ConsumerStatefulWidget {
  final VoidCallback? onSaved;
  final double? initialAmount;
  final String? initialDebtType;
  final String? initialPersonName;
  final bool? isPersonLocked;
  final TransactionModel? editTransaction;

  const AddDebtBottomSheet({
    super.key,
    this.onSaved,
    this.initialAmount,
    this.initialDebtType,
    this.initialPersonName,
    this.isPersonLocked,
    this.editTransaction,
  });

  static Future<bool?> show(
    BuildContext context, {
    VoidCallback? onSaved,
    double? initialAmount,
    String? initialDebtType,
    String? initialPersonName,
    bool? isPersonLocked,
    TransactionModel? editTransaction,
  }) {
    return Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (context) => AddDebtBottomSheet(
          onSaved: onSaved,
          initialAmount: initialAmount,
          initialDebtType: initialDebtType,
          initialPersonName: initialPersonName,
          isPersonLocked: isPersonLocked,
          editTransaction: editTransaction,
        ),
      ),
    );
  }

  @override
  ConsumerState<AddDebtBottomSheet> createState() => _AddDebtBottomSheetState();
}

class _AddDebtBottomSheetState extends ConsumerState<AddDebtBottomSheet> {
  final _amountController = TextEditingController();
  final _personController = TextEditingController();
  final _noteController = TextEditingController();

  // 'given' = Lent (Receivable / You gave money)
  // 'taken' = Borrowed (Payable / You took money)
  String _debtType = 'given';
  DateTime _txnDate = DateTime.now();
  DateTime? _dueDate;
  String _repaymentSchedule = 'one_time'; // 'one_time', 'weekly', 'biweekly', 'monthly'
  bool _affectsBalance = true;
  bool _isSaving = false;
  List<String> _savedNames = [];
  bool _showNameDropdown = false;
  bool _isPersonLocked = false;

  @override
  void initState() {
    super.initState();
    final edit = widget.editTransaction;
    if (edit != null) {
      final amt = edit.amount;
      _amountController.text =
          amt % 1 == 0 ? amt.toInt().toString() : amt.toStringAsFixed(2);
      _debtType = edit.debtType ?? (edit.type == TransactionType.expense ? 'given' : 'taken');
      final person = (edit.personName != null && edit.personName!.isNotEmpty)
          ? edit.personName!
          : (widget.initialPersonName ?? _extractPersonNameFromDescription(edit.description));
      _personController.text = person;
      _noteController.text = edit.note ?? '';
      _dueDate = edit.dueDate;
      _affectsBalance = edit.affectsBalance;
      _txnDate = edit.date;
      _isPersonLocked = widget.isPersonLocked ?? (person.trim().isNotEmpty);
      if (edit.note?.contains('Weekly') == true) {
        _repaymentSchedule = 'weekly';
      } else if (edit.note?.contains('Monthly') == true) {
        _repaymentSchedule = 'monthly';
      }
    } else {
      if (widget.initialAmount != null && widget.initialAmount! > 0) {
        final amt = widget.initialAmount!;
        _amountController.text =
            amt % 1 == 0 ? amt.toInt().toString() : amt.toStringAsFixed(2);
      }
      if (widget.initialDebtType != null &&
          widget.initialDebtType!.trim().isNotEmpty) {
        _debtType = widget.initialDebtType!;
      }
      if (widget.initialPersonName != null &&
          widget.initialPersonName!.trim().isNotEmpty) {
        _personController.text = widget.initialPersonName!.trim();
      }
      _isPersonLocked = widget.isPersonLocked ??
          (widget.initialPersonName != null &&
              widget.initialPersonName!.trim().isNotEmpty);
      _loadSavedPreferences();
    }
    _loadSavedNames();
  }

  Future<void> _loadSavedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedBalance = prefs.getBool('debt_affects_balance_preference');
      if (savedBalance != null && widget.editTransaction == null && mounted) {
        setState(() => _affectsBalance = savedBalance);
      }
    } catch (_) {}
  }

  static String _extractPersonNameFromDescription(String desc) {
    if (desc.startsWith('Lent to ')) return desc.substring(8).trim();
    if (desc.startsWith('Borrowed from ')) return desc.substring(14).trim();
    return '';
  }

  Future<void> _loadSavedNames() async {
    try {
      final names = await ref
          .read(transactionRepositoryProvider)
          .getDistinctDebtPersonNames();
      if (mounted) {
        setState(() => _savedNames = names);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _amountController.dispose();
    _personController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _addQuickAmount(double val) {
    HapticFeedback.selectionClick();
    final current = double.tryParse(_amountController.text.trim()) ?? 0;
    final updated = current + val;
    _amountController.text = updated % 1 == 0
        ? updated.toInt().toString()
        : updated.toStringAsFixed(2);
    setState(() {});
  }

  Future<void> _pickTxnDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _txnDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select Transaction Date (dd/MM/yyyy)',
    );
    if (picked != null) {
      setState(() {
        _txnDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _txnDate.hour,
          _txnDate.minute,
        );
      });
    }
  }

  void _setQuickTxnDate(int daysAgo) {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final target = now.subtract(Duration(days: daysAgo));
    setState(() {
      _txnDate = DateTime(
        target.year,
        target.month,
        target.day,
        _txnDate.hour,
        _txnDate.minute,
      );
    });
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? _txnDate.add(const Duration(days: 7)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: 'Select Repayment Date (dd/MM/yyyy)',
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  void _setQuickDueDate(int days, {String? schedule}) {
    HapticFeedback.selectionClick();
    setState(() {
      _dueDate = _txnDate.add(Duration(days: days));
      if (schedule != null) {
        _repaymentSchedule = schedule;
      }
    });
  }

  Future<void> _saveDebt() async {
    final amountText = _amountController.text.trim().replaceAll(',', '');
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter an amount greater than 0'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final person = _personController.text.trim();
    if (person.isEmpty) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _debtType == 'given'
                ? 'Please enter the borrower\'s name'
                : 'Please enter the lender\'s name',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final isGiven = _debtType == 'given';
      String note = _noteController.text.trim();
      if (_repaymentSchedule == 'weekly' && !note.contains('Weekly')) {
        note = note.isEmpty ? '[Weekly Repayment]' : '$note • [Weekly Repayment]';
      } else if (_repaymentSchedule == 'monthly' && !note.contains('Monthly')) {
        note = note.isEmpty ? '[Monthly Repayment]' : '$note • [Monthly Repayment]';
      }

      final desc = note.isNotEmpty
          ? note
          : (isGiven ? 'Lent to $person' : 'Borrowed from $person');

      if (widget.editTransaction != null) {
        final edit = widget.editTransaction!;
        edit.amount = amount;
        edit.description = desc;
        edit.date = _txnDate;
        edit.type = isGiven ? TransactionType.expense : TransactionType.income;
        edit.isDebt = true;
        edit.debtType = _debtType;
        edit.personName = person;
        edit.dueDate = _dueDate;
        edit.affectsBalance = _affectsBalance;
        edit.note = note.isNotEmpty ? note : null;

        await ref.read(transactionRepositoryProvider).saveDebtPersonName(person);
        await ref.read(transactionListProvider.notifier).updateTransaction(edit);
        ref.read(transactionChangeProvider.notifier).update((v) => v + 1);
      } else {
        final debtTxn = TransactionModel.create(
          amount: amount,
          description: desc,
          date: _txnDate,
          type: isGiven ? TransactionType.expense : TransactionType.income,
          isDebt: true,
          debtType: _debtType,
          personName: person,
          dueDate: _dueDate,
          affectsBalance: _affectsBalance,
          note: note.isNotEmpty ? note : null,
        );

        // Persist person name in repository storage
        await ref.read(transactionRepositoryProvider).saveDebtPersonName(person);

        await ref.read(transactionListProvider.notifier).addTransaction(debtTxn);
        ref.read(transactionChangeProvider.notifier).update((v) => v + 1);
      }

      HapticFeedback.heavyImpact();

      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        Navigator.of(context).pop(true);
        widget.onSaved?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.editTransaction != null
                        ? (isGiven ? 'Lent record updated!' : 'Borrowed record updated!')
                        : (isGiven
                            ? 'Lent ₹${amount.toStringAsFixed(0)} to $person recorded!'
                            : 'Borrowed ₹${amount.toStringAsFixed(0)} from $person recorded!'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor:
                isGiven ? cs.primary : const Color(0xFFF59E0B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save record: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final currency = getCurrencySymbol(ref.watch(settingsProvider).currency);
    final isGiven = _debtType == 'given';

    // Premium semantic accents
    final activeAccent =
        isGiven ? cs.primary : const Color(0xFFF59E0B);
    final activeGradient = isGiven
        ? [cs.primary, cs.primary.withValues(alpha: 0.85)]
        : const [Color(0xFFD97706), Color(0xFFF59E0B)];

    final cardBg = isDark
        ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
        : cs.surface;
    final cardBorder = cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.35);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF141416) : const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.editTransaction != null
              ? 'Edit Debt & Lent Record'
              : 'Debt & Lent Record',
          style: tt.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveDebt,
            child: Text(
              'Save',
              style: TextStyle(
                color: activeAccent,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            // Sleek Segmented Switcher (iOS / M3 style)
                Container(
                  height: 44,
                  padding: const EdgeInsets.all(3.5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? cs.surfaceContainerHighest.withValues(alpha: 0.35)
                        : cs.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      // Lent Option
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _debtType = 'given');
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            decoration: BoxDecoration(
                              color: isGiven
                                  ? (isDark ? cs.surface : Colors.white)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(11),
                              boxShadow: isGiven
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                            alpha: isDark ? 0.3 : 0.06),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.arrow_upward_rounded,
                                  size: 16,
                                  color: isGiven
                                      ? cs.primary
                                      : cs.onSurface.withValues(alpha: 0.55),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'I Lent (Given)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isGiven
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isGiven
                                        ? cs.primary
                                        : cs.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Borrowed Option
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _debtType = 'taken');
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            decoration: BoxDecoration(
                              color: !isGiven
                                  ? (isDark ? cs.surface : Colors.white)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(11),
                              boxShadow: !isGiven
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                            alpha: isDark ? 0.3 : 0.06),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.arrow_downward_rounded,
                                  size: 16,
                                  color: !isGiven
                                      ? const Color(0xFFF59E0B)
                                      : cs.onSurface.withValues(alpha: 0.55),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'I Borrowed (Taken)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: !isGiven
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: !isGiven
                                        ? (isDark
                                            ? Colors.white
                                            : const Color(0xFFB45309))
                                        : cs.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Heroic Amount Input Section
                Center(
                  child: Column(
                    children: [
                      Text(
                        'AMOUNT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: cs.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            currency,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: activeAccent,
                            ),
                          ),
                          const SizedBox(width: 6),
                          IntrinsicWidth(
                            child: TextField(
                              controller: _amountController,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                                color: cs.onSurface,
                                height: 1.1,
                              ),
                              decoration: InputDecoration(
                                hintText: '0',
                                hintStyle: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  color: cs.outlineVariant.withValues(alpha: 0.35),
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Sleek Quick Increment Pills
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [100, 500, 1000, 5000].map((amt) {
                          final amtLabel = amt >= 1000 ? '+${amt ~/ 1000}k' : '+$amt';
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: InkWell(
                              onTap: () => _addQuickAmount(amt.toDouble()),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? cs.surfaceContainerHighest.withValues(alpha: 0.35)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: cs.outlineVariant.withValues(
                                        alpha: isDark ? 0.25 : 0.4),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                          alpha: isDark ? 0.15 : 0.03),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  amtLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: activeAccent,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Card 1: Person & Reason Details
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                            alpha: isDark ? 0.15 : 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Person Field: Locked Contact Card vs Editable Field with Dropdown
                      if (_isPersonLocked && _personController.text.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      activeAccent,
                                      activeAccent.withValues(alpha: 0.8),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: activeAccent.withValues(alpha: 0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _personController.text.trim().isNotEmpty
                                      ? _personController.text.trim()[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            isGiven ? 'BORROWER' : 'LENDER',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.8,
                                              color: activeAccent,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: activeAccent.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.lock_rounded, size: 9, color: activeAccent),
                                              const SizedBox(width: 2.5),
                                              Text(
                                                'Linked',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: activeAccent,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _personController.text.trim(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: cs.onSurface,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _isPersonLocked = false);
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: cs.onSurface.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: cs.outlineVariant.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit_rounded, size: 12, color: cs.onSurface.withValues(alpha: 0.7)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Change',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: cs.onSurface.withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        // Person Field with Dropdown (when unlocked / manual input)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: activeAccent.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person_rounded,
                                  size: 18,
                                  color: activeAccent,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: TextField(
                                  controller: _personController,
                                  onChanged: (_) => setState(() {}),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    hintText: isGiven
                                        ? 'Borrower\'s name (e.g. John)'
                                        : 'Lender\'s name (e.g. Alex)',
                                    hintStyle: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: cs.onSurface.withValues(alpha: 0.4),
                                    ),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                  ),
                                ),
                              ),
                              if (_personController.text.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _personController.clear();
                                    setState(() {});
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.cancel_rounded,
                                      size: 16,
                                      color: cs.onSurface.withValues(alpha: 0.35),
                                    ),
                                  ),
                                ),
                              if (widget.initialPersonName != null &&
                                  widget.initialPersonName!.trim().isNotEmpty &&
                                  _personController.text.trim().toLowerCase() ==
                                      widget.initialPersonName!.trim().toLowerCase())
                                Tooltip(
                                  message: 'Lock to contact',
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.lock_outline_rounded,
                                      size: 18,
                                      color: activeAccent,
                                    ),
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      setState(() => _isPersonLocked = true);
                                    },
                                  ),
                                ),
                              if (_savedNames.isNotEmpty)
                                IconButton(
                                  tooltip: 'Select Previous Name',
                                  icon: AnimatedRotation(
                                    turns: _showNameDropdown ? 0.5 : 0.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 24,
                                      color: _showNameDropdown ? activeAccent : cs.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _showNameDropdown = !_showNameDropdown);
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                      // Inline dropdown opened directly under the input field
                      if (_showNameDropdown && _savedNames.isNotEmpty) ...[
                        Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: cs.outlineVariant.withValues(alpha: 0.2),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E1E22)
                                : cs.surfaceContainerHighest.withValues(alpha: 0.35),
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'SELECT PREVIOUS NAME',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                      color: cs.onSurface.withValues(alpha: 0.45),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(() => _showNameDropdown = false),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: cs.onSurface.withValues(alpha: 0.4),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _savedNames.map((name) {
                                  final isSelected = _personController.text
                                          .trim()
                                          .toLowerCase() ==
                                      name.toLowerCase();
                                  return InkWell(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      _personController.text = name;
                                      _personController.selection =
                                          TextSelection.collapsed(offset: name.length);
                                      setState(() => _showNameDropdown = false);
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? activeAccent.withValues(alpha: 0.18)
                                            : (isDark
                                                ? cs.surfaceContainerHighest.withValues(alpha: 0.4)
                                                : Colors.white),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isSelected
                                              ? activeAccent
                                              : cs.outlineVariant.withValues(
                                                  alpha: isDark ? 0.25 : 0.4),
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                                alpha: isDark ? 0.15 : 0.03),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircleAvatar(
                                            radius: 10,
                                            backgroundColor: activeAccent.withValues(
                                                alpha: isSelected ? 0.35 : 0.15),
                                            child: Text(
                                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: activeAccent,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 7),
                                          Text(
                                            name,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: isSelected ? activeAccent : cs.onSurface,
                                            ),
                                          ),
                                          if (isSelected) ...[
                                            const SizedBox(width: 4),
                                            Icon(Icons.check_rounded,
                                                size: 14, color: activeAccent),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Divider(
                        height: 1,
                        indent: 52,
                        endIndent: 16,
                        color: cs.outlineVariant.withValues(alpha: 0.15),
                      ),
                      // Reason / Note Field
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cs.onSurface.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.edit_note_rounded,
                                size: 18,
                                color: cs.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: TextField(
                                controller: _noteController,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  hintText: 'Note / Reason (Optional)',
                                  hintStyle: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: cs.onSurface.withValues(alpha: 0.4),
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Card 2: Transaction Date, Repayment Date & Wallet Impact
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                            alpha: isDark ? 0.15 : 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // 1. Transaction Date Row (Date Added/Given/Taken)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: activeAccent.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.event_note_rounded,
                                    size: 18,
                                    color: activeAccent,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Transaction Date',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Selected: ${DateFormat('dd/MM/yyyy').format(_txnDate)}',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: activeAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildMiniDateActionChip('Today', () => _setQuickTxnDate(0)),
                                _buildMiniDateActionChip('Yesterday', () => _setQuickTxnDate(1)),
                                InkWell(
                                  onTap: _pickTxnDate,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: cs.onSurface.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.35),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.calendar_month_rounded,
                                          size: 15,
                                          color: cs.onSurface.withValues(alpha: 0.8),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Custom Date',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: cs.onSurface.withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: cs.outlineVariant.withValues(alpha: 0.15),
                      ),

                      // 2. Repayment Due Date Row
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _dueDate != null
                                        ? activeAccent.withValues(alpha: 0.12)
                                        : cs.onSurface.withValues(alpha: 0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.schedule_rounded,
                                    size: 18,
                                    color: _dueDate != null
                                        ? activeAccent
                                        : cs.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Repayment Due Date',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _dueDate != null
                                            ? '${DateFormat('dd/MM/yyyy').format(_dueDate!)}${_repaymentSchedule == 'weekly' ? ' • Weekly Cycle' : (_repaymentSchedule == 'monthly' ? ' • Monthly Cycle' : '')}'
                                            : 'No due date set (Optional)',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: _dueDate != null ? FontWeight.w700 : FontWeight.w500,
                                          color: _dueDate != null
                                              ? activeAccent
                                              : cs.onSurface.withValues(alpha: 0.45),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_dueDate != null)
                                  IconButton(
                                    icon: const Icon(Icons.cancel_rounded, size: 20),
                                    color: cs.onSurface.withValues(alpha: 0.4),
                                    onPressed: () => setState(() {
                                      _dueDate = null;
                                      _repaymentSchedule = 'one_time';
                                    }),
                                    tooltip: 'Clear date',
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildMiniDateChip('1 Wk (Weekly)', 7, schedule: 'weekly'),
                                _buildMiniDateChip('2 Wks', 14),
                                _buildMiniDateChip('1 Mo (Monthly)', 30, schedule: 'monthly'),
                                InkWell(
                                  onTap: _pickDueDate,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: cs.onSurface.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.35),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.calendar_month_rounded,
                                          size: 15,
                                          color: cs.onSurface.withValues(alpha: 0.8),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Custom Date',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: cs.onSurface.withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Recurring Schedule selection pills when due date is set
                            if (_dueDate != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                'RECURRENCE SCHEDULE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildScheduleChip('One-time', 'one_time', activeAccent),
                                  _buildScheduleChip('Weekly Cycle', 'weekly', activeAccent, days: 7),
                                  _buildScheduleChip('Monthly Cycle', 'monthly', activeAccent, days: 30),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: cs.outlineVariant.withValues(alpha: 0.15),
                      ),

                      // 3. Affects Wallet Balance Row (Choice Stored in SharedPreferences)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 18,
                                color: cs.primary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Record in Transactions & Wallet',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _affectsBalance
                                        ? (isGiven
                                            ? 'Adds to transactions list & deducts balance'
                                            : 'Adds to transactions list & adds to balance')
                                        : 'Debt/Lent page only (no transaction record, balance unchanged)',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: cs.onSurface.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _affectsBalance,
                              thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return Colors.white;
                                }
                                return isDark ? Colors.grey.shade400 : Colors.white;
                              }),
                              trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return activeAccent;
                                }
                                return isDark ? Colors.white24 : Colors.grey.shade300;
                              }),
                              trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                              onChanged: (val) async {
                                HapticFeedback.selectionClick();
                                setState(() => _affectsBalance = val);
                                try {
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.setBool('debt_affects_balance_preference', val);
                                } catch (_) {}
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: activeGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: activeAccent.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isSaving ? null : _saveDebt,
                borderRadius: BorderRadius.circular(16),
                child: Center(
                  child: _isSaving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.editTransaction != null
                                  ? (isGiven
                                      ? 'Update Lent Record'
                                      : 'Update Borrowed Record')
                                  : (isGiven
                                      ? 'Save Lent Record'
                                      : 'Save Borrowed Record'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniDateChip(String label, int days, {String? schedule}) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _setQuickDueDate(days, schedule: schedule),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cs.onSurface.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniDateActionChip(String label, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: cs.onSurface.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleChip(String label, String key, Color accent, {int? days}) {
    final isSelected = _repaymentSchedule == key;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _repaymentSchedule = key;
          if (days != null) {
            _dueDate = _txnDate.add(Duration(days: days));
          }
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accent : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(Icons.check_rounded, size: 12, color: accent),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? accent : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
