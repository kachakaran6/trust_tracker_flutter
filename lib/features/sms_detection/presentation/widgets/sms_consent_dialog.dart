import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';

class SmsConsentDialog extends StatelessWidget {
  const SmsConsentDialog({super.key});

  static const String privacyPolicyUrl =
      'https://ap-kk-apps.vercel.app/trust-tracker/privacy';

  Future<void> _openPrivacyDetails(BuildContext context) async {
    final uri = Uri.parse(privacyPolicyUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Safe fallback if external browser is unavailable
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.r3Xl),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppDimensions.rMd),
            ),
            child: Icon(
              Icons.security_rounded,
              color: cs.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Enable SMS Detection',
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Import eligible transaction messages to help identify expenses and income automatically. This feature is optional, and you can continue using Trust Tracker without enabling it.',
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.8),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(AppDimensions.rMd),
                  border: Border.all(
                    color: cs.outline.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDataPoint(
                      icon: Icons.shield_outlined,
                      title: '100% On-Device Processing',
                      desc: 'Messages are analyzed entirely on your device. No SMS data is ever sent to cloud or external servers.',
                      context: context,
                    ),
                    const SizedBox(height: 8),
                    _buildDataPoint(
                      icon: Icons.filter_alt_outlined,
                      title: 'Data Minimization',
                      desc: 'Only eligible bank transactions are parsed. Non-financial SMS and OTPs are ignored; full message text is never stored.',
                      context: context,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'SMS messages may contain sensitive information. Review how messages are processed and stored in our Privacy Policy before continuing.',
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.65),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => _openPrivacyDetails(context),
                  borderRadius: BorderRadius.circular(AppDimensions.rSm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 14,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Privacy details',
                          style: tt.bodySmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: cs.onSurface.withValues(alpha: 0.7),
          ),
          child: const Text('Not now'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.rMd),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _buildDataPoint({
    required IconData icon,
    required String title,
    required String desc,
    required BuildContext context,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            icon,
            size: 16,
            color: cs.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: tt.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                desc,
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.65),
                  fontSize: 11,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
