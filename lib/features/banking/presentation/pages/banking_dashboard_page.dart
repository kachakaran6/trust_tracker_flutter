import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:trust_tracker_flutter/core/theme/app_colors.dart';
import 'package:trust_tracker_flutter/features/banking/presentation/providers/loan_provider.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';

class BankingDashboardPage extends ConsumerWidget {
  const BankingDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final currency = ref.watch(settingsProvider).currency;
    final loansAsync = ref.watch(loanProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          'Banking & Loans',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'EMI Calculator',
            icon: const Icon(Icons.calculate_outlined),
            onPressed: () => context.push('/loan-calculator'),
          ),
          IconButton(
            tooltip: 'EMI Calendar',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => context.push('/emi-calendar'),
          ),
          const SizedBox(width: 4),
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
          final double annualCommitment = totalMonthlyEmi * 12;
          final currencyFormat = NumberFormat.currency(symbol: currency, decimalDigits: 0);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Hero Card: Total Outstanding Debt
                _buildHeroDebtCard(
                  cs,
                  tt,
                  isDark,
                  totalDebt: currencyFormat.format(totalDebt),
                  activeLoansCount: activeLoans.length,
                ),
                const SizedBox(height: 14),

                // Secondary Metrics Row
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        cs,
                        tt,
                        isDark,
                        title: 'Monthly EMI',
                        amount: currencyFormat.format(totalMonthlyEmi),
                        icon: Icons.calendar_month_rounded,
                        iconColor: AppColors.getWarning(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        cs,
                        tt,
                        isDark,
                        title: 'Active Loans',
                        amount: activeLoans.length.toString(),
                        icon: Icons.account_balance_outlined,
                        iconColor: cs.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // Monthly Liability Forecast
                _buildSectionHeader(tt, cs, 'Monthly Liability Forecast'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cs.outline.withOpacity(0.12)),
                    boxShadow: [
                      BoxShadow(
                        color: cs.shadow.withOpacity(isDark ? 0.2 : 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: cs.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.date_range_rounded, size: 16, color: cs.primary),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Monthly EMI',
                                style: tt.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            currencyFormat.format(totalMonthlyEmi),
                            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(height: 1, color: cs.outline.withOpacity(0.1)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: cs.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.trending_up_rounded, size: 16, color: cs.primary),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Yearly Commitment',
                                style: tt.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            currencyFormat.format(annualCommitment),
                            style: tt.titleMedium?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Upcoming EMIs (30 Days)
                if (upcomingLoans.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader(tt, cs, 'Upcoming EMIs (30 Days)'),
                      Text(
                        currencyFormat.format(totalUpcoming),
                        style: tt.labelLarge?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 124,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: upcomingLoans.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final item = upcomingLoans[index];
                        final loan = item['loan'];
                        final days = item['days'] as int;
                        final isUrgent = days <= 3;
                        final alertColor = isUrgent ? AppColors.getError(context) : cs.primary;

                        return Container(
                          width: 210,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isUrgent ? alertColor.withOpacity(0.3) : cs.outline.withOpacity(0.12),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: cs.shadow.withOpacity(isDark ? 0.2 : 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loan.name,
                                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currencyFormat.format(loan.emiAmount),
                                style: tt.titleMedium?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: alertColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  days == 0 ? '⏰ Due Today' : 'Due in $days day(s)',
                                  style: TextStyle(
                                    color: alertColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 22),
                ],

                // Active Loans List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionHeader(tt, cs, 'Active Loans'),
                    if (activeLoans.isNotEmpty)
                      Text(
                        '${activeLoans.length} Total',
                        style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                if (activeLoans.isEmpty)
                  _buildEmptyLoansState(context, cs, tt, isDark)
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: activeLoans.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final loan = activeLoans[index];
                      return _buildLoanTile(context, loan, currencyFormat, cs, tt, isDark);
                    },
                  ),
                const SizedBox(height: 90),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add-loan'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Add Loan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(TextTheme tt, ColorScheme cs, String title) {
    return Text(
      title,
      style: tt.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: cs.onSurface,
      ),
    );
  }

  Widget _buildHeroDebtCard(
    ColorScheme cs,
    TextTheme tt,
    bool isDark, {
    required String totalDebt,
    required int activeLoansCount,
  }) {
    return Container(
      width: double.infinity,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.account_balance_wallet_rounded, size: 18, color: cs.primary),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Total Outstanding Debt',
                    style: tt.labelLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (activeLoansCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$activeLoansCount Active',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            totalDebt,
            style: tt.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
              fontSize: 32,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    ColorScheme cs,
    TextTheme tt,
    bool isDark, {
    required String title,
    required String amount,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outline.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
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
              amount,
              style: tt.titleLarge?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyLoansState(BuildContext context, ColorScheme cs, TextTheme tt, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.account_balance_outlined, size: 36, color: cs.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'No Active Loans',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Track home loans, personal loans, vehicle EMIs, and debt liabilities all in one place.',
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.primary,
              side: BorderSide(color: cs.primary.withOpacity(0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () => context.push('/add-loan'),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Your First Loan', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanTile(
    BuildContext context,
    dynamic loan,
    NumberFormat format,
    ColorScheme cs,
    TextTheme tt,
    bool isDark,
  ) {
    return InkWell(
      onTap: () {
        context.push('/loan-details', extra: loan);
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.account_balance_rounded, size: 18, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loan.name,
                        style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        loan.bankName.isNotEmpty ? loan.bankName : (loan.type ?? 'Loan'),
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      format.format(loan.amount),
                      style: tt.titleMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'EMI: ${format.format(loan.emiAmount)}/mo',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
