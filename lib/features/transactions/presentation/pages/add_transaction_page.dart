import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trust_tracker_flutter/core/utils/extensions.dart';
import 'package:trust_tracker_flutter/features/categories/data/models/category_model.dart';
import 'package:trust_tracker_flutter/features/categories/data/repositories/category_repository.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/widgets/category_dropdown_field.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// FIX Issue 9: Use autoDispose (no family caching) so categories always reload
// Also watch transactionListProvider indirectly via invalidation when needed.
// Using StreamProvider or autoDispose FutureProvider ensures fresh data each open.
final _categoriesByTypeProvider = FutureProvider.autoDispose
    .family<List<CategoryModel>, CategoryType>((ref, type) {
  // No caching — always fetches fresh list from DB each time the form opens.
  return ref.watch(categoryRepositoryProvider).getByType(type);
});

class AddTransactionPage extends ConsumerStatefulWidget {
  final String? initialType;
  final TransactionModel? editTransaction; // null = create mode
  final TransactionModel? duplicateTransaction;

  const AddTransactionPage({
    super.key,
    this.initialType,
    this.editTransaction,
    this.duplicateTransaction,
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
  bool get _isDuplicateMode => widget.duplicateTransaction != null;

  @override
  void initState() {
    super.initState();
    final edit = widget.editTransaction;
    final dup = widget.duplicateTransaction;
    final source = edit ?? dup;

    final isExpense = source != null
        ? source.type == TransactionType.expense
        : widget.initialType != 'income';

    _tabController =
        TabController(length: 2, vsync: this, initialIndex: isExpense ? 1 : 0);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        return;
      }

      final nextCategoryType = _currentCategoryType;
      if (_selectedCategory?.type != nextCategoryType) {
        setState(() => _selectedCategory = null);
      }
    });

