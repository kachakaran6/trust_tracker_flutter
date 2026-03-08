import 'package:isar/isar.dart';

part 'category_model.g.dart';

enum CategoryType { income, expense }

@collection
class CategoryModel {
  Id id = Isar.autoIncrement;

  late String name;
  late String colorHex; // e.g. "#3B82F6"
  late String iconName; // e.g. "restaurant" — maps to Material icons
  
  @enumerated
  late CategoryType type;

  late bool isDefault; // True = seeded defaults, not deletable

  CategoryModel();

  CategoryModel.create({
    required this.name,
    required this.colorHex,
    required this.iconName,
    required this.type,
    this.isDefault = false,
  });
}
