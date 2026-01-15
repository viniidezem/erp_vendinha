import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clientes/controller/clientes_controller.dart' show appDatabaseProvider;
import '../../produtos/data/produto_model.dart';
import '../../produtos/data/produto_repository.dart';
import '../data/kit_models.dart';
import '../data/kit_repository.dart';

final kitRepositoryProvider = Provider<KitRepository>((ref) {
  return KitRepository(ref.watch(appDatabaseProvider));
});

final kitProdutoRepositoryProvider = Provider<ProdutoRepository>((ref) {
  return ProdutoRepository(ref.watch(appDatabaseProvider));
});

final kitsSearchProvider = StateProvider<String>((ref) => '');
final kitsSomenteAtivosProvider = StateProvider<bool>((ref) => true);

final kitsControllerProvider =
    AsyncNotifierProvider<KitsController, List<Produto>>(KitsController.new);

class KitsController extends AsyncNotifier<List<Produto>> {
  KitRepository get _repo => ref.read(kitRepositoryProvider);

  @override
  Future<List<Produto>> build() async {
    final search = ref.watch(kitsSearchProvider);
    final onlyActive = ref.watch(kitsSomenteAtivosProvider);
    return _repo.listarKits(search: search, onlyActive: onlyActive);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final search = ref.read(kitsSearchProvider);
    final onlyActive = ref.read(kitsSomenteAtivosProvider);
    state = AsyncData(await _repo.listarKits(search: search, onlyActive: onlyActive));
  }
}

final kitDetalheProvider =
    FutureProvider.family<KitDetalhe, int>((ref, kitId) async {
  final repo = ref.watch(kitRepositoryProvider);
  return repo.carregarKit(kitId);
});

final kitsProdutosProvider =
    FutureProvider.family<List<Produto>, String>((ref, search) async {
  final repo = ref.watch(kitProdutoRepositoryProvider);
  return repo.listar(search: search, onlyActive: true, onlyWithStock: false);
});
