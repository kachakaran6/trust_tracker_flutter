import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:trust_tracker_flutter/core/theme/app_colors.dart';
import 'package:trust_tracker_flutter/features/banking/data/models/loan_model.dart';
import 'package:trust_tracker_flutter/features/banking/presentation/providers/loan_provider.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';

class AddLoanPage extends ConsumerStatefulWidget {
  const AddLoanPage({super.key});

  @override
  ConsumerState<AddLoanPage> createState() => _AddLoanPageState();
}

class _AddLoanPageState extends ConsumerState<AddLoanPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _rateController = TextEditingController();
  final _tenureController = TextEditingController();
  final _emiController = TextEditingController();
  final _dueDayController = TextEditingController(text: '1');
  final _accountNumberController = TextEditingController();
  final _notesController = TextEditingController();

  String _type = 'Personal Loan';
  double _amount = 0;
  double _interestRate = 0;
  int _tenureMonths = 0;
  double _emiAmount = 0;
  int _emiDueDay = 1;
  DateTime _startDate = DateTime.now();
  DateTime _takenDate = DateTime.now();
  bool _autoRecordExpense = false;

  final List<String> _loanTypes = [
    'Personal Loan',
    'Home Loan',
    'Vehicle Loan',
    'Education Loan',
    'Business Loan',
    'Credit Card EMI',
    'Gold Loan',
    'Custom Loan'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _bankNameController.dispose();
    _amountController.dispose();
    _rateController.dispose();
    _tenureController.dispose();
    _emiController.dispose();
    _dueDayController.dispose();
    _accountNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _calculateEmi() {
    if (_amount > 0 && _interestRate > 0 && _tenureMonths > 0) {
      final double r = _interestRate / 12 / 100;
      final double powRate = pow(1 + r, _tenureMonths).toDouble();
      final double emi = (_amount * r * powRate) / (powRate - 1);

      if (emi.isFinite && !emi.isNaN) {
        setState(() {
          _emiAmount = emi;
          _emiController.text = emi.toStringAsFixed(0);
        });
      }
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final customEmi = double.tryParse(_emiController.text.trim()) ?? _emiAmount;

      final loan = LoanModel(
        name: _nameController.text.trim(),
        type: _type,
        bankName: _bankNameController.text.trim(),
        amount: _amount,
        interestRate: _interestRate,
        startDate: _startDate,
        endDate: DateTime(_startDate.year, _startDate.month + (_tenureMonths > 0 ? _tenureMonths : 12), _startDate.day),
        tenureMonths: _tenureMonths,
        emiAmount: customEmi,
        emiDueDay: int.tryParse(_dueDayController.text.trim()) ?? _emiDueDay,
        accountNumber: _accountNumberController.text.trim().isEmpty ? null : _accountNumberController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        status: 'active',
        createdAt: DateTime.now(),
        autoRecordExpense: _autoRecordExpense,
        takenDate: _takenDate,
      );

      ref.read(loanProvider.notifier).addLoan(loan);
      context.pop();
    }
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String hintText,
    IconData? prefixIcon,
    String? prefixText,
    String? suffixText,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: cs.onSurfaceVariant.withOpacity(0.6),
        fontSize: 14,
      ),
      prefixText: prefixText,
      prefixStyle: TextStyle(
        color: cs.onSurface,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
      suffixText: suffixText,
      suffixStyle: TextStyle(
        color: cs.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: cs.primary, size: 20)
          : null,
      filled: true,
      fillColor: isDark ? cs.surfaceVariant.withOpacity(0.25) : cs.surfaceVariant.withOpacity(0.35),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outline.withOpacity(0.15)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outline.withOpacity(0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.getError(context)),
      ),
    );
  }

  Widget _buildSectionLabel(String label, ColorScheme cs, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, top: 4.0),
      child: Text(
        label,
        style: tt.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: cs.onSurfaceVariant.withOpacity(0.7),
          fontSize: 10,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final currency = ref.watch(settingsProvider).currency;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          'Add New Loan',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: FilledButton.tonal(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary.withOpacity(0.15),
                foregroundColor: cs.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. LOAN IDENTITY ---
              _buildSectionLabel('LOAN DETAILS', cs, tt),
              TextFormField(
                controller: _nameController,
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                decoration: _inputDecoration(
                  context,
                  hintText: 'e.g. HDFC Home Loan, Car EMI',
                  prefixIcon: Icons.edit_note_rounded,
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Loan name is required' : null,
              ),
              const SizedBox(height: 12),

              _buildSectionLabel('LOAN TYPE', cs, tt),
              DropdownButtonFormField<String>(
                value: _type,
                style: tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
                dropdownColor: cs.surface,
                decoration: _inputDecoration(
                  context,
                  hintText: 'Select Loan Type',
                  prefixIcon: Icons.category_outlined,
                ),
                items: _loanTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _type = val);
                },
              ),
              const SizedBox(height: 12),

              _buildSectionLabel('BANK / LENDER NAME', cs, tt),
              TextFormField(
                controller: _bankNameController,
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                decoration: _inputDecoration(
                  context,
                  hintText: 'e.g. State Bank of India, HDFC Bank',
                  prefixIcon: Icons.account_balance_outlined,
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Bank name is required' : null,
              ),
              const SizedBox(height: 20),

              // --- 2. FINANCIAL DETAILS ---
              _buildSectionLabel('PRINCIPAL AMOUNT', cs, tt),
              TextFormField(
                controller: _amountController,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDecoration(
                  context,
                  hintText: '0',
                  prefixText: '$currency ',
                  prefixIcon: Icons.payments_outlined,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Principal amount is required';
                  final parsed = double.tryParse(val.trim());
                  if (parsed == null || parsed <= 0) return 'Enter a valid amount';
                  return null;
                },
                onChanged: (val) {
                  _amount = double.tryParse(val.trim()) ?? 0;
                  _calculateEmi();
                },
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel('INTEREST RATE (% P.A.)', cs, tt),
                        TextFormField(
                          controller: _rateController,
                          style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _inputDecoration(
                            context,
                            hintText: 'e.g. 8.5',
                            suffixText: '%',
                            prefixIcon: Icons.percent_rounded,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Required';
                            final parsed = double.tryParse(val.trim());
                            if (parsed == null || parsed < 0) return 'Invalid';
                            return null;
                          },
                          onChanged: (val) {
                            _interestRate = double.tryParse(val.trim()) ?? 0;
                            _calculateEmi();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel('TENURE (MONTHS)', cs, tt),
                        TextFormField(
                          controller: _tenureController,
                          style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration(
                            context,
                            hintText: 'e.g. 36',
                            suffixText: 'Mo',
                            prefixIcon: Icons.timelapse_rounded,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Required';
                            final parsed = int.tryParse(val.trim());
                            if (parsed == null || parsed <= 0) return 'Invalid';
                            return null;
                          },
                          onChanged: (val) {
                            _tenureMonths = int.tryParse(val.trim()) ?? 0;
                            _calculateEmi();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _buildSectionLabel('MONTHLY EMI AMOUNT', cs, tt),
              TextFormField(
                controller: _emiController,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: cs.primary),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDecoration(
                  context,
                  hintText: 'Calculated automatically or custom',
                  prefixText: '$currency ',
                  prefixIcon: Icons.calculate_outlined,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'EMI amount is required';
                  final parsed = double.tryParse(val.trim());
                  if (parsed == null || parsed <= 0) return 'Enter a valid EMI';
                  return null;
                },
              ),
              if (_emiAmount > 0) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: Text(
                    '💡 Estimated EMI: $currency${_emiAmount.toStringAsFixed(0)} / month',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // --- 3. DATES & REPAYMENT ---
              _buildSectionLabel('SCHEDULE & DUE DATES', cs, tt),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _takenDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => _takenDate = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? cs.surfaceVariant.withOpacity(0.2) : cs.surfaceVariant.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.outline.withOpacity(0.12)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 14, color: cs.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'Taken Date',
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateFormat('MMM dd, yyyy').format(_takenDate),
                              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            _startDate = picked;
                            _emiDueDay = picked.day;
                            _dueDayController.text = picked.day.toString();
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? cs.surfaceVariant.withOpacity(0.2) : cs.surfaceVariant.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.outline.withOpacity(0.12)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.event_available_rounded, size: 14, color: cs.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'First EMI Date',
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateFormat('MMM dd, yyyy').format(_startDate),
                              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel('DUE DAY (1-31)', cs, tt),
                        TextFormField(
                          controller: _dueDayController,
                          style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration(
                            context,
                            hintText: '1',
                            prefixIcon: Icons.calendar_view_day_rounded,
                          ),
                          validator: (val) {
                            final parsed = int.tryParse(val ?? '');
                            if (parsed == null || parsed < 1 || parsed > 31) return '1 to 31';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel('LOAN / ACCOUNT NO. (OPTIONAL)', cs, tt),
                        TextFormField(
                          controller: _accountNumberController,
                          style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          decoration: _inputDecoration(
                            context,
                            hintText: 'e.g. 5010023491...',
                            prefixIcon: Icons.pin_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- 4. AUTOMATIC RECORDING TOGGLE ---
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? cs.surfaceVariant.withOpacity(0.2) : cs.surfaceVariant.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.outline.withOpacity(0.12)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (_autoRecordExpense ? cs.primary : cs.onSurfaceVariant).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.sync_rounded,
                        size: 20,
                        color: _autoRecordExpense ? cs.primary : cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Record EMI Payments Automatically',
                            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Generates an expense entry each month when EMI is due',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _autoRecordExpense,
                      activeColor: cs.primary,
                      onChanged: (val) => setState(() => _autoRecordExpense = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // --- 5. BOTTOM SAVE BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 20),
                  label: const Text(
                    'Save Loan',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
