import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:trust_tracker_flutter/core/theme/app_colors.dart';
import 'package:trust_tracker_flutter/features/banking/presentation/providers/loan_provider.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';

class EmiCalendarPage extends ConsumerWidget {
  const EmiCalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final currency = ref.watch(settingsProvider).currency;
    final loansAsync = ref.watch(loanProvider);
    final format = NumberFormat.currency(symbol: currency, decimalDigits: 0);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text('EMI Calendar', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: loansAsync.when(
        data: (loans) {
          final activeLoans = loans.where((l) => l.status == 'active').toList();

          if (activeLoans.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.calendar_month_outlined, size: 36, color: cs.primary),
                    ),
                    const SizedBox(height: 16),
                    Text('No Active EMIs', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      'No loans scheduled for repayment this month.',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          }

          // Sort by next due date day
          activeLoans.sort((a, b) => a.emiDueDay.compareTo(b.emiDueDay));

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: activeLoans.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final loan = activeLoans[index];
              final today = DateTime.now();

              Color statusColor = AppColors.getWarning(context);
              String statusText = 'Upcoming';
              IconData statusIcon = Icons.schedule_rounded;

              if (today.day == loan.emiDueDay) {
                statusColor = cs.primary;
                statusText = 'Due Today';
                statusIcon = Icons.today_rounded;
              } else if (today.day > loan.emiDueDay) {
                bool paidThisMonth = false;
                if (loan.payments != null) {
                  for (var p in loan.payments!) {
                    if (p.date.year == today.year && p.date.month == today.month) {
                      paidThisMonth = true;
                      break;
                    }
                  }
                }
                if (paidThisMonth) {
                  statusColor = AppColors.getSuccess(context);
                  statusText = 'Paid';
                  statusIcon = Icons.check_circle_outline_rounded;
                } else {
                  statusColor = AppColors.getError(context);
                  statusText = 'Overdue';
                  statusIcon = Icons.warning_amber_rounded;
                }
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outline.withOpacity(0.12)),
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withOpacity(isDark ? 0.2 : 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 20),
                    ),
                    const SizedBox(width: 14),
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
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'Day ${loan.emiDueDay} of month',
                                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      format.format(loan.emiAmount),
                      style: tt.titleMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
