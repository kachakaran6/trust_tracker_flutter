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
import 'package:trust_tracker_flutter/core/services/backup_service.dart';
import 'package:trust_tracker_flutter/generated/app_localizations.dart';
import 'package:trust_tracker_flutter/features/transactions/data/repositories/transaction_repository.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:trust_tracker_flutter/features/budget/presentation/providers/budget_provider.dart';
import 'package:trust_tracker_flutter/core/services/summary_service.dart';
import 'package:trust_tracker_flutter/core/database/database_helper.dart';
import 'package:trust_tracker_flutter/core/services/background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:trust_tracker_flutter/core/constants/app_avatars.dart';
import 'dart:math' as math;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/widgets/avatar_selection_modal.dart';
import 'package:path/path.dart' as p;
import 'package:trust_tracker_flutter/features/sms_detection/presentation/providers/sms_settings_provider.dart';
import 'package:trust_tracker_flutter/features/sms_detection/presentation/widgets/sms_consent_dialog.dart';
import 'package:trust_tracker_flutter/features/sms_detection/presentation/widgets/sms_sync_history_sheet.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/services/sms_channel_service.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(smsSettingsProvider.notifier).checkPermissionState();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(smsSettingsProvider.notifier).checkPermissionState();
    }
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
                        final accentHex = '#${accent.lightColor.value.toRadixString(16).substring(2).toUpperCase()}';
                        final isSelected = settings.accentColorHex.toUpperCase() == accentHex;
                        final displayColor = theme.brightness == Brightness.dark ? accent.darkColor : accent.lightColor;
                        
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
                              color: displayColor,
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
                                ? const Icon(Icons.check, color: Colors.white, size: 24) 
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

          // ── Financial Preferences ────────────────────────────────
          _SettingsSection(
            title: l10n.financialPreferences,
            children: [
              _SettingsTile(
                icon: Icons.calendar_month_outlined,
                label: l10n.monthStartDay,
                trailing: Text(
                  '${settings.monthStartDay}',
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: cs.primary),
                ),
                onTap: () async {
                  final picked = await showDialog<int>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(l10n.monthStartDay),
                      backgroundColor: cs.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: GridView.builder(
                          shrinkWrap: true,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                          itemCount: 31,
                          itemBuilder: (context, index) {
                            final day = index + 1;
                            final isSelected = settings.monthStartDay == day;
                            return InkWell(
                              onTap: () => Navigator.pop(ctx, day),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected ? cs.primary : cs.surfaceVariant.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '$day',
                                    style: tt.bodySmall?.copyWith(
                                      color: isSelected ? cs.onPrimary : cs.onSurface,
                                      fontWeight: isSelected ? FontWeight.bold : null,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                  if (picked != null) {
                    ref.read(settingsProvider.notifier).setMonthStartDay(picked);
                    HapticFeedback.mediumImpact();
                  }
                },
              ),
              _SettingsToggle(
                icon: Icons.repeat_rounded,
                label: l10n.carryForward,
                value: settings.carryForwardEnabled,
                onChanged: (v) {
                   ref.read(settingsProvider.notifier).setCarryForwardEnabled(v);
                   HapticFeedback.selectionClick();
                },
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

          // ── Automatic SMS Transaction Detection ─────────────────────
          _buildSmsDetectionSection(context, ref, cs, tt),
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
                            color: cs.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.warning_amber_rounded, size: 32, color: cs.primary),
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
                                    backgroundColor: cs.primary,
                                    foregroundColor: cs.onPrimary,
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

          // ── Backup & Storage ──────────────────────────────────────
          _SettingsSection(
            title: l10n.backupSettings,
            children: [
              _SettingsToggle(
                icon: Icons.backup_outlined,
                label: l10n.autoBackup,
                value: settings.autoBackupEnabled,
                onChanged: (v) {
                   ref.read(settingsProvider.notifier).setAutoBackupEnabled(v);
                   HapticFeedback.selectionClick();
                },
              ),
              if (settings.autoBackupEnabled) ...[
                _SettingsTile(
                  icon: Icons.history_rounded,
                  label: l10n.backupInterval,
                  trailing: Text(
                    _getIntervalLabel(settings.backupInterval, settings, l10n),
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: cs.primary),
                  ),
                  onTap: () => _showIntervalPicker(context, ref, settings, l10n),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(52, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l10n.lastBackup}: ${settings.lastBackupTime != null ? _formatDateTime(settings.lastBackupTime!) : l10n.never}',
                        style: tt.labelSmall?.copyWith(color: cs.onSurface.withOpacity(0.5)),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _getStatusIcon(settings.lastBackupStatus, cs),
                          const SizedBox(width: 6),
                          Text(
                            _getStatusLabel(settings.lastBackupStatus, l10n),
                            style: tt.labelSmall?.copyWith(
                              color: _getStatusColor(settings.lastBackupStatus, cs),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              _SettingsTile(
                icon: Icons.sync_rounded,
                label: l10n.backupNow,
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.backupRunning))
                  );
                  await ref.read(backupServiceProvider).performAutoBackup();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Summary Notifications ──────────────────────────────
          _SettingsSection(
            title: l10n.summaryNotifications,
            children: [
              _SettingsSwitchTile(
                icon: Icons.insights_rounded,
                label: l10n.summaryNotifications,
                subtitle: l10n.summaryNotificationsDesc,
                value: settings.summaryNotificationsEnabled,
                onChanged: (v) async {
                  if (v) {
                    final status = await Permission.notification.request();
                    if (!status.isGranted) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Notification permission is required for summaries"))
                        );
                      }
                      return;
                    }
                  }
                  ref.read(settingsProvider.notifier).setSummaryNotificationsEnabled(v);
                  HapticFeedback.selectionClick();
                },
              ),
              if (settings.summaryNotificationsEnabled) ...[
                _SettingsTile(
                  icon: Icons.repeat_rounded,
                  label: l10n.frequency,
                  trailing: Text(
                    _getSummaryFrequencyLabel(settings.summaryFrequency, l10n),
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: cs.primary),
                  ),
                  onTap: () => _showSummaryFrequencyPicker(context, ref, settings, l10n),
                ),
                if (settings.summaryFrequency == SummaryFrequency.weekly)
                  _SettingsTile(
                    icon: Icons.calendar_today_rounded,
                    label: l10n.dayOfWeek,
                    trailing: Text(
                      _getDayOfWeekLabel(settings.summaryDayOfWeek, l10n),
                      style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: cs.primary),
                    ),
                    onTap: () => _showSummaryDayPicker(context, ref, settings, l10n),
                  ),
                _SettingsTile(
                  icon: Icons.access_time_rounded,
                  label: l10n.preferredTime,
                  trailing: Text(
                    '${settings.summaryTimeHour.toString().padLeft(2, '0')}:${settings.summaryTimeMinute.toString().padLeft(2, '0')}',
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: cs.primary),
                  ),
                  onTap: () => _showSummaryTimePicker(context, ref, settings),
                ),
                _SettingsTile(
                  icon: Icons.notification_important_outlined,
                  label: l10n.previewNotification,
                  onTap: () => _handlePreviewNotification(context, ref, settings, l10n),
                ),
              ],
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
              _SettingsTile(
                icon: Icons.delete_sweep_rounded,
                label: 'Clear All Transactions',
                iconColor: cs.error,
                onTap: () => _handleResetAllData(context, ref, l10n),
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
              _SettingsTile(
                icon: Icons.subscriptions_outlined,
                label: 'Manage Subscriptions',
                onTap: () => context.push('/subscriptions'),
              ),
              _SettingsTile(
                icon: Icons.account_balance_outlined,
                label: 'Banking Management',
                onTap: () => context.push('/banking-dashboard'),
              ),
              _SettingsTile(
                icon: Icons.apps_rounded,
                label: 'Our Apps',
                onTap: () => context.push('/our-apps'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: l10n.about,
            children: [
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                label: l10n.termsPrivacy,
                onTap: () async {
                  final uri = Uri.parse('https://ap-kk-apps.vercel.app/trust-tracker/privacy');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.inAppWebView);
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // App info
          Center(
            child: Column(
              children: [
                Text(
                  'Trust Tracker',
                  textAlign: TextAlign.center,
                  style: tt.labelSmall?.copyWith(fontWeight: FontWeight.bold),
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

  Future<void> _handleResetAllData(BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    final cs = Theme.of(context).colorScheme;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Clear All Transactions'),
        content: const Text('Are you sure you want to clear all transactions and debt records? Your settings, preferences, and categories will remain safe. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: TextButton.styleFrom(foregroundColor: cs.error),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      // 1. Delete all transactions only (preserves settings, preferences, and categories)
      await ref.read(transactionRepositoryProvider).deleteAllTransactions();
      
      // 2. Invalidate providers to update in-memory state and UI immediately
      ref.invalidate(transactionListProvider);
      ref.read(transactionChangeProvider.notifier).update((v) => v + 1);
      ref.invalidate(budgetNotifierProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'All transactions have been cleared successfully.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF10B981),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
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
      final exportPath = await backupService.exportData();
      print("Settings: Export result path: $exportPath");
      
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Safe close

      if (exportPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export complete! Saved to: $exportPath'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
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
      builder: (ctx) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        final tt = theme.textTheme;
        
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          icon: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warning_amber_rounded, size: 32, color: cs.primary),
          ),
          title: Text(
            'Import Data',
            textAlign: TextAlign.center,
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              fontSize: 20,
            ),
          ),
          content: Text(
            'This will overwrite your current data with the backup file. This action cannot be undone. Continue?',
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
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: BorderSide(color: cs.outline.withOpacity(0.2)),
                      foregroundColor: cs.onSurface,
                    ),
                    child: Text(
                      l10n.cancel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      'Import',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        );
      },
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
              content: const Text('Data restored successfully, Close the application and reopen it to see the changes'),
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

  String _getIntervalLabel(BackupInterval interval, SettingsState settings, AppLocalizations l10n) {
    switch (interval) {
      case BackupInterval.hours6: return l10n.hours6;
      case BackupInterval.hours12: return l10n.hours12;
      case BackupInterval.daily: return l10n.daily;
      case BackupInterval.weekly: return l10n.weekly;
      case BackupInterval.custom: return "${l10n.custom} (${settings.customBackupHours}h)";
    }
  }

  void _showIntervalPicker(BuildContext context, WidgetRef ref, SettingsState settings, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: BackupInterval.values.map((interval) => ListTile(
            title: Text(_getIntervalLabel(interval, settings, l10n)),
            trailing: settings.backupInterval == interval ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
            onTap: () async {
              if (interval == BackupInterval.custom) {
                final hours = await _showCustomHoursDialog(context, l10n);
                if (hours != null) {
                  ref.read(settingsProvider.notifier).setBackupInterval(interval, customHours: hours);
                  Navigator.pop(context);
                }
              } else {
                ref.read(settingsProvider.notifier).setBackupInterval(interval);
                Navigator.pop(context);
              }
            },
          )).toList(),
        ),
      ),
    );
  }

  Future<int?> _showCustomHoursDialog(BuildContext context, AppLocalizations l10n) async {
    int hours = 24;
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.custom),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.backupInterval),
            const SizedBox(height: 16),
            TextField(
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                suffixText: "hours",
                hintText: "24",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (v) => hours = int.tryParse(v) ?? 24,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, hours), child: Text(l10n.save)),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return "${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }

  Icon _getStatusIcon(BackupStatus status, ColorScheme cs) {
    switch (status) {
      case BackupStatus.success: return Icon(Icons.check_circle_outline, size: 14, color: cs.primary);
      case BackupStatus.pending: return Icon(Icons.cloud_upload_outlined, size: 14, color: Colors.orange);
      case BackupStatus.failed: return Icon(Icons.error_outline, size: 14, color: cs.error);
      case BackupStatus.none: return const Icon(Icons.info_outline, size: 14);
    }
  }

  String _getStatusLabel(BackupStatus status, AppLocalizations l10n) {
    switch (status) {
      case BackupStatus.success: return l10n.backupSuccess;
      case BackupStatus.pending: return l10n.backupPending;
      case BackupStatus.failed: return l10n.backupFailed;
      case BackupStatus.none: return "";
    }
  }

  Color _getStatusColor(BackupStatus status, ColorScheme cs) {
    switch (status) {
      case BackupStatus.success: return cs.primary;
      case BackupStatus.pending: return Colors.orange;
      case BackupStatus.failed: return cs.error;
      case BackupStatus.none: return cs.onSurface;
    }
  }

  String _getSummaryFrequencyLabel(SummaryFrequency freq, AppLocalizations l10n) {
    switch (freq) {
      case SummaryFrequency.daily: return l10n.daily;
      case SummaryFrequency.weekly: return l10n.weekly;
      case SummaryFrequency.monthly: return l10n.monthly;
    }
  }

  String _getDayOfWeekLabel(int day, AppLocalizations l10n) {
    final days = [l10n.mon, l10n.tue, l10n.wed, l10n.thu, l10n.fri, l10n.sat, l10n.sun];
    if (day >= 1 && day <= 7) return days[day - 1];
    return days[6];
  }

  void _showSummaryFrequencyPicker(BuildContext context, WidgetRef ref, SettingsState settings, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: SummaryFrequency.values.map((f) => ListTile(
            title: Text(_getSummaryFrequencyLabel(f, l10n)),
            onTap: () {
              ref.read(settingsProvider.notifier).setSummaryFrequency(f);
              Navigator.pop(context);
            },
            trailing: settings.summaryFrequency == f ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
          )).toList(),
        ),
      ),
    );
  }

  void _showSummaryDayPicker(BuildContext context, WidgetRef ref, SettingsState settings, AppLocalizations l10n) {
    final days = [l10n.mon, l10n.tue, l10n.wed, l10n.thu, l10n.fri, l10n.sat, l10n.sun];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(7, (i) => ListTile(
            title: Text(days[i]),
            onTap: () {
              ref.read(settingsProvider.notifier).setSummaryDayOfWeek(i + 1);
              Navigator.pop(context);
            },
            trailing: settings.summaryDayOfWeek == (i + 1) ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
          )),
        ),
      ),
    );
  }

  Future<void> _showSummaryTimePicker(BuildContext context, WidgetRef ref, SettingsState settings) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.summaryTimeHour, minute: settings.summaryTimeMinute),
    );
    if (time != null) {
      ref.read(settingsProvider.notifier).setSummaryTime(time.hour, time.minute);
    }
  }

  Future<void> _handlePreviewNotification(BuildContext context, WidgetRef ref, SettingsState settings, AppLocalizations l10n) async {
    final status = await Permission.notification.request();
    if (!status.isGranted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Notification permission is denied"))
        );
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Previewing notification..."))
    );
    
    // For preview, we use today's data
    final summaryService = SummaryService(DatabaseHelper.instance);
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final data = await summaryService.getSummaryData(start, now);
    
    final message = summaryService.generateDailyMessage(data, settings.currency);
    
    final notifications = FlutterLocalNotificationsPlugin();
    const android = AndroidNotificationDetails(
      'summary_channel', 'Financial Summaries',
      importance: Importance.high, priority: Priority.high,
      color: const Color(0xFF008B9C),
      styleInformation: const BigTextStyleInformation(''),
    );
    await notifications.show(999, l10n.dailySummary, message, const NotificationDetails(android: android));
  }

  Widget _buildSmsDetectionSection(
    BuildContext context,
    WidgetRef ref,
    ColorScheme cs,
    TextTheme tt,
  ) {
    final smsSettings = ref.watch(smsSettingsProvider);
    final smsNotifier = ref.read(smsSettingsProvider.notifier);

    return _SettingsSection(
      title: 'SMS Detection',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.sms_rounded,
                      size: 20,
                      color: smsSettings.isEnabled
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Automatic Detection',
                          style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Detect bank transaction messages directly on this device. SMS data stays on your device.',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.6),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch.adaptive(
                    value: smsSettings.isEnabled,
                    onChanged: (val) async {
                      if (val) {
                        final consent = await showDialog<bool>(
                          context: context,
                          builder: (_) => const SmsConsentDialog(),
                        );
                        if (consent == true) {
                          final granted = await smsNotifier.enableFeatureWithPermission();
                          if (!granted && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('SMS permission denied. Transaction detection remains OFF.'),
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        }
                      } else {
                        await smsNotifier.disableFeature();
                      }
                    },
                  ),
                ],
              ),
              if (smsSettings.isPermanentlyDenied) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.errorContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: cs.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'SMS permission is disabled in system settings.',
                          style: TextStyle(fontSize: 12, color: cs.onErrorContainer),
                        ),
                      ),
                      TextButton(
                        onPressed: () => SmsChannelService.openAppSettings(),
                        child: const Text('Open Settings', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (smsSettings.isEnabled) ...[
          const Divider(height: 1, indent: 16, endIndent: 16),
          _SettingsTile(
            icon: Icons.mark_email_unread_outlined,
            label: 'Review Pending Transactions',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: smsSettings.pendingCount > 0
                    ? cs.primary
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${smsSettings.pendingCount} Pending',
                style: tt.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: smsSettings.pendingCount > 0
                      ? cs.onPrimary
                      : cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            onTap: () => context.push('/sms-review'),
          ),
          _SettingsToggle(
            icon: Icons.auto_awesome_rounded,
            label: 'Auto-add high confidence entries',
            value: smsSettings.autoApproveHighConfidence,
            onChanged: (v) => smsNotifier.setAutoApprove(v),
          ),
        ],
        const Divider(height: 1, indent: 16, endIndent: 16),
        _SettingsTile(
          icon: Icons.history_toggle_off_rounded,
          label: 'Sync Past Bank SMS',
          onTap: () => SmsSyncHistorySheet.show(context),
        ),
      ],
    );
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

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: cs.onSurface.withOpacity(0.55)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: tt.bodyMedium),
                Text(
                  subtitle,
                  style: tt.labelSmall?.copyWith(color: cs.onSurface.withOpacity(0.5)),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
