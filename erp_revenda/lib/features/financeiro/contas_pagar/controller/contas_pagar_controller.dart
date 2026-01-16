import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../clientes/controller/clientes_controller.dart' show appDatabaseProvider;
import '../../../fornecedores/data/fornecedor_model.dart';
import '../../../fornecedores/data/fornecedor_repository.dart';
import '../data/conta_pagar_model.dart';
import '../data/conta_pagar_repository.dart';

final contasPagarRepositoryProvider = Provider<ContaPagarRepository>((ref) {
  return ContaPagarRepository(ref.watch(appDatabaseProvider));
});

final contasPagarFornecedorRepositoryProvider =
    Provider<FornecedorRepository>((ref) {
  return FornecedorRepository(ref.watch(appDatabaseProvider));
});

final contasPagarFornecedoresProvider =
    FutureProvider<List<Fornecedor>>((ref) async {
  final repo = ref.watch(contasPagarFornecedorRepositoryProvider);
  return repo.listar();
});

final contasPagarSearchProvider = StateProvider<String>((ref) => '');
final contasPagarStatusFiltroProvider = StateProvider<String?>((ref) => null);

final contasPagarControllerProvider =
    AsyncNotifierProvider<ContasPagarController, List<ContaPagar>>(
  ContasPagarController.new,
);

final contasPagarExisteEntradaProvider =
    FutureProvider.family<bool, int>((ref, entradaId) async {
      final repo = ref.watch(contasPagarRepositoryProvider);
      return repo.existeParaEntrada(entradaId);
    });

class ContasPagarController extends AsyncNotifier<List<ContaPagar>> {
  ContaPagarRepository get _repo => ref.read(contasPagarRepositoryProvider);

  @override
  Future<List<ContaPagar>> build() async {
    final search = ref.watch(contasPagarSearchProvider);
    final status = ref.watch(contasPagarStatusFiltroProvider);
    return _repo.listar(search: search, statusFiltro: status);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final search = ref.read(contasPagarSearchProvider);
    final status = ref.read(contasPagarStatusFiltroProvider);
    state = AsyncData(await _repo.listar(search: search, statusFiltro: status));
  }

  Future<void> criarLancamento({
    int? entradaId,
    required int fornecedorId,
    required double total,
    required int parcelas,
    String? descricao,
    List<DateTime?>? vencimentos,
  }) async {
    await _repo.criarLancamento(
      entradaId: entradaId,
      fornecedorId: fornecedorId,
      total: total,
      parcelas: parcelas,
      descricao: descricao,
      vencimentos: vencimentos,
    );
    await refresh();
  }

  Future<void> atualizarStatus({
    required int id,
    required String status,
  }) async {
    await _repo.atualizarStatus(id: id, status: status);
    await refresh();
  }
}
