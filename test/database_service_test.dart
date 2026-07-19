import 'package:airmonlink_business_manager/models/contact.dart';
import 'package:airmonlink_business_manager/models/sale.dart';
import 'package:airmonlink_business_manager/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseService database;

  setUp(() {
    database = DatabaseService.forTesting();
  });

  tearDown(() async {
    await database.close();
  });

  test('credit checkout updates stock, debt and discounted profit', () async {
    final products = await database.getProducts();
    final product = products.first;
    final initialStock = product.stockQty;

    final customerId = await database.addContact(
      BusinessContact(
        id: null,
        type: ContactType.customer,
        name: 'Credit Customer',
        phone: '',
        email: '',
        balance: 0,
        createdAt: DateTime.now(),
      ),
    );

    final invoice = await database.createSale(
      SaleDraft(
        items: [
          SaleItem(
            productId: product.id!,
            productName: product.name,
            quantity: 2,
            unitPrice: product.sellingPrice,
            costPrice: product.costPrice,
          ),
        ],
        discount: 1,
        paymentMethod: 'Credit',
        customerId: customerId,
      ),
    );

    expect(invoice, startsWith('ABM-'));

    final updatedProduct = (await database.getProducts()).firstWhere(
      (item) => item.id == product.id,
    );
    expect(updatedProduct.stockQty, initialStock - 2);

    final customer = (await database.getContacts(ContactType.customer)).single;
    final expectedTotal = (product.sellingPrice * 2) - 1;
    expect(customer.balance, expectedTotal);

    final metrics = await database.getDashboardMetrics();
    final expectedProfit = ((product.sellingPrice - product.costPrice) * 2) - 1;
    expect(metrics.monthGrossProfit, expectedProfit);

    await database.recordContactPayment(customer, 1);
    final paidCustomer = (await database.getContacts(
      ContactType.customer,
    )).single;
    expect(paidCustomer.balance, expectedTotal - 1);
  });

  test('insufficient stock rolls back the complete sale', () async {
    final product = (await database.getProducts()).first;
    final initialSales = await database.getSales();

    await expectLater(
      database.createSale(
        SaleDraft(
          items: [
            SaleItem(
              productId: product.id!,
              productName: product.name,
              quantity: product.stockQty + 1,
              unitPrice: product.sellingPrice,
              costPrice: product.costPrice,
            ),
          ],
          discount: 0,
          paymentMethod: 'Cash',
          customerId: null,
        ),
      ),
      throwsStateError,
    );

    final unchanged = (await database.getProducts()).firstWhere(
      (item) => item.id == product.id,
    );
    expect(unchanged.stockQty, product.stockQty);
    expect((await database.getSales()).length, initialSales.length);
  });
}
