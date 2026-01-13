import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clientes/controller/clientes_controller.dart'
    show appDatabaseProvider;
import '../../produtos/controller/produtos_controller.dart'
    show produtoRepositoryProvider;
import '../data/venda_models.dart';
import '../data/vendas_repository.dart';

final vendasRepositoryProvider = Provider<VendasRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final prodRepo = ref.watch(produtoRepositoryProvider);
  return VendasRepository(db, prodRepo);
});

final vendasListProvider =
    AsyncNotifierProvider<VendasListController, List<Venda>>(
      VendasListController.new,
    );

class VendasListController extends AsyncNotifier<List<Venda>> {
  VendasRepository get _repo => ref.read(vendasRepositoryProvider);

  @override
  Future<List<Venda>> build() async {
    return _repo.listarVendas();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _repo.listarVendas());
  }
}

// Venda em andamento (estado local)
final vendaEmAndamentoProvider =
    NotifierProvider<VendaEmAndamentoController, List<VendaItem>>(
      VendaEmAndamentoController.new,
    );

class VendaEmAndamentoController extends Notifier<List<VendaItem>> {
  @override
  List<VendaItem> build() => [];

  void limpar() => state = [];

  void adicionarItem(VendaItem item) {
    // Se já existe o produto, soma quantidade
    final idx = state.indexWhere((e) => e.produtoId == item.produtoId);
    if (idx >= 0) {
      final atual = state[idx];
      final novo = VendaItem(
        produtoId: atual.produtoId,
        produtoNome: atual.produtoNome,
        qtd: atual.qtd + item.qtd,
        precoUnit: item.precoUnit,
      );
      state = [...state.sublist(0, idx), novo, ...state.sublist(idx + 1)];
      return;
    }
    state = [...state, item];
  }

  void removerItem(int produtoId) {
    state = state.where((e) => e.produtoId != produtoId).toList();
  }
}
