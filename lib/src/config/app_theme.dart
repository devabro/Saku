import 'package:flutter/material.dart';

/// Tema Saku: feminim yang sophisticated — warm cream + dusty rose,
/// bukan "pink semua" yang kekanakan. Dua-duanya hangat:
/// light = cream lembut, dark = charcoal kehangatan rose.
/// Tanpa gradient, tanpa shadow bertumpuk: flat, bulat, elegan.
class AppTheme {
  AppTheme._();

  // Dusty rose — primary light. Dewasa, lembut, tidak norak.
  static const _roseLight = Color(0xFFC4707F);
  // Soft rose — primary dark (lebih terang biar kebaca di gelap).
  static const _roseDark = Color(0xFFE8A0AC);

  static const _creamBg = Color(0xFFFAF4EF);
  static const _creamCard = Color(0xFFFFFBF8);
  static const _warmDarkBg = Color(0xFF221B1E);
  static const _warmDarkCard = Color(0xFF2D2428);

  static const _radius = 24.0;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _roseLight,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        surface: _creamCard,
      ),
      scaffoldBackgroundColor: _creamBg,
      cardTheme: const CardThemeData(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        elevation: 0,
        color: _creamCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(_radius)),
        ),
      ),
      appBarTheme: const AppBarTheme(centerTitle: false),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _roseDark,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        surface: _warmDarkCard,
      ),
      scaffoldBackgroundColor: _warmDarkBg,
      cardTheme: const CardThemeData(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        elevation: 0,
        color: _warmDarkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(_radius)),
        ),
      ),
      appBarTheme: const AppBarTheme(centerTitle: false),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
