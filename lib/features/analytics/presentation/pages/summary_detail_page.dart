import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trust_tracker_flutter/core/database/database_helper.dart';
import 'package:trust_tracker_flutter/core/services/summary_service.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:trust_tracker_flutter/core/utils/extensions.dart';
import 'package:trust_tracker_flutter/core/theme/app_colors.dart';

class SummaryDetailPage extends ConsumerStatefulWidget {
  const SummaryDetailPage({super.key});

  @override
  ConsumerState<SummaryDetailPage> createState() => _SummaryDetailPageState();
}

class _SummaryDetailPageState extends ConsumerState<SummaryDetailPage> {
  late Future<Map<String, dynamic>> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  void _loadSummary() {
    final settings = ref.read(settingsProvider);
    final freq = settings.summaryFrequency;
    final now = DateTime.now();
    DateTime start;
    
    if (freq == SummaryFrequency.daily) {
      start = DateTime(now.year, now.month, now.day);
    } else if (freq == SummaryFrequency.weekly) {
      start = now.subtract(const Duration(days: 7));
    } else {
      start = DateTime(now.year, now.month, 1);
    }

    _summaryFuture = SummaryService(DatabaseHelper.instance).getSummaryData(start, now);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Insight'),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final data = snapshot.data!;
          final income = data['income'] as double;
          final expense = data['expense'] as double;
          final balance = data['balance'] as double;
          final topCat = data['topCategory'] as String;
          final count = data['count'] as int;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPeriodHeader(settings.summaryFrequency, tt, cs),
                const SizedBox(height: 24),
                _buildSummaryCard(income, expense, balance, settings.currency, tt, cs),
                const SizedBox(height: 32),
                _buildInsightSection(topCat, count, balance, tt, cs),
                const SizedBox(height: 48),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to Dashboard'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPeriodHeader(SummaryFrequency freq, TextTheme tt, ColorScheme cs) {
    String title;
    String subtitle;
    switch (freq) {
      case SummaryFrequency.daily:
        title = "Your Day in Review";
        subtitle = "A quick look at your spending today";
        break;
      case SummaryFrequency.weekly:
        title = "Weekly Performance";
        subtitle = "How you've managed your money this week";
        break;
      case SummaryFrequency.monthly:
        title = "Monthly Overview";
        subtitle = "Your financial status for the month";
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: cs.primary)),
        const SizedBox(height: 4),
        Text(subtitle, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildSummaryCard(double inc, double exp, double bal, String cur, TextTheme tt, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.primary.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem("Income", inc.toCurrency(cur), cs.primary, tt),
              _buildStatItem("Expense", exp.toCurrency(cur), cs.error, tt),
            ],
          ),
          const Divider(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Net Balance", style: tt.titleMedium),
              Text(
                bal.toCurrency(cur),
                style: tt.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: bal >= 0 ? AppColors.success : cs.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: tt.labelLarge?.copyWith(color: color.withOpacity(0.8))),
        const SizedBox(height: 4),
        Text(value, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildInsightSection(String topCat, int count, double bal, TextTheme tt, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Smart Insights", style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildInsightTile(
          Icons.category_outlined,
          "Top Category",
          "Most of your expenses went to $topCat.",
          cs.secondary,
        ),
        const SizedBox(height: 12),
        _buildInsightTile(
          Icons.receipt_outlined,
          "Activity",
          "You recorded $count transactions in this period.",
          cs.tertiary,
        ),
        const SizedBox(height: 12),
        _buildInsightTile(
          bal >= 0 ? Icons.trending_up : Icons.trending_down,
          bal >= 0 ? "Savings Streak" : "Spending Alert",
          bal >= 0 
            ? "Your balance is positive. Keep maintaining this streak!"
            : "You spent more than you earned. Try to cut back on $topCat.",
          bal >= 0 ? AppColors.success : AppColors.warning,
        ),
      ],
    );
  }

  Widget _buildInsightTile(IconData icon, String title, String desc, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(desc, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
