$ErrorActionPreference = 'Stop'
$p = 'lib/screens/products_screen.dart'
$c = Get-Content $p -Raw

$old = @'
  String query = '';
'@
$new = @'
  String query = '';
  String categoryFilter = 'All';
  String stockFilter = 'All';
'
if (-not $c.Contains($old)) { throw 'Missing filter field marker' }
$c = $c.Replace($old, $new)

$old = @'
    final normalized = query.trim().toLowerCase();
    final products = state.products.where((product) {
      if (normalized.isEmpty) return true;
      return product.name.toLowerCase().contains(normalized) ||
          product.sku.toLowerCase().contains(normalized) ||
          product.barcode.toLowerCase().contains(normalized) ||
          product.category.toLowerCase().contains(normalized);
    }).toList();
'
$new = @'
    final normalized = query.trim().toLowerCase();
    final categories = state.products
        .map((product) => product.category)
        .where((category) => category.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final products = state.products.where((product) {
      if (categoryFilter != 'All' && product.category != categoryFilter) {
        return false;
      }
      if (stockFilter == 'Out of stock' && product.stockQty > 0) return false;
      if (stockFilter == 'Low stock' &&
          (product.stockQty <= 0 || !product.isLowStock)) {
        return false;
      }
      if (stockFilter == 'In stock' &&
          (product.stockQty <= 0 || product.isLowStock)) {
        return false;
      }
      if (normalized.isEmpty) return true;
      return product.name.toLowerCase().contains(normalized) ||
          product.sku.toLowerCase().contains(normalized) ||
          product.barcode.toLowerCase().contains(normalized) ||
          product.category.toLowerCase().contains(normalized);
    }).toList();
'@
if (-not $c.Contains($old)) { throw 'Missing product filter marker' }
$c = $c.Replace($old, $new)

$old = @'
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search by product, SKU, barcode or category',
          ),
          onChanged: (value) => setState(() => query = value),
        ),
        const SizedBox(height: 14),
'@
$new = @'
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 420,
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search product, SKU, barcode or category',
                ),
                onChanged: (value) => setState(() => query = value),
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: categoryFilter,
                decoration: const InputDecoration(labelText: 'Category'),
                items: ['All', ...categories]
                    .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) => setState(() => categoryFilter = value ?? 'All'),
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: stockFilter,
                decoration: const InputDecoration(labelText: 'Stock'),
                items: const ['All', 'In stock', 'Low stock', 'Out of stock']
                    .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) => setState(() => stockFilter = value ?? 'All'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
'@
if (-not $c.Contains($old)) { throw 'Missing product filter UI' }
$c = $c.Replace($old, $new)

Set-Content $p $c -NoNewline
