import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trust_tracker_flutter/features/subscriptions/data/models/subscription_model.dart';
import 'package:trust_tracker_flutter/features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:trust_tracker_flutter/features/categories/presentation/providers/category_provider.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:trust_tracker_flutter/features/subscriptions/core/subscription_engine.dart';
import 'package:trust_tracker_flutter/core/utils/category_utils.dart';
import 'package:trust_tracker_flutter/core/widgets/custom_dropdown_field.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

// Subscription type templates with emoji icons
const List<Map<String, String>> kSubscriptionTypes = [
  {'name': 'OTT Subscription', 'icon': '📺'},
  {'name': 'Music Subscription', 'icon': '🎵'},
  {'name': 'Mobile Recharge', 'icon': '📱'},
  {'name': 'DTH Recharge', 'icon': '📡'},
  {'name': 'Cloud Storage', 'icon': '☁️'},
  {'name': 'Software', 'icon': '💻'},
  {'name': 'Insurance Renewal', 'icon': '🛡️'},
  {'name': 'Internet / WiFi Plan', 'icon': '🌐'},
  {'name': 'Custom', 'icon': '⚙️'},
];

class AddSubscriptionPage extends ConsumerStatefulWidget {
  final SubscriptionModel? subscription;
  const AddSubscriptionPage({Key? key, this.subscription}) : super(key: key);

  @override
  ConsumerState<AddSubscriptionPage> createState() => _AddSubscriptionPageState();
}

