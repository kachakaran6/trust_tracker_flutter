import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';
import 'package:trust_tracker_flutter/core/utils/extensions.dart';
import 'package:trust_tracker_flutter/features/categories/data/models/category_model.dart';
import 'package:trust_tracker_flutter/features/transactions/data/repositories/transaction_repository.dart';
import 'package:trust_tracker_flutter/features/categories/data/repositories/category_repository.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

// ── Providers ─────────────────────────────────────────────────────────────────
// FIX (Issues 5, 9, 10): Watch transactionListProvider so analytics rebuilds
// automatically whenever a transaction is added / edited / deleted.

final selectedMonthProvider = StateProvider.autoDispose<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final trendDataProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  ref.watch(transactionListProvider);
  return ref.watch(transactionRepositoryProvider).getLast6MonthsTrend();
});

final monthlySummaryProvider =
    FutureProvider.autoDispose<Map<String, double>>((ref) {
  ref.watch(transactionListProvider);
  final month = ref.watch(selectedMonthProvider);
  return ref
      .watch(transactionRepositoryProvider)
      .getMonthlySummary(month.toMonthKey());
});

final expenseSpendingProvider =
    FutureProvider.autoDispose<Map<int, double>>((ref) {
  ref.watch(transactionListProvider);
  final month = ref.watch(selectedMonthProvider);
  return ref
      .watch(transactionRepositoryProvider)
      .getCategorySpendingForMonth(month.toMonthKey(), TransactionType.expense);
});

final incomeSpendingProvider =
    FutureProvider.autoDispose<Map<int, double>>((ref) {
  ref.watch(transactionListProvider);
  final month = ref.watch(selectedMonthProvider);
  return ref
      .watch(transactionRepositoryProvider)
      .getCategorySpendingForMonth(month.toMonthKey(), TransactionType.income);
});

/// Pre-load ALL categories — public so categories_page can invalidate it (Issue 9)
final analyticsExpenseCatsProvider =
    FutureProvider.autoDispose<List<CategoryModel>>((ref) {
  return ref.watch(categoryRepositoryProvider).getAll();
});


// ── Page ──────────────────────────────────────────────────────────────────────

