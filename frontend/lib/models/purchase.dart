class PurchaseEdit {
  final String? editedByName;
  final DateTime editedAt;
  final Map<String, dynamic> changes;

  PurchaseEdit({
    this.editedByName,
    required this.editedAt,
    required this.changes,
  });

  factory PurchaseEdit.fromJson(Map<String, dynamic> json) {
    return PurchaseEdit(
      editedByName: json['editedBy'] is Map
          ? (json['editedBy'] as Map)['name']
          : null,
      editedAt: json['editedAt'] != null
          ? DateTime.parse(json['editedAt'])
          : DateTime.now(),
      changes: Map<String, dynamic>.from(json['changes'] ?? {}),
    );
  }
}

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
  final String? supplierId;
  final String? supplierPhone;
  final String? supplierEmail;
  final String? invoiceNumber;
  final String? paymentMethod;
  final bool creditPaid;
  final DateTime? creditPaidAt;
  final String? notes;
  final String? recordedByName;
  final String? recordedById;
  final String status; // 'pending' | 'approved'
  final String? approvedByName;
  final DateTime? approvedAt;
  final List<PurchaseEdit> editHistory;
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
    this.supplierId,
    this.supplierPhone,
    this.supplierEmail,
    this.invoiceNumber,
    this.paymentMethod = 'cash',
    this.creditPaid = false,
    this.creditPaidAt,
    this.notes,
    this.recordedByName,
    this.recordedById,
    this.status = 'pending',
    this.approvedByName,
    this.approvedAt,
    List<PurchaseEdit>? editHistory,
    required this.purchaseDate,
  }) : editHistory = editHistory ?? const [];

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';

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
      supplierId: json['supplierId'] is Map
          ? (json['supplierId'] as Map)['_id']
          : json['supplierId'],
      supplierPhone: json['supplierPhone'],
      supplierEmail: json['supplierEmail'],
      invoiceNumber: json['invoiceNumber'],
      paymentMethod: json['paymentMethod'] ?? 'cash',
      creditPaid: json['creditPaid'] == true,
      creditPaidAt: json['creditPaidAt'] != null
          ? DateTime.parse(json['creditPaidAt'])
          : null,
      notes: json['notes'],
      recordedByName: json['recordedBy'] is Map
          ? (json['recordedBy'] as Map)['name']
          : null,
      recordedById: json['recordedBy'] is Map
          ? (json['recordedBy'] as Map)['_id']
          : null,
      status: json['status'] ?? 'pending',
      approvedByName: json['approvedBy'] is Map
          ? (json['approvedBy'] as Map)['name']
          : null,
      approvedAt: json['approvedAt'] != null
          ? DateTime.parse(json['approvedAt'])
          : null,
      editHistory: json['editHistory'] is List
          ? (json['editHistory'] as List)
                .whereType<Map>()
                .map((e) => PurchaseEdit.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : [],
      purchaseDate: DateTime.parse(
        json['purchaseDate'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
