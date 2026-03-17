import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UpdateService {
  final Ref ref;

  UpdateService(this.ref);

  /// Checks if an update is available on the Play Store.
  /// This should be called during app launch and when app returns to foreground.
  Future<void> checkForUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        // Decide whether to force immediate or allow flexible update.
        // For demonstration, we check a flag or version gap.
        if (info.immediateUpdateAllowed) {
          await _performImmediateUpdate();
        } else if (info.flexibleUpdateAllowed) {
          await _performFlexibleUpdate();
        }
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
  }

  /// Manually check for updates from settings.
  /// Returns false if no update found or error occurs.
  Future<bool> manualCheck(BuildContext context) async {
    try {
      final info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (info.flexibleUpdateAllowed) {
          final startUpdate = await _showUpdateDialog(context, info);
          if (startUpdate == true) {
            await _performFlexibleUpdate();
          }
          return true;
        } else if (info.immediateUpdateAllowed) {
          await _performImmediateUpdate();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Manual update check failed: $e');
      return false;
    }
  }

  Future<void> _performFlexibleUpdate() async {
    try {
      await InAppUpdate.startFlexibleUpdate();
      // Once downloaded, we can prompt users to complete the update.
      await InAppUpdate.completeFlexibleUpdate();
    } catch (e) {
      debugPrint('Flexible update failed: $e');
    }
  }

  Future<void> _performImmediateUpdate() async {
    try {
      await InAppUpdate.performImmediateUpdate();
    } catch (e) {
      debugPrint('Immediate update failed: $e');
    }
  }

  Future<bool?> _showUpdateDialog(BuildContext context, AppUpdateInfo info) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.system_update_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              const Text('Update Available'),
            ],
          ),
          content: const Text(
            'A new version of the app is available on the Play Store. Update now to get the latest features and improvements.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Later',
                style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Update Now'),
            ),
          ],
        );
      },
    );
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
