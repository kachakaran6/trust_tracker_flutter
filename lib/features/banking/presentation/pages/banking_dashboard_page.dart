import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trust_tracker_flutter/features/banking/presentation/providers/loan_provider.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class BankingDashboardPage extends ConsumerWidget {
  const BankingDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final loansAsync = ref.watch(loanProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Banking & Loans', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            onPressed: () {
              // TODO: Navigate to archived loans
            },
          )
        ],
      ),
      body: loansAsync.when(
        data: (loans) {
          final activeLoans = loans.where((l) => l.status == 'active').toList();
          
          double totalDebt = 0;
          double totalMonthlyEmi = 0;
          final upcomingLoans = <dynamic>[];
          double totalUpcoming = 0;
          final now = DateTime.now();
          
          for (var loan in activeLoans) {
            totalDebt += loan.amount;
            totalMonthlyEmi += loan.emiAmount;
            
            var nextDueDate = DateTime(now.year, now.month, loan.emiDueDay);
            if (nextDueDate.isBefore(DateTime(now.year, now.month, now.day))) {
              nextDueDate = DateTime(now.year, now.month + 1, loan.emiDueDay);
            }
            
            final diff = nextDueDate.difference(DateTime(now.year, now.month, now.day)).inDays;
            if (diff <= 30) {
              upcomingLoans.add({'loan': loan, 'days': diff, 'date': nextDueDate});
              totalUpcoming += loan.emiAmount;
            }
          }
          
          upcomingLoans.sort((a, b) => (a['days'] as int).compareTo(b['days'] as int));
          double annualCommitment = totalMonthlyEmi * 12;

          final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCard(
                  cs, tt, 
                  title: 'Total Outstanding Debt', 
                  amount: currencyFormat.format(totalDebt),
                  icon: Icons.account_balance_wallet_rounded,
                  isPrimary: true
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildSummaryCard(cs, tt, title: 'Monthly EMI', amount: currencyFormat.format(totalMonthlyEmi), icon: Icons.calendar_month)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildSummaryCard(cs, tt, title: 'Active Loans', amount: activeLoans.length.toString(), icon: Icons.description_outlined)),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Monthly Liability Forecast', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  color: cs.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Monthly EMI', style: tt.bodyLarge),
                            Text(currencyFormat.format(totalMonthlyEmi), style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Yearly Commitment', style: tt.bodyLarge),
                            Text(currencyFormat.format(annualCommitment), style: tt.titleLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (upcomingLoans.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Upcoming EMIs (30 Days)', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      Text(currencyFormat.format(totalUpcoming), style: tt.titleMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: upcomingLoans.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final item = upcomingLoans[index];
                        final loan = item['loan'];
                        final days = item['days'];
                        return Container(
                          width: 200,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: cs.outlineVariant),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(loan.name, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 8),
                              Text(currencyFormat.format(loan.emiAmount), style: tt.titleMedium?.copyWith(color: cs.primary)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: days <= 3 ? AppColors.error.withOpacity(0.1) : cs.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  days == 0 ? 'Due Today' : 'Due in $days days',
                                  style: tt.bodySmall?.copyWith(
                                    color: days <= 3 ? AppColors.error : cs.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                Text('Active Loans', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (activeLoans.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text('No active loans found.\nTap + to add a loan.', textAlign: TextAlign.center, style: tt.bodyLarge?.copyWith(color: cs.onSurface.withOpacity(0.5))),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: activeLoans.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final loan = activeLoans[index];
                      return _buildLoanTile(context, loan, currencyFormat, cs, tt);
                    },
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add-loan'),
        icon: const Icon(Icons.add),
        label: const Text('Add Loan'),
      ),
    );
  }

  Widget _buildSummaryCard(ColorScheme cs, TextTheme tt, {required String title, required String amount, required IconData icon, bool isPrimary = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isPrimary ? cs.primary : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: isPrimary ? cs.onPrimary.withOpacity(0.7) : cs.onSurface.withOpacity(0.7), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: tt.bodyMedium?.copyWith(color: isPrimary ? cs.onPrimary.withOpacity(0.8) : cs.onSurface.withOpacity(0.8)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            amount,
            style: tt.headlineMedium?.copyWith(
              color: isPrimary ? cs.onPrimary : cs.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanTile(BuildContext context, dynamic loan, NumberFormat format, ColorScheme cs, TextTheme tt) {
    return InkWell(
      onTap: () {
        context.push('/loan-details', extra: loan);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(loan.name, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text(format.format(loan.amount), style: tt.titleMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.account_balance, size: 14, color: cs.onSurface.withOpacity(0.5)),
                const SizedBox(width: 4),
                Text(loan.bankName, style: tt.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.6))),
                const Spacer(),
                Text('EMI: ${format.format(loan.emiAmount)}/mo', style: tt.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
