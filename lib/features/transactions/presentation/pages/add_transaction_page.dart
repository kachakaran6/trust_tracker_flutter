import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';
import 'package:trust_tracker_flutter/core/utils/extensions.dart';
import 'package:trust_tracker_flutter/features/categories/data/models/category_model.dart';
import 'package:trust_tracker_flutter/features/categories/data/repositories/category_repository.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:google_fonts/google_fonts.dart';

final _categoriesByTypeProvider =
    FutureProvider.family<List<CategoryModel>, CategoryType>((ref, type) {
  return ref.watch(categoryRepositoryProvider).getByType(type);
});

class AddTransactionPage extends ConsumerStatefulWidget {
  final String? initialType;
  final TransactionModel? editTransaction; // null = create mode

  const AddTransactionPage({
    super.key,
    this.initialType,
    this.editTransaction,
  });

  @override
  ConsumerState<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends ConsumerState<AddTransactionPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  final _noteController = TextEditingController();

  late DateTime _selectedDate;
  TimeOfDay _selectedTime = TimeOfDay.now();
  CategoryModel? _selectedCategory;
  bool _isLoading = false;

  bool get _isEditMode => widget.editTransaction != null;

  @override
  void initState() {
    super.initState();
    final edit = widget.editTransaction;
    final isExpense = edit != null
        ? edit.type == TransactionType.expense
        : widget.initialType != 'income';

    _tabController =
        TabController(length: 2, vsync: this, initialIndex: isExpense ? 1 : 0);
    _tabController.addListener(() => setState(() => _selectedCategory = null));

    // Pre-fill if editing
    if (edit != null) {
      _amountController.text = edit.amount.toStringAsFixed(
          edit.amount == edit.amount.roundToDouble() ? 0 : 2);
      _descController.text = edit.description;
      _noteController.text = edit.note ?? '';
      _selectedDate = edit.date;
      _selectedTime = TimeOfDay.fromDateTime(edit.createdAt);
    } else {
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _descController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  TransactionType get _currentType =>
      _tabController.index == 0
          ? TransactionType.income
          : TransactionType.expense;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  /// Combine date + time into a single DateTime
  DateTime get _fullDateTime => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null && !_isEditMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final notifier = ref.read(transactionListProvider.notifier);
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    try {
      if (_isEditMode) {
        // Mutate existing model
        final edit = widget.editTransaction!;
        edit.amount = amount;
        edit.description = _descController.text.trim();
        edit.date = _fullDateTime;
        edit.type = _currentType;
        if (_selectedCategory != null) edit.categoryId = _selectedCategory!.id;
        edit.note = _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim();
        edit.monthKey =
            '${_fullDateTime.year}-${_fullDateTime.month.toString().padLeft(2, '0')}';
        await notifier.updateTransaction(edit);
      } else {
        final t = TransactionModel.create(
          amount: amount,
          description: _descController.text.trim(),
          date: _fullDateTime,
          type: _currentType,
          categoryId: _selectedCategory?.id,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
        // Optimistic add — returns instantly while DB write is in background
        await notifier.addTransaction(t);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final cs = Theme.of(context).colorScheme;
    final isExpense = _currentType == TransactionType.expense;
    final accentColor =
        isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Transaction' : 'Add Transaction'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: Text('Save',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, color: cs.primary)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Income / Expense Tab
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: cs.onSurface.withOpacity(0.55),
                labelStyle:
                    GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: '  💰  Income  '),
                  Tab(text: '  💸  Expense  '),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Amount
            Text('Amount', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface),
              decoration: InputDecoration(
                hintText: '0.00',
                prefixText: '${settings.currency} ',
                prefixStyle: GoogleFonts.inter(
                    fontSize: 18,
                    color: cs.onSurface.withOpacity(0.4),
                    fontWeight: FontWeight.w500),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter an amount';
                if (double.tryParse(v) == null || double.parse(v) <= 0) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Description
            Text('Description', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(hintText: 'What was this for?'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter a description' : null,
            ),
            const SizedBox(height: 20),

            // Date & Time row
            Text('Date & Time', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: _DateTimeBox(
                      icon: Icons.calendar_today_outlined,
                      label: _selectedDate.toDisplayShort(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _pickTime,
                    child: _DateTimeBox(
                      icon: Icons.access_time_outlined,
                      label: _selectedTime.format(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Category
            Text('Category', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            _currentType == TransactionType.income
                ? _CategoryPicker(
                    type: CategoryType.income,
                    selected: _selectedCategory,
                    preselectedId:
                        _isEditMode ? widget.editTransaction!.categoryId : null,
                    onSelect: (c) => setState(() => _selectedCategory = c))
                : _CategoryPicker(
                    type: CategoryType.expense,
                    selected: _selectedCategory,
                    preselectedId:
                        _isEditMode ? widget.editTransaction!.categoryId : null,
                    onSelect: (c) => setState(() => _selectedCategory = c)),
            const SizedBox(height: 20),

            // Note (optional)
            Text('Note (optional)',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteController,
              maxLines: 2,
              decoration:
                  const InputDecoration(hintText: 'Add any extra notes...'),
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _isEditMode ? 'Update Transaction' : 'Save Transaction',
                        style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),

            // Extra spacing for safe area
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Helper widgets ───────────────────────────────────────────────────────────

class _DateTimeBox extends StatelessWidget {
  final IconData icon;
  final String label;
  const _DateTimeBox({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outline.withOpacity(0.3),
        ),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: cs.onSurface.withOpacity(0.5)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(label,
              style: Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}

class _CategoryPicker extends ConsumerStatefulWidget {
  final CategoryType type;
  final CategoryModel? selected;
  final int? preselectedId;
  final void Function(CategoryModel) onSelect;

  const _CategoryPicker({
    required this.type,
    required this.selected,
    required this.onSelect,
    this.preselectedId,
  });

  @override
  ConsumerState<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends ConsumerState<_CategoryPicker> {
  CategoryModel? _autoSelected;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(_categoriesByTypeProvider(widget.type));

    return categoriesAsync.when(
      data: (cats) {
        // Auto-select preselected category if editing
        if (_autoSelected == null && widget.preselectedId != null) {
          try {
            _autoSelected =
                cats.firstWhere((c) => c.id == widget.preselectedId);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onSelect(_autoSelected!);
            });
          } catch (_) {}
        }

        final effective = widget.selected ?? _autoSelected;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: cats.map((cat) {
            final color = Color(cat.colorHex.toColorInt());
            final isSelected = effective?.id == cat.id;
            return GestureDetector(
              onTap: () => widget.onSelect(cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? color : color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected ? color : color.withOpacity(0.3),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Text(cat.name,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? Colors.white : color)),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const Text('Failed to load categories'),
    );
  }
}
