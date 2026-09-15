class Damage {
  final String id;
  final String? productName;
  final int quantity;
  final String damageUnit;
  final String reason;
  final double estimatedLoss;
  final String? reportedByName;
  final DateTime reportDate;

  Damage({
    required this.id,
    this.productName,
    required this.quantity,
    this.damageUnit = 'piece',
    required this.reason,
    required this.estimatedLoss,
    this.reportedByName,
    required this.reportDate,
  });

  factory Damage.fromJson(Map<String, dynamic> json) {
    return Damage(
      id: json['_id'] ?? '',
      productName: json['productId'] is Map
          ? (json['productId'] as Map)['name']
          : json['productName'],
      quantity: json['quantity'] ?? 0,
      damageUnit: json['damageUnit'] ?? 'piece',
      reason: json['reason'] ?? '',
      estimatedLoss: (json['estimatedLoss'] ?? 0).toDouble(),
      reportedByName: json['reportedBy'] is Map
          ? (json['reportedBy'] as Map)['name']
          : null,
      reportDate: DateTime.parse(json['reportDate'] ?? DateTime.now().toIso8601String()),
    );
  }
}