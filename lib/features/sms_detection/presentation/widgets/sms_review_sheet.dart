import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';
import 'package:trust_tracker_flutter/core/utils/money.dart';
import 'package:trust_tracker_flutter/features/categories/data/models/category_model.dart';
import 'package:trust_tracker_flutter/features/categories/presentation/providers/category_provider.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/parser/bank_detector.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/models/detected_sms_transaction.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/models/sms_confidence.dart';
import 'package:trust_tracker_flutter/features/sms_detection/presentation/providers/sms_detection_provider.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';

class SmsReviewSheet extends ConsumerStatefulWidget {
  final DetectedSmsTransaction transaction;

  const SmsReviewSheet({
    super.key,
    required this.transaction,
  });

  static Future<void> show(BuildContext context, DetectedSmsTransaction transaction) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SmsReviewSheet(transaction: transaction),
    );
  }

  @override
  ConsumerState<SmsReviewSheet> createState() => _SmsReviewSheetState();
}

class _SmsReviewSheetState extends ConsumerState<SmsReviewSheet> {
  late TextEditingController _amountController;
  late TextEditingController _merchantController;
  late TransactionType _type;
  late DateTime _selectedDate;
  int? _selectedCategoryId;
  String? _selectedCategoryName;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    final txn = widget.transaction;
    _amountController = TextEditingController(text: txn.amount.toStringAsFixed(2));
    _merchantController = TextEditingController(text: txn.merchant ?? txn.sender);
    _type = txn.type;
    _selectedDate = txn.date;
    _selectedCategoryId = txn.categoryId;
    _selectedCategoryName = txn.categoryName;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  void _validateAmount(String val) {
    final parsed = Money.tryParse(val);
    if (parsed == null || !parsed.isPositive) {
      setState(() => _amountError = 'Enter a valid amount greater than 0');
    } else {
      setState(() => _amountError = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final txn = widget.transaction;
    final bankInfo = BankDetector.detect(sender: txn.sender, body: txn.rawSnippet);
    final isExpense = _type == TransactionType.expense;

    final categoriesAsync = ref.watch(allCategoriesProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                // Bank Avatar
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: bankInfo.brandColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      bankInfo.initials,
                      style: TextStyle(
                        color: bankInfo.brandColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bankInfo.name,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        txn.maskedAccount ?? 'Bank Transaction',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Form
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Verification needed alert banner if ambiguous or low match
                  if (txn.isAmbiguous || txn.confidenceLevel == SmsConfidenceLevel.low) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              txn.parsingWarning ?? 'Ambiguous message. Please verify amount and fields carefully.',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Original SMS Message Box (Preserved for review & auditing)
                  if (txn.rawSnippet != null && txn.rawSnippet!.isNotEmpty) ...[
                    Text(
                      'ORIGINAL SMS',
                      style: tt.labelSmall?.copyWith(
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: cs.outline.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Text(
                        txn.rawSnippet!,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.8),
                          fontFamily: 'monospace',
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Direction Segmented Button
                  Text(
                    'TRANSACTION DIRECTION',
                    style: tt.labelSmall?.copyWith(
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: isExpense
                                ? AppColors.getError(context).withValues(alpha: 0.12)
                                : null,
                            side: BorderSide(
                              color: isExpense
                                  ? AppColors.getError(context)
                                  : cs.outline.withValues(alpha: 0.25),
                              width: isExpense ? 1.5 : 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                          onPressed: () => setState(() => _type = TransactionType.expense),
                          child: Text(
                            'Expense (Debit)',
                            style: TextStyle(
                              color: isExpense ? AppColors.getError(context) : cs.onSurface,
                              fontWeight: isExpense ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: !isExpense
                                ? AppColors.getSuccess(context).withValues(alpha: 0.12)
                                : null,
                            side: BorderSide(
                              color: !isExpense
                                  ? AppColors.getSuccess(context)
                                  : cs.outline.withValues(alpha: 0.25),
                              width: !isExpense ? 1.5 : 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                          onPressed: () => setState(() => _type = TransactionType.income),
                          child: Text(
                            'Income (Credit)',
                            style: TextStyle(
                              color: !isExpense ? AppColors.getSuccess(context) : cs.onSurface,
                              fontWeight: !isExpense ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Amount Field
                  Text(
                    'TRANSACTION AMOUNT',
                    style: tt.labelSmall?.copyWith(
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: tt.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isExpense ? AppColors.getError(context) : AppColors.getSuccess(context),
                    ),
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 14, right: 8),
                        child: Text(
                          txn.currency == 'INR' ? '₹' : txn.currency,
                          style: tt.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isExpense ? AppColors.getError(context) : AppColors.getSuccess(context),
                          ),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      errorText: _amountError,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: cs.surface,
                    ),
                    onChanged: _validateAmount,
                  ),
                  const SizedBox(height: 18),

                  // Merchant / Counterparty Field
                  Text(
                    isExpense ? 'RECIPIENT / MERCHANT' : 'SOURCE / BENEFICIARY',
                    style: tt.labelSmall?.copyWith(
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _merchantController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.storefront_rounded, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: cs.surface,
                      suffixText: 'Extracted',
                      suffixStyle: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Category Selector
                  Text(
                    'CATEGORY',
                    style: tt.labelSmall?.copyWith(
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  categoriesAsync.when(
                    data: (categories) {
                      final categoryType = isExpense ? CategoryType.expense : CategoryType.income;
                      final matchingCategories = categories.where((c) => c.type == categoryType).toList();

                      return DropdownButtonFormField<int>(
                        value: matchingCategories.any((c) => c.id == _selectedCategoryId)
                            ? _selectedCategoryId
                            : null,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.category_rounded, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: cs.surface,
                          hintText: _selectedCategoryName ?? 'Select Category',
                        ),
                        items: matchingCategories.map((c) {
                          return DropdownMenuItem<int>(
                            value: c.id,
                            child: Text(c.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          final selected = matchingCategories.firstWhere((c) => c.id == val);
                          setState(() {
                            _selectedCategoryId = val;
                            _selectedCategoryName = selected.name;
                          });
                        },
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 18),

                  // Date Picker Tile
                  Text(
                    'TRANSACTION DATE',
                    style: tt.labelSmall?.copyWith(
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: cs.outline.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 18, color: cs.primary),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('d MMMM yyyy').format(_selectedDate),
                            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down_rounded),
                        ],
                      ),
                    ),
                  ),

                  // Reference Number metadata
                  if (txn.referenceNumber != null && txn.referenceNumber!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(Icons.tag_rounded, size: 16, color: cs.onSurface.withValues(alpha: 0.45)),
                        const SizedBox(width: 6),
                        Text(
                          'Reference: ${txn.referenceNumber}',
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.55),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      side: BorderSide(color: cs.error.withValues(alpha: 0.35)),
                      minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w600)),
                    onPressed: () {
                      if (txn.id != null) {
                        ref.read(smsDetectionProvider.notifier).rejectTransaction(txn.id!);
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.getSuccess(context),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text('Save & Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final parsedAmount = Money.tryParse(_amountController.text);
                      if (parsedAmount == null || !parsedAmount.isPositive) {
                        setState(() => _amountError = 'Enter a valid amount');
                        return;
                      }

                      await ref.read(smsDetectionProvider.notifier).approveTransaction(
                            txn,
                            customAmount: parsedAmount.toRupeesDouble(),
                            customType: _type,
                            customDescription: _merchantController.text.trim(),
                            customCategoryId: _selectedCategoryId,
                            customCategoryName: _selectedCategoryName,
                            customDate: _selectedDate,
                          );

                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Saved and approved ${parsedAmount.formatIndian()}'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

