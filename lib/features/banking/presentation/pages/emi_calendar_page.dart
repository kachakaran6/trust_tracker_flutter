import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trust_tracker_flutter/features/banking/presentation/providers/loan_provider.dart';
import 'package:intl/intl.dart';
import 'package:trust_tracker_flutter/core/theme/app_colors.dart';

class EmiCalendarPage extends ConsumerWidget {
  const EmiCalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(loanProvider);
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final format = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

    return Scaffold(
      appBar: AppBar(title: const Text('EMI Calendar')),
      body: loansAsync.when(
        data: (loans) {
          final activeLoans = loans.where((l) => l.status == 'active').toList();
          
          if (activeLoans.isEmpty) {
            return const Center(child: Text('No active loans to show on calendar.'));
          }

          // Sort by next due date day
          activeLoans.sort((a, b) => a.emiDueDay.compareTo(b.emiDueDay));
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activeLoans.length,
            itemBuilder: (context, index) {
              final loan = activeLoans[index];
              final today = DateTime.now();
              
              Color statusColor = Colors.orange; // Upcoming
              String statusText = 'Upcoming this month';
              
              if (today.day == loan.emiDueDay) {
                statusColor = Colors.blue;
                statusText = 'Due Today';
              } else if (today.day > loan.emiDueDay) {
                // Check if already paid this month
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
                  statusColor = AppColors.success;
                  statusText = 'Paid';
                } else {
                  statusColor = AppColors.error;
                  statusText = 'Overdue';
                }
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: statusColor, width: 2),
                ),
                child: ListTile(
                  title: Text(loan.name, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  subtitle: Text('Due on Day ${loan.emiDueDay}\n$statusText', style: tt.bodyMedium?.copyWith(color: statusColor)),
                  trailing: Text(format.format(loan.emiAmount), style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
