import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:trust_tracker_flutter/features/banking/data/models/loan_model.dart';
import 'package:trust_tracker_flutter/features/banking/presentation/providers/loan_provider.dart';
import 'dart:math';

class AddLoanPage extends ConsumerStatefulWidget {
  const AddLoanPage({super.key});

  @override
  ConsumerState<AddLoanPage> createState() => _AddLoanPageState();
}

class _AddLoanPageState extends ConsumerState<AddLoanPage> {
  final _formKey = GlobalKey<FormState>();
  
  String _name = '';
  String _type = 'Personal Loan';
  String _bankName = '';
  double _amount = 0;
  double _interestRate = 0;
  DateTime _startDate = DateTime.now();
  DateTime _takenDate = DateTime.now();
  int _tenureMonths = 0;
  double _emiAmount = 0;
  int _emiDueDay = 1;
  String? _accountNumber;
  String? _notes;
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

  void _calculateEmi() {
    if (_amount > 0 && _interestRate > 0 && _tenureMonths > 0) {
      double r = _interestRate / 12 / 100;
      double emi = (_amount * r * (1 + r)) / ((1 + r) - 1);
      // Simplify for now if it's too complex, standard formula: E = P * r * (1 + r)^n / ((1 + r)^n - 1)
      double powRate = pow(1 + r, _tenureMonths).toDouble();
      emi = (_amount * r * powRate) / (powRate - 1);
      
      setState(() {
        _emiAmount = emi;
      });
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      final loan = LoanModel(
        name: _name,
        type: _type,
        bankName: _bankName,
        amount: _amount,
        interestRate: _interestRate,
        startDate: _startDate,
        endDate: DateTime(_startDate.year, _startDate.month + _tenureMonths, _startDate.day),
        tenureMonths: _tenureMonths,
        emiAmount: _emiAmount,
        emiDueDay: _emiDueDay,
        accountNumber: _accountNumber,
        notes: _notes,
        status: 'active',
        createdAt: DateTime.now(),
        autoRecordExpense: _autoRecordExpense,
        takenDate: _takenDate,
      );

      ref.read(loanProvider.notifier).addLoan(loan);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Loan'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'Loan Name', filled: true, fillColor: cs.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                onSaved: (val) => _name = val!,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: InputDecoration(labelText: 'Loan Type', filled: true, fillColor: cs.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                items: _loanTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => _type = val!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(labelText: 'Bank Name', filled: true, fillColor: cs.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                onSaved: (val) => _bankName = val!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(labelText: 'Principal Amount', prefixText: '₹ ', filled: true, fillColor: cs.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                keyboardType: TextInputType.number,
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                onChanged: (val) {
                  _amount = double.tryParse(val) ?? 0;
                  _calculateEmi();
                },
                onSaved: (val) => _amount = double.tryParse(val!) ?? 0,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(labelText: 'Interest Rate (%)', filled: true, fillColor: cs.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        _interestRate = double.tryParse(val) ?? 0;
                        _calculateEmi();
                      },
                      onSaved: (val) => _interestRate = double.tryParse(val!) ?? 0,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(labelText: 'Tenure (Months)', filled: true, fillColor: cs.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        _tenureMonths = int.tryParse(val) ?? 0;
                        _calculateEmi();
                      },
                      onSaved: (val) => _tenureMonths = int.tryParse(val!) ?? 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: ValueKey(_emiAmount),
                initialValue: _emiAmount > 0 ? _emiAmount.toStringAsFixed(2) : '',
                decoration: InputDecoration(labelText: 'EMI Amount (Calculated or Custom)', prefixText: '₹ ', filled: true, fillColor: cs.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                keyboardType: TextInputType.number,
                onSaved: (val) => _emiAmount = double.tryParse(val!) ?? _emiAmount,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Loan Taken Date'),
                subtitle: Text(DateFormat.yMMMd().format(_takenDate)),
                trailing: const Icon(Icons.calendar_today),
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
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('First EMI Date'),
                subtitle: Text(DateFormat.yMMMd().format(_startDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _startDate = picked);
                    // Also auto-update EMI Due Day based on this date
                    setState(() => _emiDueDay = picked.day);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(labelText: 'EMI Due Day (1-31)', filled: true, fillColor: cs.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                keyboardType: TextInputType.number,
                key: ValueKey(_emiDueDay),
                initialValue: _emiDueDay.toString(),
                onSaved: (val) => _emiDueDay = int.tryParse(val!) ?? 1,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(labelText: 'Account Number (Optional)', filled: true, fillColor: cs.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                onSaved: (val) => _accountNumber = val,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Automatically Record EMI Payments'),
                subtitle: const Text('Creates an expense transaction when EMI is paid'),
                value: _autoRecordExpense,
                onChanged: (val) => setState(() => _autoRecordExpense = val),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
