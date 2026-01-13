import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../data/cliente_model.dart';
import '../data/cliente_repository.dart';
import '../data/cliente_endereco_model.dart';
import '../data/cliente_endereco_repository.dart';

// Mantém este provider aqui para não quebrar Produtos/Vendas
final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

// Repos
final clienteRepositoryProvider = Provider<ClienteRepository>((ref) {
  return ClienteRepository(ref.watch(appDatabaseProvider));
});

final clienteEnderecoRepositoryProvider = Provider<ClienteEnderecoRepository>((
  ref,
) {
  return ClienteEnderecoRepository(ref.watch(appDatabaseProvider));
});

// Filtros da tela
final clientesSearchProvider = StateProvider<String>((ref) => '');
final clientesSomenteAtivosProvider = StateProvider<bool>((ref) => true);

// Lista de clientes (reage aos filtros)
final clientesControllerProvider =
    AsyncNotifierProvider<ClientesController, List<Cliente>>(
      ClientesController.new,
    );

class ClientesController extends AsyncNotifier<List<Cliente>> {
  ClienteRepository get _repo => ref.read(clienteRepositoryProvider);

  @override
  Future<List<Cliente>> build() async {
    final search = ref.watch(clientesSearchProvider);
    final onlyActive = ref.watch(clientesSomenteAtivosProvider);
    return _repo.listar(search: search, onlyActive: onlyActive);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final search = ref.read(clientesSearchProvider);
    final onlyActive = ref.read(clientesSomenteAtivosProvider);
    state = AsyncData(
      await _repo.listar(search: search, onlyActive: onlyActive),
    );
  }

  Future<void> adicionar({
    required String nomeCompleto,
    String? apelido,
    String? telefone,
    required bool whatsapp,
    required String cpf,
    String? email,
    required ClienteStatus status,
  }) async {
    await _repo.inserir(
      Cliente(
        nome: nomeCompleto,
        apelido: (apelido ?? '').trim().isEmpty ? null : apelido!.trim(),
        telefone: (telefone ?? '').trim().isEmpty ? null : telefone!.trim(),
        telefoneWhatsapp: whatsapp,
        cpf: cpf.trim().isEmpty ? null : cpf.trim(),
        email: (email ?? '').trim().isEmpty ? null : email!.trim(),
        status: status,
        createdAt: DateTime.now(),
        ultimaCompraAt: null,
      ),
    );
    await refresh();
  }

  Future<void> editar(Cliente clienteAtualizado) async {
    await _repo.atualizar(clienteAtualizado);
    await refresh();
  }
}

// Endereços por cliente
final clienteEnderecosProvider =
    FutureProvider.family<List<ClienteEndereco>, int>((ref, clienteId) async {
      final repo = ref.watch(clienteEnderecoRepositoryProvider);
      return repo.listarPorCliente(clienteId);
    });
