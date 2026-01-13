import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_page.dart';
import '../controller/vendas_controller.dart';

class VendasScreen extends ConsumerWidget {
  const VendasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendasAsync = ref.watch(vendasListProvider);

    return AppPage(
      title: 'Vendas',
      actions: [
        IconButton(
          onPressed: () => ref.read(vendasListProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh),
          color: Colors.white,
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/vendas/nova'),
        child: const Icon(Icons.add),
      ),
      child: vendasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Erro ao carregar vendas:\n$e'),
        ),
        data: (vendas) {
          if (vendas.isEmpty) {
            return const Center(child: Text('Nenhuma venda registrada.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.only(top: 8),
            itemCount: vendas.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final v = vendas[index];
              return ListTile(
                title: Text('Venda #${v.id ?? '-'}'),
                subtitle: Text(
                  'Total: R\$ ${v.total.toStringAsFixed(2)} • ${v.status}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
