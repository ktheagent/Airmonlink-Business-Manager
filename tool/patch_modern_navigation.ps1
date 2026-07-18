$ErrorActionPreference = 'Stop'
$p = 'lib/screens/shell_screen.dart'
$c = Get-Content $p -Raw
$c = $c.Replace('>= 1280', '>= 1180')
$pairs = @(
  @('Icons.dashboard_outlined', 'Icons.dashboard', 'Dashboard'),
  @('Icons.point_of_sale_outlined', 'Icons.point_of_sale', 'Point of sale'),
  @('Icons.inventory_2_outlined', 'Icons.inventory_2', 'Products'),
  @('Icons.people_outline', 'Icons.people', 'Customers'),
  @('Icons.local_shipping_outlined', 'Icons.local_shipping', 'Suppliers'),
  @('Icons.receipt_long_outlined', 'Icons.receipt_long', 'Expenses'),
  @('Icons.analytics_outlined', 'Icons.analytics', 'Reports'),
  @('Icons.settings_outlined', 'Icons.settings', 'Settings')
)
foreach ($pair in $pairs) {
  $outline = $pair[0]
  $filled = $pair[1]
  $label = $pair[2]
  $c = $c.Replace("icon: Icon($outline)", "icon: Tooltip(message: '$label', child: Icon($outline))")
  $c = $c.Replace("selectedIcon: Icon($filled)", "selectedIcon: Tooltip(message: '$label', child: Icon($filled))")
  $c = $c.Replace("label: Text('$label')", "label: Tooltip(message: '$label', child: Text('$label'))")
}
Set-Content $p $c -NoNewline
