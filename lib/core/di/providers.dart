import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trust_tracker_flutter/core/storage/isar_service.dart';

final isarServiceProvider = Provider<IsarService>((ref) {
  return IsarService();
});
