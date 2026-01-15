import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/ui/app_colors.dart';
import '../../../shared/widgets/app_page.dart';
import '../../clientes/controller/clientes_controller.dart';
import '../../clientes/data/cliente_endereco_model.dart';
import '../../formas_pagamento/controller/formas_pagamento_controller.dart';
import '../../formas_pagamento/data/forma_pagamento_model.dart';
import '../controller/vendas_controller.dart';
import '../data/venda_models.dart';

class PedidoDetalheScreen extends ConsumerWidget {
  final int vendaId;

  const PedidoDetalheScreen({super.key, required this.vendaId});

  String _fmtDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case VendaStatus.cancelada:
        return AppColors.danger;
      case VendaStatus.finalizado:
      case VendaStatus.entregue:
      case VendaStatus.pagamentoEfetuado:
        return AppColors.success;
      default:
        return AppColors.primary;
    }
  }

  Future<void> _selecionarStatus(
    BuildContext context,
    WidgetRef ref, {
    required String atual,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final statuses = VendaStatus.filtros;
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: statuses.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final status = statuses[index];
              return ListTile(
                title: Text(VendaStatus.label(status)),
                trailing: status == atual ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(ctx).pop(status),
              );
            },
          ),
        );
      },
    );

    if (selected == null || selected == atual) return;
    if (!context.mounted) return;

    await _mudarStatus(context, ref, novoStatus: selected);
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
    // Fluxo sugerido (não rígido). Sempre permite cancelar.
    if (status == VendaStatus.pedido) {
      return const [
        _StatusAction(VendaStatus.aguardandoPagamento, Icons.payments_outlined),
        _StatusAction(VendaStatus.pagamentoEfetuado, Icons.verified_outlined),
        _StatusAction(VendaStatus.aguardandoMercadoria, Icons.inventory_2_outlined),
        _StatusAction(VendaStatus.emExpedicao, Icons.local_shipping_outlined),
        _StatusAction(VendaStatus.entregue, Icons.check_circle_outline),
        _StatusAction(VendaStatus.finalizado, Icons.flag_outlined),
        _StatusAction(VendaStatus.cancelada, Icons.cancel_outlined),
      ];
    }
    if (status == VendaStatus.aguardandoPagamento) {
      return const [
        _StatusAction(VendaStatus.pagamentoEfetuado, Icons.verified_outlined),
        _StatusAction(VendaStatus.cancelada, Icons.cancel_outlined),
      ];
    }
    if (status == VendaStatus.pagamentoEfetuado) {
      return const [
        _StatusAction(VendaStatus.aguardandoMercadoria, Icons.inventory_2_outlined),
        _StatusAction(VendaStatus.emExpedicao, Icons.local_shipping_outlined),
        _StatusAction(VendaStatus.entregue, Icons.check_circle_outline),
        _StatusAction(VendaStatus.finalizado, Icons.flag_outlined),
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
    if (status == VendaStatus.entregue) {
      return const [
        _StatusAction(VendaStatus.finalizado, Icons.flag_outlined),
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

          final formasAsync = ref.watch(formasPagamentoControllerProvider);
          final enderecosAsync = (venda.clienteId == null)
              ? const AsyncValue.data(<ClienteEndereco>[]) // evita null
              : ref.watch(clienteEnderecosProvider(venda.clienteId!));

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
                        Text('Total: R\$ ${venda.total.toStringAsFixed(2)}'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _StatusPill(
                              status: venda.status,
                              color: _statusColor(venda.status),
                            ),
                            TextButton.icon(
                              onPressed: () => _selecionarStatus(
                                context,
                                ref,
                                atual: venda.status,
                              ),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Alterar status'),
                            ),
                          ],
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
                          'Checkout',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text('Entrega: ${VendaEntregaTipo.label(venda.entregaTipo)}'),
                        const SizedBox(height: 6),
                        if (venda.entregaTipo == VendaEntregaTipo.entrega) ...[
                          if (venda.enderecoEntregaId == null)
                            const Text('Endereço: não selecionado')
                          else
                            enderecosAsync.when(
                              loading: () => const Text('Endereço: carregando...'),
                              error: (e, _) => Text('Endereço: erro ao carregar ($e)'),
                              data: (enderecos) {
                                try {
                                  final e = enderecos.firstWhere((x) => x.id == venda.enderecoEntregaId);
                                  final rotulo = (e.rotulo ?? '').trim().isEmpty ? 'Endereço' : e.rotulo!.trim();
                                  return Text('Endereço: $rotulo • ${e.resumo()}');
                                } catch (_) {
                                  return Text('Endereço: #${venda.enderecoEntregaId}');
                                }
                              },
                            ),
                        ] else ...[
                          const Text('Endereço: (retirada / sem entrega)'),
                        ],
                        const Divider(height: 24),
                        formasAsync.when(
                          loading: () => const Text('Pagamento: carregando...'),
                          error: (e, _) => Text('Pagamento: erro ao carregar ($e)'),
                          data: (formas) {
                            final id = venda.formaPagamentoId;
                            FormaPagamento? fp;
                            if (id != null) {
                              try {
                                fp = formas.firstWhere((f) => f.id == id);
                              } catch (_) {
                                fp = null;
                              }
                            }

                            final nome = fp?.nome ?? (id == null ? 'Não informado' : 'Forma #$id');
                            final parcelas = (venda.parcelas ?? 1);

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Forma de pagamento: $nome'),
                                const SizedBox(height: 6),
                                Text('Parcelas: ${parcelas}x'),
                              ],
                            );
                          },
                        ),
                        if ((venda.observacao ?? '').trim().isNotEmpty) ...[
                          const Divider(height: 24),
                          Text('Observação: ${venda.observacao!.trim()}'),
                        ],
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
                          const Text('Sem historico registrado.')
                        else
                          ...detalhe.historico.asMap().entries.map((entry) {
                            final h = entry.value;
                            final isLast = entry.key == detalhe.historico.length - 1;
                            return _TimelineItem(
                              status: h.status,
                              dateText: _fmtDate(h.createdAt),
                              obs: h.obs,
                              isLast: isLast,
                              isCurrent: isLast,
                              color: _statusColor(h.status),
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

class _StatusPill extends StatelessWidget {
  final String status;
  final Color color;

  const _StatusPill({
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        VendaStatus.label(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String status;
  final String dateText;
  final String? obs;
  final bool isLast;
  final bool isCurrent;
  final Color color;

  const _TimelineItem({
    required this.status,
    required this.dateText,
    required this.obs,
    required this.isLast,
    required this.isCurrent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isCurrent ? color.withValues(alpha: 0.08) : null,
              borderRadius: BorderRadius.circular(12),
              border: isCurrent ? Border.all(color: color.withValues(alpha: 0.35)) : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        VendaStatus.label(status),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Atual',
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  dateText,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                if ((obs ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Obs: ${obs!.trim()}'),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
