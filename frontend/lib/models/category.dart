class Category {
  final String id;
  final String name;
  final String? description;
  final String type;

  Category({
    required this.id,
    required this.name,
    this.description,
    this.type = 'product',
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      type: json['type'] == 'expense' ? 'expense' : 'product',
    );
  }
}
