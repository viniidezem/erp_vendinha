import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_page.dart';
import '../controller/clientes_controller.dart';
import '../data/cliente_model.dart';

class ClientesScreen extends ConsumerStatefulWidget {
  const ClientesScreen({super.key});

  @override
  ConsumerState<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends ConsumerState<ClientesScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Color _statusBg(ClienteStatus s) {
    switch (s) {
      case ClienteStatus.ativo:
        return const Color(0xFFEAF7EE);
      case ClienteStatus.inativo:
        return const Color(0xFFF2F4F7);
      case ClienteStatus.bloqueado:
        return const Color(0xFFFDECEC);
    }
  }

  Color _statusFg(ClienteStatus s) {
    switch (s) {
      case ClienteStatus.ativo:
        return const Color(0xFF2FB344);
      case ClienteStatus.inativo:
        return const Color(0xFF6B7280);
      case ClienteStatus.bloqueado:
        return const Color(0xFFE5484D);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientesAsync = ref.watch(clientesControllerProvider);
    final onlyActive = ref.watch(clientesSomenteAtivosProvider);

    return AppPage(
      title: 'Clientes',
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: () =>
              ref.read(clientesControllerProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh),
          color: Colors.white,
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/clientes/form'),
        child: const Icon(Icons.add),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        labelText: 'Buscar por nome',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchCtrl.text.trim().isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Limpar',
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  ref
                                          .read(clientesSearchProvider.notifier)
                                          .state =
                                      '';
                                  setState(() {});
                                },
                              ),
                      ),
                      onChanged: (v) {
                        ref.read(clientesSearchProvider.notifier).state = v;
                        setState(() {}); // apenas para atualizar o suffixIcon
                      },
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Exibir somente ativos'),
                      value: onlyActive,
                      onChanged: (v) {
                        ref.read(clientesSomenteAtivosProvider.notifier).state =
                            v ?? true;
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: clientesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('Erro ao carregar clientes:\n$e'),
                ),
                data: (clientes) {
                  if (clientes.isEmpty) {
                    return const Center(
                      child: Text('Nenhum cliente encontrado.'),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(top: 4, bottom: 90),
                    itemCount: clientes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final c = clientes[index];

                      final subtitleParts = <String>[];
                      if ((c.apelido ?? '').trim().isNotEmpty) {
                        subtitleParts.add('Apelido: ${c.apelido}');
                      }
                      if ((c.telefone ?? '').trim().isNotEmpty) {
                        subtitleParts.add(
                          c.telefoneWhatsapp
                              ? '${c.telefone} (WhatsApp)'
                              : c.telefone!,
                        );
                      }
                      if ((c.cpf ?? '').trim().isNotEmpty) {
                        subtitleParts.add('CPF: ${c.cpf}');
                      }

                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            c.nome.isNotEmpty
                                ? c.nome.trim()[0].toUpperCase()
                                : '?',
                          ),
                        ),
                        title: Text(c.nome),
                        subtitle: subtitleParts.isEmpty
                            ? null
                            : Text(subtitleParts.join(' • ')),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _statusBg(c.status),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            c.status.label,
                            style: TextStyle(
                              color: _statusFg(c.status),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        onTap: () => context.push('/clientes/form', extra: c),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
