
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clientes/controller/clientes_controller.dart' show appDatabaseProvider;
import '../../categorias/data/categoria_model.dart';
import '../../categorias/data/categoria_repository.dart';
import '../../fabricantes/data/fabricante_model.dart';
import '../../fabricantes/data/fabricante_repository.dart';
import '../../fornecedores/data/fornecedor_model.dart';
import '../../fornecedores/data/fornecedor_repository.dart';
import '../data/produto_model.dart';
import '../data/produto_repository.dart';

final produtoRepositoryProvider = Provider<ProdutoRepository>((ref) {
  return ProdutoRepository(ref.watch(appDatabaseProvider));
});

final fornecedorRepositoryProvider = Provider<FornecedorRepository>((ref) {
  return FornecedorRepository(ref.watch(appDatabaseProvider));
});

final fabricanteRepositoryProvider = Provider<FabricanteRepository>((ref) {
  return FabricanteRepository(ref.watch(appDatabaseProvider));
});

final categoriaRepositoryProvider = Provider<CategoriaRepository>((ref) {
  return CategoriaRepository(ref.watch(appDatabaseProvider));
});

final produtosSearchProvider = StateProvider<String>((ref) => '');
final produtosSomenteAtivosProvider = StateProvider<bool>((ref) => true);
final produtosSomenteComSaldoProvider = StateProvider<bool>((ref) => false);

final produtosControllerProvider =
    AsyncNotifierProvider<ProdutosController, List<Produto>>(ProdutosController.new);

class ProdutosController extends AsyncNotifier<List<Produto>> {
  ProdutoRepository get _repo => ref.read(produtoRepositoryProvider);

  @override
  Future<List<Produto>> build() async {
    final search = ref.watch(produtosSearchProvider);
    final onlyActive = ref.watch(produtosSomenteAtivosProvider);
    final onlyStock = ref.watch(produtosSomenteComSaldoProvider);
    return _repo.listar(search: search, onlyActive: onlyActive, onlyWithStock: onlyStock);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final search = ref.read(produtosSearchProvider);
    final onlyActive = ref.read(produtosSomenteAtivosProvider);
    final onlyStock = ref.read(produtosSomenteComSaldoProvider);
    state = AsyncData(await _repo.listar(search: search, onlyActive: onlyActive, onlyWithStock: onlyStock));
  }

  Future<void> adicionar(Produto p, {List<int> propriedadesIds = const []}) async {
    await _repo.inserir(p, propriedadesIds: propriedadesIds);
    await refresh();
  }

  Future<void> editar(Produto p, {List<int> propriedadesIds = const []}) async {
    await _repo.atualizar(p, propriedadesIds: propriedadesIds);
    await refresh();
  }

  Future<void> ajustarEstoque({required int id, required double delta}) async {
    await _repo.ajustarEstoque(id: id, delta: delta);
    await refresh();
  }
}

final fornecedoresProvider = FutureProvider<List<Fornecedor>>((ref) async {
  final repo = ref.watch(fornecedorRepositoryProvider);
  return repo.listar();
});

final fabricantesProvider = FutureProvider<List<Fabricante>>((ref) async {
  final repo = ref.watch(fabricanteRepositoryProvider);
  return repo.listar();
});

final categoriasPorTipoProvider =
    FutureProvider.family<List<Categoria>, CategoriaTipo>((ref, tipo) async {
  final repo = ref.watch(categoriaRepositoryProvider);
  return repo.listarPorTipo(tipo);
});
