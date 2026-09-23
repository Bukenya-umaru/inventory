class Supplier {
  final String id;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final int purchaseCount;
  final double totalSpent;

  Supplier({
    required this.id,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.purchaseCount = 0,
    this.totalSpent = 0,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      contactPerson: json['contactPerson'],
      phone: json['phone'],
      email: json['email'],
      address: json['address'],
      notes: json['notes'],
      purchaseCount: json['purchaseCount'] ?? 0,
      totalSpent: (json['totalSpent'] ?? 0).toDouble(),
    );
  }
}
