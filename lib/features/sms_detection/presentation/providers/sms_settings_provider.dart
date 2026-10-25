import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trust_tracker_flutter/core/database/database_helper.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/repositories/sms_transaction_repository_impl.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/services/sms_channel_service.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/repositories/sms_transaction_repository.dart';

class SmsSettingsState {
  final bool isEnabled;
  final bool hasPermission;
  final bool autoApproveHighConfidence;
  final int pendingCount;
  final bool isPermanentlyDenied;

  const SmsSettingsState({
    this.isEnabled = false,
    this.hasPermission = false,
    this.autoApproveHighConfidence = false,
    this.pendingCount = 0,
    this.isPermanentlyDenied = false,
  });

  SmsSettingsState copyWith({
    bool? isEnabled,
    bool? hasPermission,
    bool? autoApproveHighConfidence,
    int? pendingCount,
    bool? isPermanentlyDenied,
  }) {
    return SmsSettingsState(
      isEnabled: isEnabled ?? this.isEnabled,
      hasPermission: hasPermission ?? this.hasPermission,
      autoApproveHighConfidence:
          autoApproveHighConfidence ?? this.autoApproveHighConfidence,
      pendingCount: pendingCount ?? this.pendingCount,
      isPermanentlyDenied: isPermanentlyDenied ?? this.isPermanentlyDenied,
    );
  }
}

class SmsSettingsNotifier extends StateNotifier<SmsSettingsState> {
  final SharedPreferences _prefs;
  final SmsTransactionRepository _smsRepo;

  static const String prefKeyEnabled = 'sms_detection_enabled';
  static const String prefKeyAutoApprove = 'sms_auto_approve_high_confidence';

  SmsSettingsNotifier(this._prefs, this._smsRepo)
      : super(SmsSettingsState(
          isEnabled: _prefs.getBool(prefKeyEnabled) ?? false,
          autoApproveHighConfidence: _prefs.getBool(prefKeyAutoApprove) ?? false,
        )) {
    _init();
  }

  Future<void> _init() async {
    await checkPermissionState();
    await refreshPendingCount();
  }

  Future<void> checkPermissionState() async {
    final granted = await SmsChannelService.checkPermission();
    // Safety requirement: do not display "Enabled" if permission is not granted
    final effectiveEnabled = state.isEnabled && granted;
    if (state.isEnabled != effectiveEnabled) {
      await _prefs.setBool(prefKeyEnabled, effectiveEnabled);
      await SmsChannelService.setDetectionEnabled(effectiveEnabled);
    }
    state = state.copyWith(
      hasPermission: granted,
      isEnabled: effectiveEnabled,
    );
  }

  Future<bool> enableFeatureWithPermission() async {
    final granted = await SmsChannelService.requestPermission();
    if (granted) {
      await _prefs.setBool(prefKeyEnabled, true);
      await SmsChannelService.setDetectionEnabled(true);
      state = state.copyWith(
        isEnabled: true,
        hasPermission: true,
        isPermanentlyDenied: false,
      );
      return true;
    } else {
      // Check if permission is completely denied
      final stillGranted = await SmsChannelService.checkPermission();
      state = state.copyWith(
        isEnabled: false,
        hasPermission: stillGranted,
        isPermanentlyDenied: !stillGranted,
      );
      await _prefs.setBool(prefKeyEnabled, false);
      await SmsChannelService.setDetectionEnabled(false);
      return false;
    }
  }

  Future<void> disableFeature() async {
    await _prefs.setBool(prefKeyEnabled, false);
    await SmsChannelService.setDetectionEnabled(false);
    state = state.copyWith(isEnabled: false);
  }

  Future<void> setAutoApprove(bool auto) async {
    await _prefs.setBool(prefKeyAutoApprove, auto);
    state = state.copyWith(autoApproveHighConfidence: auto);
  }

  Future<void> refreshPendingCount() async {
    final count = await _smsRepo.getPendingCount();
    state = state.copyWith(pendingCount: count);
  }

  Future<void> clearAllPendingRecords() async {
    await _smsRepo.deleteAllPendingRecords();
    await refreshPendingCount();
  }
}

// Global providers
final smsRepositoryProvider = Provider<SmsTransactionRepository>((ref) {
  return SmsTransactionRepositoryImpl(DatabaseHelper.instance);
});

final smsSettingsProvider =
    StateNotifierProvider<SmsSettingsNotifier, SmsSettingsState>((ref) {
  throw UnimplementedError('Initialize with SharedPreferences in main or overrides');
});
