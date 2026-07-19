class SaleItem {
  const SaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.costPrice,
  });

  final int? productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double costPrice;

  double get total => quantity * unitPrice;
  double get grossProfit => quantity * (unitPrice - costPrice);
}

class SaleRecord {
  const SaleRecord({
    required this.id,
    required this.invoiceNo,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.paymentMethod,
    required this.customerId,
    required this.createdAt,
  });

  final int? id;
  final String invoiceNo;
  final double subtotal;
  final double discount;
  final double total;
  final String paymentMethod;
  final int? customerId;
  final DateTime createdAt;

  factory SaleRecord.fromMap(Map<String, Object?> map) => SaleRecord(
    id: map['id'] as int?,
    invoiceNo: map['invoice_no'] as String,
    subtotal: (map['subtotal'] as num).toDouble(),
    discount: (map['discount'] as num).toDouble(),
    total: (map['total'] as num).toDouble(),
    paymentMethod: map['payment_method'] as String,
    customerId: map['customer_id'] as int?,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}

class SaleDraft {
  const SaleDraft({
    required this.items,
    required this.discount,
    required this.paymentMethod,
    required this.customerId,
  });

  final List<SaleItem> items;
  final double discount;
  final String paymentMethod;
  final int? customerId;

  double get subtotal => items.fold(0, (sum, item) => sum + item.total);
  double get total =>
      (subtotal - discount).clamp(0, double.infinity).toDouble();
}
