class Branding {
  final String? businessName;
  final String? businessLogo;
  final String? phoneNumber;
  final String? ownerName;

  Branding({
    this.businessName,
    this.businessLogo,
    this.phoneNumber,
    this.ownerName,
  });

  factory Branding.fromJson(Map<String, dynamic> json) {
    return Branding(
      businessName: json['businessName'],
      businessLogo: json['businessLogo'],
      phoneNumber: json['phoneNumber'],
      ownerName: json['ownerName'],
    );
  }
}
