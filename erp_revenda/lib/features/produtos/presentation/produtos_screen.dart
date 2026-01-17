import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_page.dart';
import '../../../shared/plan/plan_limit_banner.dart';
import '../controller/produtos_controller.dart';
import '../../settings/controller/plan_controller.dart';

class ProdutosScreen extends ConsumerStatefulWidget {
  const ProdutosScreen({super.key});

  @override
  ConsumerState<ProdutosScreen> createState() => _ProdutosScreenState();
}

class _ProdutosScreenState extends ConsumerState<ProdutosScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = ref.read(produtosSearchProvider);
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
      ref.read(produtosSearchProvider.notifier).state = v.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final onlyActive = ref.watch(produtosSomenteAtivosProvider);
    final onlyStock = ref.watch(produtosSomenteComSaldoProvider);
    final asyncProdutos = ref.watch(produtosControllerProvider);
    final planAsync = ref.watch(planInfoProvider);

    return AppPage(
      title: 'Produtos',
      actions: [
        IconButton(
          tooltip: 'Novo produto',
          icon: const Icon(Icons.add),
          onPressed: () => context.push('/produtos/form'),
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
                setState(() {}); // atualiza suffixIcon
              },
              decoration: InputDecoration(
                hintText: 'Buscar produtos...',
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
                      ref.read(produtosSomenteAtivosProvider.notifier).state =
                          v;
                    },
                  ),
                  FilterChip(
                    label: const Text('Somente com saldo'),
                    selected: onlyStock,
                    onSelected: (v) {
                      ref.read(produtosSomenteComSaldoProvider.notifier).state =
                          v;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            planAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (info) {
                final max = info.maxProdutos;
                if (info.isPro || max == null || !info.nearProdutos()) {
                  return const SizedBox.shrink();
                }
                return PlanLimitBanner(
                  label: 'produtos',
                  used: info.produtos,
                  max: max,
                  onTap: () => context.push('/settings/plano'),
                );
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: asyncProdutos.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Erro ao carregar produtos: $e')),
                data: (produtos) {
                  if (produtos.isEmpty) {
                    return const Center(
                      child: Text('Nenhum produto encontrado.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: produtos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final p = produtos[i];

                      final precoVenda = 'R ${p.precoVenda.toStringAsFixed(2)}';
                      final estoqueTxt = p.estoque.toStringAsFixed(2);

                      final subtitleParts = <String>[];
                      if ((p.refCodigo ?? '').trim().isNotEmpty) {
                        subtitleParts.add('Ref: ${p.refCodigo}');
                      }
                      subtitleParts.add('Est: $estoqueTxt');
                      subtitleParts.add('Venda: $precoVenda');

                      return Card(
                        child: ListTile(
                          title: Text(
                            p.nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            subtitleParts.join(' • '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: p.ativo
                              ? const Chip(label: Text('Ativo'))
                              : const Chip(label: Text('Inativo')),
                          onTap: () => context.push('/produtos/form', extra: p),
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
