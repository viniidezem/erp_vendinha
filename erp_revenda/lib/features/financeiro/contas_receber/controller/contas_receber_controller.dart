import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../clientes/controller/clientes_controller.dart' show appDatabaseProvider;
import '../../../vendas/controller/vendas_controller.dart'
    show vendasRepositoryProvider;
import '../data/conta_receber_model.dart';
import '../data/conta_receber_repository.dart';

final contasReceberRepositoryProvider = Provider<ContaReceberRepository>((ref) {
  return ContaReceberRepository(ref.watch(appDatabaseProvider));
});

final contasReceberSearchProvider = StateProvider<String>((ref) => '');
final contasReceberStatusFiltroProvider = StateProvider<String?>((ref) => null);

final contasReceberControllerProvider =
    AsyncNotifierProvider<ContasReceberController, List<ContaReceber>>(
  ContasReceberController.new,
);

class ContasReceberController extends AsyncNotifier<List<ContaReceber>> {
  ContaReceberRepository get _repo => ref.read(contasReceberRepositoryProvider);

  @override
  Future<List<ContaReceber>> build() async {
    final search = ref.watch(contasReceberSearchProvider);
    final status = ref.watch(contasReceberStatusFiltroProvider);
    return _repo.listar(search: search, statusFiltro: status);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final search = ref.read(contasReceberSearchProvider);
    final status = ref.read(contasReceberStatusFiltroProvider);
    state = AsyncData(await _repo.listar(search: search, statusFiltro: status));
  }

  Future<void> atualizarStatus({
    required int id,
    required String status,
    double? valorRecebido,
    int? vendaId,
  }) async {
    await _repo.atualizarStatus(
      id: id,
      status: status,
      valorRecebido: valorRecebido,
    );

    if (vendaId != null && status == ContaReceberStatus.recebida) {
      final ok = await _repo.todasRecebidas(vendaId);
      if (ok) {
        final vendasRepo = ref.read(vendasRepositoryProvider);
        await vendasRepo.marcarPagamentoEfetuadoSePossivel(vendaId);
      }
    }
    await refresh();
  }
}
