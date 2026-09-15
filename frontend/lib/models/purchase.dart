class Purchase {
  final String id;
  final String? productName;
  final String? productId;
  final int quantity;
  final String purchaseUnit;
  final double unitCost;
  final double? unitSellingPrice;
  final double totalCost;
  final String? supplier;
  final String? supplierPhone;
  final String? supplierEmail;
  final String? invoiceNumber;
  final String? paymentMethod;
  final String? notes;
  final String? recordedByName;
  final DateTime purchaseDate;

  Purchase({
    required this.id,
    this.productName,
    this.productId,
    required this.quantity,
    this.purchaseUnit = 'box',
    required this.unitCost,
    this.unitSellingPrice,
    required this.totalCost,
    this.supplier,
    this.supplierPhone,
    this.supplierEmail,
    this.invoiceNumber,
    this.paymentMethod = 'cash',
    this.notes,
    this.recordedByName,
    required this.purchaseDate,
  });

  factory Purchase.fromJson(Map<String, dynamic> json) {
    return Purchase(
      id: json['_id'] ?? json['id'] ?? '',
      productName: json['productId'] is Map
          ? (json['productId'] as Map)['name']
          : json['productName'],
      productId: json['productId'] is Map
          ? (json['productId'] as Map)['_id']
          : json['productId'],
      quantity: json['quantity'] ?? 0,
      purchaseUnit: json['purchaseUnit'] ?? 'box',
      unitCost: (json['unitCost'] ?? 0).toDouble(),
      unitSellingPrice: (json['unitSellingPrice'] as num?)?.toDouble(),
      totalCost: (json['totalCost'] ?? 0).toDouble(),
      supplier: json['supplier'],
      supplierPhone: json['supplierPhone'],
      supplierEmail: json['supplierEmail'],
      invoiceNumber: json['invoiceNumber'],
      paymentMethod: json['paymentMethod'] ?? 'cash',
      notes: json['notes'],
      recordedByName: json['recordedBy'] is Map
          ? (json['recordedBy'] as Map)['name']
          : null,
      purchaseDate: DateTime.parse(
          json['purchaseDate'] ?? DateTime.now().toIso8601String()),
    );
  }
}