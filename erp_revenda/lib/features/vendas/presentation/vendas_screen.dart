import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_page.dart';
import '../../../shared/plan/plan_limit_banner.dart';
import '../../formas_pagamento/controller/formas_pagamento_controller.dart';
import '../../formas_pagamento/data/forma_pagamento_model.dart';
import '../controller/vendas_controller.dart';
import '../data/venda_models.dart';
import '../../settings/controller/plan_controller.dart';

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
    final formasAsync = ref.watch(formasPagamentoControllerProvider);
    final planAsync = ref.watch(planInfoProvider);

    final statusChips = <String?>[null, ...VendaStatus.filtros];
    final formas = formasAsync.asData?.value ?? const <FormaPagamento>[];
    final formasById = {
      for (final f in formas)
        if (f.id != null) f.id!: f.nome,
    };

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
              itemCount: statusChips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final status = statusChips[i];
                final selected = statusFiltro == status;
                return ChoiceChip(
                  label: Text(status == null ? 'Todos' : VendaStatus.label(status)),
                  selected: selected,
                  onSelected: (_) {
                    ref.read(pedidosStatusFiltroProvider.notifier).state = status;
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          planAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (info) {
              final max = info.maxVendas;
              if (info.isPro || max == null || !info.nearVendas()) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: PlanLimitBanner(
                  label: 'vendas',
                  used: info.vendas,
                  max: max,
                  onTap: () => context.push('/settings/plano'),
                ),
              );
            },
          ),
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
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            '${VendaStatus.label(v.status)} • Total: R\$ ${v.total.toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _pagamentoLabel(
                              formasById,
                              v.formaPagamentoId,
                              v.parcelas,
                            ),
                          ),
                        ],
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

String _pagamentoLabel(
  Map<int, String> formasById,
  int? formaId,
  int? parcelas,
) {
  if (formaId == null) return 'Pagamento: não informado';
  final nome = formasById[formaId] ?? 'Forma #$formaId';
  final qtd = (parcelas ?? 1);
  return qtd > 1 ? 'Pagamento: $nome (${qtd}x)' : 'Pagamento: $nome';
}
