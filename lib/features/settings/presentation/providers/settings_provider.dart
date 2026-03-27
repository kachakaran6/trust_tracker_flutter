import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trust_tracker_flutter/core/constants/app_constants.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';
import 'package:trust_tracker_flutter/core/utils/currency_detector.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Transaction Action Mode — Issue 8
// ─────────────────────────────────────────────────────────────────────────────
enum TransactionActionMode { swipe, tap }

class SettingsState {
  final String currency;
  final String userName;
  final bool isDarkMode;
  final bool isFirstRun;
  final TransactionActionMode transactionActionMode;
  final String languageCode;
  final String accentColorHex;

  const SettingsState({
    this.currency = 'USD',
    this.userName = '',
    this.isDarkMode = false,
    this.isFirstRun = true,
    this.transactionActionMode = TransactionActionMode.swipe,
    this.languageCode = 'en',
    this.accentColorHex = '#3B82F6', // Default Blue
  });

  SettingsState copyWith({
    String? currency,
    String? userName,
    bool? isDarkMode,
    bool? isFirstRun,
    TransactionActionMode? transactionActionMode,
    String? languageCode,
    String? accentColorHex,
  }) {
    return SettingsState(
      currency: currency ?? this.currency,
      userName: userName ?? this.userName,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isFirstRun: isFirstRun ?? this.isFirstRun,
      transactionActionMode:
          transactionActionMode ?? this.transactionActionMode,
      languageCode: languageCode ?? this.languageCode,
      accentColorHex: accentColorHex ?? this.accentColorHex,
    );
  }
}

const _kTxnActionMode = 'txn_action_mode';

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs)
      : super(SettingsState(
          currency: _prefs.getString(AppConstants.prefCurrency) ??
              CurrencyDetector.detectSupported(),
          userName: _prefs.getString(AppConstants.prefUserName) ?? '',
          isDarkMode: _prefs.getBool(AppConstants.prefTheme) ?? false,
          isFirstRun: _prefs.getBool(AppConstants.prefIsFirstRun) ?? true,
          transactionActionMode: _prefs.getString(_kTxnActionMode) == 'tap'
              ? TransactionActionMode.tap
              : TransactionActionMode.swipe,
          languageCode: _prefs.getString(AppConstants.prefLanguage) ?? 'en',
          accentColorHex: _prefs.getString(AppConstants.prefAccentColor) ?? '#3B82F6',
        ));

  Future<void> setCurrency(String code) async {
    await _prefs.setString(AppConstants.prefCurrency, code);
    state = state.copyWith(currency: code);
  }

  Future<void> setUserName(String name) async {
    await _prefs.setString(AppConstants.prefUserName, name);
    state = state.copyWith(userName: name);
  }

  Future<void> setDarkMode(bool dark) async {
    await _prefs.setBool(AppConstants.prefTheme, dark);
    state = state.copyWith(isDarkMode: dark);
  }

  Future<void> setTransactionActionMode(TransactionActionMode mode) async {
    await _prefs.setString(
        _kTxnActionMode, mode == TransactionActionMode.tap ? 'tap' : 'swipe');
    state = state.copyWith(transactionActionMode: mode);
  }

  Future<void> setLanguage(String code) async {
    await _prefs.setString(AppConstants.prefLanguage, code);
    state = state.copyWith(languageCode: code);
  }

  Future<void> setAccentColor(String hex) async {
    await _prefs.setString(AppConstants.prefAccentColor, hex);
    state = state.copyWith(accentColorHex: hex);
  }


  Future<void> completeOnboarding(String name, String currency) async {
    await _prefs.setString(AppConstants.prefUserName, name);
    await _prefs.setString(AppConstants.prefCurrency, currency);
    await _prefs.setBool(AppConstants.prefIsFirstRun, false);
    state = state.copyWith(
      userName: name,
      currency: currency,
      isFirstRun: false,
    );
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  throw UnimplementedError('Initialize with SharedPreferences override');
});
