$p="$PSScriptRoot/patch_pos_barcode.ps1"
$c=Get-Content $p -Raw
$c=$c.Replace("`$old = '  void _addProduct(Product product) {'","`$old = 'void _addProduct(Product product) {'")
Set-Content $p $c -NoNewline
