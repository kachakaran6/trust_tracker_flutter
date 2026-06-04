import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class LoanCalculatorPage extends StatefulWidget {
  const LoanCalculatorPage({super.key});

  @override
  State<LoanCalculatorPage> createState() => _LoanCalculatorPageState();
}

class _LoanCalculatorPageState extends State<LoanCalculatorPage> {
  double _principal = 100000;
  double _rate = 10.5;
  int _tenureMonths = 12;

  double _emi = 0;
  double _totalInterest = 0;
  double _totalPayable = 0;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  void _calculate() {
    if (_principal > 0 && _rate > 0 && _tenureMonths > 0) {
      double r = _rate / 12 / 100;
      double powRate = pow(1 + r, _tenureMonths).toDouble();
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
    final format = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

    return Scaffold(
      appBar: AppBar(title: const Text('Smart EMI Calculator')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Text('Monthly EMI', style: tt.titleMedium?.copyWith(color: cs.onPrimary.withOpacity(0.8))),
                  const SizedBox(height: 8),
                  Text(format.format(_emi), style: tt.headlineLarge?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          Text('Principal', style: tt.bodySmall?.copyWith(color: cs.onPrimary.withOpacity(0.8))),
                          Text(format.format(_principal), style: tt.titleMedium?.copyWith(color: cs.onPrimary)),
                        ],
                      ),
                      Column(
                        children: [
                          Text('Interest', style: tt.bodySmall?.copyWith(color: cs.onPrimary.withOpacity(0.8))),
                          Text(format.format(_totalInterest), style: tt.titleMedium?.copyWith(color: cs.onPrimary)),
                        ],
                      ),
                      Column(
                        children: [
                          Text('Total', style: tt.bodySmall?.copyWith(color: cs.onPrimary.withOpacity(0.8))),
                          Text(format.format(_totalPayable), style: tt.titleMedium?.copyWith(color: cs.onPrimary)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              initialValue: _principal.toStringAsFixed(0),
              decoration: const InputDecoration(labelText: 'Principal Amount (₹)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              onChanged: (v) { _principal = double.tryParse(v) ?? 0; _calculate(); },
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _rate.toString(),
              decoration: const InputDecoration(labelText: 'Interest Rate (% p.a.)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              onChanged: (v) { _rate = double.tryParse(v) ?? 0; _calculate(); },
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _tenureMonths.toString(),
              decoration: const InputDecoration(labelText: 'Tenure (Months)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              onChanged: (v) { _tenureMonths = int.tryParse(v) ?? 0; _calculate(); },
            ),
          ],
        ),
      ),
    );
  }
}