class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  int _touchedExpenseIndex = -1;
  int _touchedIncomeIndex = -1;

  void _previousMonth() {
    final current = ref.read(selectedMonthProvider);
    ref
        .read(selectedMonthProvider.notifier)
        .state = DateTime(current.year, current.month - 1);
  }

  void _nextMonth() {
    final current = ref.read(selectedMonthProvider);
    final now = DateTime.now();
    final candidate = DateTime(current.year, current.month + 1);
    if (candidate.isAfter(DateTime(now.year, now.month))) return;
    ref.read(selectedMonthProvider.notifier).state = candidate;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final trendAsync = ref.watch(trendDataProvider);
    final extAsync = ref.watch(expenseSpendingProvider);
    final incAsync = ref.watch(incomeSpendingProvider);
    final allCatsAsync = ref.watch(analyticsExpenseCatsProvider);
    final summaryAsync = ref.watch(monthlySummaryProvider);
    final cs = Theme.of(context).colorScheme;

    final now = DateTime.now();
    final canGoForward = selectedMonth.year < now.year ||
        (selectedMonth.year == now.year && selectedMonth.month < now.month);

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // ── Month Selector ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 28),
                onPressed: _previousMonth,
                color: cs.onSurface,
              ),
              Text(
                selectedMonth.toMonthYear(),
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right_rounded, size: 28),
                onPressed: canGoForward ? _nextMonth : null,
                color: canGoForward
                    ? cs.onSurface
                    : cs.onSurface.withOpacity(0.2),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Monthly Summary ──────────────────────────────────────────
          summaryAsync.when(
            data: (summary) {
              final inc = summary['income'] ?? 0;
              final exp = summary['expense'] ?? 0;
              final bal = summary['balance'] ?? 0;

              if (inc == 0 && exp == 0) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      'No transactions found for this month.',
                      style: GoogleFonts.inter(
                          color: cs.onSurface.withOpacity(0.5)),
                    ),
                  ),
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Income',
                      amount: inc,
                      currency: settings.currency,
                      color: AppColors.success500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Expense',
                      amount: exp,
                      currency: settings.currency,
                      color: AppColors.danger500,
                    ),
                  ),
                ],
              );
            },
            loading: () => const _ChartSkeleton(height: 80),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 32),

          // ── Expenses Pie Chart ──────────────────────────────────────
          Text('Expense Breakdown',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          extAsync.when(
            data: (spendData) => allCatsAsync.when(
              data: (cats) {
                if (spendData.isEmpty) {
                  return const _EmptyNamedChart(label: 'expenses');
                }
                return _PieChartSection(
                  spendingData: spendData,
                  categories: cats,
                  currency: settings.currency,
                  touchedIndex: _touchedExpenseIndex,
                  onTouched: (idx) => setState(() => _touchedExpenseIndex = idx),
                  themeMode: Theme.of(context).brightness,
                );
              },
              loading: () => const _ChartSkeleton(height: 220),
              error: (_, __) => const SizedBox.shrink(),
            ),
            loading: () => const _ChartSkeleton(height: 280),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 32),

          // ── Income Pie Chart ──────────────────────────────────────
          Text('Income Sources',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          incAsync.when(
            data: (spendData) => allCatsAsync.when(
              data: (cats) {
                if (spendData.isEmpty) {
                  return const _EmptyNamedChart(label: 'income');
                }
                return _PieChartSection(
                  spendingData: spendData,
                  categories: cats,
                  currency: settings.currency,
                  touchedIndex: _touchedIncomeIndex,
                  onTouched: (idx) => setState(() => _touchedIncomeIndex = idx),
                  themeMode: Theme.of(context).brightness,
                );
              },
              loading: () => const _ChartSkeleton(height: 220),
              error: (_, __) => const SizedBox.shrink(),
            ),
            loading: () => const _ChartSkeleton(height: 280),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 32),

          // ── 6-month trend ──────────────────────────────────────────
          Text('6-Month Trend',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          trendAsync.when(
            data: (data) =>
                _TrendBarChart(data: data, currency: settings.currency),
            loading: () => const _ChartSkeleton(height: 220),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final String currency;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.currency,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withOpacity(0.6))),
          const SizedBox(height: 4),
          Text(amount.toCurrency(currency),
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}

class _PieChartSection extends StatelessWidget {
  final Map<int, double> spendingData;
  final List<CategoryModel> categories;
  final String currency;
  final int touchedIndex;
  final ValueChanged<int> onTouched;
  final Brightness themeMode;

  const _PieChartSection({
    required this.spendingData,
    required this.categories,
    required this.currency,
    required this.touchedIndex,
    required this.onTouched,
    required this.themeMode,
  });

  @override
  Widget build(BuildContext context) {
    final catMap = {for (final c in categories) c.id: c};
    final colors = kChartColors;
    final entries = spendingData.entries.toList();
    final total = entries.fold<double>(0, (s, e) => s + e.value);

    return Column(children: [
      SizedBox(
        height: 220,
        child: PieChart(
          PieChartData(
            pieTouchData: PieTouchData(
              touchCallback: (event, resp) {
                if (!event.isInterestedForInteractions) return;
                onTouched(resp?.touchedSection?.touchedSectionIndex ?? -1);
              },
            ),
            borderData: FlBorderData(show: false),
            sectionsSpace: 3,
            centerSpaceRadius: 60,
            sections: entries.asMap().entries.map((e) {
              final isTouched = e.key == touchedIndex;
              final color = colors[e.key % colors.length];
              final pct = (e.value.value / total * 100).toStringAsFixed(1);
              final catColor = catMap[e.value.key] != null
                  ? Color(catMap[e.value.key]!.colorHex.toColorInt())
                  : color;
              
              return PieChartSectionData(
                color: catColor,
                value: e.value.value,
                title: isTouched ? '$pct%' : '',
                radius: isTouched ? 65 : 55,
                titleStyle: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              );
            }).toList(),
          ),
        ),
      ),
      const SizedBox(height: 16),
      ...entries.asMap().entries.map((e) {
        final color = colors[e.key % colors.length];
        final pct = (e.value.value / total * 100).toStringAsFixed(1);
        final catName = catMap[e.value.key]?.name ?? 'Cat #${e.value.key}';
        final catColor = catMap[e.value.key] != null
            ? Color(catMap[e.value.key]!.colorHex.toColorInt())
            : color;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: themeMode == Brightness.dark
                    ? const Color(0xFF2D3748)
                    : AppColors.gray200),
          ),
          child: Row(children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                  color: catColor, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child:
                  Text(catName, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Text('$pct%',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(width: 8),
            Text(
              e.value.value.toCurrency(currency),
              style: GoogleFonts.inter(color: AppColors.gray500, fontSize: 12),
            ),
          ]),
        );
      }),
    ]);
  }
}

