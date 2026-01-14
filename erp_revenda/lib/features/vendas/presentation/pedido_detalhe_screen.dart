import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_page.dart';
import '../controller/vendas_controller.dart';
import '../data/venda_models.dart';

class PedidoDetalheScreen extends ConsumerWidget {
  final int vendaId;

  const PedidoDetalheScreen({super.key, required this.vendaId});

  String _fmtDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<void> _mudarStatus(
    BuildContext context,
    WidgetRef ref, {
    required String novoStatus,
  }) async {
    final obsCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Alterar status para: ${VendaStatus.label(novoStatus)}'),
        content: TextField(
          controller: obsCtrl,
          decoration: const InputDecoration(
            labelText: 'Observação (opcional)',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await ref.read(vendasRepositoryProvider).atualizarStatus(
          vendaId: vendaId,
          status: novoStatus,
          obs: obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim(),
        );

    // Atualiza tela e lista
    ref.invalidate(pedidoDetalheProvider(vendaId));
    await ref.read(vendasListProvider.notifier).refresh();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status atualizado para ${VendaStatus.label(novoStatus)}')),
      );
    }
  }

  List<_StatusAction> _acoesPara(String status) {
    // Fluxo básico: PEDIDO -> (AGUARDANDO) -> EM_EXPEDICAO -> ENTREGUE
    // Cancelamento em qualquer etapa.
    if (status == VendaStatus.pedido) {
      return const [
        _StatusAction(VendaStatus.aguardandoMercadoria, Icons.inventory_2_outlined),
        _StatusAction(VendaStatus.emExpedicao, Icons.local_shipping_outlined),
        _StatusAction(VendaStatus.entregue, Icons.check_circle_outline),
        _StatusAction(VendaStatus.cancelada, Icons.cancel_outlined),
      ];
    }
    if (status == VendaStatus.aguardandoMercadoria) {
      return const [
        _StatusAction(VendaStatus.emExpedicao, Icons.local_shipping_outlined),
        _StatusAction(VendaStatus.cancelada, Icons.cancel_outlined),
      ];
    }
    if (status == VendaStatus.emExpedicao) {
      return const [
        _StatusAction(VendaStatus.entregue, Icons.check_circle_outline),
        _StatusAction(VendaStatus.cancelada, Icons.cancel_outlined),
      ];
    }
    return const [];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalheAsync = ref.watch(pedidoDetalheProvider(vendaId));

    return AppPage(
      title: 'Pedido #$vendaId',
      showBack: true,
      child: detalheAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Erro ao carregar pedido: $e'),
        ),
        data: (detalhe) {
          final venda = detalhe.venda;
          final actions = _acoesPara(venda.status);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          venda.clienteNome ?? 'Cliente não informado',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text('Criado em: ${_fmtDate(venda.createdAt)}'),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Text('Status: '),
                            Text(
                              VendaStatus.label(venda.status),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Total: R\$ ${venda.total.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                ),

                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final a in actions)
                            ElevatedButton.icon(
                              onPressed: () => _mudarStatus(
                                context,
                                ref,
                                novoStatus: a.status,
                              ),
                              icon: Icon(a.icon),
                              label: Text(VendaStatus.label(a.status)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Itens',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ...detalhe.itens.map(
                          (it) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(it.produtoNome),
                            subtitle: Text(
                              '${it.qtd.toStringAsFixed(2)} x R\$ ${it.precoUnit.toStringAsFixed(2)}',
                            ),
                            trailing: Text(
                              'R\$ ${it.subtotal.toStringAsFixed(2)}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Histórico de status',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (detalhe.historico.isEmpty)
                          const Text('Sem histórico registrado.')
                        else
                          ...detalhe.historico.map((h) {
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(VendaStatus.label(h.status)),
                              subtitle: Text(_fmtDate(h.createdAt)),
                              trailing: (h.obs == null || h.obs!.isEmpty)
                                  ? null
                                  : IconButton(
                                      tooltip: 'Ver observação',
                                      onPressed: () => showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Observação'),
                                          content: Text(h.obs!),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(ctx).pop(),
                                              child: const Text('Fechar'),
                                            ),
                                          ],
                                        ),
                                      ),
                                      icon: const Icon(Icons.notes_outlined),
                                    ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusAction {
  final String status;
  final IconData icon;

  const _StatusAction(this.status, this.icon);
}
