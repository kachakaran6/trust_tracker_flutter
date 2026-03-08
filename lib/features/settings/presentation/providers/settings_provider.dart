import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trust_tracker_flutter/core/constants/app_constants.dart';
import 'package:trust_tracker_flutter/core/utils/currency_detector.dart';

class SettingsState {
  final String currency;
  final String userName;
  final bool isDarkMode;
  final bool isFirstRun;

  const SettingsState({
    this.currency = 'USD',
    this.userName = '',
    this.isDarkMode = false,
    this.isFirstRun = true,
  });

  SettingsState copyWith({
    String? currency,
    String? userName,
    bool? isDarkMode,
    bool? isFirstRun,
  }) {
    return SettingsState(
      currency: currency ?? this.currency,
      userName: userName ?? this.userName,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isFirstRun: isFirstRun ?? this.isFirstRun,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs)
      : super(SettingsState(
          // If the user has previously saved a currency, use that.
          // Otherwise detect from the device locale (first install).
          currency: _prefs.getString(AppConstants.prefCurrency) ??
              CurrencyDetector.detectSupported(),
          userName: _prefs.getString(AppConstants.prefUserName) ?? '',
          isDarkMode: _prefs.getBool(AppConstants.prefTheme) ?? false,
          isFirstRun: _prefs.getBool(AppConstants.prefIsFirstRun) ?? true,
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

