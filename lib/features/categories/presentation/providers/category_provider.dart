import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trust_tracker_flutter/features/categories/data/models/category_model.dart';
import 'package:trust_tracker_flutter/features/categories/data/repositories/category_repository.dart';

final allCategoriesProvider = StreamProvider.autoDispose<List<CategoryModel>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchAll();
});
