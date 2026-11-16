class Product {
  final String id;
  final String name;
  final String? skuOrCategory;
  final int quantity;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    this.skuOrCategory,
    required this.quantity,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      skuOrCategory: map['sku_or_category'] as String?,
      quantity: (map['quantity'] as num).toInt(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'sku_or_category': skuOrCategory,
      'quantity': quantity,
    };
  }
}
