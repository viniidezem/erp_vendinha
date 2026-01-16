import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clientes/controller/clientes_controller.dart'
    show appDatabaseProvider;
import '../data/app_settings_repository.dart';
import '../data/app_preferences.dart';

final appPreferencesRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return AppSettingsRepository(ref.watch(appDatabaseProvider));
});

final appPreferencesProvider =
    AsyncNotifierProvider<AppPreferencesController, AppPreferences>(
  AppPreferencesController.new,
);

class AppPreferencesController extends AsyncNotifier<AppPreferences> {
  AppSettingsRepository get _repo => ref.read(appPreferencesRepositoryProvider);

  @override
  Future<AppPreferences> build() async {
    return _repo.carregarPreferencias();
  }

  Future<void> salvar(AppPreferences prefs) async {
    await _repo.salvarPreferencias(prefs);
    state = AsyncData(prefs);
  }

  Future<void> atualizar({
    String? storeName,
    String? paletteId,
  }) async {
    final atual = state.value ?? await _repo.carregarPreferencias();
    final nome = storeName?.trim();
    final novo = atual.copyWith(
      storeName: nome == null || nome.isEmpty ? null : nome,
      paletteId: paletteId,
    );
    await salvar(novo);
  }
}
