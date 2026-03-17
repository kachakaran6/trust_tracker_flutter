import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
          left: 20, right: 20, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(cs),
          const SizedBox(height: 24),
          
          Text('Select Format', style: _labelStyle(cs)),
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
                activeColor: Colors.red.shade400,
                cs: cs,
              ),
              const SizedBox(width: 12),
              _ExportFormatCard(
                format: ExportFormat.excel,
                title: 'Excel Export',
                description: 'For spreadsheet analysis',
                icon: Icons.table_chart_outlined,
                isSelected: _selectedFormat == ExportFormat.excel,
                onTap: () => setState(() => _selectedFormat = ExportFormat.excel),
                activeColor: Colors.green.shade500,
                cs: cs,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          Text('Date Range', style: _labelStyle(cs)),
          const SizedBox(height: 12),
          _buildRangeSelector(cs),
          
          if (_selectedRange == ExportTimeRange.custom) ...[
            const SizedBox(height: 12),
            _CustomRangePicker(
              range: _customRange != null ? DateTimeRange(start: _customRange!.start, end: _customRange!.end) : null,
              onTap: _pickCustomRange,
              cs: cs,
            ),
          ],
          
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isExporting ? null : _handleExport,
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isExporting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.file_download_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text('Generate Export', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export Transactions',
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: cs.onSurface)),
            const SizedBox(height: 4),
            Text('Save or share your financial data',
                style: GoogleFonts.inter(fontSize: 13, color: cs.onSurface.withOpacity(0.5))),
          ],
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.close, color: cs.onSurface.withOpacity(0.3)),
          style: IconButton.styleFrom(backgroundColor: cs.onSurface.withOpacity(0.05)),
        ),
      ],
    );
  }

  Widget _buildRangeSelector(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.onSurface.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
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
              ),
              _RangeButton(
                label: 'Last Month',
                selected: _selectedRange == ExportTimeRange.lastMonth,
                onTap: () => setState(() => _selectedRange = ExportTimeRange.lastMonth),
                cs: cs,
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
              ),
              _RangeButton(
                label: 'All History',
                selected: _selectedRange == ExportTimeRange.all,
                onTap: () => setState(() => _selectedRange = ExportTimeRange.all),
                cs: cs,
              ),
              _RangeButton(
                label: 'Custom',
                selected: _selectedRange == ExportTimeRange.custom,
                onTap: () {
                   setState(() => _selectedRange = ExportTimeRange.custom);
                   if (_customRange == null) _pickCustomRange();
                },
                cs: cs,
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

  _labelStyle(ColorScheme cs) => GoogleFonts.inter(
      fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurface.withOpacity(0.4), letterSpacing: 0.5);

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

  const _ExportFormatCard({
    required this.format,
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.activeColor,
    required this.cs,
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
            color: isSelected ? activeColor.withOpacity(0.08) : cs.onSurface.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? activeColor : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: isSelected ? activeColor : cs.onSurface.withOpacity(0.3), size: 28),
              const SizedBox(height: 12),
              Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: cs.onSurface)),
              const SizedBox(height: 4),
              Text(description, style: GoogleFonts.inter(fontSize: 10, color: cs.onSurface.withOpacity(0.4))),
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

  const _RangeButton({required this.label, required this.selected, required this.onTap, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected ? cs.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : null,
          ),
          child: Center(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w500, color: selected ? cs.primary : cs.onSurface.withOpacity(0.5))),
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

  const _CustomRangePicker({double? val, this.range, required this.onTap, required this.cs});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.onSurface.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.date_range_outlined, size: 18, color: cs.primary),
            const SizedBox(width: 12),
            Text(
              range == null 
                ? 'Select date range' 
                : '${range!.start.day}/${range!.start.month}/${range!.start.year} - ${range!.end.day}/${range!.end.month}/${range!.end.year}',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, size: 18, color: cs.onSurface.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}
