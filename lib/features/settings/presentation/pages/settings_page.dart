import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trust_tracker_flutter/core/constants/app_constants.dart';
import 'package:trust_tracker_flutter/core/security/security_provider.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:trust_tracker_flutter/core/services/update_service.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage>
    with WidgetsBindingObserver {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _nameController =
        TextEditingController(text: ref.read(settingsProvider).userName);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final security = ref.watch(securityProvider);
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isTapMode =
        settings.transactionActionMode == TransactionActionMode.tap;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // â”€â”€ Profile card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _SectionCard(
            children: [
              Row(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    settings.userName.isNotEmpty
                        ? settings.userName[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: cs.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            settings.userName.isEmpty
                                ? 'Set your name'
                                : settings.userName,
                            style: theme.textTheme.headlineSmall),
                        Text('Trust Tracker User',
                            style: theme.textTheme.bodySmall),
                      ]),
                ),
              ]),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'Your name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).setUserName(v),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // â”€â”€ Appearance â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _SettingsSection(
            title: 'Appearance',
            children: [
              _SettingsToggle(
                icon: Icons.dark_mode_outlined,
                label: 'Dark Mode',
                value: settings.isDarkMode,
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).setDarkMode(v),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // â”€â”€ Currency â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _SettingsSection(
            title: 'Currency',
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: DropdownButtonFormField<String>(
                  value: settings.currency,
                  dropdownColor: cs.surface,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.attach_money,
                        color: cs.onSurface.withOpacity(0.6)),
                  ),
                  items: AppConstants.currencies
                      .map((c) => DropdownMenuItem(
                          value: c['code'],
                          child: Text(
                              '${c['code']} â€” ${c['name']} (${c['symbol']})',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: cs.onSurface))))
                      .toList(),
                  onChanged: (code) {
                    if (code != null) {
                      ref.read(settingsProvider.notifier).setCurrency(code);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // â”€â”€ Transaction Interaction â”€â”€ Issue 8 â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _SettingsSection(
            title: 'Transactions',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(
                          isTapMode
                              ? Icons.touch_app_outlined
                              : Icons.swipe_rounded,
                          size: 20,
                          color: cs.onSurface.withOpacity(0.55)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Transaction Action Mode',
                                style: theme.textTheme.bodyMedium),
                            const SizedBox(height: 2),
                            Text(
                              isTapMode
                                  ? 'Tap to edit â€¢ Delete icon visible'
                                  : 'Swipe right to delete â€¢ Swipe left to edit',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: cs.onSurface.withOpacity(0.4)),
                            ),
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    const SizedBox(height: 12),
                    // Polished Segmented Control for Action Mode
                    const SizedBox(height: 12),
                    // Premium Sliding Segmented Control
                    _SlidingSegmentedControl(
                      isSelected: isTapMode,
                      onModeChanged: (mode) => ref
                          .read(settingsProvider.notifier)
                          .setTransactionActionMode(mode),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),


          _SettingsSection(
            title: 'Security',
            children: [
              _SettingsTile(
                icon: Icons.lock_outline,
                label: security.isPinEnabled ? 'Change PIN' : 'Set PIN Lock',
                trailing: security.isPinEnabled
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: cs.secondaryContainer,
                            borderRadius: BorderRadius.circular(8)),
                        child: Text('ON',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                color: cs.onSecondaryContainer,
                                fontWeight: FontWeight.w700)),
                      )
                    : null,
                onTap: () => context.push('/set-pin',
                    extra: security.isPinEnabled ? {'changing': true} : null),
              ),
              if (security.isPinEnabled)
                _SettingsTile(
                  icon: Icons.lock_open_outlined,
                  label: 'Disable PIN Lock',
                  iconColor: cs.error,
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        title: const Text('Disable PIN?'),
                        content: const Text(
                            'Your app will no longer require a PIN to open.'),
                        actions: [
                          TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogCtx).pop(false),
                              child: const Text('Cancel')),
                          ElevatedButton(
                              onPressed: () =>
                                  Navigator.of(dialogCtx).pop(true),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: cs.error,
                                  foregroundColor: cs.onError),
                              child: const Text('Disable')),
                        ],
                      ),
                    );

                    if (confirm == true && mounted) {
                      // FIX Issue 3: Ensure the dialog is completely gone
                      // before we trigger a state update that forces a router refresh.
                      await ref.read(securityProvider.notifier).disablePin();
                    }
                  },
                ),
              if (security.canUseBiometrics && security.isPinEnabled)
                _SettingsToggle(
                  icon: Icons.fingerprint,
                  label: 'Biometric Unlock',
                  value: security.isBiometricEnabled,
                  onChanged: (v) =>
                      ref.read(securityProvider.notifier).setBiometric(v),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // â”€â”€ Support â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _SettingsSection(
            title: 'Support',
            children: [
              _SettingsTile(
                icon: Icons.star_outline_rounded,
                label: 'Rate App',
                iconColor: const Color(0xFFF59E0B),
                onTap: () async {
                  const url =
                      'https://play.google.com/store/apps/details?id=com.trusttracker.trust_tracker_flutter';
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              _SettingsTile(
                icon: Icons.share_outlined,
                label: 'Share App',
                iconColor: const Color(0xFF6366F1),
                onTap: () {
                Share.share(
  'Take control of your personal finances with Trust Tracker.\n\n'
  'Trust Tracker is a private, offline-first expense tracker designed to help you manage your income, expenses, and budgets with ease.\n\n'
  'Key Features:\n'
  '• Simple expense and income tracking\n'
  '• Budget management and financial insights\n'
  '• Secure PIN and biometric protection\n'
  '• Completely offline and privacy focused\n'
  '• Clean and easy-to-use interface\n\n'
  'Download the app from the Google Play Store:\n'
  'https://play.google.com/store/apps/details?id=com.trusttracker.trust_tracker_flutter\n\n'
  'Your feedback and support would mean a lot.',
  subject: 'Trust Tracker – Smart Expense Tracker',
);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          _SettingsSection(
            title: 'Data',
            children: [
              _SettingsTile(
                icon: Icons.category_outlined,
                label: 'Manage Categories',
                onTap: () => context.push('/categories'),
              ),
              _SettingsTile(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Set Monthly Budgets',
                onTap: () => context.push('/budget'),
              ),
            ],
          ),

          _SettingsSection(
            title: 'About',
            children: [
              _SettingsTile(
                icon: Icons.update_rounded,
                label: 'Check for Updates',
                onTap: () async {
                  final updateService = ref.read(updateServiceProvider);
                  final hasUpdate = await updateService.manualCheck(context);

                  if (!hasUpdate && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            const Text('You are already on the latest version'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }
                },
              ),
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                label: 'Terms & Privacy',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 24),

          // App info
          Center(
            child: FutureBuilder<String>(
              future: ref.read(updateServiceProvider).getCurrentVersion(),
              builder: (context, snapshot) {
                final version = snapshot.data ?? '1.0.0';
                return Text(
                  'Trust Tracker v$version\nOffline & Private â€” Your data stays on your device',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      color: cs.onSurface.withOpacity(0.35),
                      fontSize: 12,
                      height: 1.8),
                );
              },
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// â”€â”€ Sliding Segmented Control â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _SlidingSegmentedControl extends StatelessWidget {
  final bool isSelected; // false = Swipe, true = Tap
  final ValueChanged<TransactionActionMode> onModeChanged;

  const _SlidingSegmentedControl({
    required this.isSelected,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1F2937).withOpacity(0.5)
            : cs.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(isDark ? 0.1 : 0.3),
        ),
      ),
      child: Stack(
        children: [
          // The Sliding Pill
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            alignment:
                isSelected ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Interactive Labels
          Row(
            children: [
              _ModeLabel(
                icon: Icons.swipe_rounded,
                label: 'Swipe Mode',
                selected: !isSelected,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onModeChanged(TransactionActionMode.swipe);
                },
              ),
              _ModeLabel(
                icon: Icons.touch_app_outlined,
                label: 'Tap Mode',
                selected: isSelected,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onModeChanged(TransactionActionMode.tap);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeLabel({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// â”€â”€ Reusable UI components â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(title.toUpperCase(),
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: cs.onSurface.withOpacity(0.45),
                letterSpacing: 0.8)),
      ),
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ?? cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
        ),
        child: Column(children: children),
      ),
    ]);
  }
}


class _SettingsToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SettingsToggle(
      {required this.icon,
      required this.label,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: [
        Icon(icon, size: 20, color: cs.onSurface.withOpacity(0.55)),
        const SizedBox(width: 12),
        Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: cs.primary,
        ),
      ]),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? iconColor;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon,
              size: 20, color: iconColor ?? cs.onSurface.withOpacity(0.55)),
          const SizedBox(width: 12),
          Expanded(
              child:
                  Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          if (trailing != null) ...[trailing!, const SizedBox(width: 4)],
          Icon(Icons.chevron_right,
              color: cs.onSurface.withOpacity(0.3), size: 18),
        ]),
      ),
    );
  }
}
