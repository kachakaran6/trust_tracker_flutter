import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';

class LoanCalculatorPage extends ConsumerStatefulWidget {
  const LoanCalculatorPage({super.key});

  @override
  ConsumerState<LoanCalculatorPage> createState() => _LoanCalculatorPageState();
}

class _LoanCalculatorPageState extends ConsumerState<LoanCalculatorPage> {
  double _principal = 100000;
  double _rate = 10.5;
  int _tenureMonths = 12;

  double _emi = 0;
  double _totalInterest = 0;
  double _totalPayable = 0;

  final _principalController = TextEditingController(text: '100000');
  final _rateController = TextEditingController(text: '10.5');
  final _tenureController = TextEditingController(text: '12');

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  @override
  void dispose() {
    _principalController.dispose();
    _rateController.dispose();
    _tenureController.dispose();
    super.dispose();
  }

  void _calculate() {
    if (_principal > 0 && _rate > 0 && _tenureMonths > 0) {
      final double r = _rate / 12 / 100;
      final double powRate = pow(1 + r, _tenureMonths).toDouble();
      _emi = (_principal * r * powRate) / (powRate - 1);
      _totalPayable = _emi * _tenureMonths;
      _totalInterest = _totalPayable - _principal;
    } else {
      _emi = 0;
      _totalInterest = 0;
      _totalPayable = 0;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final currency = ref.watch(settingsProvider).currency;
    final format = NumberFormat.currency(symbol: currency, decimalDigits: 0);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text('Smart EMI Calculator', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero EMI Display Card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.primary.withOpacity(0.14),
                    cs.primary.withOpacity(0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: cs.primary.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withOpacity(0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Monthly EMI',
                    style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    format.format(_emi),
                    style: tt.headlineMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 34,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Divider(height: 1, color: cs.primary.withOpacity(0.15)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem('Principal', format.format(_principal), cs, tt),
                      Container(height: 28, width: 1, color: cs.primary.withOpacity(0.15)),
                      _buildSummaryItem('Total Interest', format.format(_totalInterest), cs, tt),
                      Container(height: 28, width: 1, color: cs.primary.withOpacity(0.15)),
                      _buildSummaryItem('Total Payable', format.format(_totalPayable), cs, tt),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Input Fields
            _buildFieldLabel('PRINCIPAL AMOUNT', cs, tt),
            TextFormField(
              controller: _principalController,
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              decoration: _inputDeco(context, prefixText: '$currency ', prefixIcon: Icons.payments_outlined),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) {
                _principal = double.tryParse(v) ?? 0;
                _calculate();
              },
            ),
            const SizedBox(height: 16),

            _buildFieldLabel('INTEREST RATE (% P.A.)', cs, tt),
            TextFormField(
              controller: _rateController,
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              decoration: _inputDeco(context, suffixText: '%', prefixIcon: Icons.percent_rounded),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) {
                _rate = double.tryParse(v) ?? 0;
                _calculate();
              },
            ),
            const SizedBox(height: 16),

            _buildFieldLabel('TENURE (MONTHS)', cs, tt),
            TextFormField(
              controller: _tenureController,
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              decoration: _inputDeco(context, suffixText: 'Mo', prefixIcon: Icons.timelapse_rounded),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                _tenureMonths = int.tryParse(v) ?? 0;
                _calculate();
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, ColorScheme cs, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
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

  Widget _buildSummaryItem(String label, String value, ColorScheme cs, TextTheme tt) {
    return Column(
      children: [
        Text(
          label,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: tt.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  InputDecoration _inputDeco(
    BuildContext context, {
    String? prefixText,
    String? suffixText,
    IconData? prefixIcon,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return InputDecoration(
      prefixText: prefixText,
      prefixStyle: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold),
      suffixText: suffixText,
      suffixStyle: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: cs.primary, size: 20) : null,
      filled: true,
      fillColor: isDark ? cs.surfaceVariant.withOpacity(0.25) : cs.surfaceVariant.withOpacity(0.35),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outline.withOpacity(0.12))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outline.withOpacity(0.12))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary, width: 1.5)),
    );
  }
}
