import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'package:archive/archive.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;
import 'package:trust_tracker_flutter/core/utils/pdf_generator.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/export_transaction_row.dart';

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

      final fileName = "trust_tracker_export_${DateTime.now().millisecondsSinceEpoch}.json";

      // 5. Save to public Downloads directory
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getDownloadsDirectory();
        }
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir == null) {
        throw Exception("Could not find Downloads directory");
      }

      final exportDir = Directory('${downloadsDir.path}/TrustTracker/Exports');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final file = File('${exportDir.path}/$fileName');
      print("BackupService: Writing JSON export to: ${file.path}");
      await file.writeAsString(jsonString);
      
      print("BackupService: Export complete");
      return file.path;
    } catch (e) {
      print("BackupService ERROR: $e");
      return null;
    }
  }

  Future<File?> createCompressedBackup() async {
    try {
      final db = await _dbHelper.database;
      
      // 1. Fetch data for JSON and PDF
      final transactionsData = await db.query('transactions');
      final categoriesData = await db.query('categories');
      final budgetsData = await db.query('budgets');
      final settings = _settingsNotifier.state;

      // 2. Generate JSON data
      final backupMap = {
        "version": "1.0",
        "exportedAt": DateTime.now().toIso8601String(),
        "data": {
          "transactions": transactionsData,
          "categories": categoriesData,
          "budgets": budgetsData,
          "settings": settings.toJson(),
        }
      };
      final jsonString = jsonEncode(backupMap);
      final jsonBytes = utf8.encode(jsonString);

      // 3. Generate PDF Report
      final categoryMap = {for (var c in categoriesData) c['id'] as int?: CategoryModel.fromJson(c)};
      final transactions = transactionsData.map((t) => TransactionModel.fromJson(t)).toList();
      
      final rows = transactions.map((t) {
        final category = categoryMap[t.categoryId];
        final isIncome = t.type == TransactionType.income;
        return ExportTransactionRow(
          timestamp: t.date,
          title: t.description,
          category: category?.name ?? 'Uncategorized',
          typeLabel: isIncome ? 'Income' : 'Expense',
          notes: t.note?.trim() ?? '',
          amount: t.amount,
          isIncome: isIncome,
        );
      }).toList();

      final pdfFile = await PdfGenerator.generate(
        rows: rows,
        currency: settings.currency,
        dateRange: "Full Backup History",
      );
      final pdfBytes = await pdfFile.readAsBytes();

      // 4. Create Archive
      final archive = Archive();
      archive.addFile(ArchiveFile('backup_data.json', jsonBytes.length, jsonBytes));
      archive.addFile(ArchiveFile('transaction_report.pdf', pdfBytes.length, pdfBytes));
      
      // 5. Encode to ZIP
      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) return null;

      final tempDir = await getTemporaryDirectory();
      final zipFile = File('${tempDir.path}/trust_tracker_backup_${DateTime.now().millisecondsSinceEpoch}.zip');
      await zipFile.writeAsBytes(zipBytes);
      
      return zipFile;
    } catch (e) {
      print("BackupService Compression ERROR: $e");
      return null;
    }
  }

  Future<String> _saveToLocalBackups(File file) async {
    try {
      // 1. App Private Storage (Internal)
      final appDir = await getApplicationDocumentsDirectory();
      final internalBackupDir = Directory('${appDir.path}/backups');
      if (!await internalBackupDir.exists()) {
        await internalBackupDir.create(recursive: true);
      }
      
      final fileName = p.basename(file.path);
      await file.copy('${internalBackupDir.path}/$fileName');

      // Clean up internal backups
      final internalFiles = internalBackupDir.listSync().whereType<File>().toList();
      internalFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      if (internalFiles.length > 5) {
        for (var i = 5; i < internalFiles.length; i++) {
          await internalFiles[i].delete();
        }
      }

      // 2. Public Downloads Storage
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getDownloadsDirectory();
        }
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir != null) {
        final publicBackupDir = Directory('${downloadsDir.path}/TrustTracker/Backups');
        if (!await publicBackupDir.exists()) {
          await publicBackupDir.create(recursive: true);
        }
        final publicFile = await file.copy('${publicBackupDir.path}/$fileName');
        print("BackupService: Saved to public Downloads: ${publicFile.path}");
        
        // Clean up old public backups (keep last 5)
        final files = publicBackupDir.listSync().whereType<File>().toList();
        files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        if (files.length > 5) {
          for (var i = 5; i < files.length; i++) {
            await files[i].delete();
          }
        }
        return publicFile.path;
      }
      
      return "Internal Storage (Downloads unavailable)";
    } catch (e) {
      print("BackupService Local Save ERROR: $e");
      rethrow;
    }
  }

  Future<void> performAutoBackup() async {
    print("BackupService: Running Auto Backup (Local Only)...");
    
    try {
      final compressedFile = await createCompressedBackup();
      if (compressedFile == null) {
        await _settingsNotifier.setLastBackupInfo(DateTime.now(), BackupStatus.failed);
        _showNotification("Backup Failed", "Could not create backup file.");
        return;
      }

      final savedPath = await _saveToLocalBackups(compressedFile);
      
      await _settingsNotifier.setLastBackupInfo(DateTime.now(), BackupStatus.success);
      _showNotification("Backup Successful", "Saved to: $savedPath");
      
    } catch (e) {
      print("BackupService: Auto backup failed -> $e");
      await _settingsNotifier.setLastBackupInfo(DateTime.now(), BackupStatus.failed);
      _showNotification("Backup Failed", "Error saving to local storage.");
    }
  }

  void _showNotification(String title, String body) async {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const androidDetails = AndroidNotificationDetails('backup_channel', 'Backups',
        importance: Importance.low, priority: Priority.low,
        icon: 'tt_stat_icon',
        color: const Color(0xFF008B9C));
    const details = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(0, title, body, details);
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
