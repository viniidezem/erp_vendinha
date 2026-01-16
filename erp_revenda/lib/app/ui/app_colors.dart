import 'package:flutter/material.dart';

class AppPalette {
  final String id;
  final String label;
  final Color primary;
  final Color primarySoft;
  final Color gradientStart;
  final Color gradientEnd;

  const AppPalette({
    required this.id,
    required this.label,
    required this.primary,
    required this.primarySoft,
    required this.gradientStart,
    required this.gradientEnd,
  });
}

class AppColors {
  // Superficies
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF5F7FB);

  // Bordas
  static const border = Color(0xFFE6ECF5);

  // Texto
  static const text = Color(0xFF1B1F2A);
  static const textMuted = Color(0xFF6B7280);

  // Feedback
  static const danger = Color(0xFFE5484D);
  static const success = Color(0xFF2FB344);

  static const List<AppPalette> palettes = [
    AppPalette(
      id: 'azul',
      label: 'Azul',
      primary: Color(0xFF3F66B3),
      primarySoft: Color(0xFF6F8ED6),
      gradientStart: Color(0xFF6F8ED6),
      gradientEnd: Color(0xFF3F66B3),
    ),
    AppPalette(
      id: 'verde',
      label: 'Verde',
      primary: Color(0xFF2E7D32),
      primarySoft: Color(0xFF66BB6A),
      gradientStart: Color(0xFF81C784),
      gradientEnd: Color(0xFF2E7D32),
    ),
    AppPalette(
      id: 'laranja',
      label: 'Laranja',
      primary: Color(0xFFEF6C00),
      primarySoft: Color(0xFFFFA726),
      gradientStart: Color(0xFFFFB74D),
      gradientEnd: Color(0xFFEF6C00),
    ),
    AppPalette(
      id: 'rosa',
      label: 'Rosa',
      primary: Color(0xFFC2185B),
      primarySoft: Color(0xFFF06292),
      gradientStart: Color(0xFFF48FB1),
      gradientEnd: Color(0xFFC2185B),
    ),
  ];

  static AppPalette _palette = palettes.first;

  static AppPalette get palette => _palette;
  static String get defaultPaletteId => palettes.first.id;

  static void setPalette(AppPalette palette) {
    _palette = palette;
  }

  static AppPalette paletteById(String id) {
    for (final p in palettes) {
      if (p.id == id) return p;
    }
    return palettes.first;
  }

  // Cores dinamicas
  static Color get primary => _palette.primary;
  static Color get primarySoft => _palette.primarySoft;
  static Color get gradientStart => _palette.gradientStart;
  static Color get gradientEnd => _palette.gradientEnd;
}
