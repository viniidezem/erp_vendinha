import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_page.dart';
import '../controller/clientes_controller.dart';

class ClientesScreen extends ConsumerStatefulWidget {
  const ClientesScreen({super.key});

  @override
  ConsumerState<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends ConsumerState<ClientesScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Estado inicial do campo (mantém se já havia filtro)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = ref.read(clientesSearchProvider);
      _searchCtrl.text = current;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(clientesSearchProvider.notifier).state = v.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final onlyActive = ref.watch(clientesSomenteAtivosProvider);
    final asyncClientes = ref.watch(clientesControllerProvider);

    return AppPage(
      title: 'Clientes',
      actions: [
        IconButton(
          tooltip: 'Novo cliente',
          icon: const Icon(Icons.add),
          onPressed: () => context.push('/clientes/form'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              onChanged: (v) {
                _onSearchChanged(v);
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: 'Buscar clientes...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearchChanged('');
                          setState(() {});
                        },
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Somente ativos'),
                    selected: onlyActive,
                    onSelected: (v) {
                      ref.read(clientesSomenteAtivosProvider.notifier).state =
                          v;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: asyncClientes.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Erro ao carregar clientes: $e')),
                data: (clientes) {
                  if (clientes.isEmpty) {
                    return const Center(
                      child: Text('Nenhum cliente encontrado.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: clientes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final c = clientes[i];

                      final subtitleParts = <String>[];
                      if ((c.apelido ?? '').trim().isNotEmpty) {
                        subtitleParts.add('Apelido: ${c.apelido}');
                      }
                      if ((c.telefone ?? '').trim().isNotEmpty) {
                        subtitleParts.add(
                          'Tel: ${c.telefone}${c.telefoneWhatsapp ? " (WhatsApp)" : ""}',
                        );
                      }
                      if ((c.cpf ?? '').trim().isNotEmpty) {
                        subtitleParts.add('CPF: ${c.cpf}');
                      }

                      return Card(
                        child: ListTile(
                          title: Text(
                            c.nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: subtitleParts.isEmpty
                              ? null
                              : Text(
                                  subtitleParts.join(' • '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          trailing: Chip(label: Text(c.status.label)),
                          onTap: () => context.push('/clientes/form', extra: c),
                        ),
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
