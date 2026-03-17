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
import 'package:google_fonts/google_fonts.dart';

// ── Supporting providers ───────────────────────────────────────────────────────

final _expenseCategoriesProvider =
    FutureProvider.autoDispose<List<CategoryModel>>((ref) {
  return ref.watch(categoryRepositoryProvider).getByType(CategoryType.expense);
});

/// Spending map is derived from DB (read-only, no mutation). Auto-dispose is
/// fine here because spending data is never mutated from this page.
final _monthSpendingProvider =
    FutureProvider.autoDispose<Map<int, double>>((ref) async {
  final monthKey = DateTime.now().toMonthKey();
  return ref
      .watch(transactionRepositoryProvider)
      .getCategorySpendingForMonth(monthKey, TransactionType.expense);
});

// ── Page ──────────────────────────────────────────────────────────────────────

class BudgetPage extends ConsumerWidget {
  const BudgetPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final catsAsync = ref.watch(_expenseCategoriesProvider);
    // Watch budgets from the stable StateNotifier — no autoDispose FutureProvider
    final budgetState = ref.watch(budgetNotifierProvider);
    final spendAsync = ref.watch(_monthSpendingProvider);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: Text('Budget — ${now.toMonthYear()}')),
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
                      // Pass the ref so the card can open the safe sheet
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

  // ── Budget sheet — safe save pattern ────────────────────────────────────────
  //
  // KEY FIX: All provider mutations happen BEFORE Navigator.pop().
  // The sheet uses its own WidgetRef from Consumer so it is independent of
  // the page's ref lifecycle. No ref.invalidate() is called anywhere.

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
      // Use Consumer so the sheet has its own WidgetRef, isolated from
      // the page ref that may be in a different lifecycle state.
      builder: (sheetCtx) => _BudgetSheet(
        cat: cat,
        existing: existing,
        currency: currency,
      ),
    );
  }
}

// ── Budget sheet widget — owns its lifecycle ──────────────────────────────────

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
        categoryId: widget.cat.id,
        amount: amount,
        monthKey: DateTime.now().toMonthKey(),
      );

      // STEP 1: Update notifier state (in-memory + DB write) — no invalidation.
      // This happens BEFORE Navigator.pop() to avoid the _dependents.isEmpty
      // assertion that fires when route removal races with provider disposal.
      await ref.read(budgetNotifierProvider.notifier).setBudget(budget);

      // STEP 2: Only now is it safe to close the sheet.
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
      // STEP 1: Remove from notifier (in-memory + DB) BEFORE pop.
      await ref
          .read(budgetNotifierProvider.notifier)
          .deleteBudget(widget.existing!.id);

      // STEP 2: Safe to close.
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
    final cs = Theme.of(context).colorScheme;

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
          // Header
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(widget.cat.name[0].toUpperCase(),
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, color: catColor)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Budget for ${widget.cat.name}',
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: cs.onSurface)),
            ),
          ]),
          const SizedBox(height: 20),

          // Amount input
          TextField(
            controller: _controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            enabled: !_isSaving,
            decoration: InputDecoration(
              hintText: '0.00',
              prefixText: '${widget.currency} ',
              labelText: 'Monthly limit',
            ),
          ),

          const SizedBox(height: 16),

          // Delete button (only when editing)
          if (widget.existing != null)
            TextButton.icon(
              onPressed: _isSaving ? null : _delete,
              icon: const Icon(Icons.delete_outline,
                  color: Color(0xFFEF4444), size: 18),
              label: Text('Remove budget',
                  style: GoogleFonts.inter(
                      color: const Color(0xFFEF4444))),
            ),

          const SizedBox(height: 8),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.existing == null ? 'Set Budget' : 'Update Budget'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Summary Card ──────────────────────────────────────────────────────────────

class _BudgetSummaryCard extends StatelessWidget {
  final double totalBudgeted, totalSpent;
  final String currency;
  const _BudgetSummaryCard(
      {required this.totalBudgeted,
      required this.totalSpent,
      required this.currency});

  @override
  Widget build(BuildContext context) {
    if (totalBudgeted == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppColors.primary600, AppColors.primary500]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tap any category below to set a monthly budget limit.',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
            ),
          ),
        ]),
      );
    }

    final remaining = totalBudgeted - totalSpent;
    final pct = (totalSpent / totalBudgeted).clamp(0.0, 1.0);
    final isOver = totalSpent > totalBudgeted;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOver
              ? [AppColors.danger600, AppColors.danger500]
              : [AppColors.primary600, AppColors.primary500],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Monthly Budget Overview',
            style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.8), fontSize: 13)),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(totalSpent.toCurrency(currency),
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700)),
          Text('of ${totalBudgeted.toCurrency(currency)}',
              style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.7), fontSize: 13)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (_, val, __) => LinearProgressIndicator(
              value: val,
              backgroundColor: Colors.white.withOpacity(0.25),
              color: isOver ? Colors.orange : Colors.white,
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isOver
              ? '🚨 Over budget by ${(totalSpent - totalBudgeted).toCurrency(currency)}'
              : '✅ ${remaining.toCurrency(currency)} remaining',
          style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600),
        ),
      ]),
    );
  }
}

// ── Category Budget Card ──────────────────────────────────────────────────────

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
    final catColor = Color(category.colorHex.toColorInt());
    final budgetAmt = budget?.amount ?? 0;
    final pct = budgetAmt > 0 ? (spent / budgetAmt).clamp(0.0, 1.0) : 0.0;
    final isOver = pct >= 1.0;
    final isWarning = pct > 0.75;
    final progressColor = isOver
        ? AppColors.danger500
        : isWarning
            ? AppColors.warning500
            : AppColors.success500;

    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isOver
                ? const Color(0xFFEF4444).withOpacity(0.4)
                : cs.outlineVariant.withOpacity(0.5)),
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
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, color: catColor),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(category.name,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontSize: 15)),
          ),
          if (isOver)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(8)),
              child: Text('Over',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      color: cs.onErrorContainer,
                      fontWeight: FontWeight.w700)),
            ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: onSet,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            child: Text(budget == null ? 'Set' : 'Edit',
                style: GoogleFonts.inter(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        ]),
        if (budget != null) ...[
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${spent.toCurrency(currency)} spent',
                style: GoogleFonts.inter(
                    fontSize: 12, color: cs.onSurface.withOpacity(0.5))),
            Text('of ${budgetAmt.toCurrency(currency)}',
                style: GoogleFonts.inter(
                    fontSize: 12, color: cs.onSurface.withOpacity(0.5))),
          ]),
          const SizedBox(height: 6),
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
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                  '🚨 Over by ${(spent - budgetAmt).toCurrency(currency)}',
                  style: GoogleFonts.inter(
                      color: AppColors.danger500,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            )
          else if (isWarning)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                  '⚠️ ${((1 - pct) * 100).toStringAsFixed(0)}% remaining',
                  style: GoogleFonts.inter(
                      color: AppColors.warning600,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
        ] else ...[
          const SizedBox(height: 8),
          Text('No budget set — tap "Set" to add a limit',
              style: GoogleFonts.inter(
                  fontSize: 12, color: cs.onSurface.withOpacity(0.35))),
        ],
      ]),
    );
  }
}
