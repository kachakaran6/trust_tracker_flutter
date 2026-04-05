import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  final Ref ref;

  UpdateService(this.ref);

  /// Checks if an update is available on the Play Store.
  /// If available, shows a custom dialog to the user.
  /// Set [isDebugUpdateTest] to true to simulate update available in debug mode.
  static const bool isDebugUpdateTest = false;

  Future<void> checkForUpdate(BuildContext context) async {
    try {
      bool updateAvailable = false;
      AppUpdateInfo? info;

      // Simulation logic for testing UI without Play Store dependency
      if (!kReleaseMode && isDebugUpdateTest) {
        updateAvailable = true;
      } else {
        info = await InAppUpdate.checkForUpdate();
        updateAvailable =
            info.updateAvailability == UpdateAvailability.updateAvailable;
      }

      if (updateAvailable) {
        if (!context.mounted) return;
        _showUpdateDialog(context, info);
      }
    } catch (e) {
      if (e.toString().contains('ERROR_APP_NOT_OWNED')) {
        debugPrint(
            'In-app update skipped: app not from Play Store (expected in debug/APK)');
        return;
      }
      debugPrint('Update check failed: $e');
    }
  }

  /// Manually check for updates from settings.
  Future<bool> manualCheck(BuildContext context) async {
    try {
      bool updateAvailable = false;
      AppUpdateInfo? info;

      if (!kReleaseMode && isDebugUpdateTest) {
        updateAvailable = true;
      } else {
        info = await InAppUpdate.checkForUpdate();
        updateAvailable =
            info.updateAvailability == UpdateAvailability.updateAvailable;
      }

      if (updateAvailable) {
        if (!context.mounted) return true;
        _showUpdateDialog(context, info);
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

  /// Trigger the update dialog manually for UI testing.
  void testUpdateUI(BuildContext context) {
    _showUpdateDialog(context, null);
  }

  void _showUpdateDialog(BuildContext context, AppUpdateInfo? info) {
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
            'A new version of Trust Tracker is available. Please update to get the latest features and security improvements.',
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
                    await _openPlayStore();
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
