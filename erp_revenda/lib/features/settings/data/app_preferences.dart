import '../../../app/ui/app_colors.dart';

class AppPreferences {
  final String? storeName;
  final String paletteId;

  const AppPreferences({
    required this.storeName,
    required this.paletteId,
  });

  AppPreferences copyWith({
    String? storeName,
    String? paletteId,
  }) {
    return AppPreferences(
      storeName: storeName ?? this.storeName,
      paletteId: paletteId ?? this.paletteId,
    );
  }

  static AppPreferences defaults() {
    return AppPreferences(
      storeName: null,
      paletteId: AppColors.defaultPaletteId,
    );
  }
}
