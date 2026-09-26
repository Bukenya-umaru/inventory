class AuditLog {
  final String id;
  final String eventType;
  final String severity;
  final String? userName;
  final String? userRole;
  final String? businessName;
  final String? action;
  final Map<String, dynamic>? details;
  final DateTime timestamp;

  AuditLog({
    required this.id,
    required this.eventType,
    this.severity = 'info',
    this.userName,
    this.userRole,
    this.businessName,
    this.action,
    this.details,
    required this.timestamp,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['_id'] ?? '',
      eventType: json['eventType'] ?? '',
      severity: json['severity'] ?? 'info',
      userName: json['userId'] is Map ? (json['userId'] as Map)['name'] : null,
      userRole: json['userRole'],
      businessName: json['tenantId'] is Map
          ? (json['tenantId'] as Map)['businessName']
          : null,
      action: json['action'],
      details: json['details'] is Map
          ? Map<String, dynamic>.from(json['details'])
          : null,
      timestamp: DateTime.parse(
        json['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
