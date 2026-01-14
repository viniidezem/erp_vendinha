import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clientes/controller/clientes_controller.dart';
import '../../fornecedores/data/fornecedor_repository.dart';
import '../../fornecedores/data/fornecedor_model.dart';
import '../../fabricantes/data/fabricante_repository.dart';
import '../../fabricantes/data/fabricante_model.dart';
import '../../categorias/data/categoria_repository.dart';
import '../../categorias/data/categoria_model.dart';
import '../data/cadastros_resumo_repository.dart';
import '../data/cadastros_resumo.dart';

final cadastrosResumoRepositoryProvider = Provider<CadastrosResumoRepository>(
  (ref) => CadastrosResumoRepository(ref.watch(appDatabaseProvider)),
);

final cadastrosResumoProvider = FutureProvider<CadastrosResumo>(
  (ref) => ref.watch(cadastrosResumoRepositoryProvider).carregar(),
);

// --------------------
// Fornecedores (modal)
// --------------------
final cadFornecedorRepositoryProvider = Provider<FornecedorRepository>(
  (ref) => FornecedorRepository(ref.watch(appDatabaseProvider)),
);

final cadFornecedoresProvider = FutureProvider<List<Fornecedor>>(
  (ref) => ref.watch(cadFornecedorRepositoryProvider).listar(),
);

// --------------------
// Fabricantes (modal)
// --------------------
final cadFabricanteRepositoryProvider = Provider<FabricanteRepository>(
  (ref) => FabricanteRepository(ref.watch(appDatabaseProvider)),
);

final cadFabricantesProvider = FutureProvider<List<Fabricante>>(
  (ref) => ref.watch(cadFabricanteRepositoryProvider).listar(),
);

// --------------------
// Categorias (modal)
// --------------------
final cadCategoriaRepositoryProvider = Provider<CategoriaRepository>(
  (ref) => CategoriaRepository(ref.watch(appDatabaseProvider)),
);

final cadCategoriasPorTipoProvider =
    FutureProvider.family<List<Categoria>, CategoriaTipo>(
  (ref, tipo) => ref.watch(cadCategoriaRepositoryProvider).listarPorTipo(tipo),
);
