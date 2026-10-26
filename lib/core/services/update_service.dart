import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  final Ref ref;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  UpdateService(this.ref);

  /// Checks if an update is available on the Play Store.
  /// If available, triggers either immediate or flexible update based on priority.
  Future<void> checkForUpdate(BuildContext context) async {
    try {
      if (!kReleaseMode) {
        debugPrint('Update check skipped: Not in release mode');
        return;
      }

      final info = await InAppUpdate.checkForUpdate();
      final bool updateAvailable = info.updateAvailability == UpdateAvailability.updateAvailable;

      if (updateAvailable) {
        _analytics.logEvent(name: 'update_available', parameters: {
          'priority': info.updatePriority,
          'available_version_code': info.availableVersionCode as Object,
        });

        _showUpdateNotification();

        // Priority >= 4 is considered a critical update (can be adjusted)
        if (info.updatePriority >= 4) {
          await _performImmediateUpdate(context);
        } else {
          await _performFlexibleUpdate(context, info);
        }
      }
    } catch (e) {
      if (e.toString().contains('ERROR_APP_NOT_OWNED')) {
        debugPrint('In-app update skipped: app not from Play Store (expected in debug/APK)');
        return;
      }
      debugPrint('Update check failed: $e');
    }
  }

  Future<void> _showUpdateNotification() async {
    try {
      final notifications = FlutterLocalNotificationsPlugin();
      const androidInit = AndroidInitializationSettings('tt_stat_icon');
      await notifications.initialize(const InitializationSettings(android: androidInit));

      const androidDetails = AndroidNotificationDetails(
        'update_channel', 'App Updates',
        channelDescription: 'Notifications for app updates',
        importance: Importance.max, 
        priority: Priority.high,
        color: Color(0xFF008B9C),
        icon: 'tt_stat_icon',
        styleInformation: BigTextStyleInformation('A new version of Trust Tracker is ready with improvements, fixes, and new features.'),
      );

      await notifications.show(
        300,
        'New Update Available! \uD83C\uDF89',
        'A new version of Trust Tracker is ready with improvements, fixes, and new features.',
        const NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('Failed to show update notification: $e');
    }
  }

  Future<void> _performImmediateUpdate(BuildContext context) async {
    try {
      _analytics.logEvent(name: 'update_started', parameters: {'type': 'immediate'});
      await InAppUpdate.performImmediateUpdate();
      _analytics.logEvent(name: 'update_completed', parameters: {'type': 'immediate'});
    } catch (e) {
      debugPrint('Immediate update failed: $e');
      _analytics.logEvent(name: 'update_skipped', parameters: {'type': 'immediate', 'error': e.toString()});
    }
  }

  Future<void> _performFlexibleUpdate(BuildContext context, AppUpdateInfo info) async {
    try {
      if (!context.mounted) return;
      
      // We can still show our custom UI before starting the flexible update
      // But the user requested the "Modern update card". We will use our custom dialog
      // to prompt them, and if they click "Update Now", we start the flexible update.
      _showUpdateDialog(context, info);
    } catch (e) {
      debugPrint('Flexible update init failed: $e');
    }
  }

  /// Manually check for updates from settings.
  Future<bool> manualCheck(BuildContext context) async {
    try {
      if (!kReleaseMode) {
        _showUpdateDialog(context, null, isDebug: true);
        return true;
      }

      final info = await InAppUpdate.checkForUpdate();
      final bool updateAvailable = info.updateAvailability == UpdateAvailability.updateAvailable;

      if (updateAvailable) {
        if (!context.mounted) return true;
        
        _showUpdateNotification();
        
        if (info.updatePriority >= 4) {
           await _performImmediateUpdate(context);
        } else {
           _showUpdateDialog(context, info);
        }
        return true;
      }
      return false;
    } catch (e) {
      if (e.toString().contains('ERROR_APP_NOT_OWNED')) {
        debugPrint(
            'In-app update skipped: app not from Play Store (expected in debug/APK)');
        return false;
      }
      debugPrint('Manual update check failed: $e');
      return false;
    }
  }

  void _showUpdateDialog(BuildContext context, AppUpdateInfo? info, {bool isDebug = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
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
            child: Icon(Icons.system_update_rounded, size: 32, color: cs.primary),
          ),
          title: Text(
            'Update Available',
            textAlign: TextAlign.center,
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          content: Text(
            'A new version of Trust Tracker is ready with improvements, fixes, and new features.',
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(color: cs.onSurface.withOpacity(0.6), height: 1.5),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          actions: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                    
                    if (isDebug) {
                      debugPrint('Debug mode: Update Now clicked');
                      return;
                    }

                    _analytics.logEvent(name: 'update_started', parameters: {'type': 'flexible'});
                    try {
                      await InAppUpdate.startFlexibleUpdate();
                      await InAppUpdate.completeFlexibleUpdate();
                      _analytics.logEvent(name: 'update_completed', parameters: {'type': 'flexible'});
                    } catch (e) {
                      debugPrint('Flexible update error: $e');
                      _analytics.logEvent(name: 'update_skipped', parameters: {'type': 'flexible', 'error': e.toString()});
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text(
                    'Update Now',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    _analytics.logEvent(name: 'update_skipped', parameters: {'type': 'flexible', 'reason': 'user_dismissed'});
                  },
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: cs.onSurface.withOpacity(0.5),
                  ),
                  child: const Text(
                    'Later',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        );
      },
    );
  }

  Future<void> _openPlayStore() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final packageName = packageInfo.packageName;
      final url = Uri.parse("https://play.google.com/store/apps/details?id=$packageName");
      
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      debugPrint('Error opening Play Store: $e');
    }
  }

  /// Get current app version for reference
  Future<String> getCurrentVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return "${packageInfo.version}+${packageInfo.buildNumber}";
  }
}

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService(ref);
});
