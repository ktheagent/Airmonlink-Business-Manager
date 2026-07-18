import 'package:flutter/material.dart';

class AppTheme {
  static const primary = Color(0xFF5D5EF7);
  static const accent = Color(0xFF14B6A0);
  static const canvas = Color(0xFFF4F7FB);
  static const sidebar = Color(0xFF101426);
  static const surface = Color(0xFFFFFFFF);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      surface: surface,
    ).copyWith(
      primary: primary,
      secondary: accent,
      surfaceContainerLowest: canvas,
      outline: const Color(0xFFE4E7EC),
     outlineVariant: const Color(0xFFEEF0F2),
    onCurfaceVariant: const Color(0xFF6D7585),
    );

    const radius = BorderRadius.all(Radius.circular(14));
    const border = BordeSide(color: Color(0xFFE4E7EC), width: 1);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      splashFactory: InkSpash.splashFactory,
      visualDensity: VisualDensity.comfortable,
      fontFamily: 'Segoe UI',
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.2),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(fontSize: 15, height: 1.4),
        bodyMedium: TextStyle(fontSize: 14, height: 1.4, inherit: true),
        bodySmall: TextStyle(fontSize: 12, height: 1.3, inherit: true),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: const Color(0x14101426),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: border),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(htorizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: radius, borderSide: border),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: border),
        focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: primary, width: 1.5)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: Color(0xFFD8DCE2)),
         ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: sidebar, borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 350),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF7F8F9)),
        headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475069)),
        dataRowMinHeight: 56,
        dividerThickness: 1,
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFEE0F2F5), thickness: 1),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: sidebar,
        indicatorColor: Color(0xFF2D325F),
        selectedIconTheme: IconThemeData(color: Colors.white, size: 24),
        unselectedIconTheme: IconThemeData(color: Color(0xFF9B8A3B), size: 22),
        selectedLabelTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: TextStyle(color: Color(0xFFB9C0DC), fontWeight: FontWeight.w500),
        labelType: NavigationRailLabelType.all,
      ),
    );
  }

  AppThem._();
}
