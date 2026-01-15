import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_page.dart';
import '../controller/entradas_controller.dart';
import '../data/entrada_models.dart';

class EntradasScreen extends ConsumerStatefulWidget {
  const EntradasScreen({super.key});

  @override
  ConsumerState<EntradasScreen> createState() => _EntradasScreenState();
}

class _EntradasScreenState extends ConsumerState<EntradasScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(entradasSearchProvider.notifier).state = v;
    });
  }

  String _fmtDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final entradasAsync = ref.watch(entradasControllerProvider);
    final statusFiltro = ref.watch(entradasStatusFiltroProvider);
    final statusChips = <String?>[null, ...EntradaStatus.filtros];

    return AppPage(
      title: 'Entradas',
      actions: [
        IconButton(
          tooltip: 'Nova entrada',
          onPressed: () => context.push('/entradas/form'),
          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
        ),
        IconButton(
          tooltip: 'Atualizar',
          onPressed: () => ref.read(entradasControllerProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh, color: Colors.white),
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por fornecedor ou numero da nota',
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: statusChips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final status = statusChips[i];
                final selected = statusFiltro == status;
                return ChoiceChip(
                  label: Text(
                    status == null ? 'Todos' : EntradaStatus.label(status),
                  ),
                  selected: selected,
                  onSelected: (_) {
                    ref.read(entradasStatusFiltroProvider.notifier).state =
                        status;
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: entradasAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Erro ao carregar entradas: $e'),
              ),
              data: (entradas) {
                if (entradas.isEmpty) {
                  return const Center(child: Text('Nenhuma entrada encontrada.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: entradas.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final e = entradas[index];
                    final id = e.id;
                    final total = e.totalNota.toStringAsFixed(2);
                    final fornecedor = e.fornecedorNome ?? 'Fornecedor';
                    final status = EntradaStatus.label(e.status);

                    return ListTile(
                      onTap: id == null
                          ? null
                          : () {
                              if (e.status == EntradaStatus.confirmada) {
                                context.push('/entradas/$id');
                              } else {
                                context.push('/entradas/form', extra: id);
                              }
                            },
                      title: Text('#${id ?? '-'} - $fornecedor'),
                      subtitle: Text('$status | Total: R\$ $total'),
                      trailing: Text(_fmtDate(e.dataEntrada)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
