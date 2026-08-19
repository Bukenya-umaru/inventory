class Product {
  final String id;
  final String name;
  final String? description;
  final String? sku;
  final String categoryId;
  final String? categoryName;
  final double costPrice;
  final double sellingPrice;
  final int currentStock;
  final int minimumStock;
  final String unit;

  Product({
    required this.id,
    required this.name,
    this.description,
    this.sku,
    required this.categoryId,
    this.categoryName,
    required this.costPrice,
    required this.sellingPrice,
    required this.currentStock,
    this.minimumStock = 5,
    this.unit = 'piece',
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      sku: json['sku'],
      categoryId: json['categoryId'] is String
          ? json['categoryId']
          : (json['categoryId'] as Map?)?['_id'] ?? '',
      categoryName: json['categoryId'] is Map
          ? (json['categoryId'] as Map)['name']
          : null,
      costPrice: (json['costPrice'] ?? 0).toDouble(),
      sellingPrice: (json['sellingPrice'] ?? 0).toDouble(),
      currentStock: json['currentStock'] ?? 0,
      minimumStock: json['minimumStock'] ?? 5,
      unit: json['unit'] ?? 'piece',
    );
  }

  bool get isLowStock => currentStock <= minimumStock;
}
