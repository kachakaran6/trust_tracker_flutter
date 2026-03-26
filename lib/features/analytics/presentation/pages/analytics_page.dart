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
import 'package:trust_tracker_flutter/core/utils/category_utils.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:trust_tracker_flutter/generated/app_localizations.dart';

// ── Providers ─────────────────────────────────────────────────────────────────
enum AnalyticsMode { overview, spending, categories, trends }

final analyticsModeProvider = StateProvider.autoDispose<AnalyticsMode>((ref) => AnalyticsMode.overview);

final selectedMonthProvider = StateProvider.autoDispose<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final trendDataProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  ref.watch(transactionListProvider);
  return ref.watch(transactionRepositoryProvider).getLast6MonthsTrend();
});

final savingsRateTrendProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  ref.watch(transactionListProvider);
  return ref.watch(transactionRepositoryProvider).getSavingsRateTrend(6);
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

final dailySpendingProvider =
    FutureProvider.autoDispose<Map<int, double>>((ref) {
  ref.watch(transactionListProvider);
  final month = ref.watch(selectedMonthProvider);
  return ref
      .watch(transactionRepositoryProvider)
      .getDailySpending(month.toMonthKey(), TransactionType.expense);
});

final weekdaySpendingProvider =
    FutureProvider.autoDispose<Map<int, double>>((ref) {
  ref.watch(transactionListProvider);
  final month = ref.watch(selectedMonthProvider);
  return ref
      .watch(transactionRepositoryProvider)
      .getWeekdaySpending(month.toMonthKey(), TransactionType.expense);
});

final timeOfDaySpendingProvider =
    FutureProvider.autoDispose<Map<String, double>>((ref) {
  ref.watch(transactionListProvider);
  final month = ref.watch(selectedMonthProvider);
  return ref
      .watch(transactionRepositoryProvider)
      .getTimeOfDaySpending(month.toMonthKey(), TransactionType.expense);
});

final analyticsExpenseCatsProvider =
    StreamProvider.autoDispose<List<CategoryModel>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchAll();
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
    final mode = ref.watch(analyticsModeProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final now = DateTime.now();
    final canGoForward = selectedMonth.year < now.year ||
        (selectedMonth.year == now.year && selectedMonth.month < now.month);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.analytics),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          // ── Premium Mode Selector ──────────────────────────────────
          _AnalyticsSelector(
            currentMode: mode,
            onChanged: (m) => ref.read(analyticsModeProvider.notifier).state = m,
          ),

          // ── Month Selector ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.5), width: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 28),
                  onPressed: _previousMonth,
                  color: cs.onSurface,
                ),
                Text(
                  selectedMonth.toMonthYear(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
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
          ),

          // ── Main Content Area ──────────────────────────────────────
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildModeContent(mode),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeContent(AnalyticsMode mode) {
    switch (mode) {
      case AnalyticsMode.overview:
        return const _OverviewModule(key: ValueKey('overview'));
      case AnalyticsMode.spending:
        return const _SpendingModule(key: ValueKey('spending'));
      case AnalyticsMode.categories:
        return _CategoriesModule(
          key: const ValueKey('categories'),
          touchedExpenseIndex: _touchedExpenseIndex,
          touchedIncomeIndex: _touchedIncomeIndex,
          onTouchedExpense: (idx) => setState(() => _touchedExpenseIndex = idx),
          onTouchedIncome: (idx) => setState(() => _touchedIncomeIndex = idx),
        );
      case AnalyticsMode.trends:
        return const _TrendsModule(key: ValueKey('trends'));
    }
  }
}

class _AnalyticsSelector extends StatelessWidget {
  final AnalyticsMode currentMode;
  final ValueChanged<AnalyticsMode> onChanged;

  const _AnalyticsSelector({
    required this.currentMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _SelectorChip(
            label: l10n.overview,
            icon: Icons.dashboard_outlined,
            selected: currentMode == AnalyticsMode.overview,
            onTap: () => onChanged(AnalyticsMode.overview),
          ),
          const SizedBox(width: 10),
          _SelectorChip(
            label: l10n.spending,
            icon: Icons.bar_chart_rounded,
            selected: currentMode == AnalyticsMode.spending,
            onTap: () => onChanged(AnalyticsMode.spending),
          ),
          const SizedBox(width: 10),
          _SelectorChip(
            label: l10n.categories,
            icon: Icons.category_outlined,
            selected: currentMode == AnalyticsMode.categories,
            onTap: () => onChanged(AnalyticsMode.categories),
          ),
          const SizedBox(width: 10),
          _SelectorChip(
            label: l10n.trends,
            icon: Icons.show_chart_rounded,
            selected: currentMode == AnalyticsMode.trends,
            onTap: () => onChanged(AnalyticsMode.trends),
          ),
        ],
      ),
    );
  }
}

