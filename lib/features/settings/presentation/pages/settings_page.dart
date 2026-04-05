import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trust_tracker_flutter/core/constants/app_constants.dart';
import 'package:trust_tracker_flutter/core/security/security_provider.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:trust_tracker_flutter/core/services/update_service.dart';
import 'package:trust_tracker_flutter/core/services/backup_service.dart';
import 'package:trust_tracker_flutter/generated/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:trust_tracker_flutter/core/constants/app_avatars.dart';
import 'dart:math' as math;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/widgets/avatar_selection_modal.dart';
import 'package:path/path.dart' as p;

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage>
    with WidgetsBindingObserver {
  late TextEditingController _nameController;

  // _pickCustomAvatar removed (now in shared showAvatarSelectionModal)
  // _showAvatarPicker removed (now in shared showAvatarSelectionModal)

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

  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final security = ref.watch(securityProvider);
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final cs = theme.colorScheme;
    final isTapMode =
        settings.transactionActionMode == TransactionActionMode.tap;

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings, style: tt.headlineSmall)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Profile card (Edit on Demand) ──────────────────────────
          _SectionCard(
            children: [
              Row(children: [
                GestureDetector(
                  onTap: () => showAvatarSelectionModal(context: context, ref: ref, settings: settings),
                  child: Stack(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.primaryContainer,
                          border: Border.all(color: cs.primary.withOpacity(0.2), width: 2),
                          image: settings.userAvatar != null
                              ? DecorationImage(
                                  image: settings.userAvatar!.startsWith('assets/')
                                      ? AssetImage(settings.userAvatar!)
                                      : FileImage(File(settings.userAvatar!)) as ImageProvider,
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: settings.userAvatar == null
                            ? Center(
                                child: Text(
                                  settings.userName.isNotEmpty
                                      ? settings.userName[0].toUpperCase()
                                      : '?',
                                  style: tt.displaySmall?.copyWith(
                                      color: cs.onPrimaryContainer,
                                      fontWeight: FontWeight.bold),
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: cs.surface, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _isEditing
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _nameController,
                              autofocus: true,
                              style: tt.bodyLarge,
                              decoration: InputDecoration(
                                hintText: l10n.yourName,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                border: UnderlineInputBorder(
                                    borderSide: BorderSide(color: cs.primary)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _isEditing = false;
                                      _nameController.text = settings.userName; 
                                    });
                                  },
                                  child: Text(l10n.cancel,
                                      style: TextStyle(
                                          color: cs.onSurface.withOpacity(0.5))),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: () {
                                    if (_nameController.text.trim().isNotEmpty) {
                                      ref.read(settingsProvider.notifier).setUserName(_nameController.text.trim());
                                      setState(() => _isEditing = false);
                                      HapticFeedback.lightImpact();
                                    }
                                  },
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    minimumSize: const Size(80, 40),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Text(l10n.save),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    settings.userName.isEmpty
                                        ? l10n.setName
                                        : settings.userName,
                                    style: tt.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.edit_outlined,
                                      size: 20,
                                      color: cs.primary.withOpacity(0.8)),
                                  onPressed: () =>
                                      setState(() => _isEditing = true),
                                ),
                              ],
                            ),
                            Text(l10n.trustTrackerUser,
                                style: tt.bodySmall?.copyWith(
                                    color: cs.onSurface.withOpacity(0.5))),
                          ],
                        ),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 16),

          // ── Appearance ─────────────────────────────────────────────
          _SettingsSection(
            title: l10n.language,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.language_rounded, color: cs.onSurface.withOpacity(0.55), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.language,
                        style: tt.bodyMedium,
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: PopupMenuButton<String>(
                        initialValue: settings.languageCode,
                        onSelected: (code) {
                          ref.read(settingsProvider.notifier).setLanguage(code);
                        },
                        offset: const Offset(0, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        itemBuilder: (context) => [
                          PopupMenuItem(value: 'en', child: Text(l10n.english)),
                          PopupMenuItem(value: 'hi', child: Text(l10n.hindi)),
                          PopupMenuItem(value: 'gu', child: Text(l10n.gujarati)),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                settings.languageCode == 'en' 
                                    ? l10n.english 
                                    : (settings.languageCode == 'hi' ? l10n.hindi : l10n.gujarati),
                                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: cs.primary),
                              ),
                              Icon(Icons.arrow_drop_down, color: cs.primary),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _SettingsSection(
            title: l10n.appearance,
            children: [
              _SettingsToggle(
                icon: Icons.dark_mode_outlined,
                label: l10n.darkMode,
                value: settings.isDarkMode,
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).setDarkMode(v),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _SettingsSection(
            title: l10n.appTheme,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.selectAccentColor,
                      style: tt.titleSmall?.copyWith(color: cs.onSurface.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: AppAccentColors.all.map((accent) {
                        final accentHex = '#${accent.color.value.toRadixString(16).substring(2).toUpperCase()}';
                        final isSelected = settings.accentColorHex.toUpperCase() == accentHex;
                        
                        return GestureDetector(
                          onTap: () {
                            if (!isSelected) {
                              ref.read(settingsProvider.notifier).setAccentColor(accentHex);
                              HapticFeedback.mediumImpact();
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: accent.color,
                              shape: BoxShape.circle,
                              // Multi-layer border for premium look
                              border: Border.all(
                                color: isSelected 
                                    ? (theme.brightness == Brightness.dark ? Colors.white : cs.primary)
                                    : cs.outline.withOpacity(0.12), 
                                width: isSelected ? 3 : 1.5,
                              ),
                            ),
                            child: isSelected 
                                ? Icon(Icons.check, color: theme.brightness == Brightness.dark ? Colors.black : Colors.white, size: 24) 
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Currency ──────────────────────────────────────────────
          _SettingsSection(
            title: l10n.currency,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.payments_outlined, color: cs.onSurface.withOpacity(0.55), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.currency,
                        style: tt.bodyMedium,
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: PopupMenuButton<String>(
                        initialValue: settings.currency,
                        onSelected: (code) {
                          ref.read(settingsProvider.notifier).setCurrency(code);
                        },
                        offset: const Offset(0, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        itemBuilder: (context) => AppConstants.currencies.map((c) => PopupMenuItem(
                          value: c['code'],
                          child: Text('${c['code']} — ${c['name']}', style: tt.bodyMedium),
                        )).toList(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                settings.currency,
                                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: cs.primary),
                              ),
                              Icon(Icons.arrow_drop_down, color: cs.primary),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Transaction Interaction ──────────────────
          _SettingsSection(
            title: l10n.transactions,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                            Text(l10n.transactionActionMode,
                                style: tt.titleSmall),
                            const SizedBox(height: 2),
                            Text(
                              isTapMode
                                  ? l10n.tapModeDetails
                                  : l10n.swipeModeDetails,
                              style: tt.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _SlidingSegmentedControl(
                      isSelected: isTapMode,
                      l10n: l10n,
                      onModeChanged: (mode) => ref
                          .read(settingsProvider.notifier)
                          .setTransactionActionMode(mode),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),


          _SettingsSection(
            title: l10n.security,
            children: [
              _SettingsTile(
                icon: Icons.lock_outline,
                label: security.isPinEnabled ? l10n.changePin : l10n.setPin,
                trailing: security.isPinEnabled
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: cs.secondaryContainer,
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(l10n.on,
                            style: tt.labelSmall?.copyWith(color: cs.onSecondaryContainer, fontWeight: FontWeight.bold)),
                      )
                    : null,
                onTap: () => context.push('/set-pin',
                    extra: security.isPinEnabled ? {'changing': true} : null),
              ),
              if (security.isPinEnabled)
                _SettingsTile(
                  icon: Icons.lock_open_outlined,
                  label: l10n.disablePin,
                  iconColor: cs.error,
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        icon: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cs.error.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.warning_amber_rounded, size: 32, color: cs.error),
                        ),
                        title: Text(l10n.disablePinConfirm, 
                          textAlign: TextAlign.center,
                          style: tt.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800, 
                            letterSpacing: -0.5,
                            fontSize: 20, // Slightly more controlled size
                          )),
                        content: Text(
                          l10n.disablePinDetails,
                          textAlign: TextAlign.center,
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurface.withOpacity(0.6), 
                            height: 1.3,
                            fontSize: 14,
                          ),
                        ),
                        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                        actions: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    side: BorderSide(color: cs.outline.withOpacity(0.2)),
                                    foregroundColor: cs.onSurface,
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                  ),
                                  child: Text(
                                    l10n.cancel, 
                                    maxLines: 1,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                    backgroundColor: cs.error,
                                    foregroundColor: cs.onError,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                  ),
                                  child: Text(
                                    l10n.disablePin, 
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      ),
                    );

                    if (confirm == true && mounted) {
                      context.push('/set-pin', extra: {'disabling': true});
                    }
                  },
                ),
              if (security.canUseBiometrics)
                _SettingsToggle(
                  icon: Icons.fingerprint,
                  label: l10n.biometricUnlock,
                  value: security.isBiometricEnabled,
                  onChanged: (v) async {
                    if (v && !security.isPinEnabled) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.setPinBeforeBiometric),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                      context.push('/set-pin');
                      return;
                    }
                    context.push('/set-pin', extra: {'verifyingForBio': v});
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Data Management ──────────────────────────────────────
          _SettingsSection(
            title: l10n.dataManagement,
            children: [
              _SettingsTile(
                icon: Icons.upload_file,
                label: l10n.exportDataJson,
                onTap: () => _handleExport(context, ref),
              ),
              _SettingsTile(
                icon: Icons.download,
                label: l10n.importDataJson,
                onTap: () => _handleImport(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _SettingsSection(
            title: l10n.support,
            children: [
              _SettingsTile(
                icon: Icons.star_outline_rounded,
                label: l10n.rateApp,
                iconColor: AppColors.warning,
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
                label: l10n.shareApp,
                iconColor: cs.primary,
                onTap: () {
                  Share.share(
                    l10n.shareMessage,
                    subject: l10n.shareSubject,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          _SettingsSection(
            title: l10n.data,
            children: [
              _SettingsTile(
                icon: Icons.category_outlined,
                label: l10n.manageCategories,
                onTap: () => context.push('/categories'),
              ),
              _SettingsTile(
                icon: Icons.account_balance_wallet_outlined,
                label: l10n.setMonthlyBudgets,
                onTap: () => context.push('/budget'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: l10n.about,
            children: [
              _SettingsTile(
                icon: Icons.update_rounded,
                label: l10n.checkForUpdates,
                onTap: () async {
                  final updateService = ref.read(updateServiceProvider);
                  final hasUpdate = await updateService.manualCheck(context);

                  if (!hasUpdate && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text(l10n.latestVersion),
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
                label: l10n.termsPrivacy,
                onTap: () {},
              ),
            ],
          ),

/*
          if (!kReleaseMode) ...[
             const SizedBox(height: 16),
             _SettingsSection(
               title: "Developer Testing",
               children: [
                 _SettingsTile(
                   icon: Icons.bug_report_outlined,
                   label: "Test Update Popup",
                   iconColor: cs.secondary,
                   onTap: () {
                     HapticFeedback.lightImpact();
                     ref.read(updateServiceProvider).testUpdateUI(context);
                   },
                 ),
               ],
             ),
           ],
*/

          const SizedBox(height: 24),

          // App info
          Center(
            child: Column(
              children: [
                FutureBuilder<String>(
                  future: ref.read(updateServiceProvider).getCurrentVersion(),
                  builder: (context, snapshot) {
                    final version = snapshot.data ?? '1.0.0';
                    final versionOnly = version.split('+')[0];
                    return Text(
                      versionOnly,
                      textAlign: TextAlign.center,
                      style: tt.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.builtWithLove('Karan'),
                  style: tt.labelSmall?.copyWith(color: cs.onSurface.withOpacity(0.5)),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.offlineNote,
                  textAlign: TextAlign.center,
                  style: tt.labelSmall?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  bool _isProcessing = false;

  Future<void> _handleExport(BuildContext context, WidgetRef ref) async {
    if (_isProcessing) return;
    print("Settings: Export clicked");

    final backupService = ref.read(backupServiceProvider);
    
    setState(() => _isProcessing = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.offlineNote.contains('offline') 
              ? 'Exporting Data...' 
              : 'Preparing Backup...'),
          ],
        ),
      ),
    );

    try {
      final result = await backupService.exportData();
      print("Settings: Export result path: $result");
      
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Safe close

      if (result != null) {
        print("Settings: Triggering auto-share...");
        await Share.shareXFiles(
          [XFile(result)], 
          subject: 'Trust Tracker Backup File',
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Export complete! Save the file to your device.'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Export failed or cancelled. Check permissions.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      print("Settings: EXPORT ERROR -> $e");
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
      print("Settings: Export handler finished");
    }
  }

  Future<void> _handleImport(BuildContext context, WidgetRef ref) async {
    if (_isProcessing) return;
    
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Data'),
        content: const Text('This will overwrite your current data with the backup file. This action cannot be undone. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isProcessing = true);
      final backupService = ref.read(backupServiceProvider);
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Restoring Data...'),
            ],
          ),
        ),
      );

      try {
        final success = await backupService.importData();
        
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop();

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Data restored successfully'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Import failed or invalid file'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }
}

class _SlidingSegmentedControl extends StatelessWidget {
  final bool isSelected; // false = Swipe, true = Tap
  final ValueChanged<TransactionActionMode> onModeChanged;
  final AppLocalizations l10n;

  const _SlidingSegmentedControl({
    required this.isSelected,
    required this.onModeChanged,
    required this.l10n,
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
        color: cs.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withOpacity(0.1)),
      ),
      child: Stack(
        children: [
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
          Row(
            children: [
              _ModeLabel(
                icon: Icons.swipe_rounded,
                label: l10n.swipeMode,
                selected: !isSelected,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onModeChanged(TransactionActionMode.swipe);
                },
              ),
              _ModeLabel(
                icon: Icons.touch_app_outlined,
                label: l10n.tapMode,
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
    final theme = Theme.of(context);
    final tt = theme.textTheme;
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
                    : theme.colorScheme.onSurface.withOpacity(0.4),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: tt.labelMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
        border: Border.all(color: cs.outline.withOpacity(0.1)),
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(title.toUpperCase(),
            style: Theme.of(context).textTheme.sectionLabel),
      ),
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.1)),
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
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: [
        Icon(icon, size: 20, color: cs.onSurface.withOpacity(0.55)),
        const SizedBox(width: 12),
        Expanded(
            child: Text(label, style: tt.bodyMedium)),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: cs.primary,
          trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.selected)) {
              return cs.primary.withAlpha(120);
            }
            return cs.outline.withOpacity(0.2);
          }),
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
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final cs = theme.colorScheme;
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
                  Text(label, style: tt.bodyMedium)),
          if (trailing != null) ...[trailing!, const SizedBox(width: 4)],
          Icon(Icons.chevron_right,
              color: cs.onSurface.withOpacity(0.3), size: 18),
        ]),
      ),
    );
  }
}
