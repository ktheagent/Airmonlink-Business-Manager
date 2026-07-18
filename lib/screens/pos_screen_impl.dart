import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/formatters.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../state/app_state.dart';
import '../widgets/feedback.dart';
import '../widgets/page_header.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final Map<int, _CartLine> _cart = {};
  final TextEditingController _scannerController = TextEditingController();
  final FocusNode _scannerFocus = FocusNode(debugLabel: 'pos_barcode_scanner');
  String _query = '';
  bool _processingScan = false;

  double get _subtotal => _cart.values.fold(0.0, (sum, line) => sum + line.total);

  @override
  void initState() {
    super.initState();
    _focusScanner();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _scannerFocus.dispose();
    super.dispose();
  }

  void _focusScanner() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scannerFocus.requestFocus();
    });
  }

  Future<void> _processScan(String value) async {
    if (_processingScan) return;
    final code = value.trim();
    if (code.isEmpty) {
      _focusScanner();
      return;
    }
    _processingScan = true;
    try {
      final state = AppStateScope.of(context);
      Product? match;
      for (final product in state.products) {
        if (product.barcode.isNotEmpty && product.barcode.toLowerCase() == code.toLowerCase()) {
          match = product;
          break;
        }
      }
      if (match == null) {
        for (final product in state.products) {
          if (product.sku.isNotEmpty && product.sku.toLowerCase() == code.toLowerCase()) {
            match = product;
            break;
          }
        }
      }
      if (match == null) {
        showFailure(context, 'Product not found for barcode or SKU: $code');
        return;
      }
      _addProduct(match, fromScanner: true);
    } finally {
      _scannerController.clear();
      if (mounted) setState(() => _query = '');
      _processingScan = false;
      _focusScanner();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final needle = _query.trim().toLowerCase();
    final products = state.products.where((product) {
      if (product.stockQty <= 0) return false;
      if (needle.isEmpty) return true;
      return product.name.toLowerCase().contains(needle) ||
          product.sku.toLowerCase().contains(needle) ||
          product.barcode.toLowerCase().contains(needle) ||
          product.category.toLowerCase().contains(needle);
    }).toList(growable: false);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f2): _focusScanner,
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): _focusScanner,
      },
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const PageHeader(
              title: 'Point of sale',
              subtitle: 'Scan a barcode or search products, then complete payment.',
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.qr_code_scanner, color: Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        const Text('Scanner ready', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                        const Spacer(),
                        const Text('F2 / Ctrl+B to focus'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _scannerController,
                      focusNode: _scannerFocus,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onChanged: (value) => setState(() => _query = value),
                      onSubmitted: _processScan,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Scan barcode or search by product, SKU or category',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final catalog = _buildCatalog(products);
                  final cart = _buildCart(state);
                  if (constraints.maxWidth >= 980) {
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
                      Expanded(child: catalog),
                      const SizedBox(height: 12),
                      Expanded(child: cart),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildCatalog(List<Product> products) {
    return Card(
      child: products.isEmpty
          ? const Center(child: Text('No available products match this search.'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: products.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final product = products[index];
                return ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(product.name),
                  subtitle: Text('${product.sku} • ${product.barcode}'),
                  trailing: Text(AppFormatters.money(product.sellingPrice)),
                  onTap: () => _addProduct(product),
                );
              },
            ),
    );
  }

  Widget _buildCart(AppState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Current sale', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton(
                  onPressed: _cart.isEmpty ? null : () => setState(_cart.clear),
                  child: const Text('Clear'),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: _cart.isEmpty
                  ? const Center(child: Text('Scan or select a product to begin.'))
                  : ListView.builder(
                      itemCount: _cart.length,
                      itemBuilder: (context, index) {
                        final line = _cart.values.elementAt(index);
                        return ListTile(
                          title: Text(line.product.name),
                          subtitle: Text('${AppFormatters.money(line.product.sellingPrice)} × ${line.quantity.toStringAsFixed(0)}'),
                          trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                on@ressed: () => _changeQuantity(line.product, -1),
                                icon: const Icon(Icons.remove),
                              ),
                            Text(AppFormatters.money(line.total)),
                            IconButton(
                                on@ressed: line.quantity >= line.product.stockQty ? null : () => _changeQuantity(line.product, 1),
                                icon: const Icon(Icons.add),
                              ),
                          ],
                        ),
                      );
                      },
                    ),
            ),
            const Divider(),
            Row(
              children: [
                const Text('Subtotal'),
                const Spacer(),
                Text(AppFormatters.money(_subtotal), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _cart.isEmpty ? null : () => _checkout(state),
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

  void _addProduct(Product product, {bool fromScanner = false}) {
    final id = product.id;
    if (id == null) return;
    final current = _cart[id];
    final quantity = current?.quantity ?? 0.0;
    if (product.stockQty <= 0) {
      showFailure(context, '${product.name} is out of stock.');
      return;
    }
    if (quantity >= product.stockQty) {
      showFailure(context, 'Maximum available stock reached for ${product.name}.');
      return;
    }
    setState(() => _cart[id] = _CartLine(product: product, quantity: quantity + 1));
    if (fromScanner) showSuccess(context, '${product.name} added to cart.');
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

  Future<void> _checkout(AppState state) async {
    final discountController = TextEditingController(text: '0.00');
    var paymentMethod = 'Cash';
    int? customerId;

    final result = await showDialog<_CheckoutResult>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Complete sale'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: paymentMethod,
                  decoration: const InputDecoration(labelText: 'Payment method'),
                  items: const [
                    DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'Card', child: Text('Card')),
                    DropdownMenuItem(value: 'Mobile Money', child: Text('Mobile Money')),
                    DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'Credit', child: Text('Credit')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => paymentMethod = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: customerId,
                  decoration: InputDecoration(
                    labelText: paymentMethod == 'Credit' ? 'Customer (required)' : 'Customer (optional)',
                  ),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Walk-in customer')),
                    ...state.customers.map((customer) => DropdownMenuItem<int?>(value: customer.id, child: Text(customer.name))),
                  ],
                  onChanged: (value) => setDialogState(() => customerId = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: discountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Discount'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: paymentMethod == 'Credit' && customerId == null
                  ? null
                  : () {
                      final discount = double.tryParse(discountController.text.trim());
                      if (discount == null || discount < 0 || discount > _subtotal) return;
                      Navigator.pop(
                        dialogContext,
                        _CheckoutResult(
                          discount: discount,
                          paymentMethod: paymentMethod,
                          customerId: customerId,
                        ),
                      );
                    },
              child: const Text('Confirm payment'),
            ),
          ],
        ),
      ),
    );

    discountController.dispose();
    if (result == null || !mounted) return;

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
      discount: result.discount,
      paymentMethod: result.paymentMethod,
      customerId: result.customerId,
    );

    try {
      final invoice = await state.completeSale(draft);
      if (!mounted) return;
      setState(_cart.clear);
      showSuccess(context, 'Sale completed. Invoice: $invoice');
      _focusScanner();
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
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
