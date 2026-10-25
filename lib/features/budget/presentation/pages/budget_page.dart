import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';
import 'package:trust_tracker_flutter/core/utils/extensions.dart';
import 'package:trust_tracker_flutter/features/budget/data/models/budget_model.dart';
import 'package:trust_tracker_flutter/features/budget/presentation/providers/budget_provider.dart';
import 'package:trust_tracker_flutter/features/categories/data/models/category_model.dart';
import 'package:trust_tracker_flutter/features/categories/data/repositories/category_repository.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/transactions/data/repositories/transaction_repository.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:trust_tracker_flutter/generated/app_localizations.dart';
import 'package:trust_tracker_flutter/core/utils/financial_utils.dart';
import 'package:intl/intl.dart' as intl;

final _expenseCategoriesProvider =
    FutureProvider.autoDispose<List<CategoryModel>>((ref) {
  return ref.watch(categoryRepositoryProvider).getByType(CategoryType.expense);
});

final _monthSpendingProvider =
    FutureProvider.autoDispose<Map<int, double>>((ref) async {
  ref.watch(transactionChangeProvider);
  final settings = ref.watch(settingsProvider);
  final range = FinancialUtils.getCurrentCycleRange(settings.monthStartDay);
  return ref
      .watch(transactionRepositoryProvider)
      .getCategorySpendingInRange(range.start, range.end, TransactionType.expense);
});

class BudgetPage extends ConsumerWidget {
  const BudgetPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final catsAsync = ref.watch(_expenseCategoriesProvider);
    final budgetState = ref.watch(budgetNotifierProvider);
    final spendAsync = ref.watch(_monthSpendingProvider);
    final now = DateTime.now();
    final tt = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    final cycleRange = FinancialUtils.getCurrentCycleRange(settings.monthStartDay);
    final rangeText = '${intl.DateFormat('MMM d').format(cycleRange.start)} – ${intl.DateFormat('MMM d').format(cycleRange.end)}';

    return Scaffold(
      appBar: AppBar(title: Text('${l10n.budgetLabel} ($rangeText)', style: tt.headlineSmall)),
      body: catsAsync.when(
        data: (cats) => budgetState.budgets.when(
          data: (budgets) {
            final budgetMap = <int, BudgetModel>{};
            for (final b in budgets) budgetMap[b.categoryId] = b;

            return spendAsync.when(
              data: (spendMap) {
                double totalBudgeted = 0;
                double totalSpent = 0;
                for (final b in budgets) {
                  totalBudgeted += b.amount;
                  totalSpent += spendMap[b.categoryId] ?? 0;
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: cats.length + 1,
                  separatorBuilder: (_, i) => i == 0
                      ? const SizedBox(height: 16)
                      : const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return _BudgetSummaryCard(
                        totalBudgeted: totalBudgeted,
                        totalSpent: totalSpent,
                        currency: settings.currency,
                      );
                    }
                    final cat = cats[i - 1];
                    final budget = budgetMap[cat.id];
                    final spent = spendMap[cat.id] ?? 0.0;
                    return _BudgetCategoryCard(
                      category: cat,
                      budget: budget,
                      spent: spent,
                      currency: settings.currency,
                      onSet: () => _openBudgetSheet(
                          context, ref, cat, budget, settings.currency),
                    ).animate().fadeIn(delay: Duration(milliseconds: i * 50));
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  static Future<void> _openBudgetSheet(
    BuildContext pageContext,
    WidgetRef pageRef,
    CategoryModel cat,
    BudgetModel? existing,
    String currency,
  ) async {
    await showModalBottomSheet<void>(
      context: pageContext,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => _BudgetSheet(
        cat: cat,
        existing: existing,
        currency: currency,
      ),
    );
  }
}

class _BudgetSheet extends ConsumerStatefulWidget {
  final CategoryModel cat;
  final BudgetModel? existing;
  final String currency;

  const _BudgetSheet({
    required this.cat,
    required this.existing,
    required this.currency,
  });

  @override
  ConsumerState<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<_BudgetSheet> {
  late final TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
        text: widget.existing?.amount.toStringAsFixed(0) ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_controller.text.trim()) ?? 0;
    if (amount <= 0) return;

    setState(() => _isSaving = true);
    try {
      final budget = BudgetModel.create(
        categoryId: widget.cat.id!,
        amount: amount,
        monthKey: DateTime.now().toMonthKey(),
      );
      await ref.read(budgetNotifierProvider.notifier).setBudget(budget);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save budget: $e')),
        );
      }
    }
  }

  Future<void> _delete() async {
    if (widget.existing == null) return;
    setState(() => _isSaving = true);
    try {
      await ref
          .read(budgetNotifierProvider.notifier)
          .deleteBudget(widget.existing!.id!);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove budget: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catColor = Color(widget.cat.colorHex.toColorInt());
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(widget.cat.name[0].toUpperCase(),
                    style: tt.headlineSmall?.copyWith(color: catColor)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(l10n.budgetFor(widget.cat.name),
                  style: tt.headlineSmall),
            ),
          ]),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            enabled: !_isSaving,
            decoration: InputDecoration(
              hintText: '0.00',
              prefixText: '${widget.currency} ',
              labelText: AppLocalizations.of(context)!.monthlyLimit,
            ),
          ),
          const SizedBox(height: 24),
          if (widget.existing != null)
            TextButton.icon(
              onPressed: _isSaving ? null : _delete,
              icon: Icon(Icons.delete_outline, color: cs.error, size: 18),
              label: Text(AppLocalizations.of(context)!.removeBudget,
                  style: tt.labelLarge?.copyWith(color: cs.error)),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.existing == null ? l10n.setBudget : l10n.updateBudget),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetSummaryCard extends StatelessWidget {
  final double totalBudgeted, totalSpent;
  final String currency;
  const _BudgetSummaryCard(
      {required this.totalBudgeted,
      required this.totalSpent,
      required this.currency});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    if (totalBudgeted == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [cs.primary, cs.primary.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          Icon(Icons.info_outline, color: cs.onPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.tapToSetBudget,
              style: tt.bodyMedium?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      );
    }

    final remaining = totalBudgeted - totalSpent;
    final pct = (totalSpent / totalBudgeted).clamp(0.0, 1.0);
    final isOver = totalSpent > totalBudgeted;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOver
              ? [cs.error, cs.error.withOpacity(0.8)]
              : [cs.primary, cs.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isOver ? cs.error : cs.primary).withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(AppLocalizations.of(context)!.monthlyBudgetOverview,
            style: tt.sectionLabel.copyWith(color: (isOver ? cs.onError : cs.onPrimary).withOpacity(0.7))),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(totalSpent.toCurrency(currency),
              style: tt.displaySmall?.copyWith(color: isOver ? cs.onError : cs.onPrimary, fontWeight: FontWeight.w800)),
          Text(AppLocalizations.of(context)!.ofAmount(totalBudgeted.toCurrency(currency)),
              style: tt.labelLarge?.copyWith(color: (isOver ? cs.onError : cs.onPrimary).withOpacity(0.7))),
        ]),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (_, val, __) => LinearProgressIndicator(
              value: val,
              backgroundColor: (isOver ? cs.onError : cs.onPrimary).withOpacity(0.2),
              color: isOver ? AppColors.warning : cs.onPrimary,
              minHeight: 10,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          isOver
              ? l10n.overBudgetBy((totalSpent - totalBudgeted).toCurrency(currency))
              : l10n.remainingAmount(remaining.toCurrency(currency)),
          style: tt.bodyMedium?.copyWith(color: isOver ? cs.onError : cs.onPrimary, fontWeight: FontWeight.w700),
        ),
      ]),
    );
  }
}

