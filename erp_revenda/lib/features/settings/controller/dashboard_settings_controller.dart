import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clientes/controller/clientes_controller.dart'
    show appDatabaseProvider;
import '../data/app_settings_repository.dart';
import '../data/dashboard_settings.dart';

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return AppSettingsRepository(ref.watch(appDatabaseProvider));
});

final dashboardSettingsProvider =
    AsyncNotifierProvider<DashboardSettingsController, DashboardSettings>(
  DashboardSettingsController.new,
);

class DashboardSettingsController extends AsyncNotifier<DashboardSettings> {
  AppSettingsRepository get _repo => ref.read(appSettingsRepositoryProvider);

  @override
  Future<DashboardSettings> build() async {
    return _repo.carregarDashboardSettings();
  }

  Future<void> salvar(DashboardSettings settings) async {
    await _repo.salvarDashboardSettings(settings);
    state = AsyncData(settings);
  }

  Future<void> atualizar({
    bool? mostrarGraficos,
    double? metaFaturamentoMensal,
    String? periodoGrafico,
  }) async {
    final atual = state.value ?? await _repo.carregarDashboardSettings();
    final novo = atual.copyWith(
      mostrarGraficos: mostrarGraficos,
      metaFaturamentoMensal: metaFaturamentoMensal,
      periodoGrafico: periodoGrafico,
    );
    await salvar(novo);
  }
}
