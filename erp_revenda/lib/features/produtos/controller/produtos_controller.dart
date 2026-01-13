import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clientes/controller/clientes_controller.dart'
    show appDatabaseProvider;
import '../data/produto_model.dart';
import '../data/produto_repository.dart';

// Repository provider
final produtoRepositoryProvider = Provider<ProdutoRepository>((ref) {
  return ProdutoRepository(ref.watch(appDatabaseProvider));
});

// Controller provider
final produtosControllerProvider =
    AsyncNotifierProvider<ProdutosController, List<Produto>>(
      ProdutosController.new,
    );

class ProdutosController extends AsyncNotifier<List<Produto>> {
  ProdutoRepository get _repo => ref.read(produtoRepositoryProvider);

  @override
  Future<List<Produto>> build() async {
    return _repo.listarTodos();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _repo.listarTodos());
  }

  Future<void> adicionar({
    required String nome,
    required double precoVenda,
    double estoqueInicial = 0,
  }) async {
    await _repo.inserir(
      Produto(
        nome: nome,
        precoVenda: precoVenda,
        estoque: estoqueInicial,
        ativo: true,
        createdAt: DateTime.now(),
      ),
    );
    await refresh();
  }

  Future<void> editar(Produto produtoAtualizado) async {
    await _repo.atualizar(produtoAtualizado);
    await refresh();
  }

  Future<void> remover(int id) async {
    await _repo.excluir(id);
    await refresh();
  }

  Future<void> ajustarEstoque({required int id, required double delta}) async {
    await _repo.ajustarEstoque(id: id, delta: delta);
    await refresh();
  }
}
