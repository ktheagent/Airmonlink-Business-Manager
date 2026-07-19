import 'package:airmonlink_business_manager/models/sale.dart';
import 'package:airmonlink_business_manager/services/database_service.dart';
import 'package:airmonlink_business_manager/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('build 5 receipt reprinting', () {
    late DatabaseService database;
    late AppState state;

    setUp(() async {
      database = DatabaseService.forTesting();
      state = AppState(databaseService: database);
      await state.initialize();

      final products = await database.getProducts();
      if (products.isNotEmpty) {
        await database.createSale(
          SaleDraft(
            items: [
              SaleItem(
                productId: products.first.id,
                productName: products.first.name,
                quantity: 1,
                unitPrice: products.first.sellingPrice,
                costPrice: products.first.costPrice,
              ),
            ],
            discount: 0,
            paymentMethod: 'Cash',
            customerId: null,
          ),
        );
        await state.refreshAll();
      }
    });

    test('reprinting does not alter stock or transaction data', () async {
      final beforeStock = await database.getProducts();
      final beforeSales = await database.getSales();

      final sale = beforeSales.first;
      final pdf = await state.buildReceiptPdfForSavedSale(sale);

      expect(pdf.length, greaterThan(500));

      final afterStock = await database.getProducts();
      final afterSales = await database.getSales();
      expect(afterSales.length, beforeSales.length);
      expect(afterSales.first.invoiceNo, beforeSales.first.invoiceNo);
      expect(afterStock.first.stockQty, beforeStock.first.stockQty);
    });

    test(
      'receipt PDF generation succeeds for an existing saved sale',
      () async {
        final sale = await database.getSales();
        expect(sale, isNotEmpty);

        final pdf = await state.buildReceiptPdfForSavedSale(sale.first);
        expect(pdf.length, greaterThan(500));
        expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
      },
    );

    test(
      'original invoice number and transaction values are retained',
      () async {
        final sale = await database.getSales();
        expect(sale, isNotEmpty);

        final pdf = await state.buildReceiptPdfForSavedSale(sale.first);
        expect(pdf.length, greaterThan(500));
        expect(sale.first.invoiceNo, isNotEmpty);
        expect(sale.first.total, greaterThan(0));
      },
    );
  });
}