class _BudgetCategoryCard extends StatelessWidget {
  final CategoryModel category;
  final BudgetModel? budget;
  final double spent;
  final String currency;
  final VoidCallback onSet;

  const _BudgetCategoryCard({
    required this.category,
    this.budget,
    required this.spent,
    required this.currency,
    required this.onSet,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final catColor = Color(category.colorHex.toColorInt());
    final budgetAmt = budget?.amount ?? 0;
    final pct = budgetAmt > 0 ? (spent / budgetAmt).clamp(0.0, 1.0) : 0.0;
    final isOver = pct >= 1.0;
    final isWarning = pct > 0.75;
    final progressColor = isOver
        ? cs.error
        : isWarning
            ? AppColors.warning
            : AppColors.success;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isOver ? cs.error.withOpacity(0.3) : cs.outline.withOpacity(0.1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: catColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                category.name[0].toUpperCase(),
                style: tt.titleLarge?.copyWith(color: catColor),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(category.name,
                style: tt.titleSmall),
          ),
          if (isOver)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(8)),
              child: Text(AppLocalizations.of(context)!.over,
                  style: tt.labelSmall?.copyWith(fontSize: 9, color: cs.onErrorContainer, fontWeight: FontWeight.bold)),
            ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: onSet,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text(budget == null ? AppLocalizations.of(context)!.setBudget.split(' ')[0].toUpperCase() : AppLocalizations.of(context)!.updateBudget.split(' ')[0].toUpperCase(),
                style: tt.labelLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.w800)),
          ),
        ]),
        if (budget != null) ...[
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(AppLocalizations.of(context)!.spentAmount(spent.toCurrency(currency)),
                style: tt.labelSmall),
            Text(AppLocalizations.of(context)!.ofAmount(budgetAmt.toCurrency(currency)),
                style: tt.labelSmall),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOut,
              builder: (_, val, __) => LinearProgressIndicator(
                value: val,
                backgroundColor: cs.surfaceContainerHighest,
                color: progressColor,
                minHeight: 8,
              ),
            ),
          ),
          if (isOver)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                  l10n.overBudgetBy((spent - budgetAmt).toCurrency(currency)),
                  style: tt.labelSmall?.copyWith(color: cs.error, fontWeight: FontWeight.w700)),
            )
          else if (isWarning)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                  l10n.remainingAmount((budgetAmt - spent).toCurrency(currency)),
                  style: tt.labelSmall?.copyWith(color: AppColors.warning, fontWeight: FontWeight.w700)),
            ),
        ] else ...[
          const SizedBox(height: 8),
          Text(AppLocalizations.of(context)!.noBudgetSet,
              style: tt.labelSmall?.copyWith(fontStyle: FontStyle.italic)),
        ],
      ]),
    );
  }
}
