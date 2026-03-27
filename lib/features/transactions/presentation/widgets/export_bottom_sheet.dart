import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/transactions/data/services/export_service.dart';

class ExportBottomSheet extends ConsumerStatefulWidget {
  final List<TransactionModel> transactions;
  const ExportBottomSheet({super.key, required this.transactions});

  @override
  ConsumerState<ExportBottomSheet> createState() => _ExportBottomSheetState();
}

class _ExportBottomSheetState extends ConsumerState<ExportBottomSheet> {
  ExportFormat _selectedFormat = ExportFormat.pdf;
  ExportTimeRange _selectedRange = ExportTimeRange.thisMonth;
  ExportDateRange? _customRange;
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
          left: 20, right: 20, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 32),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(cs, tt),
          const SizedBox(height: 24),
          
          Text('SELECT FORMAT', style: tt.sectionLabel),
          const SizedBox(height: 12),
          Row(
            children: [
              _ExportFormatCard(
                format: ExportFormat.pdf,
                title: 'PDF Report',
                description: 'Formatted financial report',
                icon: Icons.picture_as_pdf_outlined,
                isSelected: _selectedFormat == ExportFormat.pdf,
                onTap: () => setState(() => _selectedFormat = ExportFormat.pdf),
                activeColor: cs.error,
                cs: cs,
                tt: tt,
              ),
              const SizedBox(width: 12),
              _ExportFormatCard(
                format: ExportFormat.excel,
                title: 'Excel Export',
                description: 'For spreadsheet analysis',
                icon: Icons.table_chart_outlined,
                isSelected: _selectedFormat == ExportFormat.excel,
                onTap: () => setState(() => _selectedFormat = ExportFormat.excel),
                activeColor: AppColors.success,
                cs: cs,
                tt: tt,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          Text('DATE RANGE', style: tt.sectionLabel),
          const SizedBox(height: 12),
          _buildRangeSelector(cs, tt),
          
          if (_selectedRange == ExportTimeRange.custom) ...[
            const SizedBox(height: 12),
            _CustomRangePicker(
              range: _customRange != null ? DateTimeRange(start: _customRange!.start, end: _customRange!.end) : null,
              onTap: _pickCustomRange,
              cs: cs,
              tt: tt,
            ),
          ],
          
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isExporting ? null : _handleExport,
              style: ElevatedButton.styleFrom(
                elevation: 0,
              ),
              child: _isExporting
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                          color: cs.onPrimary, strokeWidth: 2))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.file_download_outlined, size: 22),
                        const SizedBox(width: 10),
                        Text('Generate Export',
                            style: tt.titleMedium?.copyWith(
                                color: cs.onPrimary,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs, TextTheme tt) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export Transactions', style: tt.headlineSmall),
            const SizedBox(height: 4),
            Text('Save or share your financial data', style: tt.bodySmall),
          ],
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.close, color: cs.onSurfaceVariant),
          style: IconButton.styleFrom(backgroundColor: cs.surfaceVariant),
        ),
      ],
    );
  }

  Widget _buildRangeSelector(ColorScheme cs, TextTheme tt) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _RangeButton(
                label: 'This Month',
                selected: _selectedRange == ExportTimeRange.thisMonth,
                onTap: () => setState(() => _selectedRange = ExportTimeRange.thisMonth),
                cs: cs,
                tt: tt,
              ),
              _RangeButton(
                label: 'Last Month',
                selected: _selectedRange == ExportTimeRange.lastMonth,
                onTap: () => setState(() => _selectedRange = ExportTimeRange.lastMonth),
                cs: cs,
                tt: tt,
              ),
            ],
          ),
          Row(
            children: [
              _RangeButton(
                label: '3 Months',
                selected: _selectedRange == ExportTimeRange.last3Months,
                onTap: () => setState(() => _selectedRange = ExportTimeRange.last3Months),
                cs: cs,
                tt: tt,
              ),
              _RangeButton(
                label: 'All History',
                selected: _selectedRange == ExportTimeRange.all,
                onTap: () => setState(() => _selectedRange = ExportTimeRange.all),
                cs: cs,
                tt: tt,
              ),
              _RangeButton(
                label: 'Custom',
                selected: _selectedRange == ExportTimeRange.custom,
                onTap: () {
                   setState(() => _selectedRange = ExportTimeRange.custom);
                   if (_customRange == null) _pickCustomRange();
                },
                cs: cs,
                tt: tt,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customRange != null 
        ? DateTimeRange(start: _customRange!.start, end: _customRange!.end)
        : null,
    );
    if (picked != null) {
      setState(() => _customRange = ExportDateRange(start: picked.start, end: picked.end));
    }
  }

  Future<void> _handleExport() async {
    if (_selectedRange == ExportTimeRange.custom && _customRange == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a date range')));
       return;
    }

    setState(() => _isExporting = true);
    try {
      await ref.read(exportServiceProvider).exportData(
        format: _selectedFormat,
        range: _selectedRange,
        allTransactions: widget.transactions,
        customRange: _customRange,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }
}

class _ExportFormatCard extends StatelessWidget {
  final ExportFormat format;
  final String title, description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeColor;
  final ColorScheme cs;
  final TextTheme tt;

  const _ExportFormatCard({
    required this.format,
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.activeColor,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.1) : cs.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? activeColor : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: isSelected ? activeColor : cs.onSurfaceVariant, size: 30),
              const SizedBox(height: 16),
              Text(title, style: tt.titleSmall),
              const SizedBox(height: 4),
              Text(description, style: tt.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _RangeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;

  const _RangeButton({required this.label, required this.selected, required this.onTap, required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 42,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected ? cs.surface : cs.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected ? [BoxShadow(color: cs.shadow.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))] : null,
          ),
          child: Center(
            child: Text(label,
                style: tt.labelLarge?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: selected ? cs.primary : cs.onSurfaceVariant)),
          ),
        ),
      ),
    );
  }
}

class _CustomRangePicker extends StatelessWidget {
  final DateTimeRange? range;
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;

  const _CustomRangePicker({this.range, required this.onTap, required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          children: [
            Icon(Icons.date_range_outlined, size: 20, color: cs.primary),
            const SizedBox(width: 12),
            Text(
              range == null 
                ? 'Select date range' 
                : '${range!.start.day}/${range!.start.month}/${range!.start.year} - ${range!.end.day}/${range!.end.month}/${range!.end.year}',
              style: tt.titleSmall,
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, size: 20, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
