import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../models/product.dart';
import '../state/app_state.dart';
import '../widgets/feedback.dart';
import '../widgets/page_header.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final normalized = query.trim().toLowerCase();
    final products = state.products.where((product) {
      if (normalized.isEmpty) return true;
      return product.name.toLowerCase().contains(normalized) ||
          product.sku.toLowerCase().contains(normalized) ||
          product.barcode.toLowerCase().contains(normalized) ||
          product.category.toLowerCase().contains(normalized);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Products and inventory',
            subtitle: 'Manage prices, barcodes, stock levels and categories.',
            actions: [
              FilledButton.icon(
                onPressed: () => _showProductDialog(context, state),
                icon: const Icon(Icons.add),
                label: const Text('Add product'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search by product, SKU, barcode or category',
            ),
            onChanged: (value) => setState(() => query = value),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Card(
              child: products.isEmpty
                  ? const Center(child: Text('No matching products found.'))
                  : SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Product')),
                            DataColumn(label: Text('SKU')),
                            DataColumn(label: Text('Category')),
                            DataColumn(label: Text('Cost'), numeric: true),
                            DataColumn(label: Text('Selling'), numeric: true),
                            DataColumn(label: Text('Stock'), numeric: true),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: products.map((product) {
                            return DataRow(
                              cells: [
                                DataCell(Text(product.name)),
                                DataCell(
                                  Text(product.sku.isEmpty ? '—' : product.sku),
                                ),
                                DataCell(Text(product.category)),
                                DataCell(
                                  Text(AppFormatters.money(product.costPrice)),
                                ),
                                DataCell(
                                  Text(
                                    AppFormatters.money(product.sellingPrice),
                                  ),
                                ),
                                DataCell(
                                  Text(product.stockQty.toStringAsFixed(1)),
                                ),
                                DataCell(
                                  Chip(
                                    label: Text(
                                      product.isLowStock
                                          ? 'Low stock'
                                          : 'In stock',
                                    ),
                                    avatar: Icon(
                                      product.isLowStock
                                          ? Icons.warning_amber
                                          : Icons.check_circle,
                                      size: 17,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Adjust stock',
                                        onPressed: () => _adjustStock(
                                          context,
                                          state,
                                          product,
                                        ),
                                        icon: const Icon(
                                          Icons.inventory_2_outlined,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Edit product',
                                        onPressed: () => _showProductDialog(
                                          context,
                                          state,
                                          product: product,
                                        ),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'Delete product',
                                        onPressed: () => _deleteProduct(
                                          context,
                                          state,
                                          product,
                                        ),
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showProductDialog(
    BuildContext context,
    AppState state, {
    Product? product,
  }) async {
    final name = TextEditingController(text: product?.name ?? '');
    final sku = TextEditingController(text: product?.sku ?? '');
    final barcode = TextEditingController(text: product?.barcode ?? '');
    final category = TextEditingController(
      text: product?.category ?? 'General',
    );
    final cost = TextEditingController(
      text: product?.costPrice.toStringAsFixed(2) ?? '0.00',
    );
    final selling = TextEditingController(
      text: product?.sellingPrice.toStringAsFixed(2) ?? '0.00',
    );
    final stock = TextEditingController(
      text: product?.stockQty.toStringAsFixed(1) ?? '0',
    );
    final lowStock = TextEditingController(
      text: product?.lowStockLevel.toStringAsFixed(1) ?? '5',
    );
    final formKey = GlobalKey<FormState>();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(product == null ? 'Add product' : 'Edit product'),
        content: SizedBox(
          width: 620,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 288,
                    child: TextFormField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Product name',
                      ),
                      validator: _required,
                    ),
                  ),
                  SizedBox(
                    width: 288,
                    child: TextFormField(
                      controller: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      validator: _required,
                    ),
                  ),
                  SizedBox(
                    width: 288,
                    child: TextFormField(
                      controller: sku,
                      decoration: const InputDecoration(labelText: 'SKU'),
                    ),
                  ),
                  SizedBox(
                    width: 288,
                    child: TextFormField(
                      controller: barcode,
                      decoration: const InputDecoration(labelText: 'Barcode'),
                    ),
                  ),
                  SizedBox(
                    width: 288,
                    child: TextFormField(
                      controller: cost,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Cost price',
                      ),
                      validator: _nonNegativeNumber,
                    ),
                  ),
                  SizedBox(
                    width: 288,
                    child: TextFormField(
                      controller: selling,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Selling price',
                      ),
                      validator: _nonNegativeNumber,
                    ),
                  ),
                  SizedBox(
                    width: 288,
                    child: TextFormField(
                      controller: stock,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Opening stock',
                      ),
                      validator: _nonNegativeNumber,
                    ),
                  ),
                  SizedBox(
                    width: 288,
                    child: TextFormField(
                      controller: lowStock,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Low-stock alert level',
                      ),
                      validator: _nonNegativeNumber,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Save product'),
          ),
        ],
      ),
    );

    if (shouldSave != true || !context.mounted) return;

    final value = Product(
      id: product?.id,
      name: name.text.trim(),
      sku: sku.text.trim(),
      barcode: barcode.text.trim(),
      category: category.text.trim(),
      costPrice: double.parse(cost.text.trim()),
      sellingPrice: double.parse(selling.text.trim()),
      stockQty: double.parse(stock.text.trim()),
      lowStockLevel: double.parse(lowStock.text.trim()),
      createdAt: product?.createdAt ?? DateTime.now(),
    );

    try {
      if (product == null) {
        await state.addProduct(value);
      } else {
        await state.updateProduct(value);
      }
      if (context.mounted) showSuccess(context, 'Product saved successfully.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _adjustStock(
    BuildContext context,
    AppState state,
    Product product,
  ) async {
    final amount = TextEditingController(text: '1');
    var addStock = true;
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Adjust ${product.name}'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      label: Text('Add stock'),
                      icon: Icon(Icons.add),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text('Remove stock'),
                      icon: Icon(Icons.remove),
                    ),
                  ],
                  selected: {addStock},
                  onSelectionChanged: (selection) {
                    setDialogState(() => addStock = selection.first);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Quantity'),
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
              onPressed: () {
                final parsed = double.tryParse(amount.text.trim());
                if (parsed == null || parsed <= 0) return;
                Navigator.pop(dialogContext, addStock ? parsed : -parsed);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );

    if (result == null || !context.mounted) return;
    try {
      await state.adjustStock(product, result);
      if (context.mounted) showSuccess(context, 'Stock adjusted successfully.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _deleteProduct(
    BuildContext context,
    AppState state,
    Product product,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          'Delete ${product.name}? Existing sale records will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await state.deleteProduct(product);
      if (context.mounted) showSuccess(context, 'Product deleted.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  static String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  static String? _nonNegativeNumber(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed < 0) return 'Enter a valid number';
    return null;
  }
}
