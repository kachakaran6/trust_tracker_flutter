import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:trust_tracker_flutter/core/utils/debt_pdf_generator.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';

class DebtExportPdfSheet extends StatefulWidget {
  final List<TransactionModel> allTransactions;
  final String currency;
  final String? initialPerson;

  const DebtExportPdfSheet({
    super.key,
    required this.allTransactions,
    required this.currency,
    this.initialPerson,
  });

  static Future<void> show(
    BuildContext context, {
    required List<TransactionModel> allTransactions,
    required String currency,
    String? initialPerson,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DebtExportPdfSheet(
        allTransactions: allTransactions,
        currency: currency,
        initialPerson: initialPerson,
      ),
    );
  }

  @override
  State<DebtExportPdfSheet> createState() => _DebtExportPdfSheetState();
}

class _DebtExportPdfSheetState extends State<DebtExportPdfSheet> {
  late String? _selectedPerson;
  int _statusScopeIndex = 0; // 0: All, 1: Active Only, 2: Settled Only
  bool _isGenerating = false;

  late List<String> _availablePersons;

  @override
  void initState() {
    super.initState();
    _selectedPerson = widget.initialPerson;

    // Collect unique contact names
    final set = <String>{};
    for (final t in widget.allTransactions) {
      final name = t.personName?.trim();
      if (name != null && name.isNotEmpty) {
        set.add(name);
      }
    }
    _availablePersons = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  List<TransactionModel> _getFilteredList() {
    return widget.allTransactions.where((t) {
      // 1. Person filter
      if (_selectedPerson != null && _selectedPerson!.isNotEmpty) {
        if ((t.personName ?? '').trim().toLowerCase() != _selectedPerson!.trim().toLowerCase()) {
          return false;
        }
      }
      // 2. Status filter
      if (_statusScopeIndex == 1 && t.isSettled) {
        return false;
      }
      if (_statusScopeIndex == 2 && !t.isSettled) {
        return false;
      }
      return true;
    }).toList();
  }

  String _getScopeTitle() {
    switch (_statusScopeIndex) {
      case 1:
        return 'Active Debts & Lent Only';
      case 2:
        return 'Settled History Only';
      default:
        return 'All Records (Active & Settled)';
    }
  }

  Future<DebtPdfResult?> _generatePdf() async {
    final list = _getFilteredList();
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No transactions match the selected filter'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return null;
    }

    setState(() => _isGenerating = true);
    try {
      final result = await DebtPdfGenerator.generate(
        transactions: list,
        currency: widget.currency,
        specificPerson: _selectedPerson,
        filterTitle: _getScopeTitle(),
      );
      return result;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _handlePreviewAndPrint() async {
    HapticFeedback.mediumImpact();
    final result = await _generatePdf();
    if (result != null && mounted) {
      Navigator.pop(context);
      await Printing.layoutPdf(
        name: result.fileName,
        onLayout: (format) async => result.bytes,
      );
    }
  }

  Future<void> _handleShare() async {
    HapticFeedback.mediumImpact();
    final result = await _generatePdf();
    if (result != null && mounted) {
      Navigator.pop(context);
      final personLabel = _selectedPerson != null ? ' - ${_selectedPerson!}' : '';
      await Share.shareXFiles(
        [XFile(result.file.path)],
        text: 'Trust Tracker Debt & Lent Statement$personLabel',
        subject: 'Debt & Lent Statement$personLabel',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final matchingTxns = _getFilteredList();

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE11D48).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export Debt & Lent Statement',
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Generate professional PDF ledger report',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 1. Select Contact Scope
              Text(
                'CONTACT SCOPE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 8),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Master All Contacts Chip
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        showCheckmark: false,
                        avatar: Icon(
                          Icons.people_alt_rounded,
                          size: 15,
                          color: _selectedPerson == null ? cs.onPrimary : cs.onSurfaceVariant,
                        ),
                        label: Text(
                          'All Contacts',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: _selectedPerson == null ? cs.onPrimary : cs.onSurface,
                          ),
                        ),
                        selected: _selectedPerson == null,
                        selectedColor: cs.primary,
                        backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(
                          color: _selectedPerson == null ? cs.primary : cs.outline.withValues(alpha: 0.15),
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedPerson = null);
                        },
                      ),
                    ),
                    // Contact Specific Chips
                    ..._availablePersons.map((person) {
                      final isSelected = _selectedPerson?.toLowerCase() == person.toLowerCase();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          showCheckmark: false,
                          avatar: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white.withValues(alpha: 0.2) : cs.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                person.isNotEmpty ? person[0].toUpperCase() : '?',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : cs.primary,
                                ),
                              ),
                            ),
                          ),
                          label: Text(
                            person,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 12.5,
                              color: isSelected ? cs.onPrimary : cs.onSurface,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: cs.primary,
                          backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(
                            color: isSelected ? cs.primary : cs.outline.withValues(alpha: 0.15),
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _selectedPerson = person);
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 2. Select Status Scope
              Text(
                'TRANSACTION STATUS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  _buildScopeSegment(0, 'All Records', Icons.list_alt_rounded, cs),
                  const SizedBox(width: 8),
                  _buildScopeSegment(1, 'Active Only', Icons.pending_actions_rounded, cs),
                  const SizedBox(width: 8),
                  _buildScopeSegment(2, 'Settled Only', Icons.check_circle_outline_rounded, cs),
                ],
              ),
              const SizedBox(height: 18),

              // Preview Strip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${matchingTxns.length} ${matchingTxns.length == 1 ? 'transaction' : 'transactions'} will be included in the statement.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Action Buttons
              if (_isGenerating)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        CircularProgressIndicator(strokeWidth: 3, color: cs.primary),
                        const SizedBox(height: 10),
                        Text(
                          'Generating PDF Statement...',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    // Preview & Print Button
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: matchingTxns.isEmpty ? null : _handlePreviewAndPrint,
                          icon: const Icon(Icons.print_rounded, size: 19),
                          label: const Text(
                            'Preview / Print',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cs.primary,
                            side: BorderSide(color: cs.primary.withValues(alpha: 0.4), width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Share PDF Button
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: matchingTxns.isEmpty ? null : _handleShare,
                          icon: const Icon(Icons.share_rounded, size: 19),
                          label: const Text(
                            'Share PDF',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScopeSegment(int index, String label, IconData icon, ColorScheme cs) {
    final isSelected = _statusScopeIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _statusScopeIndex = index);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? cs.primary.withValues(alpha: 0.12) : cs.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? cs.primary : cs.outline.withValues(alpha: 0.15),
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected ? cs.primary : cs.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