// ── Trend Bar Chart ───────────────────────────────────────────────────────────

class _TrendBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String currency;
  const _TrendBarChart({required this.data, required this.currency});

  @override
  Widget build(BuildContext context) {
    final maxY = data.fold<double>(0, (m, d) {
      final inc = (d['income'] as double? ?? 0);
      final exp = (d['expense'] as double? ?? 0);
      return [m, inc, exp].reduce((a, b) => a > b ? a : b);
    }) * 1.25;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2D3748)
                : AppColors.gray200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Legend
        Row(children: [
          _LegendDot(color: AppColors.success500, label: 'Income'),
          const SizedBox(width: 16),
          _LegendDot(color: AppColors.danger500, label: 'Expense'),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY == 0 ? 100 : maxY,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final d = data[groupIndex];
                    final label = rodIndex == 0
                        ? 'Income: ${(d['income'] as double).toCurrencyCompact(currency)}'
                        : 'Expense: ${(d['expense'] as double).toCurrencyCompact(currency)}';
                    return BarTooltipItem(
                      label,
                      GoogleFonts.inter(
                          color: Colors.white, fontSize: 11),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (val, _) => Text(
                      data[val.toInt()]['label'] as String,
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.gray500),
                    ),
                  ),
                ),
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: data.asMap().entries.map((e) {
                final d = e.value;
                return BarChartGroupData(
                  x: e.key,
                  groupVertically: false,
                  barRods: [
                    BarChartRodData(
                      toY: (d['income'] as double? ?? 0),
                      color: AppColors.success500,
                      width: 10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    BarChartRodData(
                      toY: (d['expense'] as double? ?? 0),
                      color: AppColors.danger500,
                      width: 10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ]),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label,
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500)),
    ]);
  }
}

// ── Skeleton & Empty ──────────────────────────────────────────────────────────

class _ChartSkeleton extends StatelessWidget {
  final double height;
  const _ChartSkeleton({required this.height});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkCard
            : AppColors.gray100,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _EmptyNamedChart extends StatelessWidget {
  final String label;

  const _EmptyNamedChart({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(children: [
          Icon(Icons.pie_chart_outline,
              size: 42, color: AppColors.gray300.withOpacity(0.5)),
          const SizedBox(height: 12),
          Text('No $label data to display',
              style: GoogleFonts.inter(color: AppColors.gray500)),
        ]),
      ),
    );
  }
}

// Chart colors for pie segments
const List<Color> kChartColors = [
  AppColors.primary500,
  AppColors.success500,
  AppColors.warning500,
  AppColors.danger500,
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
  Color(0xFF06B6D4),
  Color(0xFF84CC16),
];
