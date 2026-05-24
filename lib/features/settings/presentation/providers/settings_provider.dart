import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trust_tracker_flutter/core/constants/app_constants.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';
import 'package:trust_tracker_flutter/core/utils/currency_detector.dart';
import 'package:trust_tracker_flutter/core/database/database_helper.dart';
import 'package:trust_tracker_flutter/core/services/background_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Transaction Action Mode — Issue 8
// ─────────────────────────────────────────────────────────────────────────────
enum TransactionActionMode { swipe, tap }
enum BackupInterval { hours6, hours12, daily, weekly, custom }
enum BackupStatus { success, pending, failed, none }
enum SummaryFrequency { daily, weekly, monthly }

class SettingsState {
  final String currency;
  final String userName;
  final bool isDarkMode;
  final bool isFirstRun;
  final TransactionActionMode transactionActionMode;
  final String languageCode;
  final String accentColorHex;
  final String? userAvatar;
  final int monthStartDay;
  final bool carryForwardEnabled;
  final bool autoBackupEnabled;
  final BackupInterval backupInterval;
  final DateTime? lastBackupTime;
  final BackupStatus lastBackupStatus;
  final bool summaryNotificationsEnabled;
  final SummaryFrequency summaryFrequency;
  final int summaryTimeHour;
  final int summaryTimeMinute;
  final int summaryDayOfWeek; // 1 (Mon) - 7 (Sun)
  final int customBackupHours;

  const SettingsState({
    this.currency = 'USD',
    this.userName = '',
    this.isDarkMode = false,
    this.isFirstRun = true,
    this.transactionActionMode = TransactionActionMode.swipe,
    this.languageCode = 'en',
    this.accentColorHex = '#3B82F6', // Default Blue
    this.userAvatar,
    this.monthStartDay = 1,
    this.carryForwardEnabled = false,
    this.autoBackupEnabled = false,
    this.backupInterval = BackupInterval.daily,
    this.lastBackupTime,
    this.lastBackupStatus = BackupStatus.none,
    this.summaryNotificationsEnabled = false,
    this.summaryFrequency = SummaryFrequency.daily,
    this.summaryTimeHour = 21, // Default 9 PM
    this.summaryTimeMinute = 0,
    this.summaryDayOfWeek = 7, // Default Sunday
    this.customBackupHours = 24,
  });

  SettingsState copyWith({
    String? currency,
    String? userName,
    bool? isDarkMode,
    bool? isFirstRun,
    TransactionActionMode? transactionActionMode,
    String? languageCode,
    String? accentColorHex,
    String? userAvatar,
    int? monthStartDay,
    bool? carryForwardEnabled,
    bool? autoBackupEnabled,
    BackupInterval? backupInterval,
    DateTime? lastBackupTime,
    BackupStatus? lastBackupStatus,
    bool? summaryNotificationsEnabled,
    SummaryFrequency? summaryFrequency,
    int? summaryTimeHour,
    int? summaryTimeMinute,
    int? summaryDayOfWeek,
    int? customBackupHours,
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
      userAvatar: userAvatar ?? this.userAvatar,
      monthStartDay: monthStartDay ?? this.monthStartDay,
      carryForwardEnabled: carryForwardEnabled ?? this.carryForwardEnabled,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      backupInterval: backupInterval ?? this.backupInterval,
      lastBackupTime: lastBackupTime ?? this.lastBackupTime,
      lastBackupStatus: lastBackupStatus ?? this.lastBackupStatus,
      summaryNotificationsEnabled: summaryNotificationsEnabled ?? this.summaryNotificationsEnabled,
      summaryFrequency: summaryFrequency ?? this.summaryFrequency,
      summaryTimeHour: summaryTimeHour ?? this.summaryTimeHour,
      summaryTimeMinute: summaryTimeMinute ?? this.summaryTimeMinute,
      summaryDayOfWeek: summaryDayOfWeek ?? this.summaryDayOfWeek,
      customBackupHours: customBackupHours ?? this.customBackupHours,
    );
  }

