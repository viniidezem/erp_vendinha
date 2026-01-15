import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clientes/controller/clientes_controller.dart' show appDatabaseProvider;
import '../../fornecedores/data/fornecedor_model.dart';
import '../../fornecedores/data/fornecedor_repository.dart';
import '../../produtos/data/produto_model.dart';
import '../../produtos/data/produto_repository.dart';
import '../data/entrada_models.dart';
import '../data/entrada_repository.dart';

final entradasRepositoryProvider = Provider<EntradaRepository>((ref) {
  return EntradaRepository(ref.watch(appDatabaseProvider));
});

final entradasFornecedorRepositoryProvider = Provider<FornecedorRepository>((ref) {
  return FornecedorRepository(ref.watch(appDatabaseProvider));
});

final entradasProdutoRepositoryProvider = Provider<ProdutoRepository>((ref) {
  return ProdutoRepository(ref.watch(appDatabaseProvider));
});

final entradasFornecedoresProvider = FutureProvider<List<Fornecedor>>((ref) async {
  final repo = ref.watch(entradasFornecedorRepositoryProvider);
  return repo.listar();
});

final entradasSearchProvider = StateProvider<String>((ref) => '');
final entradasStatusFiltroProvider = StateProvider<String?>((ref) => null);

final entradasControllerProvider =
    AsyncNotifierProvider<EntradasController, List<Entrada>>(
  EntradasController.new,
);

class EntradasController extends AsyncNotifier<List<Entrada>> {
  EntradaRepository get _repo => ref.read(entradasRepositoryProvider);

  @override
  Future<List<Entrada>> build() async {
    final search = ref.watch(entradasSearchProvider);
    final status = ref.watch(entradasStatusFiltroProvider);
    return _repo.listarEntradas(search: search, statusFiltro: status);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final search = ref.read(entradasSearchProvider);
    final status = ref.read(entradasStatusFiltroProvider);
    state = AsyncData(
      await _repo.listarEntradas(search: search, statusFiltro: status),
    );
  }

  Future<int> salvarEntrada({
    int? entradaId,
    required Entrada entrada,
    required List<EntradaItem> itens,
    required bool confirmar,
    required bool atualizarCusto,
  }) async {
    final id = await _repo.salvarEntrada(
      entradaId: entradaId,
      entrada: entrada,
      itens: itens,
      confirmar: confirmar,
      atualizarCusto: atualizarCusto,
    );
    await refresh();
    return id;
  }
}

final entradaDetalheProvider =
    FutureProvider.family<EntradaDetalhe, int>((ref, entradaId) async {
  final repo = ref.watch(entradasRepositoryProvider);
  return repo.carregarDetalhe(entradaId);
});

final entradaProdutosProvider =
    FutureProvider.family<List<Produto>, EntradaProdutosArgs>((ref, args) async {
  final repo = ref.watch(entradasProdutoRepositoryProvider);
  return repo.listar(
    search: args.search,
    onlyActive: true,
    onlyWithStock: false,
    fornecedorId: args.fornecedorId,
  );
});

class EntradaProdutosArgs {
  final int? fornecedorId;
  final String search;
  const EntradaProdutosArgs({
    required this.fornecedorId,
    required this.search,
  });

  @override
  bool operator ==(Object other) {
    return other is EntradaProdutosArgs &&
        other.fornecedorId == fornecedorId &&
        other.search == search;
  }

  @override
  int get hashCode => Object.hash(fornecedorId, search);
}
