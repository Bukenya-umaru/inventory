class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? tenantId;
  final List<String> permissions;
  final String? employeeId;
  final String? department;
  final String? position;
  final String accountStatus;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.tenantId,
    this.permissions = const [],
    this.employeeId,
    this.department,
    this.position,
    this.accountStatus = 'active',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'employee',
      tenantId: json['tenantId'] is String
          ? json['tenantId']
          : json['tenantId']?['_id'],
      permissions: List<String>.from(json['permissions'] ?? []),
      employeeId: json['employeeId'],
      department: json['department'],
      position: json['position'],
      accountStatus: json['accountStatus'] ?? 'active',
    );
  }

  bool get isDeveloper => role == 'developer';
  bool get isAdmin => role == 'admin';
  bool get isEmployee => role == 'employee';

  bool hasPermission(String permission) =>
      isDeveloper || isAdmin || permissions.contains(permission);
}