  Map<String, dynamic> toJson() => {
        'currency': currency,
        'userName': userName,
        'isDarkMode': isDarkMode,
        'isFirstRun': isFirstRun,
        'transactionActionMode': transactionActionMode.name,
        'languageCode': languageCode,
        'accentColorHex': accentColorHex,
        'userAvatar': userAvatar,
        'monthStartDay': monthStartDay,
        'carryForwardEnabled': carryForwardEnabled,
        'autoBackupEnabled': autoBackupEnabled,
        'backupInterval': backupInterval.name,
        'lastBackupTime': lastBackupTime?.toIso8601String(),
        'lastBackupStatus': lastBackupStatus.name,
        'summaryNotificationsEnabled': summaryNotificationsEnabled,
        'summaryFrequency': summaryFrequency.name,
        'summaryTimeHour': summaryTimeHour,
        'summaryTimeMinute': summaryTimeMinute,
        'summaryDayOfWeek': summaryDayOfWeek,
        'customBackupHours': customBackupHours,
      };

  factory SettingsState.fromJson(Map<String, dynamic> json) => SettingsState(
        currency: json['currency'] ?? 'USD',
        userName: json['userName'] ?? '',
        isDarkMode: json['isDarkMode'] ?? false,
        isFirstRun: json['isFirstRun'] ?? true,
        transactionActionMode: json['transactionActionMode'] == 'tap'
            ? TransactionActionMode.tap
            : TransactionActionMode.swipe,
        languageCode: json['languageCode'] ?? 'en',
        accentColorHex: json['accentColorHex'] ?? '#3B82F6',
        userAvatar: json['userAvatar'],
        monthStartDay: json['monthStartDay'] ?? 1,
        carryForwardEnabled: json['carryForwardEnabled'] ?? false,
        autoBackupEnabled: json['autoBackupEnabled'] ?? false,
        backupInterval: BackupInterval.values.firstWhere(
          (e) => e.name == json['backupInterval'],
          orElse: () => BackupInterval.daily,
        ),
        lastBackupTime: json['lastBackupTime'] != null
            ? DateTime.parse(json['lastBackupTime'])
            : null,
        lastBackupStatus: BackupStatus.values.firstWhere(
          (e) => e.name == json['lastBackupStatus'],
          orElse: () => BackupStatus.none,
        ),
        summaryNotificationsEnabled: json['summaryNotificationsEnabled'] ?? false,
        summaryFrequency: SummaryFrequency.values.firstWhere(
          (e) => e.name == json['summaryFrequency'],
          orElse: () => SummaryFrequency.daily,
        ),
        summaryTimeHour: json['summaryTimeHour'] ?? 21,
        summaryTimeMinute: json['summaryTimeMinute'] ?? 0,
        summaryDayOfWeek: json['summaryDayOfWeek'] ?? 7,
        customBackupHours: json['customBackupHours'] ?? 24,
      );
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
          userAvatar: _prefs.getString(AppConstants.prefUserAvatar),
          autoBackupEnabled: _prefs.getBool('auto_backup_enabled') ?? false,
          backupInterval: BackupInterval.values.firstWhere(
            (e) => e.name == _prefs.getString('backup_interval'),
            orElse: () => BackupInterval.daily,
          ),
          lastBackupTime: _prefs.getString('last_backup_time') != null
              ? DateTime.parse(_prefs.getString('last_backup_time')!)
              : null,
          lastBackupStatus: BackupStatus.values.firstWhere(
            (e) => e.name == _prefs.getString('last_backup_status'),
            orElse: () => BackupStatus.none,
          ),
          summaryNotificationsEnabled: _prefs.getBool('summary_notifications_enabled') ?? false,
          summaryFrequency: SummaryFrequency.values.firstWhere(
            (e) => e.name == _prefs.getString('summary_frequency'),
            orElse: () => SummaryFrequency.daily,
          ),
          summaryTimeHour: _prefs.getInt('summary_time_hour') ?? 21,
          summaryTimeMinute: _prefs.getInt('summary_time_minute') ?? 0,
          summaryDayOfWeek: _prefs.getInt('summary_day_of_week') ?? 7,
          customBackupHours: _prefs.getInt('custom_backup_hours') ?? 24,
        )) {
    _loadFinancialSettings();
  }

  Future<void> _loadFinancialSettings() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> maps = await db.query('app_settings', where: 'id = 1');
      if (maps.isNotEmpty) {
        final data = maps.first;
        state = state.copyWith(
          monthStartDay: data['monthStartDay'] as int,
          carryForwardEnabled: (data['carryForwardEnabled'] as int) == 1,
        );
      }
    } catch (e) {
      // Fallback to defaults already in state
    }
  }

  Future<void> setMonthStartDay(int day) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'app_settings',
      {'monthStartDay': day},
      where: 'id = 1',
    );
    state = state.copyWith(monthStartDay: day);
  }

  Future<void> setCarryForwardEnabled(bool enabled) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'app_settings',
      {'carryForwardEnabled': enabled ? 1 : 0},
      where: 'id = 1',
    );
    state = state.copyWith(carryForwardEnabled: enabled);
  }

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

  Future<void> setUserAvatar(String? path) async {
    if (path == null) {
      await _prefs.remove(AppConstants.prefUserAvatar);
    } else {
      await _prefs.setString(AppConstants.prefUserAvatar, path);
    }
    state = state.copyWith(userAvatar: path);
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    await _prefs.setBool('auto_backup_enabled', enabled);
    state = state.copyWith(autoBackupEnabled: enabled);
    
    if (enabled) {
      await BackgroundService.scheduleBackup(state.backupInterval);
    } else {
      await BackgroundService.stopBackups();
    }
  }

  Future<void> setBackupInterval(BackupInterval interval, {int? customHours}) async {
    await _prefs.setString('backup_interval', interval.name);
    if (customHours != null) {
      await _prefs.setInt('custom_backup_hours', customHours);
    }
    state = state.copyWith(
      backupInterval: interval,
      customBackupHours: customHours,
    );
    
    if (state.autoBackupEnabled) {
      await BackgroundService.scheduleBackup(interval, customHours: customHours ?? state.customBackupHours);
    }
  }

  Future<void> setLastBackupInfo(DateTime time, BackupStatus status) async {
    await _prefs.setString('last_backup_time', time.toIso8601String());
    await _prefs.setString('last_backup_status', status.name);
    state = state.copyWith(lastBackupTime: time, lastBackupStatus: status);
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

  Future<void> restoreSettings(SettingsState other) async {
    await _prefs.setString(AppConstants.prefCurrency, other.currency);
    await _prefs.setString(AppConstants.prefUserName, other.userName);
    await _prefs.setBool(AppConstants.prefTheme, other.isDarkMode);
    await _prefs.setBool(AppConstants.prefIsFirstRun, other.isFirstRun);
    await _prefs.setString(_kTxnActionMode,
        other.transactionActionMode == TransactionActionMode.tap ? 'tap' : 'swipe');
    await _prefs.setString(AppConstants.prefLanguage, other.languageCode);
    await _prefs.setString(AppConstants.prefAccentColor, other.accentColorHex);
    state = other;
  }

  Future<void> setSummaryNotificationsEnabled(bool enabled) async {
    await _prefs.setBool('summary_notifications_enabled', enabled);
    state = state.copyWith(summaryNotificationsEnabled: enabled);
    
    if (enabled) {
      await BackgroundService.scheduleSummaryNotification(
        state.summaryFrequency,
        state.summaryTimeHour,
        state.summaryTimeMinute,
        dayOfWeek: state.summaryDayOfWeek,
      );
    } else {
      await BackgroundService.cancelSummaryNotifications();
    }
  }

  Future<void> setSummaryFrequency(SummaryFrequency frequency) async {
    await _prefs.setString('summary_frequency', frequency.name);
    state = state.copyWith(summaryFrequency: frequency);
    
    if (state.summaryNotificationsEnabled) {
      await BackgroundService.scheduleSummaryNotification(
        frequency,
        state.summaryTimeHour,
        state.summaryTimeMinute,
        dayOfWeek: state.summaryDayOfWeek,
      );
    }
  }

  Future<void> setSummaryTime(int hour, int minute) async {
    await _prefs.setInt('summary_time_hour', hour);
    await _prefs.setInt('summary_time_minute', minute);
    state = state.copyWith(summaryTimeHour: hour, summaryTimeMinute: minute);
    
    if (state.summaryNotificationsEnabled) {
      await BackgroundService.scheduleSummaryNotification(
        state.summaryFrequency,
        hour,
        minute,
        dayOfWeek: state.summaryDayOfWeek,
      );
    }
  }

  Future<void> setSummaryDayOfWeek(int day) async {
    await _prefs.setInt('summary_day_of_week', day);
    state = state.copyWith(summaryDayOfWeek: day);
    
    if (state.summaryNotificationsEnabled && state.summaryFrequency == SummaryFrequency.weekly) {
      await BackgroundService.scheduleSummaryNotification(
        state.summaryFrequency,
        state.summaryTimeHour,
        state.summaryTimeMinute,
        dayOfWeek: day,
      );
    }
  }

  Future<void> resetAll() async {
    await _prefs.clear();
    state = const SettingsState();
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  throw UnimplementedError('Initialize with SharedPreferences override');
});
