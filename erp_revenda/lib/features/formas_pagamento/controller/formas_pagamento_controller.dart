import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clientes/controller/clientes_controller.dart' show appDatabaseProvider;
import '../data/forma_pagamento_model.dart';
import '../data/forma_pagamento_repository.dart';

final formaPagamentoRepositoryProvider = Provider<FormaPagamentoRepository>((ref) {
  return FormaPagamentoRepository(ref.watch(appDatabaseProvider));
});

final formasPagamentoSearchProvider = StateProvider<String>((ref) => '');
final formasPagamentoSomenteAtivasProvider = StateProvider<bool>((ref) => true);

final formasPagamentoControllerProvider =
    AsyncNotifierProvider<FormasPagamentoController, List<FormaPagamento>>(
  FormasPagamentoController.new,
);

class FormasPagamentoController extends AsyncNotifier<List<FormaPagamento>> {
  FormaPagamentoRepository get _repo => ref.read(formaPagamentoRepositoryProvider);

  @override
  Future<List<FormaPagamento>> build() async {
    final search = ref.watch(formasPagamentoSearchProvider);
    final onlyActive = ref.watch(formasPagamentoSomenteAtivasProvider);
    return _repo.listar(search: search, onlyActive: onlyActive);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final search = ref.read(formasPagamentoSearchProvider);
    final onlyActive = ref.read(formasPagamentoSomenteAtivasProvider);
    state = AsyncData(await _repo.listar(search: search, onlyActive: onlyActive));
  }

  Future<void> salvar(FormaPagamento fp) async {
    await _repo.salvar(fp);
    await refresh();
  }

  Future<void> setAtivo(int id, bool ativo) async {
    await _repo.setAtivo(id, ativo);
    await refresh();
  }
}
