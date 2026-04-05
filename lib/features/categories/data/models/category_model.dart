enum CategoryType { income, expense }

class CategoryModel {
  int? id;
  late String name;
  late String colorHex;
  late String iconName;
  late CategoryType type;
  late bool isDefault;

  CategoryModel();

  CategoryModel.create({
    required this.name,
    required this.colorHex,
    required this.iconName,
    required this.type,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'colorHex': colorHex,
        'iconName': iconName,
        'type': type.index,
        'isDefault': isDefault ? 1 : 0,
      };

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    final c = CategoryModel();
    c.id = map['id'];
    c.name = map['name'];
    c.colorHex = map['colorHex'];
    c.iconName = map['iconName'];
    c.type = CategoryType.values[map['type'] as int];
    c.isDefault = (map['isDefault'] as int) == 1;
    return c;
  }

  // Keep compatibility if needed
  Map<String, dynamic> toJson() => toMap();
  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel.fromMap(json);
}
