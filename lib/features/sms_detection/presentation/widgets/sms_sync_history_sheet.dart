import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/services/sms_channel_service.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/services/sms_processing_service.dart';
import 'package:trust_tracker_flutter/features/sms_detection/presentation/providers/sms_detection_provider.dart';

class SmsSyncHistorySheet extends ConsumerStatefulWidget {
  const SmsSyncHistorySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SmsSyncHistorySheet(),
    );
  }

  @override
  ConsumerState<SmsSyncHistorySheet> createState() => _SmsSyncHistorySheetState();
}

class _SmsSyncHistorySheetState extends ConsumerState<SmsSyncHistorySheet> {
  int _selectedDays = 30;
  bool _isScanning = false;
  int _currentScanned = 0;
  int _totalToScan = 0;
  HistoricalScanResult? _scanResult;
  String? _errorMessage;

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
      _currentScanned = 0;
      _totalToScan = 0;
      _scanResult = null;
    });

    try {
      final result = await ref.read(smsDetectionProvider.notifier).syncHistoricalSms(
            days: _selectedDays,
            onProgress: (current, total) {
              if (mounted) {
                setState(() {
                  _currentScanned = current;
                  _totalToScan = total;
                });
              }
            },
          );

      if (!mounted) return;

      if (result == null) {
        setState(() {
          _isScanning = false;
          _errorMessage =
              'SMS permission was not granted. Please enable SMS permissions to scan historical transactions.';
        });
      } else {
        setState(() {
          _isScanning = false;
          _scanResult = result;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _errorMessage = 'An error occurred during scan: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return SafeArea(
      child: Container(
        padding: EdgeInsets.only(
          top: 14,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.history_toggle_off_rounded,
                      color: cs.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sync Past Bank SMS',
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Scan inbox locally for previous bank transactions',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Privacy Callout
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.getSuccess(context).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.getSuccess(context).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: AppColors.getSuccess(context), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '100% on-device processing. Personal messages and OTPs are ignored. No financial data leaves your phone.',
                        style: tt.bodySmall?.copyWith(
                          color: AppColors.getSuccess(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              if (_scanResult != null) ...[
                // Results View
                _buildResultsView(context, _scanResult!, cs, tt),
              ] else if (_isScanning) ...[
                // Scanning In Progress
                _buildScanningProgress(cs, tt),
              ] else ...[
                // Config & Start View
                Text(
                  'SELECT TIMEFRAME',
                  style: tt.sectionLabel,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildTimeChip(7, 'Last 7 Days', cs),
                    const SizedBox(width: 8),
                    _buildTimeChip(30, 'Last 30 Days', cs),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildTimeChip(90, 'Last 90 Days', cs),
                    const SizedBox(width: 8),
                    _buildTimeChip(0, 'All Messages', cs),
                  ],
                ),
                const SizedBox(height: 20),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cs.error.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: cs.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: cs.error, fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: () => SmsChannelService.openAppSettings(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 32),
                          ),
                          child: const Text('Settings', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _startScan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.rLg),
                      ),
                    ),
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text(
                      'Scan Device Inbox',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeChip(int days, String label, ColorScheme cs) {
    final isSelected = _selectedDays == days;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedDays = days;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? cs.primary.withValues(alpha: 0.12)
                : cs.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? cs.primary : cs.outline.withValues(alpha: 0.08),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? cs.primary : cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScanningProgress(ColorScheme cs, TextTheme tt) {
    final progress = _totalToScan > 0 ? (_currentScanned / _totalToScan) : null;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: Column(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _totalToScan > 0
                ? 'Scanning message $_currentScanned of $_totalToScan...'
                : 'Reading inbox messages locally...',
            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Filtering non-financial SMS & deduplicating',
            style: tt.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
          ),
          if (progress != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: cs.outline.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsView(
    BuildContext context,
    HistoricalScanResult result,
    ColorScheme cs,
    TextTheme tt,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.getSuccess(context), size: 26),
            const SizedBox(width: 8),
            Text(
              'Inbox Scan Complete!',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              _buildStatRow('Total messages analyzed', '${result.totalScanned}', cs),
              Divider(height: 16, color: cs.outline.withValues(alpha: 0.08)),
              _buildStatRow('Bank transactions recognized', '${result.transactionsFound}', cs),
              Divider(height: 16, color: cs.outline.withValues(alpha: 0.08)),
              _buildStatRow(
                'Added to Pending Review',
                '${result.newPending}',
                cs,
                valueColor: cs.primary,
                bold: true,
              ),
              if (result.autoApproved > 0) ...[
                Divider(height: 16, color: cs.outline.withValues(alpha: 0.08)),
                _buildStatRow(
                  'Auto-approved',
                  '${result.autoApproved}',
                  cs,
                  valueColor: AppColors.getSuccess(context),
                  bold: true,
                ),
              ],
              Divider(height: 16, color: cs.outline.withValues(alpha: 0.08)),
              _buildStatRow(
                'Duplicates skipped (already recorded)',
                '${result.duplicatesSkipped}',
                cs,
                valueColor: cs.onSurface.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.rLg),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
            if (result.newPending > 0) ...[
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/sms-review');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    minimumSize: const Size(0, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.rLg),
                    ),
                  ),
                  child: const Text('Review Now'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value, ColorScheme cs, {Color? valueColor, bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.8))),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? cs.onSurface,
          ),
        ),
      ],
    );
  }
}
