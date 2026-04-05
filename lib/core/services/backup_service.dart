import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:trust_tracker_flutter/core/database/database_helper.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/categories/data/models/category_model.dart';
import 'package:trust_tracker_flutter/features/budget/data/models/budget_model.dart';
import 'package:trust_tracker_flutter/core/di/providers.dart';

class BackupService {
  final DatabaseHelper _dbHelper;
  final SettingsNotifier _settingsNotifier;

  BackupService(this._dbHelper, this._settingsNotifier);

  Future<String?> exportData() async {
    print("BackupService: Export started");
    try {
      final db = await _dbHelper.database;
      
      // 1. Fetch all data
      print("BackupService: Fetching data from DB...");
      final transactionsData = await db.query('transactions');
      final categoriesData = await db.query('categories');
      final budgetsData = await db.query('budgets');
      final settings = _settingsNotifier.state;

      // 2. Prepare data map
      final backup = {
        "version": "1.0",
        "exportedAt": DateTime.now().toIso8601String(),
        "data": {
          "transactions": transactionsData,
          "categories": categoriesData,
          "budgets": budgetsData,
          "settings": settings.toJson(),
        }
      };

      // 4. Encode to JSON in background thread (Compute)
      print("BackupService: Encoding JSON (Background thread)...");
      final jsonString = await compute(_jsonEncodeTask, backup);
      print("BackupService: JSON size: ${jsonString.length} bytes");

      final fileName = "trust_tracker_backup_${DateTime.now().millisecondsSinceEpoch}.json";

      // 5. Save to a temporary location
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      print("BackupService: Writing file to: ${file.path}");
      await file.writeAsString(jsonString);
      
      print("BackupService: Export complete");
      return file.path;
    } catch (e) {
      print("BackupService ERROR: $e");
      return null;
    }
  }

  static String _jsonEncodeTask(Map<String, dynamic> data) {
    return jsonEncode(data);
  }

  Future<bool> importData() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();
        final backup = jsonDecode(jsonString);

        if (backup['version'] == null || backup['data'] == null) return false;

        final data = backup['data'];
        final transactionsJson = data['transactions'] as List?;
        final categoriesJson = data['categories'] as List?;
        final budgetsJson = data['budgets'] as List?;
        final settingsJson = data['settings'];

        final db = await _dbHelper.database;

        await db.transaction((txn) async {
          if (categoriesJson != null) {
            await txn.delete('categories');
            for (var c in categoriesJson) {
              await txn.insert('categories', c);
            }
          }

          if (transactionsJson != null) {
            await txn.delete('transactions');
            for (var t in transactionsJson) {
              await txn.insert('transactions', t);
            }
          }

          if (budgetsJson != null) {
            await txn.delete('budgets');
            for (var b in budgetsJson) {
              await txn.insert('budgets', b);
            }
          }
        });

        if (settingsJson != null) {
          final settings = SettingsState.fromJson(settingsJson);
          await _settingsNotifier.restoreSettings(settings);
        }

        return true;
      }
    } catch (e) {
      print("BackupService Import ERROR: $e");
      return false;
    }
    return false;
  }
}

final backupServiceProvider = Provider<BackupService>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  final settingsNotifier = ref.watch(settingsProvider.notifier);
  return BackupService(dbHelper, settingsNotifier);
});
