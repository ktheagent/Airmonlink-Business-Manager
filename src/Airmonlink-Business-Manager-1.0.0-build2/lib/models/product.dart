class Product {
  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.barcode,
    required this.category,
    required this.costPrice,
    required this.sellingPrice,
    required this.stockQty,
    required this.lowStockLevel,
    required this.createdAt,
  });

  final int? id;
  final String name;
  final String sku;
  final String barcode;
  final String category;
  final double costPrice;
  final double sellingPrice;
  final double stockQty;
  final double lowStockLevel;
  final DateTime createdAt;

  bool get isLowStock => stockQty <= lowStockLevel;

  Product copyWith({
    int? id,
    String? name,
    String? sku,
    String? barcode,
    String? category,
    double? costPrice,
    double? sellingPrice,
    double? stockQty,
    double? lowStockLevel,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      stockQty: stockQty ?? this.stockQty,
      lowStockLevel: lowStockLevel ?? this.lowStockLevel,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'sku': sku,
        'barcode': barcode,
        'category': category,
        'cost_price': costPrice,
        'selling_price': sellingPrice,
        'stock_qty': stockQty,
        'low_stock_level': lowStockLevel,
        'created_at': createdAt.toIso8601String(),
      };

  factory Product.fromMap(Map<String, Object?> map) => Product(
        id: map['id'] as int?,
        name: map['name'] as String,
        sku: map['sku'] as String? ?? '',
        barcode: map['barcode'] as String? ?? '',
        category: map['category'] as String? ?? 'General',
        costPrice: (map['cost_price'] as num).toDouble(),
        sellingPrice: (map['selling_price'] as num).toDouble(),
        stockQty: (map['stock_qty'] as num).toDouble(),
        lowStockLevel: (map['low_stock_level'] as num).toDouble(),
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
