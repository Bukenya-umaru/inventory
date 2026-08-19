class Tenant {
  final String id;
  final String businessName;
  final String businessType;
  final String? businessLogo;
  final String phoneNumber;
  final String? address;
  final String? taxId;
  final String email;
  final String ownerName;
  final String status;
  final int userCount;
  final DateTime createdAt;

  Tenant({
    required this.id,
    required this.businessName,
    this.businessType = 'Retail',
    this.businessLogo,
    required this.phoneNumber,
    this.address,
    this.taxId,
    required this.email,
    required this.ownerName,
    this.status = 'active',
    this.userCount = 0,
    required this.createdAt,
  });

  factory Tenant.fromJson(Map<String, dynamic> json) {
    return Tenant(
      id: json['_id'] ?? '',
      businessName: json['businessName'] ?? '',
      businessType: json['businessType'] ?? 'Retail',
      businessLogo: json['businessLogo'],
      phoneNumber: json['phoneNumber'] ?? '',
      address: json['address'],
      taxId: json['taxId'],
      email: json['email'] ?? '',
      ownerName: json['ownerName'] ?? '',
      status: json['status'] ?? 'active',
      userCount: json['userCount'] ?? 0,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}
