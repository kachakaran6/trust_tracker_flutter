import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trust_tracker_flutter/core/constants/app_constants.dart';

// ── Secure Storage ─────────────────────────────────────────────────────────
const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

const _kPin = 'app_pin';
const _kPinEnabled = 'pin_enabled';
const _kBioEnabled = 'bio_enabled';

// ── Security State ─────────────────────────────────────────────────────────
class SecurityState {
  final bool isPinEnabled;
  final bool isBiometricEnabled;
  final bool isLocked;
  final bool canUseBiometrics;
  final bool isAppVisible; // For Recents screen protection
  final int failedAttempts;
  final DateTime? lockUntil;

  const SecurityState({
    this.isPinEnabled = false,
    this.isBiometricEnabled = false,
    this.isLocked = false,
    this.canUseBiometrics = false,
    this.isAppVisible = true,
    this.failedAttempts = 0,
    this.lockUntil,
  });

  SecurityState copyWith({
    bool? isPinEnabled,
    bool? isBiometricEnabled,
    bool? isLocked,
    bool? canUseBiometrics,
    bool? isAppVisible,
    int? failedAttempts,
    DateTime? lockUntil,
    bool clearLockUntil = false,
  }) {
    return SecurityState(
      isPinEnabled: isPinEnabled ?? this.isPinEnabled,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      isLocked: isLocked ?? this.isLocked,
      canUseBiometrics: canUseBiometrics ?? this.canUseBiometrics,
      isAppVisible: isAppVisible ?? this.isAppVisible,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockUntil: clearLockUntil ? null : (lockUntil ?? this.lockUntil),
    );
  }
}

// ── Security Notifier ───────────────────────────────────────────────────────
class SecurityNotifier extends StateNotifier<SecurityState> {
  final LocalAuthentication _localAuth;
  final SharedPreferences _prefs;

  SecurityNotifier(this._localAuth, this._prefs) : super(const SecurityState()) {
    _init();
  }

  Future<void> _init() async {
    final pinEnabled = await _storage.read(key: _kPinEnabled);
    final bioEnabled = await _storage.read(key: _kBioEnabled);
    final canAuth = await _localAuth.canCheckBiometrics;
    final available = await _localAuth.getAvailableBiometrics();
    final hasBio = canAuth && (available.isNotEmpty || await _localAuth.isDeviceSupported());

    final failedAttempts = _prefs.getInt(AppConstants.prefPinAttempts) ?? 0;
    final lockUntilTimestamp = _prefs.getInt(AppConstants.prefPinLockUntil);
    final lockUntil = lockUntilTimestamp != null ? DateTime.fromMillisecondsSinceEpoch(lockUntilTimestamp) : null;

    state = state.copyWith(
      isPinEnabled: pinEnabled == 'true',
      isBiometricEnabled: bioEnabled == 'true' && hasBio,
      isLocked: pinEnabled == 'true',
      canUseBiometrics: hasBio,
      failedAttempts: failedAttempts,
      lockUntil: lockUntil,
    );
  }

  /// Verify PIN. Returns true on match and unlocks the app.
  Future<bool> verifyPin(String pin) async {
    if (state.lockUntil != null && DateTime.now().isBefore(state.lockUntil!)) {
      return false; // Still locked
    }

    final stored = await _storage.read(key: _kPin);
    if (stored == pin) {
      await _resetAttempts();
      state = state.copyWith(isLocked: false);
      return true;
    } else {
      await _incrementAttempts();
      return false;
    }
  }

  Future<void> _incrementAttempts() async {
    final newAttempts = state.failedAttempts + 1;
    
    if (newAttempts >= 5) {
      final lockUntil = DateTime.now().add(const Duration(minutes: 1));
      state = state.copyWith(lockUntil: lockUntil, failedAttempts: 5);
      await _prefs.setInt(AppConstants.prefPinLockUntil, lockUntil.millisecondsSinceEpoch);
      await _prefs.setInt(AppConstants.prefPinAttempts, 0);
    } else {
      state = state.copyWith(failedAttempts: newAttempts);
      await _prefs.setInt(AppConstants.prefPinAttempts, newAttempts);
    }
  }

  Future<void> _resetAttempts() async {
    state = state.copyWith(failedAttempts: 0, clearLockUntil: true);
    await _prefs.setInt(AppConstants.prefPinAttempts, 0);
    await _prefs.remove(AppConstants.prefPinLockUntil);
  }

  /// Verify OLD pin without unlocking – used during flows where verification is required.
  Future<bool> verifyOldPin(String pin) async {
    final stored = await _storage.read(key: _kPin);
    return stored == pin;
  }

  /// Attempt biometric authentication. On success, unlocks the app.
  Future<bool> authenticateBiometric() async {
    if (!state.isBiometricEnabled || !state.canUseBiometrics) return false;
    
    try {
      final success = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access your Trust Tracker',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      
      if (success) {
        state = state.copyWith(isLocked: false);
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  /// Set a brand new PIN (replaces existing).
  Future<void> setPin(String pin) async {
    await _storage.write(key: _kPin, value: pin);
    await _storage.write(key: _kPinEnabled, value: 'true');
    state = state.copyWith(isPinEnabled: true, isLocked: false);
  }

  Future<void> disablePin() async {
    await _storage.delete(key: _kPin);
    await _storage.delete(key: _kPinEnabled);
    await _storage.delete(key: _kBioEnabled);
    
    state = state.copyWith(
      isPinEnabled: false,
      isBiometricEnabled: false,
      isLocked: false,
    );
  }

  Future<void> setBiometric(bool enabled) async {
    if (enabled && !state.isPinEnabled) return; // Feature 1: Cannot enable without PIN

    await _storage.write(key: _kBioEnabled, value: enabled.toString());
    state = state.copyWith(isBiometricEnabled: enabled);
  }

  /// Update app visibility (called on background/pause).
  /// This is used to overlay a blur/shield in the Recents screen.
  void setVisibility(bool visible) {
    if (state.isPinEnabled) {
      state = state.copyWith(
        isAppVisible: visible,
        isLocked: !visible ? true : state.isLocked,
      );
    }
  }

  void lock() {
    if (state.isPinEnabled) {
      state = state.copyWith(isLocked: true);
    }
  }
}

// ── Providers ───────────────────────────────────────────────────────────────
final localAuthProvider = Provider<LocalAuthentication>((ref) {
  return LocalAuthentication();
});

final securityProvider =
    StateNotifierProvider<SecurityNotifier, SecurityState>((ref) {
  throw UnimplementedError('Initialize with SharedPreferences override');
});
