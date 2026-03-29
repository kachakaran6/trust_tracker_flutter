import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trust_tracker_flutter/features/categories/data/models/category_model.dart';
import 'package:trust_tracker_flutter/features/categories/data/repositories/category_repository.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/widgets/category_dropdown_field.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:trust_tracker_flutter/generated/app_localizations.dart';

// Removed unused provider

class AddTransactionPage extends ConsumerStatefulWidget {
  final String? initialType;
  final TransactionModel? editTransaction;
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
        final nextCategoryType = _currentCategoryType;
        if (_selectedCategory?.type != nextCategoryType) {
          setState(() => _selectedCategory = null);
        }
        setState(() {}); // Rebuild for toggle accent updates
      }
    });

    if (source != null) {
      _amountController.text = source.amount.toStringAsFixed(
          source.amount == source.amount.roundToDouble() ? 0 : 2);
      _descController.text = source.description;
      _noteController.text = source.note ?? '';

      if (edit != null) {
        _selectedDate = edit.date;
        _selectedTime = TimeOfDay.fromDateTime(edit.date);
      } else {
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
    _tabController.removeListener(() {});
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

  DateTime get _fullDateTime => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

  void _handleCategorySelected(CategoryModel category) {
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
        await notifier.addTransaction(t);
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    // --- 8pt Spacing Scale ---
    const double spMicro = 4.0;
    const double spTight = 8.0;
    const double spSmall = 12.0;
    const double spStd = 16.0;
    const double spSect = 24.0;
    
    final expenseColor = cs.error;
    final incomeColor = AppColors.success;
    final l10n = AppLocalizations.of(context)!;
    
    final isExpense = _currentType == TransactionType.expense;
    final activeAccent = isExpense ? expenseColor : incomeColor;

    final labelColor = cs.onSurfaceVariant;
    final inputBorderColor = cs.outline.withOpacity(0.1);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: cs.onSurface, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _isEditMode ? l10n.editTransaction : l10n.addTransaction,
          style: tt.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
        actions: const [], // Removed profile icon as requested
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: spStd),
          children: [
            const SizedBox(height: spStd),
            
            // --- Amount Section ---
            Center(
              child: Column(
                children: [
                  Text(
                    l10n.amount.toUpperCase(),
                    style: tt.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: labelColor.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: spMicro),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        settings.currency,
                        style: tt.headlineMedium?.copyWith(
                          color: labelColor.withOpacity(0.3),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: spTight),
                      IntrinsicWidth(
                        child: TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: tt.displayLarge?.copyWith(
                            fontSize: 64, // Slightly reduced for tightness
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            color: cs.onSurface,
                            height: 1.0,
                          ),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            hintStyle: tt.displayLarge?.copyWith(
                              fontSize: 64,
                              fontWeight: FontWeight.w900,
                              color: cs.outline.withOpacity(0.2),
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            fillColor: Colors.transparent,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: spSect),

            // --- Type Toggle (Segmented Control) ---
            Container(
              padding: const EdgeInsets.all(spMicro),
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: isDark ? activeAccent.withOpacity(0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                        color: activeAccent.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: activeAccent,
                unselectedLabelColor: labelColor.withOpacity(0.5),
                labelStyle: tt.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                unselectedLabelStyle: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                tabs: [
                  Tab(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: tt.labelLarge!.copyWith(
                        color: !isExpense ? incomeColor : labelColor.withOpacity(0.5),
                        fontWeight: FontWeight.w800,
                      ),
                      child: Text(l10n.income),
                    ),
                  ),
                  Tab(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: tt.labelLarge!.copyWith(
                        color: isExpense ? expenseColor : labelColor.withOpacity(0.5),
                        fontWeight: FontWeight.w800,
                      ),
                      child: Text(l10n.expense),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: spSect),

            // --- Category Dropdown ---
            _buildSectionLabel(l10n.categoriesCaps, labelColor),
            const SizedBox(height: spTight),
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
            const SizedBox(height: spSect),

            // --- Description ---
            _buildSectionLabel(l10n.description.toUpperCase(), labelColor),
            const SizedBox(height: spMicro),
            TextFormField(
              controller: _descController,
              style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: l10n.whatWasThisFor,
                prefixIcon: Icon(Icons.edit_note_rounded, color: labelColor.withOpacity(0.6), size: 22),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: inputBorderColor)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: activeAccent, width: 2)),
                fillColor: Colors.transparent,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: spStd),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? l10n.enterDescription : null,
            ),
            const SizedBox(height: spSect),

            // --- Date and Time ---
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel(l10n.date.toUpperCase(), labelColor),
                      const SizedBox(height: spMicro),
                      InkWell(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: spStd),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: inputBorderColor)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, color: labelColor.withOpacity(0.6), size: 18),
                              const SizedBox(width: spSmall),
                              Text(
                                DateFormat('MMM dd, yyyy').format(_selectedDate),
                                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: spSect),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('TIME', labelColor),
                      const SizedBox(height: spMicro),
                   InkWell(
                        onTap: _pickTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: spStd),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: inputBorderColor)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time_filled_rounded, color: labelColor.withOpacity(0.6), size: 18),
                              const SizedBox(width: spSmall),
                              Text(
                                _selectedTime.format(context),
                                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: spSect),

            // --- Notes ---
            _buildSectionLabel('NOTES (OPTIONAL)', labelColor),
            const SizedBox(height: spMicro),
            TextFormField(
              controller: _noteController,
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Add a quick note...',
                prefixIcon: Icon(Icons.subject_rounded, color: labelColor.withOpacity(0.6), size: 20),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: inputBorderColor)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: activeAccent, width: 2)),
                fillColor: Colors.transparent,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: spStd),
              ),
            ),
            const SizedBox(height: spStd),

            // --- Attach Receipt ---
            // Container(
            //   width: double.infinity,
            //   height: 48, // Reduced height for tightness
            //   margin: const EdgeInsets.only(top: spSmall),
            //   decoration: BoxDecoration(
            //     borderRadius: BorderRadius.circular(12),
            //     border: Border.all(
            //       color: isDark ? AppColors.gray800 : AppColors.gray100,
            //       width: 1.5,
            //     ),
            //   ),
            //   child: InkWell(
            //     onTap: () {}, 
            //     borderRadius: BorderRadius.circular(12),
            //     child: Row(
            //       mainAxisAlignment: MainAxisAlignment.center,
            //       children: [
            //         Icon(Icons.add_a_photo_outlined, color: labelColor.withOpacity(0.7), size: 16),
            //         const SizedBox(width: spTight),
            //         Text(
            //           'Attach Receipt',
            //           style: tt.labelLarge?.copyWith(color: labelColor, fontWeight: FontWeight.w700, fontSize: 13),
            //         ),
            //       ],
            //     ),
            //   ),
            // ),
            const SizedBox(height: 32),

            // --- Save Button ---
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeAccent,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: activeAccent.withOpacity(0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: isExpense ? cs.onError : Colors.white, strokeWidth: 2))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.done_rounded, size: 20),
                          const SizedBox(width: spSmall),
                          Text(
                            _isEditMode ? 'Update Transaction' : 'Save Transaction',
                            style: tt.titleMedium?.copyWith(
                              color: isExpense ? cs.onError : Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, Color color) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: color.withOpacity(0.5),
            fontSize: 10,
          ),
    );
  }
}
