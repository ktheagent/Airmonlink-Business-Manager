$ErrorActionPreference = 'Stop'
$path = 'lib/screens/pos_screen.dart'
$content = Get-Content $path -Raw

$old = @'
  final Map<int, _CartLine> _cart = {};
  String _query = '';
'@
$new = @'
  final Map<int, _CartLine> _cart = {};
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
'@
$marker = 'Pos cart fields'
if (-not $content.Contains($old)) { throw "Missing $marker" }
$content = $content.Replace($old, $new)

$old = @'
          TextField(
            autofocus: true,
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Scan barcode or search products',
            ),
          ),
'@
$new = @'
          TextField(
            controller: _searchController,
            autofocus: true,
            onSubmitted: _scanBarcode,
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.qr_code_scanner),
              hintText: 'Scan barcode or search products',
              helperText: 'Scan and press Enter to add the item.',
            ),
          ),
'
$marker = 'Pos search field'
if (-not $content.Contains($old)) { throw "Missing $marker" }
$content = $content.Replace($old, $new)

$old = '  void _addProduct(Product product) {'
$new = @'
  void _scanBarcode(String value) {
    final code = value.trim().toLowerCase();
    if (code.isEmpty) return;
    final matches = AppStateScope.of(context).products.where((product) =>
        product.stockQty > 0 &&
        (product.barcode.trim().toLowerCase() == code ||
            product.sku.trim().toLowerCase() == code)).toList();
    if (matches.length != 1) {
      showFailure(
        context,
        matches.isEmpty
            ? 'No in-stock product uses that barcode or SKU.'
            : 'More than one product uses that code.',
      );
      return;
    }
    _addProduct(matches.single);
    _searchController.clear();
    setState(() => _query = '');
  }

  void _addProduct(Product product) {
'@
$marker = 'Pos barcode handler'
if (-not $content.Contains($old)) { throw "Missing $marker" }
$content = $content.Replace($old, $new)

Set-Content $path $content -NoNewline
