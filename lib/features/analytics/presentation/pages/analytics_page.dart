import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';
import 'package:trust_tracker_flutter/core/utils/extensions.dart';
import 'package:trust_tracker_flutter/features/categories/data/models/category_model.dart';
import 'package:trust_tracker_flutter/features/transactions/data/repositories/transaction_repository.dart';
import 'package:trust_tracker_flutter/features/categories/data/repositories/category_repository.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final trendDataProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(transactionRepositoryProvider).getLast6MonthsTrend();
});

final categorySpendingProvider =
    FutureProvider.autoDispose<Map<int, double>>((ref) {
  final now = DateTime.now();
  return ref
      .watch(transactionRepositoryProvider)
      .getCategorySpendingForMonth(now.toMonthKey());
});

/// Pre-load ALL expense categories to avoid FutureBuilder per legend row (old bug).
final _analyticsExpenseCatsProvider =
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
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final trendAsync = ref.watch(trendDataProvider);
    final catSpendAsync = ref.watch(categorySpendingProvider);
    final allCatsAsync = ref.watch(_analyticsExpenseCatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
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
          const SizedBox(height: 32),

          // ── Category spending pie chart ─────────────────────────────
          Text('Spending by Category',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(DateTime.now().toMonthYear(),
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),

          catSpendAsync.when(
            data: (catSpend) => allCatsAsync.when(
              data: (cats) {
                if (catSpend.isEmpty) {
                  return const _EmptyChart();
                }

                // Build a lookup map for O(1) category name resolution
                final catMap = {for (final c in cats) c.id: c};
                final colors = kChartColors;
                final entries = catSpend.entries.toList();
                final total =
                    entries.fold<double>(0, (s, e) => s + e.value);

                return Column(children: [
                  SizedBox(
                    height: 220,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (event, resp) {
                            if (!event.isInterestedForInteractions) return;
                            setState(() {
                              _touchedIndex = resp?.touchedSection
                                      ?.touchedSectionIndex ??
                                  -1;
                            });
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 3,
                        centerSpaceRadius: 60,
                        sections: entries.asMap().entries.map((e) {
                          final isTouched = e.key == _touchedIndex;
                          final color = colors[e.key % colors.length];
                          final pct = (e.value.value / total * 100)
                              .toStringAsFixed(1);
                          return PieChartSectionData(
                            color: color,
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
                  // Legend — NO FutureBuilder per row! Use the pre-loaded catMap.
                  ...entries.asMap().entries.map((e) {
                    final color = colors[e.key % colors.length];
                    final pct =
                        (e.value.value / total * 100).toStringAsFixed(1);
                    final catName =
                        catMap[e.value.key]?.name ?? 'Cat #${e.value.key}';
                    final catColor = catMap[e.value.key] != null
                        ? Color(catMap[e.value.key]!.colorHex.toColorInt())
                        : color;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Theme.of(context).brightness ==
                                    Brightness.dark
                                ? const Color(0xFF2D3748)
                                : AppColors.gray200),
                      ),
                      child: Row(children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                              color: catColor,
                              borderRadius: BorderRadius.circular(3)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(catName,
                              style: Theme.of(context).textTheme.bodyMedium),
                        ),
                        Text('$pct%',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(width: 8),
                        Text(
                          e.value.value.toCurrency(settings.currency),
                          style: GoogleFonts.inter(
                              color: AppColors.gray500, fontSize: 12),
                        ),
                      ]),
                    );
                  }),
                ]);
              },
              loading: () => const _ChartSkeleton(height: 220),
              error: (_, __) => const SizedBox.shrink(),
            ),
            loading: () => const _ChartSkeleton(height: 280),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
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

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(children: [
          const Icon(Icons.pie_chart_outline,
              size: 52, color: AppColors.gray300),
          const SizedBox(height: 12),
          Text('No expense data for this month',
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
