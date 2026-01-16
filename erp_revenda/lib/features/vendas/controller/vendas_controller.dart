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


// Filtros da tela de Pedidos (lista)
final pedidosStatusFiltroProvider = StateProvider<String?>((ref) => null); // null = todos (exceto ABERTA)
final pedidosSearchProvider = StateProvider<String>((ref) => '');

// Lista de clientes ativos para seleção na Nova Venda (não interfere nos filtros da tela de Clientes).
final _clienteRepoVendaProvider = Provider<ClienteRepository>((ref) {
  return ClienteRepository(ref.watch(appDatabaseProvider));
});

final clientesAtivosParaVendaProvider = FutureProvider<List<Cliente>>((ref) async {
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
    final status = ref.watch(pedidosStatusFiltroProvider);
    final search = ref.watch(pedidosSearchProvider);
    return _repo.listarVendas(statusFiltro: status, search: search);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final status = ref.read(pedidosStatusFiltroProvider);
    final search = ref.read(pedidosSearchProvider);
    state = AsyncData(
      await _repo.listarVendas(statusFiltro: status, search: search),
    );
  }
}


// Detalhe do Pedido (inclui itens e histórico de status)
final pedidoDetalheProvider =
    FutureProvider.family<PedidoDetalhe, int>((ref, vendaId) async {
  final repo = ref.watch(vendasRepositoryProvider);
  return repo.carregarPedidoDetalhe(vendaId);
});

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

  /// Regra:
  /// - Mesmo produto + mesmo preço unitário => soma quantidade (mantém 1 linha)
  /// - Mesmo produto + preço diferente      => cria nova linha (ex.: desconto)
  void adicionarItem(VendaItem item) {
    final idx = state.indexWhere(
      (e) => e.produtoId == item.produtoId && (e.precoUnit - item.precoUnit).abs() < _eps,
    );

    if (idx >= 0) {
      final atual = state[idx];
      final novo = VendaItem(
        id: atual.id,
        vendaId: atual.vendaId,
        produtoId: atual.produtoId,
        produtoNome: atual.produtoNome,
        qtd: atual.qtd + item.qtd,
        precoUnit: atual.precoUnit,
      );

      state = [...state.sublist(0, idx), novo, ...state.sublist(idx + 1)];
      return;
    }

    state = [...state, item];
  }

  void removerItemAt(int index) {
    if (index < 0 || index >= state.length) return;
    final novo = [...state]..removeAt(index);
    state = novo;
  }

  /// Edita quantidade e/ou preço de uma linha específica.
  /// Se após editar ficar igual a outra linha (mesmo produto + mesmo preço),
  /// consolida automaticamente.
  void atualizarItemAt(int index, {double? qtd, double? precoUnit}) {
    if (index < 0 || index >= state.length) return;

    final atual = state[index];
    final updated = VendaItem(
      id: atual.id,
      vendaId: atual.vendaId,
      produtoId: atual.produtoId,
      produtoNome: atual.produtoNome,
      qtd: qtd ?? atual.qtd,
      precoUnit: precoUnit ?? atual.precoUnit,
    );

    var novo = [...state];
    novo[index] = updated;

    // Consolida com outra linha se necessário
    final dupIdx = novo.indexWhere((e) =>
        e.produtoId == updated.produtoId &&
        (e.precoUnit - updated.precoUnit).abs() < _eps &&
        novo.indexOf(e) != index);

    if (dupIdx >= 0) {
      final other = novo[dupIdx];

      // Mantém a linha mais "antiga" (menor índice) por estabilidade visual
      final keep = dupIdx < index ? dupIdx : index;
      final drop = dupIdx < index ? index : dupIdx;

      final kept = novo[keep];
      final merged = VendaItem(
        id: kept.id,
        vendaId: kept.vendaId,
        produtoId: kept.produtoId,
        produtoNome: kept.produtoNome,
        qtd: kept.qtd + other.qtd,
        precoUnit: kept.precoUnit,
      );

      novo[keep] = merged;
      novo.removeAt(drop);
    }

    state = novo;
  }

  void carregarItens(List<VendaItem> itens) {
    state = itens
        .map(
          (it) => VendaItem(
            produtoId: it.produtoId,
            produtoNome: it.produtoNome,
            qtd: it.qtd,
            precoUnit: it.precoUnit,
            isKit: it.isKit,
          ),
        )
        .toList();
  }
}