    // Pre-fill if editing OR duplicating
    if (source != null) {
      _amountController.text = source.amount.toStringAsFixed(
          source.amount == source.amount.roundToDouble() ? 0 : 2);
      _descController.text = source.description;
      _noteController.text = source.note ?? '';

      if (edit != null) {
        _selectedDate = edit.date;
        _selectedTime = TimeOfDay.fromDateTime(edit.createdAt);
      } else {
        // For duplicates, use current date/time
        _selectedDate = DateTime.now();
        _selectedTime = TimeOfDay.now();
      }
    } else {
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
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

  TransactionType get _currentType => _tabController.index == 0
      ? TransactionType.income
      : TransactionType.expense;

  CategoryType get _currentCategoryType =>
      _currentType == TransactionType.income
          ? CategoryType.income
          : CategoryType.expense;

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

  void _handleCategorySelected(CategoryModel category) {
    final targetIndex = category.type == CategoryType.income ? 0 : 1;
    if (_tabController.index != targetIndex) {
      _tabController.animateTo(targetIndex);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() => _selectedCategory = category);
      });
      return;
    }

    setState(() => _selectedCategory = category);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null && !_isEditMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a category'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
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

    if (mounted) {
      if (_isDuplicateMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Transaction duplicated successfully'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF10B981),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isExpense = _currentType == TransactionType.expense;
    final accentColor =
        isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    final accentLight =
        isExpense ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: _buildCloseButton(context, cs),
        title: Text(
          _isEditMode
              ? 'Edit Transaction'
              : _isDuplicateMode
                  ? 'Duplicate Transaction'
                  : 'New Transaction',
          style: GoogleFonts.inter(
              fontSize: 17, fontWeight: FontWeight.w600, color: cs.onSurface),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isLoading ? null : _save,
              style: TextButton.styleFrom(
                backgroundColor: accentColor.withOpacity(0.1),
                foregroundColor: accentColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              child: Text(_isDuplicateMode ? 'Copy' : 'Save',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: accentColor)),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            // ── Type Toggle (Income / Expense) ───────────────────────
            _buildTypeToggle(cs, accentColor, isDark),
            const SizedBox(height: 28),

            // ── Amount Hero Field ────────────────────────────────────
            _buildAmountCard(settings, cs, accentColor, accentLight, isDark),
            const SizedBox(height: 20),

            // ── Description ──────────────────────────────────────────
            _buildSectionLabel('Description', cs),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descController,
              decoration: InputDecoration(
                hintText: 'What was this for?',
                prefixIcon: Icon(Icons.edit_note_rounded,
                    color: cs.onSurface.withOpacity(0.4), size: 20),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter a description' : null,
            ),
            const SizedBox(height: 20),

            // ── Date & Time ──────────────────────────────────────────
            _buildSectionLabel('Date & Time', cs),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildDateTimePill(
                    icon: Icons.calendar_today_outlined,
                    label: DateFormat('MMM dd, yyyy').format(_selectedDate),
                    onTap: _pickDate,
                    cs: cs,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _buildDateTimePill(
                    icon: Icons.access_time_rounded,
                    label: _selectedTime.format(context),
                    onTap: _pickTime,
                    cs: cs,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Category ─────────────────────────────────────────────
            _buildSectionLabel('Category', cs),
            const SizedBox(height: 10),
            TransactionCategoryDropdown(
              type: _currentCategoryType,
              selected: _selectedCategory,
              preselectedId: _isEditMode
                  ? widget.editTransaction!.categoryId
                  : _isDuplicateMode
                      ? widget.duplicateTransaction!.categoryId
                      : null,
              onSelect: _handleCategorySelected,
            ),
            const SizedBox(height: 20),

            // ── Note ─────────────────────────────────────────────────
            _buildSectionLabel('Note (optional)', cs),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add any extra details...',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Icon(Icons.sticky_note_2_outlined,
                      color: cs.onSurface.withOpacity(0.4), size: 20),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Save Button ──────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                              _isEditMode
                                  ? Icons.check_circle_outline
                                  : _isDuplicateMode
                                      ? Icons.content_copy_rounded
                                      : Icons.add_circle_outline,
                              size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _isEditMode
                                ? 'Update Transaction'
                                : _isDuplicateMode
                                    ? 'Duplicate Transaction'
                                    : 'Save Transaction',
                            style: GoogleFonts.inter(
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ── Sub-builders ────────────────────────────────────────────────────────

  Widget _buildCloseButton(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: InkWell(
        onTap: () => context.pop(),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: cs.onSurface.withOpacity(0.06),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.close, size: 18, color: cs.onSurface),
        ),
      ),
    );
  }

  Widget _buildTypeToggle(ColorScheme cs, Color accent, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1F2937)
            : cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: cs.onSurface.withOpacity(0.5),
        labelStyle:
            GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle:
            GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('💰', style: TextStyle(fontSize: 16)),
                SizedBox(width: 6),
                Text('Income'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('💸', style: TextStyle(fontSize: 16)),
                SizedBox(width: 6),
                Text('Expense'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard(SettingsState settings, ColorScheme cs, Color accent,
      Color accentLight, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2535) : accentLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'Amount',
          style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: accent.withOpacity(0.8),
              letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              settings.currency,
              style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withOpacity(0.4)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.inter(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: GoogleFonts.inter(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface.withOpacity(0.2)),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter an amount';
                  if (double.tryParse(v) == null || double.parse(v) <= 0) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ]),
    );
  }

  Widget _buildSectionLabel(String label, ColorScheme cs) {
    return Text(
      label,
      style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: cs.onSurface.withOpacity(0.5),
          letterSpacing: 0.5),
    );
  }

  Widget _buildDateTimePill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ColorScheme cs,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outline.withOpacity(0.3)),
          ),
          child: Row(children: [
            Icon(icon, size: 16, color: cs.onSurface.withOpacity(0.5)),
            const SizedBox(width: 7),
            Flexible(
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Category Picker ───────────────────────────────────────────────────────────

class _CategoryPicker extends ConsumerStatefulWidget {
  final CategoryType type;
  final CategoryModel? selected;
  final void Function(CategoryModel) onSelect;

  const _CategoryPicker({
    required this.type,
    required this.selected,
    required this.onSelect,
  });

  @override
  ConsumerState<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends ConsumerState<_CategoryPicker> {
  CategoryModel? _autoSelected;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(_categoriesByTypeProvider(widget.type));
    final cs = Theme.of(context).colorScheme;

    return categoriesAsync.when(
      data: (cats) {
        if (cats.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outline.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.category_outlined,
                    color: cs.onSurface.withOpacity(0.35), size: 18),
                const SizedBox(width: 8),
                Text('No categories yet — create one in Settings',
                    style: GoogleFonts.inter(
                        color: cs.onSurface.withOpacity(0.45), fontSize: 13)),
              ],
            ),
          );
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
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? color : color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected ? color : color.withOpacity(0.3),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      const Icon(Icons.check, color: Colors.white, size: 13),
                      const SizedBox(width: 4),
                    ],
                    Text(cat.name,
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : color.withOpacity(0.9))),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const SizedBox(
          height: 40, child: Center(child: LinearProgressIndicator())),
      error: (_, __) => const Text('Failed to load categories'),
    );
  }
}
