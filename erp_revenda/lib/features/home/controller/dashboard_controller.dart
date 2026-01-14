import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clientes/controller/clientes_controller.dart' show appDatabaseProvider;
import '../data/dashboard_repository.dart';
import '../data/dashboard_resumo.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(appDatabaseProvider));
});

final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardResumo>(DashboardController.new);

class DashboardController extends AsyncNotifier<DashboardResumo> {
  DashboardRepository get _repo => ref.read(dashboardRepositoryProvider);

  @override
  Future<DashboardResumo> build() async {
    return _repo.carregarResumo();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _repo.carregarResumo());
  }
}
