import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_page.dart';
import '../controller/produtos_controller.dart';

class ProdutosScreen extends ConsumerWidget {
  const ProdutosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final produtosAsync = ref.watch(produtosControllerProvider);

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
      child: produtosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Erro ao carregar produtos:\n$e'),
        ),
        data: (produtos) {
          if (produtos.isEmpty) {
            return const Center(child: Text('Nenhum produto cadastrado.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.only(top: 8),
            itemCount: produtos.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final p = produtos[index];

              return ListTile(
                title: Text(p.nome),
                subtitle: Text(
                  'Preço: R\$ ${p.precoVenda.toStringAsFixed(2)} • Estoque: ${p.estoque.toStringAsFixed(2)}',
                ),
                onTap: () => context.push('/produtos/form', extra: p),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'ajuste') {
                      context.push('/produtos/ajuste', extra: p);
                      return;
                    }
                    if (value == 'excluir') {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Excluir produto'),
                          content: Text('Deseja excluir "${p.nome}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Excluir'),
                            ),
                          ],
                        ),
                      );

                      if (ok == true) {
                        await ref
                            .read(produtosControllerProvider.notifier)
                            .remover(p.id!);
                      }
                    }
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(
                      value: 'ajuste',
                      child: Text('Ajustar estoque'),
                    ),
                    PopupMenuItem(value: 'excluir', child: Text('Excluir')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
