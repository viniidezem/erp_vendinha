import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_page.dart';
import '../controller/produtos_controller.dart';

class ProdutosScreen extends ConsumerStatefulWidget {
  const ProdutosScreen({super.key});

  @override
  ConsumerState<ProdutosScreen> createState() => _ProdutosScreenState();
}

class _ProdutosScreenState extends ConsumerState<ProdutosScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final produtosAsync = ref.watch(produtosControllerProvider);
    final onlyActive = ref.watch(produtosSomenteAtivosProvider);
    final onlyStock = ref.watch(produtosSomenteComSaldoProvider);

    return AppPage(
      title: 'Produtos / Estoque',
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: () =>
              ref.read(produtosControllerProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh),
          color: Colors.white,
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/produtos/form'),
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
                        labelText: 'Buscar por nome ou referência',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchCtrl.text.trim().isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Limpar',
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  ref
                                          .read(produtosSearchProvider.notifier)
                                          .state =
                                      '';
                                  setState(() {});
                                },
                              ),
                      ),
                      onChanged: (v) {
                        ref.read(produtosSearchProvider.notifier).state = v;
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Somente produtos ativos'),
                      value: onlyActive,
                      onChanged: (v) =>
                          ref
                                  .read(produtosSomenteAtivosProvider.notifier)
                                  .state =
                              v ?? true,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Somente com saldo (estoque > 0)'),
                      value: onlyStock,
                      onChanged: (v) =>
                          ref
                                  .read(
                                    produtosSomenteComSaldoProvider.notifier,
                                  )
                                  .state =
                              v ?? false,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: produtosAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('Erro ao carregar produtos:\n$e'),
                ),
                data: (produtos) {
                  if (produtos.isEmpty) {
                    return const Center(
                      child: Text('Nenhum produto encontrado.'),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(top: 4, bottom: 90),
                    itemCount: produtos.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = produtos[i];
                      final sub = <String>[];
                      if ((p.refCodigo ?? '').trim().isNotEmpty) {
                        sub.add('Ref: ${p.refCodigo}');
                      }
                      sub.add('Est: ${p.estoque.toStringAsFixed(2)}');
                      sub.add('Venda: R\$ ${p.precoVenda.toStringAsFixed(2)}');

                      return ListTile(
                        title: Text(p.nome),
                        subtitle: Text(sub.join(' • ')),
                        trailing: Icon(
                          p.ativo ? Icons.check_circle : Icons.block,
                          size: 18,
                        ),
                        onTap: () => context.push('/produtos/form', extra: p),
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
