import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:trust_tracker_flutter/core/theme/app_colors.dart';
import 'package:trust_tracker_flutter/features/banking/data/models/loan_model.dart';
import 'package:trust_tracker_flutter/features/banking/data/models/loan_payment_model.dart';
import 'package:trust_tracker_flutter/features/banking/presentation/providers/loan_provider.dart';
import 'package:trust_tracker_flutter/features/banking/utils/loan_calculator.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';

class LoanDetailPage extends ConsumerStatefulWidget {
  final LoanModel loan;
  const LoanDetailPage({super.key, required this.loan});

  @override
  ConsumerState<LoanDetailPage> createState() => _LoanDetailPageState();
}

class _LoanDetailPageState extends ConsumerState<LoanDetailPage> {
  void _addPayment() {
    final currency = ref.read(settingsProvider).currency;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        double amt = widget.loan.emiAmount;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.payment_rounded, color: cs.primary, size: 22),
              ),
              const SizedBox(width: 10),
              const Text('Record EMI Payment'),
            ],
          ),
          content: TextFormField(
            initialValue: amt.toStringAsFixed(0),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Amount Paid',
              prefixText: '$currency ',
              filled: true,
              fillColor: isDark ? cs.surfaceVariant.withOpacity(0.25) : cs.surfaceVariant.withOpacity(0.35),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outline.withOpacity(0.15))),
            ),
            onChanged: (val) => amt = double.tryParse(val) ?? 0,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: cs.onSurfaceVariant)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
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
                Navigator.pop(context);
              },
              child: const Text('Save Payment'),
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
    final isDark = theme.brightness == Brightness.dark;
    final currency = ref.watch(settingsProvider).currency;
    final currencyFormat = NumberFormat.currency(symbol: currency, decimalDigits: 0);

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

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(widget.loan.name, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (widget.loan.status == 'active')
            IconButton(
              icon: const Icon(Icons.archive_outlined),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Card
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Loan Amount',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currencyFormat.format(widget.loan.amount),
                    style: tt.headlineMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 32,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Divider(height: 1, color: cs.primary.withOpacity(0.15)),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildHeaderStat('Interest Rate', '${widget.loan.interestRate}%', cs, tt),
                      _buildHeaderStat('Monthly EMI', currencyFormat.format(widget.loan.emiAmount), cs, tt),
                      _buildHeaderStat('Tenure', '${widget.loan.tenureMonths} Mo', cs, tt),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Date Information Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cs.outline.withOpacity(0.12)),
                boxShadow: [
                  BoxShadow(
                    color: cs.shadow.withOpacity(isDark ? 0.2 : 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildDateRow('Loan Taken Date', DateFormat.yMMMd().format(takenDate), tt, cs),
                  Divider(height: 18, color: cs.outline.withOpacity(0.08)),
                  _buildDateRow('First EMI Date', DateFormat.yMMMd().format(firstEmiDate), tt, cs),
                  Divider(height: 18, color: cs.outline.withOpacity(0.08)),
                  _buildDateRow('Maturity Date', DateFormat.yMMMd().format(maturityDate), tt, cs),
                  Divider(height: 18, color: cs.outline.withOpacity(0.08)),
                  _buildDateRow('Loan Age', loanAgeStr, tt, cs, isPrimary: true),
                ],
              ),
            ),
            const SizedBox(height: 22),

            if (widget.loan.status == 'archived')
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.getSuccess(context).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.getSuccess(context).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: AppColors.getSuccess(context)),
                        const SizedBox(width: 8),
                        Text(
                          'Loan Closed & Completed',
                          style: tt.titleMedium?.copyWith(
                            color: AppColors.getSuccess(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildSummaryRow('Original Amount', currencyFormat.format(widget.loan.amount), tt),
                    _buildSummaryRow('Total Paid', currencyFormat.format(summary.totalPaid), tt),
                    _buildSummaryRow('Total Interest', currencyFormat.format(summary.totalPayable - widget.loan.amount), tt),
                    _buildSummaryRow('Loan Duration', '${widget.loan.tenureMonths} Months', tt),
                  ],
                ),
              )
            else ...[
              Text('Loan Progress', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cs.outline.withOpacity(0.12)),
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withOpacity(isDark ? 0.2 : 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          height: 72,
                          width: 72,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: widget.loan.tenureMonths > 0 ? (summary.completedEmis / widget.loan.tenureMonths) : 0,
                                strokeWidth: 7,
                                backgroundColor: isDark ? cs.surfaceVariant.withOpacity(0.3) : cs.surfaceVariant.withOpacity(0.5),
                                color: cs.primary,
                              ),
                              Center(
                                child: Text(
                                  '${summary.completedEmis}/${widget.loan.tenureMonths}',
                                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('EMIs Completed: ${summary.completedEmis}', style: tt.bodyMedium),
                              const SizedBox(height: 4),
                              Text('EMIs Remaining: ${summary.remainingEmis}', style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(height: 1, color: cs.outline.withOpacity(0.1)),
                    const SizedBox(height: 14),
                    _buildSummaryRow('Paid Till Date', currencyFormat.format(summary.totalPaid), tt),
                    _buildSummaryRow('Remaining Amount', currencyFormat.format(summary.remainingAmount), tt, isBold: true),
                    _buildSummaryRow('Principal Paid', currencyFormat.format(summary.principalPaid), tt),
                    _buildSummaryRow('Remaining Principal', currencyFormat.format(summary.remainingPrincipal), tt),
                    _buildSummaryRow('Interest Paid', currencyFormat.format(summary.interestPaid), tt),
                    _buildSummaryRow('Interest Remaining', currencyFormat.format(summary.interestRemaining), tt),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Loan Health Score', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getScoreColor(context, healthScore).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$healthScore/100 ${_getHealthLabel(healthScore)}',
                      style: tt.labelMedium?.copyWith(
                        color: _getScoreColor(context, healthScore),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 28),
            Text('Payment History', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (widget.loan.payments == null || widget.loan.payments!.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Text('No payments recorded yet.', style: tt.bodyMedium?.copyWith(color: cs.onSurface.withOpacity(0.5))),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.loan.payments!.length,
                separatorBuilder: (context, index) => Divider(height: 1, color: cs.outline.withOpacity(0.08)),
                itemBuilder: (context, index) {
                  final p = widget.loan.payments![index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: cs.primary.withOpacity(0.12),
                      child: Icon(Icons.check, color: cs.primary, size: 18),
                    ),
                    title: Text('EMI Paid', style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text(DateFormat.yMMMd().format(p.date), style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    trailing: Text(
                      currencyFormat.format(p.amount),
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.getSuccess(context),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: widget.loan.status == 'active'
          ? FloatingActionButton.extended(
              onPressed: _addPayment,
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              icon: const Icon(Icons.payment_rounded, size: 20),
              label: const Text('Record EMI Payment', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildHeaderStat(String label, String value, ColorScheme cs, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 11)),
        const SizedBox(height: 3),
        Text(value, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface)),
      ],
    );
  }

  Widget _buildDateRow(String label, String value, TextTheme tt, ColorScheme cs, {bool isPrimary = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        Text(
          value,
          style: tt.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isPrimary ? cs.primary : cs.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, TextTheme tt, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: tt.bodyMedium),
          Text(value, style: tt.bodyMedium?.copyWith(fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
        ],
      ),
    );
  }

  Color _getScoreColor(BuildContext context, int score) {
    if (score >= 90) return AppColors.getSuccess(context);
    if (score >= 70) return AppColors.getWarning(context);
    return AppColors.getError(context);
  }

  String _getHealthLabel(int score) {
    if (score >= 90) return 'Excellent';
    if (score >= 70) return 'Good';
    if (score >= 50) return 'Average';
    return 'Needs Attention';
  }
}