class _SelectorChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SelectorChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant.withOpacity(0.3),
          ),
          boxShadow: selected
              ? [BoxShadow(color: cs.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: selected ? cs.onPrimary : cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? cs.onPrimary : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewModule extends ConsumerWidget {
  const _OverviewModule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(monthlySummaryProvider);
    final settings = ref.watch(settingsProvider);
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        summaryAsync.when(
          data: (summary) {
            final inc = summary['income'] ?? 0;
            final exp = summary['expense'] ?? 0;
            final bal = summary['balance'] ?? 0;
            final savingsRate = inc > 0 ? ((inc - exp) / inc * 100) : 0.0;

            if (inc == 0 && exp == 0) {
              return _EmptyState(message: l10n.noTransactionsMonth);
            }

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: l10n.income,
                        amount: inc,
                        currency: settings.currency,
                        color: AppColors.success500,
                        icon: Icons.south_west_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        title: l10n.expense,
                        amount: exp,
                        currency: settings.currency,
                        color: AppColors.danger500,
                        icon: Icons.north_east_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SavingsRateCard(rate: savingsRate, balance: bal, currency: settings.currency),
                const SizedBox(height: 24),
                _SectionTitle(title: l10n.incomeVsExpense),
                const SizedBox(height: 16),
                _MiniTrendChart(summary: summary, currency: settings.currency),
              ],
            );
          },
          loading: () => const _ChartSkeleton(height: 200),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _CategoriesModule extends ConsumerWidget {
  final int touchedExpenseIndex;
  final int touchedIncomeIndex;
  final ValueChanged<int> onTouchedExpense;
  final ValueChanged<int> onTouchedIncome;

  const _CategoriesModule({
    super.key,
    required this.touchedExpenseIndex,
    required this.touchedIncomeIndex,
    required this.onTouchedExpense,
    required this.onTouchedIncome,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extAsync = ref.watch(expenseSpendingProvider);
    final incAsync = ref.watch(incomeSpendingProvider);
    final allCatsAsync = ref.watch(analyticsExpenseCatsProvider);
    final settings = ref.watch(settingsProvider);
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle(title: l10n.expenseBreakdown),
        const SizedBox(height: 16),
        extAsync.when(
          data: (spendData) => allCatsAsync.when(
            data: (cats) {
              if (spendData.isEmpty) {
                return _EmptyNamedChart(label: l10n.expenses.toLowerCase());
              }
              return _PieChartSection(
                spendingData: spendData,
                categories: cats,
                currency: settings.currency,
                touchedIndex: touchedExpenseIndex,
                onTouched: onTouchedExpense,
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
        _SectionTitle(title: l10n.incomeSources),
        const SizedBox(height: 16),
        incAsync.when(
          data: (spendData) => allCatsAsync.when(
            data: (cats) {
              if (spendData.isEmpty) {
                return _EmptyNamedChart(label: l10n.income.toLowerCase());
              }
              return _PieChartSection(
                spendingData: spendData,
                categories: cats,
                currency: settings.currency,
                touchedIndex: touchedIncomeIndex,
                onTouched: onTouchedIncome,
                themeMode: Theme.of(context).brightness,
              );
            },
            loading: () => const _ChartSkeleton(height: 220),
            error: (_, __) => const SizedBox.shrink(),
          ),
          loading: () => const _ChartSkeleton(height: 280),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _SpendingModule extends ConsumerWidget {
  const _SpendingModule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyAsync = ref.watch(dailySpendingProvider);
    final weekdayAsync = ref.watch(weekdaySpendingProvider);
    final timeOfDayAsync = ref.watch(timeOfDaySpendingProvider);
    final settings = ref.watch(settingsProvider);
    final l10n = AppLocalizations.of(context)!;
    final selectedMonth = ref.watch(selectedMonthProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle(title: l10n.dailySpending),
        const SizedBox(height: 16),
        dailyAsync.when(
          data: (data) => _DailyBarChart(
            data: data,
            currency: settings.currency,
            daysInMonth: DateUtils.getDaysInMonth(selectedMonth.year, selectedMonth.month),
          ),
          loading: () => const _ChartSkeleton(height: 180),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 32),
        _SectionTitle(title: l10n.weekdayDistribution),
        const SizedBox(height: 16),
        weekdayAsync.when(
          data: (data) => _WeekdayBarChart(data: data, currency: settings.currency),
          loading: () => const _ChartSkeleton(height: 180),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 32),
        _SectionTitle(title: l10n.timeOfDay),
        const SizedBox(height: 16),
        timeOfDayAsync.when(
          data: (data) => _TimeOfDayChart(data: data, currency: settings.currency),
          loading: () => const _ChartSkeleton(height: 180),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _TrendsModule extends ConsumerWidget {
  const _TrendsModule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(trendDataProvider);
    final savingsTrendAsync = ref.watch(savingsRateTrendProvider);
    final settings = ref.watch(settingsProvider);
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle(title: l10n.incomeVsExpense),
        const SizedBox(height: 16),
        trendAsync.when(
          data: (data) => _TrendBarChart(data: data, currency: settings.currency),
          loading: () => const _ChartSkeleton(height: 220),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 32),
        _SectionTitle(title: l10n.savingsRate),
        const SizedBox(height: 16),
        savingsTrendAsync.when(
          data: (data) => _SavingsTrendLineChart(data: data),
          loading: () => const _ChartSkeleton(height: 180),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 32),
        // Future: Heatmap placeholder
        _SectionTitle(title: l10n.spendingIntensity),
        const SizedBox(height: 16),
        const _IntensityPlaceholder(),
      ],
    );
  }
}
class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final String currency;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.currency,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 12),
          Text(title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withOpacity(0.6))),
          const SizedBox(height: 4),
          Text(amount.toCurrency(currency),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface)),
        ],
      ),
    );
  }
}

class _SavingsRateCard extends StatelessWidget {
  final double rate;
  final double balance;
  final String currency;

  const _SavingsRateCard({
    required this.rate,
    required this.balance,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isPositive = rate >= 0;
    final color = isPositive ? AppColors.success500 : AppColors.danger500;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primaryContainer.withOpacity(0.5),
            cs.primaryContainer.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.netSavings,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(balance.toCurrency(currency),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(l10n.savingsRate,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${rate.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _MiniTrendChart extends StatelessWidget {
  final Map<String, double> summary;
  final String currency;

  const _MiniTrendChart({required this.summary, required this.currency});

  @override
  Widget build(BuildContext context) {
    final inc = summary['income'] ?? 0;
    final exp = summary['expense'] ?? 0;
    final maxVal = [inc, exp].reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      height: 160,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.center,
          maxY: maxVal == 0 ? 100 : maxVal * 1.2,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, _) {
                  final l10n = AppLocalizations.of(context)!;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      val == 0 ? l10n.income : l10n.expense,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: AppColors.gray500),
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: [
            BarChartGroupData(
              x: 0,
              barRods: [
                BarChartRodData(
                  toY: inc,
                  color: AppColors.success500,
                  width: 40,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxVal * 1.2,
                    color: AppColors.success500.withOpacity(0.05),
                  ),
                ),
              ],
            ),
            BarChartGroupData(
              x: 1,
              barRods: [
                BarChartRodData(
                  toY: exp,
                  color: AppColors.danger500,
                  width: 40,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxVal * 1.2,
                    color: AppColors.danger500.withOpacity(0.05),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyBarChart extends StatelessWidget {
  final Map<int, double> data;
  final String currency;
  final int daysInMonth;

  const _DailyBarChart({
    required this.data,
    required this.currency,
    required this.daysInMonth,
  });

  @override
  Widget build(BuildContext context) {
    double maxVal = 0;
    data.values.forEach((v) => maxVal = v > maxVal ? v : maxVal);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal == 0 ? 100 : maxVal * 1.1,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${group.x}\n${rod.toY.toCurrencyCompact(currency)}',
                  Theme.of(context).textTheme.labelSmall!.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, _) {
                  if (val % 5 != 0 && val != 1 && val != daysInMonth) return const SizedBox.shrink();
                  return Text(
                    val.toInt().toString(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9, color: AppColors.gray500),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(daysInMonth, (index) {
            final day = index + 1;
            final val = data[day] ?? 0;
            return BarChartGroupData(
              x: day,
              barRods: [
                BarChartRodData(
                  toY: val,
                  color: Theme.of(context).colorScheme.primary,
                  width: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _WeekdayBarChart extends StatelessWidget {
  final Map<int, double> data;
  final String currency;

  const _WeekdayBarChart({required this.data, required this.currency});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final weekdays = [l10n.mon, l10n.tue, l10n.wed, l10n.thu, l10n.fri, l10n.sat, l10n.sun];
    double maxVal = 0;
    data.values.forEach((v) => maxVal = v > maxVal ? v : maxVal);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal == 0 ? 100 : maxVal * 1.1,
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, _) {
                  final idx = val.toInt() - 1;
                  if (idx < 0 || idx >= 7) return const SizedBox.shrink();
                  return Text(
                    weekdays[idx],
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.gray500, fontWeight: FontWeight.bold),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(7, (index) {
            final weekday = index + 1;
            final val = data[weekday] ?? 0;
            return BarChartGroupData(
              x: weekday,
              barRods: [
                BarChartRodData(
                  toY: val,
                  color: AppColors.secondary500,
                  width: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _TimeOfDayChart extends StatelessWidget {
  final Map<String, double> data;
  final String currency;

  const _TimeOfDayChart({required this.data, required this.currency});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final times = [l10n.morning, l10n.afternoon, l10n.evening, l10n.night];
    final keys = ['morning', 'afternoon', 'evening', 'night'];
    double maxVal = 0;
    data.values.forEach((v) => maxVal = v > maxVal ? v : maxVal);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal == 0 ? 100 : maxVal * 1.1,
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, _) {
                  final idx = val.toInt();
                  if (idx < 0 || idx >= 4) return const SizedBox.shrink();
                  return Text(
                    times[idx],
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.gray500, fontWeight: FontWeight.bold),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(4, (index) {
            final key = keys[index];
            final val = data[key] ?? 0;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: val,
                  color: const Color(0xFF8B5CF6),
                  width: 32,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            );
          }),
        ),
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
                titleStyle: Theme.of(context).textTheme.labelSmall!.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700),
              );
            }).toList(),
          ),
        ),
      ),
      const SizedBox(height: 16),
      ...entries.asMap().entries.map((e) {
        final color = colors[e.key % colors.length];
        final pct = (e.value.value / total * 100).toStringAsFixed(1);
        final catName = catMap[e.value.key]?.name ?? '${AppLocalizations.of(context)!.appName} #${e.value.key}';
        final catColor = catMap[e.value.key] != null
            ? Color(catMap[e.value.key]!.colorHex.toColorInt())
            : color;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: themeMode == Brightness.dark
                    ? const Color(0xFF2D3748)
                    : AppColors.gray200),
          ),
          child: Row(children: [
            Text(
              catMap[e.value.key] != null
                  ? CategoryUtils.getEmoji(catMap[e.value.key]!.iconName)
                  : '📦',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('$catName — $pct%',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            Text(
              e.value.value.toCurrency(currency),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.gray500, fontWeight: FontWeight.w700),
            ),
          ]),
        );
      }),
    ]);
  }
}

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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2D3748)
                : AppColors.gray200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _LegendDot(color: AppColors.success500, label: AppLocalizations.of(context)!.income),
          const SizedBox(width: 16),
          _LegendDot(color: AppColors.danger500, label: AppLocalizations.of(context)!.expense),
        ]),
        const SizedBox(height: 24),
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
                        ? '${AppLocalizations.of(context)!.income}: ${(d['income'] as double).toCurrencyCompact(currency)}'
                        : '${AppLocalizations.of(context)!.expense}: ${(d['expense'] as double).toCurrencyCompact(currency)}';
                    return BarTooltipItem(
                      label,
                      Theme.of(context).textTheme.labelSmall!.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
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
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.gray500, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: data.asMap().entries.map((e) {
                final d = e.value;
                return BarChartGroupData(
                  x: e.key,
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

class _SavingsTrendLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const _SavingsTrendLineChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant.withOpacity(0.2), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, _) {
                  final idx = val.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                  return Text(
                    data[idx]['label'],
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.gray500, fontWeight: FontWeight.w600),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value['savingsRate'])).toList(),
              isCurved: true,
              color: cs.primary,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [cs.primary.withOpacity(0.2), cs.primary.withOpacity(0.0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntensityPlaceholder extends StatelessWidget {
  const _IntensityPlaceholder();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5), style: BorderStyle.none),
      ),
      child: Column(
        children: [
          Icon(Icons.grid_view_rounded, size: 48, color: cs.primary.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.spendingIntensity,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Coming Soon: Track your financial velocity and intensity across the month.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
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
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.gray500, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _ChartSkeleton extends StatelessWidget {
  final double height;
  const _ChartSkeleton({required this.height});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkCard : AppColors.gray100,
        borderRadius: BorderRadius.circular(20),
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
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(children: [
          Icon(Icons.query_stats_rounded, size: 48, color: AppColors.gray300.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context)!.noDataFor(label), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.gray500, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.analytics_outlined, size: 80, color: cs.primary.withOpacity(0.1)),
            const SizedBox(height: 24),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

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

