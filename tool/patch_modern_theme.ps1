$ErrorActionPreference = 'Stop'
$p = 'lib/core/app_theme.dart'
$c = Get-Content $p -Raw
$c = $c.Replace('0xFF123A75', '0xFF4F46E5')
$c = $c.Replace('xFFF4F7FB', 'xFFF8FAFC')
$c = $c.Replace('BorderRadius.circular(16)', 'BorderRadius.circular(20)')
$c = $c.Replace('0xFFE1E7F0', '0xFFE6E8EF')
$anchor = "     );`n  }"
$nav = "@     navigationRailTheme: const NavigationRailThemeData(`n        backgroundColor: Color(0xFF0B1220),`n        indicatorColor: Color(0x334F46E5),`n        useIndicator: true,`n        selectedIconTheme: IconThemeData(color: Colors.white),`n        unselectedIconTheme: IconThemeData(color: Color(0xFF94A3B8)),`n        selectedLabelTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),`n        unselectedLabelTextStyle: TextStyle(color: Color(0xFFC4CBD8)),`n      ),`n      tooltipTheme: const TooltipThemeData(`n        backgroundColor: Color(0xFF0B1220),`n        textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),`n        waitDuration: Duration(milliseconds: 300),`n      ),`n    );`n}"
$if (-not $c.Contains($anchor)) { throw 'Theme anchor not found.' }
$c = $c.Replace($anchor, $nav)
Set-Content $p $c -NoNewline
