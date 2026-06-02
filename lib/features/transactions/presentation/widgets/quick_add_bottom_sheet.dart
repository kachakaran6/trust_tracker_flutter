import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:trust_tracker_flutter/features/categories/data/repositories/category_repository.dart';
import 'package:trust_tracker_flutter/features/categories/data/models/category_model.dart';
import 'package:trust_tracker_flutter/generated/app_localizations.dart';

class QuickAddBottomSheet extends ConsumerStatefulWidget {
  final TransactionType type;

  const QuickAddBottomSheet({super.key, required this.type});

  static Future<void> show(BuildContext context, TransactionType type) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickAddBottomSheet(type: type),
    );
  }

  @override
  ConsumerState<QuickAddBottomSheet> createState() => _QuickAddBottomSheetState();
}

class _QuickAddBottomSheetState extends ConsumerState<QuickAddBottomSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  int? _selectedCategoryId;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) return;
    
    final amount = double.tryParse(amountText.replaceAll(',', ''));
    if (amount == null || amount <= 0) return;

    setState(() => _isSaving = true);

    final l10n = AppLocalizations.of(context)!;
    
    String defaultDesc = widget.type == TransactionType.expense ? l10n.expense : l10n.income;
    if (widget.type == TransactionType.expense && _selectedCategoryId != null) {
        defaultDesc = l10n.expense;
    }

    final transaction = TransactionModel.create(
      amount: amount,
      description: _noteController.text.trim().isEmpty ? defaultDesc : _noteController.text.trim(),
      date: DateTime.now(),
      type: widget.type,
      categoryId: _selectedCategoryId,
      note: _noteController.text.trim(),
    );

    try {
      await ref.read(transactionListProvider.notifier).addTransaction(transaction);
      HapticFeedback.heavyImpact();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('✓ ${widget.type == TransactionType.expense ? "Expense" : "Income"} Saved: ₹${amount.toStringAsFixed(0)}'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final catRepo = ref.watch(categoryRepositoryProvider);
    final catType = widget.type == TransactionType.expense ? CategoryType.expense : CategoryType.income;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.bottomSheetTheme.backgroundColor ?? cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.type == TransactionType.expense ? 'Quick Add Expense' : 'Quick Add Income',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'Record an ${widget.type == TransactionType.expense ? "expense" : "income"} instantly',
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurface.withOpacity(0.6)),
            ),
            const SizedBox(height: 24),
            
            // Amount
            TextField(
              controller: _amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: cs.primary,
                ),
                border: InputBorder.none,
                hintText: '0',
                hintStyle: theme.textTheme.displayMedium?.copyWith(
                  color: cs.onSurface.withOpacity(0.2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Categories
            StreamBuilder<List<CategoryModel>>(
              stream: catRepo.watchByType(catType),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SizedBox.shrink();
                }
                final categories = snapshot.data!;
                // Auto-select first if none selected
                if (_selectedCategoryId == null && categories.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _selectedCategoryId = categories.first.id);
                  });
                }
                return SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final isSelected = _selectedCategoryId == cat.id;
                      return ChoiceChip(
                        label: Text(cat.name),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedCategoryId = cat.id);
                            HapticFeedback.selectionClick();
                          }
                        },
                        selectedColor: cs.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? cs.onPrimary : cs.onSurface,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Note
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: 'Optional Note',
                filled: true,
                fillColor: cs.onSurface.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
