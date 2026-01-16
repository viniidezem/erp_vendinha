import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clientes/controller/clientes_controller.dart' show appDatabaseProvider;
import '../data/dashboard_repository.dart';
import '../data/dashboard_resumo.dart';
import '../data/dashboard_grafico.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(appDatabaseProvider));
});

final dashboardResumoPeriodoProvider =
    StateProvider<String>((ref) => DashboardResumoPeriodo.hoje);

final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardResumo>(DashboardController.new);

final dashboardGraficoProvider =
    FutureProvider.family<DashboardGrafico, String>((ref, periodo) async {
      final repo = ref.watch(dashboardRepositoryProvider);
      return repo.carregarGrafico(periodo: periodo);
    });

class DashboardController extends AsyncNotifier<DashboardResumo> {
  DashboardRepository get _repo => ref.read(dashboardRepositoryProvider);

  @override
  Future<DashboardResumo> build() async {
    final periodo = ref.watch(dashboardResumoPeriodoProvider);
    return _repo.carregarResumo(periodoVendas: periodo);
  }

  Future<void> refresh() async {
    final periodo = ref.read(dashboardResumoPeriodoProvider);
    state = const AsyncLoading();
    state = AsyncData(await _repo.carregarResumo(periodoVendas: periodo));
  }
}