class _AddSubscriptionPageState extends ConsumerState<AddSubscriptionPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _customDaysController = TextEditingController();

  BillingCycle _cycle = BillingCycle.monthly;
  DateTime _startDate = DateTime.now();
  bool _autoAddExpense = true;
  int? _categoryId;
  int _notifyBeforeDays = -1;
  String? _subscriptionType;

  @override
  void initState() {
    super.initState();
    if (widget.subscription != null) {
      final sub = widget.subscription!;
      _nameController.text = sub.name;
      _amountController.text = sub.amount.toString();
      _notesController.text = sub.notes ?? '';
      _cycle = sub.billingCycle;
      _startDate = sub.startDate;
      _autoAddExpense = sub.autoAddExpense;
      _categoryId = sub.categoryId;
      _notifyBeforeDays = sub.notifyBeforeDays;
      _subscriptionType = sub.subscriptionType;
      if (sub.customDays != null) {
        _customDaysController.text = sub.customDays.toString();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _customDaysController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final amount = double.parse(_amountController.text.trim());
      final customDays = _cycle == BillingCycle.custom
          ? int.tryParse(_customDaysController.text.trim())
          : null;

      final sub = widget.subscription != null
          ? widget.subscription!
          : SubscriptionModel.create(
              name: name,
              amount: amount,
              billingCycle: _cycle,
              startDate: _startDate,
              nextDueDate: _startDate,
              customDays: customDays,
            );

      sub.name = name;
      sub.amount = amount;
      sub.billingCycle = _cycle;
      sub.customDays = customDays;
      sub.startDate = _startDate;
      sub.autoAddExpense = _autoAddExpense;
      sub.notes = _notesController.text.trim();
      sub.categoryId = _categoryId;
      sub.notifyBeforeDays = _notifyBeforeDays;
      sub.subscriptionType = _subscriptionType;

      if (widget.subscription == null) {
        sub.nextDueDate = SubscriptionEngine.calcNextDueDate(_startDate, _cycle, customDays: customDays);
      }

      if (widget.subscription != null) {
        ref.read(subscriptionListProvider.notifier).updateSubscription(sub);
      } else {
        ref.read(subscriptionListProvider.notifier).addSubscription(sub);
      }
      context.pop();
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() {
        _startDate = date;
      });
    }
  }

  String _billingCycleLabel(BillingCycle c) {
    switch (c) {
      case BillingCycle.daily: return 'Daily';
      case BillingCycle.weekly: return 'Weekly';
      case BillingCycle.monthly: return 'Monthly';
      case BillingCycle.quarterly: return 'Quarterly (3 months)';
      case BillingCycle.halfYearly: return 'Half Yearly (6 months)';
      case BillingCycle.yearly: return 'Yearly';
      case BillingCycle.custom: return 'Custom Days';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final currency = ref.watch(settingsProvider).currency;
    final categoriesAsync = ref.watch(allCategoriesProvider);

    final notificationOptions = {
      -1: 'Never',
      0: 'Same day',
      1: '1 day before',
      3: '3 days before',
      7: '1 week before',
    };

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(widget.subscription != null ? 'Edit Subscription' : 'Add Subscription'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Subscription Type Templates ────────────────────────
              Text(
                'SUBSCRIPTION TYPE',
                style: tt.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: cs.onSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: kSubscriptionTypes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final type = kSubscriptionTypes[index];
                    final isSelected = _subscriptionType == type['name'];
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _subscriptionType = type['name']);
                        if (type['name'] != 'Custom' && _nameController.text.isEmpty) {
                          _nameController.text = type['name']!;
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? cs.primaryContainer : cs.surfaceVariant.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isSelected ? cs.primary : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(type['icon']!, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 6),
                            Text(
                              type['name']!.split(' ').first,
                              style: tt.labelMedium?.copyWith(
                                color: isSelected ? cs.onPrimaryContainer : cs.onSurface.withOpacity(0.7),
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // ── Service Name ──────────────────────────────────────
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Service Name',
                  hintText: 'e.g. Netflix, Airtel, Jio',
                  prefixIcon: Icon(Icons.event_repeat),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // ── Amount ───────────────────────────────────────────
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(currency,
                        style: TextStyle(
                            fontSize: 16,
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  if (double.tryParse(val) == null) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Billing Cycle ─────────────────────────────────────
              CustomDropdownField<BillingCycle>(
                value: _cycle,
                label: 'Billing Cycle',
                prefixIcon: Icons.update,
                itemLabelBuilder: _billingCycleLabel,
                items: BillingCycle.values.map((c) {
                  return CustomDropdownItem<BillingCycle>(
                    value: c,
                    label: _billingCycleLabel(c),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _cycle = val);
                },
              ),
              if (_cycle == BillingCycle.custom) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _customDaysController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Number of Days',
                    prefixIcon: Icon(Icons.calendar_today),
                    hintText: 'e.g. 45',
                  ),
                  validator: (val) {
                    if (_cycle != BillingCycle.custom) return null;
                    if (val == null || val.isEmpty) return 'Required for Custom cycle';
                    final d = int.tryParse(val);
                    if (d == null || d < 1) return 'Enter a valid number of days';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),

              // ── Start Date ────────────────────────────────────────
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'First Billing Date',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(DateFormat.yMMMd().format(_startDate)),
                ),
              ),
              const SizedBox(height: 8),

              // Auto-calculated next renewal preview
              _NextRenewalPreview(startDate: _startDate, cycle: _cycle,
                  customDays: int.tryParse(_customDaysController.text)),
              const SizedBox(height: 16),

              // ── Category ──────────────────────────────────────────
              categoriesAsync.when(
                data: (categories) => CustomDropdownField<int?>(
                  value: _categoryId,
                  label: 'Category (Optional)',
                  prefixIcon: Icons.category,
                  itemLabelBuilder: (val) {
                    if (val == null) return 'None';
                    try {
                      final c = categories.firstWhere((c) => c.id == val);
                      return '${CategoryUtils.getEmoji(c.iconName)}  ${c.name}';
                    } catch (_) {
                      return 'Unknown';
                    }
                  },
                  items: [
                    const CustomDropdownItem<int?>(
                      value: null,
                      label: 'None',
                    ),
                    const PopupMenuDivider(),
                    ...categories.map((c) => CustomDropdownItem<int?>(
                          value: c.id,
                          label: '${CategoryUtils.getEmoji(c.iconName)}  ${c.name}',
                        ))
                  ],
                  onChanged: (val) => setState(() => _categoryId = val),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const SizedBox(),
              ),
              const SizedBox(height: 24),

              // ── Auto-add Expense ──────────────────────────────────
              InputDecorator(
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: cs.outline.withOpacity(0.12)),
                  ),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withOpacity(0.42),
                ),
                child: SwitchListTile(
                  title: const Text('Auto-add Expense'),
                  subtitle: const Text('Automatically deduct from balance on due date'),
                  value: _autoAddExpense,
                  onChanged: (val) => setState(() => _autoAddExpense = val),
                  activeTrackColor: cs.primary,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),

              // ── Reminder ──────────────────────────────────────────
              CustomDropdownField<int>(
                value: notificationOptions.containsKey(_notifyBeforeDays)
                    ? _notifyBeforeDays
                    : -1,
                label: 'Reminder',
                prefixIcon: Icons.notifications,
                itemLabelBuilder: (val) => notificationOptions[val] ?? 'Never',
                items: notificationOptions.entries.map((e) {
                  return CustomDropdownItem<int>(
                    value: e.key,
                    label: e.value,
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _notifyBeforeDays = val);
                },
              ),
              const SizedBox(height: 16),

              // ── Notes ─────────────────────────────────────────────
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              // ── Save Button ───────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(widget.subscription != null
                      ? 'Update Subscription'
                      : 'Save Subscription'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows computed next renewal date preview based on start date and billing cycle.
class _NextRenewalPreview extends StatelessWidget {
  final DateTime startDate;
  final BillingCycle cycle;
  final int? customDays;

  const _NextRenewalPreview({
    required this.startDate,
    required this.cycle,
    this.customDays,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (cycle == BillingCycle.custom && customDays == null) return const SizedBox();

    final nextRenewal = SubscriptionEngine.calcNextDueDate(startDate, cycle, customDays: customDays);
    final daysUntil = nextRenewal.difference(DateTime.now()).inDays;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.event_available_rounded, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: tt.bodySmall?.copyWith(color: cs.onSurface),
                children: [
                  const TextSpan(text: 'Next renewal: '),
                  TextSpan(
                    text: DateFormat.yMMMd().format(nextRenewal),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: daysUntil >= 0 ? '  (in $daysUntil days)' : '  (overdue)',
                    style: TextStyle(
                      color: daysUntil < 3 ? cs.error : cs.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
