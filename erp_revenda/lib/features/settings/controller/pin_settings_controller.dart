import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clientes/controller/clientes_controller.dart'
    show appDatabaseProvider;
import '../data/app_settings_repository.dart';
import '../data/pin_settings.dart';

final pinSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return AppSettingsRepository(ref.watch(appDatabaseProvider));
});

final pinSettingsProvider =
    AsyncNotifierProvider<PinSettingsController, PinSettings>(
  PinSettingsController.new,
);

final pinSessionUnlockedProvider = StateProvider<bool>((ref) => false);

class PinSettingsController extends AsyncNotifier<PinSettings> {
  AppSettingsRepository get _repo => ref.read(pinSettingsRepositoryProvider);

  @override
  Future<PinSettings> build() async {
    return _repo.carregarPinSettings();
  }

  Future<void> salvar(PinSettings settings) async {
    await _repo.salvarPinSettings(settings);
    state = AsyncData(settings);
  }

  Future<void> atualizar({
    bool? enabled,
    String? pinHash,
    String? securityQuestion,
    String? securityAnswerHash,
    bool? lockOnBackground,
    int? lockTimeoutMinutes,
  }) async {
    final atual = state.value ?? await _repo.carregarPinSettings();
    final novo = atual.copyWith(
      enabled: enabled,
      pinHash: pinHash,
      securityQuestion: securityQuestion,
      securityAnswerHash: securityAnswerHash,
      lockOnBackground: lockOnBackground,
      lockTimeoutMinutes: lockTimeoutMinutes,
    );
    await salvar(novo);
  }
}
