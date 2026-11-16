class StockMovement {
  final String id;
  final String productId;
  final String productName;
  final String type; // 'ENTRY' ou 'EXIT'
  final int quantity;
  final String userEmail;
  final DateTime createdAt;

  StockMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    required this.userEmail,
    required this.createdAt,
  });

  bool get isEntry => type == 'ENTRY';

  factory StockMovement.fromMap(Map<String, dynamic> map) {
    return StockMovement(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      productName: map['product_name'] as String,
      type: map['type'] as String,
      quantity: (map['quantity'] as num).toInt(),
      userEmail: map['user_email'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
