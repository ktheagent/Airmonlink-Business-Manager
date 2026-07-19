import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

import '../core/formatters.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../state/app_state.dart';
import '../widgets/feedback.dart';
import '../widgets/page_header.dart';
import '../widgets/pdf_preview_dialog.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final Map<int, _CartLine> _cart = {};
  String _query = '';

  double get _subtotal =>
      _cart.values.fold(0, (sum, line) => sum + line.total);

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final query = _query.trim().toLowerCase();
    final products = state.products.where((product) {
      if (product.stockQty <= 0) return false;
      if (query.isEmpty) return true;
      return product.name.toLowerCase().contains(query) ||
          product.sku.toLowerCase().contains(query) ||
          product.barcode.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const PageHeader(
            title: 'Point of sale',
            subtitle: 'Select products, review quantities and complete payment.',
          ),
          const SizedBox(height: 18),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 980;
                final catalog = _buildCatalog(context, products);
                final cart = _buildCart(context, state);
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 7, child: catalog),
                      const SizedBox(width: 16),
                      SizedBox(width: 390, child: cart),
                    ],
                  );
                }
                return Column(
                  children: [
                    Expanded(flex: 6, child: catalog),
                    const SizedBox(height: 14),
                    Expanded(flex: 5, child: cart),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalog(BuildContext context, List<Product> products) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Scan barcode or search products',
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: products.isEmpty
                  ? const Center(child: Text('No available products match this search.'))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 900
                            ? 4
                            : constraints.maxWidth >= 620
                                ? 3
                                : 2;
                        return GridView.builder(
                          itemCount: products.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.35,
                          ),
                          itemBuilder: (context, index) {
                            final product = products[index];
                            final inCart = _cart[product.id]?.quantity ?? 0;
                            return InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _addProduct(product),
                              child: Ink(
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFDCE4EF)),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(13),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              product.category,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context).textTheme.labelMedium,
                                            ),
                                          ),
                                          if (inCart > 0)
                                            Badge(label: Text(inCart.toStringAsFixed(0))),
                                        ],
                                      ),
                                      const Spacer(),
                                      Text(
                                        product.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        AppFormatters.money(product.sellingPrice),
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              color: Theme.of(context).colorScheme.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      Text(
                                        '${product.stockQty.toStringAsFixed(1)} available',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCart(BuildContext context, AppState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Current sale',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _cart.isEmpty ? null : () => setState(_cart.clear),
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Clear'),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: _cart.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 44),
                          SizedBox(height: 10),
                          Text('Select a product to begin.'),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _cart.length,
                      separatorBuilder: (_, __) => const Divider(height: 18),
                      itemBuilder: (context, index) {
                        final line = _cart.values.elementAt(index);
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    line.product.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${AppFormatters.money(line.product.sellingPrice)} × ${line.quantity.toStringAsFixed(0)}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      IconButton.outlined(
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => _changeQuantity(line.product, -1),
                                        icon: const Icon(Icons.remove, size: 17),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        child: Text(line.quantity.toStringAsFixed(0)),
                                      ),
                                      IconButton.outlined(
                                        visualDensity: VisualDensity.compact,
                                        onPressed: line.quantity >= line.product.stockQty
                                            ? null
                                            : () => _changeQuantity(line.product, 1),
                                        icon: const Icon(Icons.add, size: 17),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  AppFormatters.money(line.total),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                IconButton(
                                  tooltip: 'Remove',
                                  onPressed: () => setState(() => _cart.remove(line.product.id)),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
            ),
            const Divider(),
            Row(
              children: [
                const Text('Subtotal'),
                const Spacer(),
                Text(
                  AppFormatters.money(_subtotal),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _cart.isEmpty ? null : () => _checkout(context, state),
              icon: const Icon(Icons.payments_outlined),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Complete sale'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addProduct(Product product) {
    final id = product.id;
    if (id == null) return;
    final existing = _cart[id];
    final quantity = existing?.quantity ?? 0;
    if (quantity >= product.stockQty) {
      showFailure(context, 'No more stock is available for ${product.name}.');
      return;
    }
    setState(() {
      _cart[id] = _CartLine(product: product, quantity: quantity + 1);
    });
  }

  void _changeQuantity(Product product, double change) {
    final id = product.id;
    if (id == null) return;
    final current = _cart[id];
    if (current == null) return;
    final next = current.quantity + change;
    setState(() {
      if (next <= 0) {
        _cart.remove(id);
      } else if (next <= product.stockQty) {
        _cart[id] = _CartLine(product: product, quantity: next);
      }
    });
  }

  Future<void> _checkout(BuildContext context, AppState state) async {
    final discountController = TextEditingController(text: '0.00');
    var paymentMethod = 'Cash';
    int? customerId;

    final checkout = await showDialog<_CheckoutResult>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final discount = double.tryParse(discountController.text) ?? 0;
          final payable = (_subtotal - discount).clamp(0, double.infinity);
          return AlertDialog(
            title: const Text('Complete sale'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: paymentMethod,
                    decoration: const InputDecoration(labelText: 'Payment method'),
                    items: const [
                      DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'Mobile Money', child: Text('Mobile Money')),
                      DropdownMenuItem(value: 'Card', child: Text('Card')),
                      DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                      DropdownMenuItem(value: 'Credit', child: Text('Credit sale')),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => paymentMethod = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: customerId,
                    decoration: InputDecoration(
                      labelText: paymentMethod == 'Credit'
                          ? 'Customer (required for credit)'
                          : 'Customer (optional)',
                      helperText: paymentMethod == 'Credit'
                          ? 'The amount will be added to the customer balance.'
                          : null,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Walk-in customer')),
                      ...state.customers.map(
                        (customer) => DropdownMenuItem<int?>(
                          value: customer.id,
                          child: Text(customer.name),
                        ),
                      ),
                    ],
                    onChanged: (value) => setDialogState(() => customerId = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: discountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Discount'),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Text('Amount payable'),
                        const Spacer(),
                        Text(
                          AppFormatters.money(payable),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              FilledButton(
                onPressed: paymentMethod == 'Credit' && customerId == null
                    ? null
                    : () {
                  final discountValue = double.tryParse(discountController.text.trim());
                  if (discountValue == null || discountValue < 0 || discountValue > _subtotal) {
                    return;
                  }
                  Navigator.pop(
                    dialogContext,
                    _CheckoutResult(
                      discount: discountValue,
                      paymentMethod: paymentMethod,
                      customerId: customerId,
                    ),
                  );
                },
                child: const Text('Confirm payment'),
              ),
            ],
          );
        },
      ),
    );

    if (checkout == null || !context.mounted) return;

    final draft = SaleDraft(
      items: _cart.values
          .map(
            (line) => SaleItem(
              productId: line.product.id!,
              productName: line.product.name,
              quantity: line.quantity,
              unitPrice: line.product.sellingPrice,
              costPrice: line.product.costPrice,
            ),
          )
          .toList(growable: false),
      discount: checkout.discount,
      paymentMethod: checkout.paymentMethod,
      customerId: checkout.customerId,
    );

    try {
      final soldAt = DateTime.now();
      final customerName = _customerName(state, draft.customerId);
      final invoice = await state.completeSale(draft);
      if (!context.mounted) return;
      setState(_cart.clear);
      showSuccess(context, 'Sale completed. Invoice: $invoice');
      await _showReceiptPreview(
        context,
        state,
        invoice: invoice,
        draft: draft,
        soldAt: soldAt,
        customerName: customerName,
      );
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  String? _customerName(AppState state, int? customerId) {
    if (customerId == null) return null;
    for (final customer in state.customers) {
      if (customer.id == customerId) return customer.name;
    }
    return null;
  }

  Future<void> _showReceiptPreview(
    BuildContext context,
    AppState state, {
    required String invoice,
    required SaleDraft draft,
    required DateTime soldAt,
    String? customerName,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AppPdfPreviewDialog(
        title: 'Receipt $invoice',
        buildPdf: (format) => state.buildReceiptPdf(
          format: format,
          invoiceNo: invoice,
          sale: draft,
          soldAt: soldAt,
          customerName: customerName,
        ),
        fileName: 'receipt-$invoice.pdf',
        initialPageFormat: PdfPageFormat.roll80,
        pageFormats: const {
          '80 mm receipt': PdfPageFormat.roll80,
          '57 mm receipt': PdfPageFormat.roll57,
        },
        canChangeOrientation: false,
        canChangePageFormat: true,
        dynamicLayout: false,
        forceCustomPrintPaper: true,
      ),
    );
  }
}

class _CartLine {
  const _CartLine({required this.product, required this.quantity});

  final Product product;
  final double quantity;

  double get total => product.sellingPrice * quantity;
}

class _CheckoutResult {
  const _CheckoutResult({
    required this.discount,
    required this.paymentMethod,
    required this.customerId,
  });

  final double discount;
  final String paymentMethod;
  final int? customerId;
}
