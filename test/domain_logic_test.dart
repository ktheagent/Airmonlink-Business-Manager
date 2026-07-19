import 'package:airmonlink_business_manager/models/product.dart';
import 'package:airmonlink_business_manager/models/sale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Product', () {
    test('detects low stock at or below threshold', () {
      final product = Product(
        id: 1,
        name: 'Test item',
        sku: 'TEST',
        barcode: '',
        category: 'General',
        costPrice: 4,
        sellingPrice: 6,
        stockQty: 5,
        lowStockLevel: 5,
        createdAt: DateTime(2026),
      );

      expect(product.isLowStock, isTrue);
      expect(product.copyWith(stockQty: 6).isLowStock, isFalse);
    });
  });

  group('SaleDraft', () {
    test('calculates subtotal, discount and total', () {
      final draft = SaleDraft(
        items: const [
          SaleItem(
            productId: 1,
            productName: 'A',
            quantity: 2,
            unitPrice: 10,
            costPrice: 6,
          ),
          SaleItem(
            productId: 2,
            productName: 'B',
            quantity: 1,
            unitPrice: 5,
            costPrice: 2,
          ),
        ],
        discount: 3,
        paymentMethod: 'Cash',
        customerId: null,
      );

      expect(draft.subtotal, 25);
      expect(draft.total, 22);
      expect(draft.items.first.grossProfit, 8);
    });

    test('does not produce a negative total', () {
      final draft = SaleDraft(
        items: const [
          SaleItem(
            productId: 1,
            productName: 'A',
            quantity: 1,
            unitPrice: 5,
            costPrice: 2,
          ),
        ],
        discount: 10,
        paymentMethod: 'Cash',
        customerId: null,
      );

      expect(draft.total, 0);
    });
  });
}
