$ErrorActionPreference = 'Stop'

$p = 'lib/core/app_theme.dart'
$c = Get-Content $p -Raw
$c = $c.Replace('onCurfaceVariant', 'onSurfaceVariant')
$c = $c.Replace('htorizontal:', 'horizontal:')
Set-Content $p $c -NoNewline

$p = 'lib/screens/modern_shell_screen.dart'
$c = Get-Content $p -Raw
$c = $c.Replace('EdgeInsets.fly', 'EdgeInsets.symmetric')
$c = $c.Replace('Theme.o(', 'Theme.of(')
Set-Content $p $c -NoNewline
