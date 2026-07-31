import 'package:airmonlink_business_manager/commercial/models/commercial_models.dart';
import 'package:airmonlink_business_manager/commercial/services/commercial_service.dart';
import 'package:airmonlink_business_manager/commercial/services/security_service.dart';
import 'package:airmonlink_business_manager/models/contact.dart';
import 'package:airmonlink_business_manager/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseService database;
  late CommercialService commercial;
  late StaffUser owner;

  setUp(() async {
    database = DatabaseService.forTesting();
    commercial = CommercialService(database);
    owner = await commercial.createInitialOwner(
      name: 'Business Owner',
      username: 'owner',
      pin: '2468',
    );
  });

  tearDown(() => database.close());

  test('staff PIN is salted and verifies without storing the plain PIN', () {
    const security = SecurityService();
    final first = security.hashPin('2468');
    final second = security.hashPin('2468');
    expect(first, isNot(second));
    expect(first, isNot(contains('2468')));
    expect(security.verifyPin('2468', first), isTrue);
    expect(security.verifyPin('1111', first), isFalse);
  });

  test('issued invoice posts customer debt once and part payment reduces it', () async {
    final product = (await database.getProducts()).first;
    final customerId = await database.addContact(
      BusinessContact(
        id: null,
        type: ContactType.customer,
        name: 'Invoice Customer',
        phone: '0240000000',
        email: '',
        balance: 0,
        createdAt: DateTime.now(),
      ),
    );
    final documentId = await commercial.createDocument(
      actor: owner,
      draft: CommercialDocumentDraft(
        type: 'invoice',
        customerId: customerId,
        items: [
          CommercialDocumentItem(
            productId: product.id,
            description: product.name,
            quantity: 2,
            unitPrice: product.sellingPrice,
            costPrice: product.costPrice,
          ),
        ],
        discount: 0,
        tax: 0,
        notes: '',
        terms: '',
      ),
    );

    await commercial.issueDocument(actor: owner, documentId: documentId);
    final expected = product.sellingPrice * 2;
    expect(
      (await database.getContacts(ContactType.customer)).single.balance,
      expected,
    );
    await expectLater(
      commercial.issueDocument(actor: owner, documentId: documentId),
      throwsStateError,
    );
    expect(
      (await database.getContacts(ContactType.customer)).single.balance,
      expected,
    );

    await commercial.recordDocumentPayment(
      actor: owner,
      documentId: documentId,
      amount: 1,
      paymentMethod: 'Bank',
      reference: 'TEST',
    );
    expect(
      (await database.getContacts(ContactType.customer)).single.balance,
      expected - 1,
    );
  });

  test('first purchase receipt increases stock exactly once', () async {
    final product = (await database.getProducts()).first;
    final initial = product.stockQty;
    final supplierId = await database.addContact(
      BusinessContact(
        id: null,
        type: ContactType.supplier,
        name: 'Supplier One',
        phone: '',
        email: '',
        balance: 0,
        createdAt: DateTime.now(),
      ),
    );
    final poId = await commercial.createPurchaseOrder(
      actor: owner,
      supplierId: supplierId,
      items: [
        {
          'product_id': product.id,
          'description': product.name,
          'quantity': 5.0,
          'unit_cost': product.costPrice,
          'tax_rate': 0.0,
        },
      ],
    );
    final items = await commercial.purchaseOrderItems(
      actor: owner,
      purchaseOrderId: poId,
    );
    await commercial.receivePurchaseOrder(
      actor: owner,
      purchaseOrderId: poId,
      quantitiesByItemId: {items.single['id'] as int: 5},
    );
    final updated = (await database.getProducts()).firstWhere(
      (item) => item.id == product.id,
    );
    expect(updated.stockQty, initial + 5);
    await expectLater(
      commercial.receivePurchaseOrder(
        actor: owner,
        purchaseOrderId: poId,
        quantitiesByItemId: {items.single['id'] as int: 1},
      ),
      throwsStateError,
    );
  });

  test('quotation converts to sale once and deducts stock once', () async {
    final product = (await database.getProducts()).first;
    final initial = product.stockQty;
    final customerId = await database.addContact(
      BusinessContact(
        id: null,
        type: ContactType.customer,
        name: 'Quotation Customer',
        phone: '',
        email: '',
        balance: 0,
        createdAt: DateTime.now(),
      ),
    );
    final documentId = await commercial.createDocument(
      actor: owner,
      draft: CommercialDocumentDraft(
        type: 'quotation',
        customerId: customerId,
        items: [
          CommercialDocumentItem(
            productId: product.id,
            description: product.name,
            quantity: 1,
            unitPrice: product.sellingPrice,
            costPrice: product.costPrice,
          ),
        ],
        discount: 0,
        tax: 0,
        notes: '',
        terms: '',
      ),
    );
    await commercial.convertDocumentToSale(
      actor: owner,
      documentId: documentId,
      paymentMethod: 'Credit',
    );
    final after = (await database.getProducts()).firstWhere(
      (item) => item.id == product.id,
    );
    expect(after.stockQty, initial - 1);
    await expectLater(
      commercial.convertDocumentToSale(
        actor: owner,
        documentId: documentId,
        paymentMethod: 'Credit',
      ),
      throwsStateError,
    );
  });

  test('cashier cannot create a discounted document', () async {
    await commercial.createStaff(
      actor: owner,
      branchId: owner.branchId,
      name: 'Cashier One',
      username: 'cashier',
      pin: '1234',
      role: StaffRole.cashier,
    );
    final cashier = await commercial.login(username: 'cashier', pin: '1234');
    final product = (await database.getProducts()).first;
    await expectLater(
      commercial.createDocument(
        actor: cashier,
        draft: CommercialDocumentDraft(
          type: 'quotation',
          customerId: null,
          items: [
            CommercialDocumentItem(
              productId: product.id,
              description: product.name,
              quantity: 1,
              unitPrice: product.sellingPrice,
              costPrice: product.costPrice,
            ),
          ],
          discount: 1,
          tax: 0,
          notes: '',
          terms: '',
        ),
      ),
      throwsStateError,
    );
  });

  test('customer credit and account payment remain branch scoped', () async {
    final customerId = await database.addContact(
      BusinessContact(
        id: null,
        type: ContactType.customer,
        name: 'Credit Customer',
        phone: '',
        email: '',
        balance: 25,
        createdAt: DateTime.now(),
      ),
    );
    await commercial.setCustomerCredit(
      actor: owner,
      customerId: customerId,
      enabled: true,
      creditLimit: 100,
      reason: 'Approved for testing',
    );
    var accounts = await commercial.listCustomerAccounts(owner);
    final account = accounts.singleWhere((row) => row['id'] == customerId);
    expect((account['credit_limit'] as num).toDouble(), 100);
    expect((account['credit_enabled'] as num).toInt(), 1);

    await commercial.recordCustomerPayment(
      actor: owner,
      customerId: customerId,
      amount: 10,
      paymentMethod: 'Bank',
      reference: 'BANK-001',
    );
    accounts = await commercial.listCustomerAccounts(owner);
    expect(
      (accounts.singleWhere((row) => row['id'] == customerId)['balance'] as num)
          .toDouble(),
      15,
    );
    final transactions = await commercial.customerTransactions(
      actor: owner,
      customerId: customerId,
    );
    expect(transactions.first['transaction_type'], 'payment');
    expect((transactions.first['amount'] as num).toDouble(), -10);
  });

  test('stock transfer dispatches and receives inventory once', () async {
    final product = (await database.getProducts()).first;
    final sourceStock = product.stockQty;
    final destinationBranchId = await commercial.createBranch(
      actor: owner,
      name: 'Second Branch',
      code: 'BR002',
    );
    final transferId = await commercial.createStockTransfer(
      actor: owner,
      destinationBranchId: destinationBranchId,
      quantitiesByProductId: {product.id!: 2},
      notes: 'Test transfer',
    );
    await commercial.dispatchStockTransfer(
      actor: owner,
      transferId: transferId,
    );
    final sourceAfter = (await database.getProducts()).firstWhere(
      (item) => item.id == product.id,
    );
    expect(sourceAfter.stockQty, sourceStock - 2);

    final destinationOwner = owner.copyWith(branchId: destinationBranchId);
    await commercial.receiveStockTransfer(
      actor: destinationOwner,
      transferId: transferId,
    );
    final destinationProduct = (await database.getProducts(
      branchId: destinationBranchId,
    )).firstWhere((item) => item.id == product.id);
    expect(destinationProduct.stockQty, 2);
    await expectLater(
      commercial.receiveStockTransfer(
        actor: destinationOwner,
        transferId: transferId,
      ),
      throwsStateError,
    );
  });

  test('month-end recurring date clamps safely', () {
    final next = CommercialService.nextRecurringDate(
      DateTime(2026, 1, 31),
      'monthly',
    );
    expect(next, DateTime(2026, 2, 28));
    final leap = CommercialService.nextRecurringDate(
      DateTime(2028, 1, 31),
      'monthly',
    );
    expect(leap, DateTime(2028, 2, 29));
  });
}
