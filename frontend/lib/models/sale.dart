class Sale {
  final String id;
  final String? productName;
  final int quantity;
  final double unitPrice;
  final double costPrice;
  final double totalAmount;
  final double profit;
  final String paymentMethod;
  final String? customerName;
  final String? recordedByName;
  final DateTime saleDate;

  Sale({
    required this.id,
    this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.costPrice,
    required this.totalAmount,
    required this.profit,
    this.paymentMethod = 'cash',
    this.customerName,
    this.recordedByName,
    required this.saleDate,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['_id'] ?? '',
      productName: json['productId'] is Map
          ? (json['productId'] as Map)['name']
          : json['productName'],
      quantity: json['quantity'] ?? 0,
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
      costPrice: (json['costPrice'] ?? 0).toDouble(),
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      profit: (json['profit'] ?? 0).toDouble(),
      paymentMethod: json['paymentMethod'] ?? 'cash',
      customerName: json['customerName'],
      recordedByName: json['recordedBy'] is Map
          ? (json['recordedBy'] as Map)['name']
          : null,
      saleDate: DateTime.parse(json['saleDate'] ?? DateTime.now().toIso8601String()),
    );
  }
}
