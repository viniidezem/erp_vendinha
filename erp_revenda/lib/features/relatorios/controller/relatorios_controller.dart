import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clientes/controller/clientes_controller.dart'
    show appDatabaseProvider;
import '../data/relatorios_repository.dart';
import '../../fornecedores/data/fornecedor_model.dart';
import '../../clientes/data/cliente_model.dart';

final relatoriosRepositoryProvider = Provider<RelatoriosRepository>((ref) {
  return RelatoriosRepository(ref.watch(appDatabaseProvider));
});

final relatorioFornecedoresProvider =
    FutureProvider<List<Fornecedor>>((ref) async {
  final repo = ref.watch(relatoriosRepositoryProvider);
  return repo.listarFornecedores();
});

final relatorioClientesProvider = FutureProvider<List<Cliente>>((ref) async {
  final repo = ref.watch(relatoriosRepositoryProvider);
  return repo.listarClientes();
});
