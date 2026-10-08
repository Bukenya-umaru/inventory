class PriceHistoryEntry {
  final double costPrice; 
  final double sellingPrice; 
  final double? boxCostPrice;
  final double? boxSellingPrice;
  final int unitsPerBox;
  final String source; 
  final DateTime changedAt;

  PriceHistoryEntry({
    required this.costPrice,
    required this.sellingPrice,
    this.boxCostPrice,
    this.boxSellingPrice,
    this.unitsPerBox = 1,
    this.source = 'restock',
    required this.changedAt,
  });

  factory PriceHistoryEntry.fromJson(Map<String, dynamic> json) {
    return PriceHistoryEntry(
      costPrice: (json['costPrice'] ?? 0).toDouble(),
      sellingPrice: (json['sellingPrice'] ?? 0).toDouble(),
      boxCostPrice: (json['boxCostPrice'] as num?)?.toDouble(),
      boxSellingPrice: (json['boxSellingPrice'] as num?)?.toDouble(),
      unitsPerBox: (json['unitsPerBox'] as num?)?.toInt() ?? 1,
      source: json['source']?.toString() ?? 'restock',
      changedAt: json['changedAt'] != null
          ? DateTime.parse(json['changedAt'])
          : DateTime.now(),
    );
  }

  String get sourceLabel {
    switch (source) {
      case 'created':
        return 'Initial price';
      case 'edit':        return 'Manual edit';
      case 'restock':
        return 'Restock';
      default:
        return 'Restock';
    }
  }
}

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
  final String sellingUnit;
  final int unitsPerBox;
  final int stockBoxes;
  final double? boxSellingPrice;
  final double? boxCostPrice;
  final DateTime? createdAt;
  final List<PriceHistoryEntry> priceHistory;

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
    this.sellingUnit = 'piece',
    this.unitsPerBox = 1,
    this.stockBoxes = 0,
    this.boxSellingPrice,
    this.boxCostPrice,
    this.createdAt,
    this.priceHistory = const [],
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
      unit: json['unit']?.toString() ?? 'piece',
      sellingUnit: (json['sellingUnit']?.toString() == 'box') ? 'box' : 'piece',
      unitsPerBox: (json['unitsPerBox'] as num?)?.toInt() ?? 1,
      stockBoxes: (json['stockBoxes'] as num?)?.toInt() ?? 0,
      boxSellingPrice: (json['boxSellingPrice'] as num?)?.toDouble(),
      boxCostPrice: (json['boxCostPrice'] as num?)?.toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      priceHistory: (json['priceHistory'] as List?)
              ?.map((h) => PriceHistoryEntry.fromJson(h as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  bool get isLowStock => currentStock <= minimumStock;
  bool get isBoxLowStock => stockBoxes == 0 && sellingUnit != 'piece';
  bool get sellsAsBox => sellingUnit == 'box';
  bool get sellsAsPiece => sellingUnit == 'piece';

  int get totalStockPieces => (stockBoxes * unitsPerBox) + currentStock;

  bool get hasOpenBox => currentStock > 0 && currentStock < unitsPerBox && stockBoxes >= 0;

  int get fullBoxes => stockBoxes;

  int get loosePieces => currentStock;

  bool get hasLoosePieces => currentStock > 0;

  bool get hasFullBoxes => stockBoxes > 0;
}