import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';
import 'package:trust_tracker_flutter/core/constants/app_constants.dart';
import 'package:trust_tracker_flutter/core/utils/extensions.dart';
import 'package:trust_tracker_flutter/core/utils/category_utils.dart';
import 'package:trust_tracker_flutter/features/categories/data/models/category_model.dart';
import 'package:trust_tracker_flutter/features/categories/data/repositories/category_repository.dart';
// FIX Issue 9: Import analytics providers so we can invalidate them
import 'package:trust_tracker_flutter/features/analytics/presentation/pages/analytics_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trust_tracker_flutter/generated/app_localizations.dart';

// FIX Issue 9: Use autoDispose so the provider refreshes each time this
// screen is opened (no stale cache).
final _allCategoriesListProvider = FutureProvider.autoDispose<List<CategoryModel>>((ref) {
  return ref.watch(categoryRepositoryProvider).getAll();
});

class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> {
  /// Invalidates all providers that depend on categories so real-time
  /// updates propagate immediately — no app restart needed.
  void _invalidateAll() {
    ref.invalidate(_allCategoriesListProvider);
    // Keep analytics category labels/colors and monthly pie data in sync.
    ref.invalidate(expenseSpendingProvider);
    ref.invalidate(incomeSpendingProvider);
    ref.invalidate(trendDataProvider);
    ref.invalidate(analyticsExpenseCatsProvider);
  }

  Future<void> _showCategoryDialog({CategoryModel? editing}) async {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    String selectedColor = editing?.colorHex ?? '#3B82F6';
    String selectedIcon = editing?.iconName ?? '📦';
    CategoryType selectedType = editing?.type ?? CategoryType.expense;
    final l10n = AppLocalizations.of(context)!;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 32),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(editing == null ? l10n.newCategory : l10n.editCategory,
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(hintText: l10n.categoryName),
            ),
            const SizedBox(height: 16),
            Text(l10n.type, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(children: CategoryType.values.map((t) {
              final isSelected = selectedType == t;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setModalState(() => selectedType = t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (t == CategoryType.income ? AppColors.success500 : AppColors.danger500)
                            : AppColors.gray100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        t == CategoryType.income ? '💰 ${l10n.income}' : '💸 ${l10n.expense}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.gray600),
                      ),
                    ),
                  ),
                ),
              );
            }).toList()),
            const SizedBox(height: 16),
            Text(l10n.icon, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: AppConstants.categoryIcons.map((emoji) {
                  final isSelected = selectedIcon == emoji;
                  return GestureDetector(
                    onTap: () => setModalState(() => selectedIcon = emoji),
                    child: Container(
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary500 : AppColors.gray100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(emoji, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.color, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: AppConstants.categoryColors.map((hex) {
                final color = Color(hex.toColorInt());
                final isSelected = selectedColor == hex;
                return GestureDetector(
                  onTap: () => setModalState(() => selectedColor = hex),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3),
                      boxShadow: isSelected
                          ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final repo = ref.read(categoryRepositoryProvider);
                  if (editing != null) {
                    editing.name = name;
                    editing.colorHex = selectedColor;
                    editing.iconName = selectedIcon;
                    editing.type = selectedType;
                    await repo.update(editing);
                  } else {
                    await repo.add(CategoryModel.create(
                        name: name,
                        colorHex: selectedColor,
                        iconName: selectedIcon,
                        type: selectedType));
                  }
                  // FIX: Invalidate and pop modal context
                  _invalidateAll();
                  if (mounted) Navigator.of(ctx).pop();
                },
                child: Text(editing == null ? l10n.createCategory : l10n.update),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(_allCategoriesListProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.categories),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCategoryDialog,
          ),
        ],
      ),
      body: catsAsync.when(
        data: (cats) {
          if (cats.isEmpty) {
            return Center(child: Text(AppLocalizations.of(context)!.noCategoriesYet));
          }
          final income = cats.where((c) => c.type == CategoryType.income).toList();
          final expense = cats.where((c) => c.type == CategoryType.expense).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (income.isNotEmpty) ...[
                _SectionHeader(label: '${l10n.income} (${income.length})'),
                ...income.map((c) => _CategoryTile(
                    cat: c,
                    onEdit: () => _showCategoryDialog(editing: c),
                    onDelete: () async {
                      if (c.isDefault) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context)!.cantDeleteDefault)));
                        return;
                      }
                      await ref.read(categoryRepositoryProvider).delete(c.id);
                      _invalidateAll();
                    })),
              ],
              if (expense.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionHeader(label: '${l10n.expense} (${expense.length})'),
                ...expense.map((c) => _CategoryTile(
                    cat: c,
                    onEdit: () => _showCategoryDialog(editing: c),
                    onDelete: () async {
                      if (c.isDefault) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context)!.cantDeleteDefault)));
                        return;
                      }
                      await ref.read(categoryRepositoryProvider).delete(c.id);
                      _invalidateAll();
                    })),
              ],
              const SizedBox(height: 80),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label.toUpperCase(),
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.gray500,
              letterSpacing: 0.8)),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final CategoryModel cat;
  final VoidCallback onEdit, onDelete;
  const _CategoryTile({required this.cat, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = Color(cat.colorHex.toColorInt());
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration:
              BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
          child: Center(
            child: Text(CategoryUtils.getEmoji(cat.iconName),
                style: const TextStyle(fontSize: 20)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(cat.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 14)),
        ),
        if (cat.isDefault)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: AppColors.gray100, borderRadius: BorderRadius.circular(8)),
            child: Text(AppLocalizations.of(context)!.defaultLabel,
                style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray500)),
          ),
        IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: onEdit),
        IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger500),
            onPressed: onDelete),
      ]),
    );
  }
}
