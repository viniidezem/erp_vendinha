import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_page.dart';
import '../controller/vendas_controller.dart';
import '../data/venda_models.dart';

class VendasScreen extends ConsumerStatefulWidget {
  final bool showBack;

  const VendasScreen({super.key, this.showBack = true});

  @override
  ConsumerState<VendasScreen> createState() => _VendasScreenState();
}

class _VendasScreenState extends ConsumerState<VendasScreen> {
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
      ref.read(pedidosSearchProvider.notifier).state = v;
    });
  }

  String _fmtDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final vendasAsync = ref.watch(vendasListProvider);
    final statusFiltro = ref.watch(pedidosStatusFiltroProvider);

    final chips = <MapEntry<String?, String>>[
      const MapEntry(null, 'Todos'),
      const MapEntry(VendaStatus.pedido, 'Pedido'),
      const MapEntry(VendaStatus.aguardandoMercadoria, 'Aguardando'),
      const MapEntry(VendaStatus.emExpedicao, 'Expedição'),
      const MapEntry(VendaStatus.entregue, 'Entregue'),
      const MapEntry(VendaStatus.cancelada, 'Cancelado'),
    ];

    return AppPage(
      title: 'Pedidos',
      showBack: widget.showBack,
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: () => ref.read(vendasListProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh),
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
                hintText: 'Buscar por cliente ou número do pedido',
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final entry = chips[i];
                final selected = statusFiltro == entry.key;
                return ChoiceChip(
                  label: Text(entry.value),
                  selected: selected,
                  onSelected: (_) {
                    ref.read(pedidosStatusFiltroProvider.notifier).state =
                        entry.key;
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: vendasAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Erro ao carregar pedidos: $e'),
              ),
              data: (vendas) {
                if (vendas.isEmpty) {
                  return const Center(child: Text('Nenhum pedido encontrado.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: vendas.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final v = vendas[index];
                    final id = v.id;

                    return ListTile(
                      onTap: id == null ? null : () => context.push('/pedidos/$id'),
                      title: Text(
                        '#${id ?? '-'} • ${v.clienteNome ?? 'Cliente não informado'}',
                      ),
                      subtitle: Text(
                        '${VendaStatus.label(v.status)} • Total: R\$ ${v.total.toStringAsFixed(2)}',
                      ),
                      trailing: Text(_fmtDate(v.createdAt)),
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
