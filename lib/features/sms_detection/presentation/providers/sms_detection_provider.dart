import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trust_tracker_flutter/core/database/database_helper.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/services/sms_channel_service.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/services/sms_processing_service.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/models/detected_sms_transaction.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/models/sms_parse_result.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/repositories/sms_transaction_repository.dart';
import 'package:trust_tracker_flutter/features/sms_detection/presentation/providers/sms_settings_provider.dart';
import 'package:trust_tracker_flutter/features/transactions/data/repositories/transaction_repository.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/providers/transaction_provider.dart';

final smsProcessingServiceProvider = Provider<SmsProcessingService>((ref) {
  final smsRepo = ref.watch(smsRepositoryProvider);
  final txnRepo = TransactionRepository(DatabaseHelper.instance);
  return SmsProcessingService(
    smsRepository: smsRepo,
    transactionRepository: txnRepo,
    dbHelper: DatabaseHelper.instance,
  );
});

class SmsDetectionState {
  final bool isLoading;
  final List<DetectedSmsTransaction> pendingList;
  final String? errorMessage;

  const SmsDetectionState({
    this.isLoading = false,
    this.pendingList = const [],
    this.errorMessage,
  });

  SmsDetectionState copyWith({
    bool? isLoading,
    List<DetectedSmsTransaction>? pendingList,
    String? errorMessage,
  }) {
    return SmsDetectionState(
      isLoading: isLoading ?? this.isLoading,
      pendingList: pendingList ?? this.pendingList,
      errorMessage: errorMessage,
    );
  }
}

class SmsDetectionNotifier extends StateNotifier<SmsDetectionState> {
  final SmsTransactionRepository _smsRepo;
  final SmsProcessingService _processingService;
  final Ref _ref;

  SmsDetectionNotifier(this._smsRepo, this._processingService, this._ref)
      : super(const SmsDetectionState()) {
    loadPending();
  }

  Future<void> loadPending() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _smsRepo.getPendingTransactions();
      state = state.copyWith(isLoading: false, pendingList: list);
      _ref.read(smsSettingsProvider.notifier).refreshPendingCount();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> approveTransaction(
    DetectedSmsTransaction transaction, {
    int? customCategoryId,
    String? customDescription,
    double? customAmount,
    DateTime? customDate,
  }) async {
    await _processingService.approveDetectedTransaction(
      detected: transaction,
      customCategoryId: customCategoryId,
      customDescription: customDescription,
      customAmount: customAmount,
      customDate: customDate,
    );
    // Refresh main transactions list in Trust Tracker
    _ref.read(transactionListProvider.notifier).refresh();
    await loadPending();
  }

  Future<void> rejectTransaction(int id) async {
    await _processingService.rejectDetectedTransaction(id);
    await loadPending();
  }

  Future<SmsParseResult> processManualSms({
    required String body,
    required String sender,
    DateTime? receivedTime,
  }) async {
    final settings = _ref.read(smsSettingsProvider);
    final result = await _processingService.processSms(
      body: body,
      sender: sender,
      receivedTime: receivedTime,
      autoApproveHighConfidence: settings.autoApproveHighConfidence,
    );

    if (result.isTransaction && !result.isDuplicate) {
      if (settings.autoApproveHighConfidence && result.transaction?.status == 'approved') {
        _ref.read(transactionListProvider.notifier).refresh();
      }
      await loadPending();
    }

    return result;
  }

  Future<void> approveAllPending() async {
    state = state.copyWith(isLoading: true);
    try {
      final list = List<DetectedSmsTransaction>.from(state.pendingList);
      for (final item in list) {
        if (item.id != null) {
          await _processingService.approveDetectedTransaction(detected: item);
        }
      }
      _ref.read(transactionListProvider.notifier).refresh();
      await loadPending();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> rejectAllPending() async {
    state = state.copyWith(isLoading: true);
    try {
      final list = List<DetectedSmsTransaction>.from(state.pendingList);
      for (final item in list) {
        if (item.id != null) {
          await _processingService.rejectDetectedTransaction(item.id!);
        }
      }
      await loadPending();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> clearAllPending() async {
    await _smsRepo.deleteAllPendingRecords();
    await loadPending();
  }

  Future<HistoricalScanResult?> syncHistoricalSms({
    int days = 30,
    void Function(int current, int total)? onProgress,
  }) async {
    bool hasPermission = await SmsChannelService.checkReadPermission();
    if (!hasPermission) {
      hasPermission = await SmsChannelService.requestReadPermission();
    }
    if (!hasPermission) {
      return null;
    }

    state = state.copyWith(isLoading: true);
    try {
      final messages = await SmsChannelService.readHistoricalSms(days: days);
      final settings = _ref.read(smsSettingsProvider);
      final result = await _processingService.processHistoricalMessages(
        messages: messages,
        autoApproveHighConfidence: settings.autoApproveHighConfidence,
        onProgress: onProgress,
      );

      if (result.autoApproved > 0) {
        _ref.read(transactionListProvider.notifier).refresh();
      }
      await loadPending();
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }
}

final smsDetectionProvider =
    StateNotifierProvider<SmsDetectionNotifier, SmsDetectionState>((ref) {
  final smsRepo = ref.watch(smsRepositoryProvider);
  final processingService = ref.watch(smsProcessingServiceProvider);
  return SmsDetectionNotifier(smsRepo, processingService, ref);
});
