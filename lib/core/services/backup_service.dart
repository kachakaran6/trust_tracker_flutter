import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:isar/isar.dart';
import 'package:trust_tracker_flutter/core/storage/isar_service.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/categories/data/models/category_model.dart';
import 'package:trust_tracker_flutter/features/budget/data/models/budget_model.dart';
import 'package:path_provider/path_provider.dart';
import 'package:trust_tracker_flutter/core/di/providers.dart';

class BackupService {
  final Isar _isar;
  final SettingsNotifier _settingsNotifier;

  BackupService(this._isar, this._settingsNotifier);

  Future<String?> exportData() async {
    print("BackupService: Export started");
    try {
      // 1. Fetch all data
      print("BackupService: Fetching data from DB...");
      final transactions = await _isar.transactionModels.where().findAll();
      final categories = await _isar.categoryModels.where().findAll();
      final budgets = await _isar.budgetModels.where().findAll();
      final settings = _settingsNotifier.state;

      // 2. Prepare data map
      final backup = {
        "version": "1.0",
        "exportedAt": DateTime.now().toIso8601String(),
        "data": {
          "transactions": transactions.map((t) => t.toJson()).toList(),
          "categories": categories.map((c) => c.toJson()).toList(),
          "budgets": budgets.map((b) => b.toJson()).toList(),
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

  // Top-level or static function for compute()
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

        // Basic version & structure validation
        if (backup['version'] == null || backup['data'] == null) return false;

        final data = backup['data'];
        final transactionsJson = data['transactions'] as List?;
        final categoriesJson = data['categories'] as List?;
        final budgetsJson = data['budgets'] as List?;
        final settingsJson = data['settings'];

        await _isar.writeTxn(() async {
          // Wipe and replace in a single transaction for safety
          if (categoriesJson != null) {
            await _isar.categoryModels.clear();
            final cats = categoriesJson.map((j) => CategoryModel.fromJson(j)).toList();
            await _isar.categoryModels.putAll(cats);
          }

          if (transactionsJson != null) {
            await _isar.transactionModels.clear();
            final txns = transactionsJson.map((j) => TransactionModel.fromJson(j)).toList();
            await _isar.transactionModels.putAll(txns);
          }

          if (budgetsJson != null) {
            await _isar.budgetModels.clear();
            final bdgts = budgetsJson.map((j) => BudgetModel.fromJson(j)).toList();
            await _isar.budgetModels.putAll(bdgts);
          }
        });

        // Restore user preferences
        if (settingsJson != null) {
          final settings = SettingsState.fromJson(settingsJson);
          await _settingsNotifier.restoreSettings(settings);
        }

        return true;
      }
    } catch (e) {
      return false;
    }
    return false;
  }
}

final backupServiceProvider = Provider<BackupService>((ref) {
  final isarService = ref.watch(isarServiceProvider);
  final settingsNotifier = ref.watch(settingsProvider.notifier);
  return BackupService(isarService.db, settingsNotifier);
});
