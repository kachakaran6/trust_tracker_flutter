import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:trust_tracker_flutter/features/banking/data/models/loan_model.dart';
import 'package:trust_tracker_flutter/features/banking/data/models/loan_payment_model.dart';
import 'package:trust_tracker_flutter/features/banking/presentation/providers/loan_provider.dart';
import 'package:trust_tracker_flutter/features/banking/utils/loan_calculator.dart';
import 'package:trust_tracker_flutter/core/theme/app_colors.dart';

class LoanDetailPage extends ConsumerStatefulWidget {
  final LoanModel loan;
  const LoanDetailPage({super.key, required this.loan});

  @override
  ConsumerState<LoanDetailPage> createState() => _LoanDetailPageState();
}

class _LoanDetailPageState extends ConsumerState<LoanDetailPage> {
  void _addPayment() {
    showDialog(
      context: context,
      builder: (context) {
        double amt = widget.loan.emiAmount;
        return AlertDialog(
          title: const Text('Record EMI Payment'),
          content: TextFormField(
            initialValue: amt.toStringAsFixed(2),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount Paid'),
            onChanged: (val) => amt = double.tryParse(val) ?? 0,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final payment = LoanPaymentModel(
                  loanId: widget.loan.id!,
                  amount: amt,
                  date: DateTime.now(),
                  status: 'paid',
                  method: 'manual',
                );
                ref.read(loanProvider.notifier).addPayment(payment);
                Navigator.pop(context);
                Navigator.pop(context); // Pop details page to refresh for now
              },
              child: const Text('Save'),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

    final summary = LoanCalculator.calculateSummary(widget.loan);
    final healthScore = LoanCalculator.calculateHealthScore(summary);
    
    final takenDate = widget.loan.takenDate ?? widget.loan.startDate;
    final firstEmiDate = widget.loan.startDate;
    final maturityDate = widget.loan.endDate;
    
    final loanAgeDays = DateTime.now().difference(takenDate).inDays;
    final loanAgeYears = loanAgeDays ~/ 365;
    final loanAgeMonths = (loanAgeDays % 365) ~/ 30;
    final loanAgeRemainingDays = (loanAgeDays % 365) % 30;
    
    String loanAgeStr = '';
    if (loanAgeYears > 0) loanAgeStr += '$loanAgeYears Year${loanAgeYears > 1 ? 's' : ''} ';
    if (loanAgeMonths > 0) loanAgeStr += '$loanAgeMonths Month${loanAgeMonths > 1 ? 's' : ''} ';
    loanAgeStr += '$loanAgeRemainingDays Day${loanAgeRemainingDays != 1 ? 's' : ''}';

    double progress = summary.totalPayable > 0 ? (summary.totalPaid / summary.totalPayable) : 0;
    if (progress > 1.0) progress = 1.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.loan.name),
        actions: [
          if (widget.loan.status == 'active')
            IconButton(
              icon: const Icon(Icons.archive),
              tooltip: 'Close & Archive Loan',
              onPressed: () {
                final closedLoan = widget.loan.copyWith(status: 'archived');
                ref.read(loanProvider.notifier).updateLoan(closedLoan);
                Navigator.pop(context);
              },
            ),
        ],
      ),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Loan Amount', style: tt.bodyMedium?.copyWith(color: cs.onPrimary.withOpacity(0.8))),
                  const SizedBox(height: 8),
                  Text(currencyFormat.format(widget.loan.amount), style: tt.headlineMedium?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Interest Rate', style: tt.bodySmall?.copyWith(color: cs.onPrimary.withOpacity(0.8))),
                          Text('${widget.loan.interestRate}%', style: tt.titleMedium?.copyWith(color: cs.onPrimary)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('EMI Amount', style: tt.bodySmall?.copyWith(color: cs.onPrimary.withOpacity(0.8))),
                          Text(currencyFormat.format(widget.loan.emiAmount), style: tt.titleMedium?.copyWith(color: cs.onPrimary)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tenure', style: tt.bodySmall?.copyWith(color: cs.onPrimary.withOpacity(0.8))),
                          Text('${widget.loan.tenureMonths} mo', style: tt.titleMedium?.copyWith(color: cs.onPrimary)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Date Information Card
            Card(
              elevation: 0,
              color: cs.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Loan Taken Date', style: tt.bodyMedium),
                        Text(DateFormat.yMMMd().format(takenDate), style: tt.titleSmall),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('First EMI Date', style: tt.bodyMedium),
                        Text(DateFormat.yMMMd().format(firstEmiDate), style: tt.titleSmall),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Maturity Date', style: tt.bodyMedium),
                        Text(DateFormat.yMMMd().format(maturityDate), style: tt.titleSmall),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Loan Age', style: tt.bodyMedium),
                        Text(loanAgeStr, style: tt.titleSmall?.copyWith(color: cs.primary)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (widget.loan.status == 'archived')
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.success),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: AppColors.success),
                        const SizedBox(width: 8),
                        Text('Loan Completion Report', style: tt.titleLarge?.copyWith(color: AppColors.success, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSummaryRow('Original Amount', currencyFormat.format(widget.loan.amount), tt),
                    _buildSummaryRow('Total Paid', currencyFormat.format(summary.totalPaid), tt),
                    _buildSummaryRow('Total Interest', currencyFormat.format(summary.totalPayable - widget.loan.amount), tt),
                    _buildSummaryRow('Loan Duration', '${widget.loan.tenureMonths} Months', tt),
                    _buildSummaryRow('Completion Date', DateFormat.yMMMd().format(DateTime.now()), tt),
                  ],
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Loan Progress', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      SizedBox(
                        height: 80,
                        width: 80,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: summary.completedEmis / widget.loan.tenureMonths,
                              strokeWidth: 8,
                              backgroundColor: cs.surfaceContainerHighest,
                              color: cs.primary,
                            ),
                            Center(
                              child: Text(
                                '${summary.completedEmis}/${widget.loan.tenureMonths}',
                                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('EMIs Completed: ${summary.completedEmis}'),
                            Text('EMIs Remaining: ${summary.remainingEmis}', style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 0,
                    color: cs.surfaceContainerLowest,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildSummaryRow('Paid Till Date', currencyFormat.format(summary.totalPaid), tt),
                          _buildSummaryRow('Remaining Amount', currencyFormat.format(summary.remainingAmount), tt, isBold: true),
                          const Divider(),
                          _buildSummaryRow('Principal Paid', currencyFormat.format(summary.principalPaid), tt),
                          _buildSummaryRow('Remaining Principal', currencyFormat.format(summary.remainingPrincipal), tt),
                          const Divider(),
                          _buildSummaryRow('Interest Paid', currencyFormat.format(summary.interestPaid), tt),
                          _buildSummaryRow('Interest Remaining', currencyFormat.format(summary.interestRemaining), tt),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Loan Health Score', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getScoreColor(healthScore).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$healthScore/100 ${_getHealthLabel(healthScore)}',
                          style: tt.titleSmall?.copyWith(color: _getScoreColor(healthScore), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 32),
            Text('Payment History', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (widget.loan.payments == null || widget.loan.payments!.isEmpty)
              Text('No payments recorded yet.', style: tt.bodyMedium?.copyWith(color: cs.onSurface.withOpacity(0.5)))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.loan.payments!.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final p = widget.loan.payments![index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: cs.primaryContainer,
                      child: Icon(Icons.check, color: cs.onPrimaryContainer),
                    ),
                    title: Text('EMI Paid', style: tt.titleMedium),
                    subtitle: Text(DateFormat.yMMMd().format(p.date)),
                    trailing: Text(currencyFormat.format(p.amount), style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.success)),
                  );
                },
              )
          ],
        ),
      ),
      floatingActionButton: widget.loan.status == 'active' ? FloatingActionButton.extended(
        onPressed: _addPayment,
        icon: const Icon(Icons.payment),
        label: const Text('Pay EMI'),
      ) : null,
    );
  }

  Widget _buildSummaryRow(String label, String value, TextTheme tt, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: tt.bodyMedium),
          Text(value, style: tt.titleMedium?.copyWith(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 90) return AppColors.success;
    if (score >= 70) return AppColors.warning;
    return AppColors.error;
  }

  String _getHealthLabel(int score) {
    if (score >= 90) return 'Excellent';
    if (score >= 70) return 'Good';
    if (score >= 50) return 'Average';
    return 'Needs Attention';
  }
}
