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

  Map<String, dynamic> toJson() => {
        'id': id == Isar.autoIncrement ? null : id,
        'name': name,
        'colorHex': colorHex,
        'iconName': iconName,
        'type': type.index,
        'isDefault': isDefault,
      };

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    final c = CategoryModel();
    if (json['id'] != null) c.id = json['id'];
    c.name = json['name'];
    c.colorHex = json['colorHex'];
    c.iconName = json['iconName'];
    c.type = CategoryType.values[json['type'] as int];
    c.isDefault = json['isDefault'] ?? false;
    return c;
  }
}
