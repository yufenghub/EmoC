part of '../main.dart';

class EmoCTheme {
  const EmoCTheme._();

  static ThemeData light([Color seedColor = const Color(0xFF3F7BFF)]) {
    return _base(Brightness.light, seedColor).copyWith(
      scaffoldBackgroundColor: const Color(0xFFF7F8FB),
      cardTheme: _cardTheme(Colors.white),
    );
  }

  static ThemeData dark([Color seedColor = const Color(0xFF3F7BFF)]) {
    return _base(Brightness.dark, seedColor).copyWith(
      scaffoldBackgroundColor: const Color(0xFF0A0B0E),
      cardTheme: _cardTheme(const Color(0xFF1A1C22)),
    );
  }

  static ThemeData _base(Brightness brightness, Color seedColor) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return ThemeData(useMaterial3: true, colorScheme: scheme);
  }

  static CardThemeData _cardTheme(Color color) {
    return CardThemeData(
      color: color,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
