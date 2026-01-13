import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_page.dart';
import '../controller/vendas_controller.dart';

class VendasScreen extends ConsumerWidget {
  final bool showBack;

  const VendasScreen({super.key, this.showBack = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendasAsync = ref.watch(vendasListProvider);

    return AppPage(
      title: 'Vendas',
      showBack: showBack,
      actions: [
        IconButton(
          onPressed: () => context.push('/vendas/nova'),
          icon: const Icon(Icons.add),
        ),
      ],
      child: vendasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Erro ao carregar vendas: $e'),
        ),
        data: (vendas) {
          if (vendas.isEmpty) {
            return const Center(child: Text('Nenhuma venda cadastrada.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
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
