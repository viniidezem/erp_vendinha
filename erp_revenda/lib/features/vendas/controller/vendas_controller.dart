import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clientes/controller/clientes_controller.dart'
    show appDatabaseProvider;
import '../../produtos/controller/produtos_controller.dart'
    show produtoRepositoryProvider;
import '../../clientes/data/cliente_model.dart';
import '../../clientes/data/cliente_repository.dart';
import '../data/venda_models.dart';
import '../data/vendas_repository.dart';

final vendasRepositoryProvider = Provider<VendasRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final prodRepo = ref.watch(produtoRepositoryProvider);
  return VendasRepository(db, prodRepo);
});

// Cliente selecionado na venda em andamento (opcional).
final vendaClienteSelecionadoIdProvider = StateProvider<int?>((ref) => null);

// Lista de clientes ativos para seleção na Nova Venda (não interfere nos filtros da tela de Clientes).
final _clienteRepoVendaProvider = Provider<ClienteRepository>((ref) {
  return ClienteRepository(ref.watch(appDatabaseProvider));
});

final clientesAtivosParaVendaProvider = FutureProvider<List<Cliente>>((
  ref,
) async {
  final repo = ref.watch(_clienteRepoVendaProvider);
  return repo.listar(search: '', onlyActive: true);
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
  static const double _eps = 0.00001;

  @override
  List<VendaItem> build() => [];

  void limpar() => state = [];

  void adicionarItem(VendaItem item) {
    // Consolida apenas se for o mesmo produto E o mesmo preço unitário
    final idx = state.indexWhere(
      (e) =>
          e.produtoId == item.produtoId &&
          (e.precoUnit - item.precoUnit).abs() < _eps,
    );

    if (idx >= 0) {
      final atual = state[idx];

      final novo = VendaItem(
        id: atual.id,
        vendaId: atual.vendaId,
        produtoId: atual.produtoId,
        produtoNome: atual.produtoNome,
        qtd: atual.qtd + item.qtd,
        precoUnit: atual.precoUnit, // mantém o preço (é o mesmo)
      );

      state = [...state.sublist(0, idx), novo, ...state.sublist(idx + 1)];
      return;
    }

    // Preço diferente => nova linha
    state = [...state, item];
  }

  void removerItem({required int produtoId, required double precoUnit}) {
    final idx = state.indexWhere(
      (e) => e.produtoId == produtoId && (e.precoUnit - precoUnit).abs() < _eps,
    );

    if (idx < 0) return;

    final novo = [...state]..removeAt(idx);
    state = novo;
  }
}
