import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_page.dart';
import '../../financeiro/contas_pagar/controller/contas_pagar_controller.dart';
import '../controller/entradas_controller.dart';
import '../data/entrada_models.dart';

class EntradaDetalheScreen extends ConsumerWidget {
  final int entradaId;
  const EntradaDetalheScreen({super.key, required this.entradaId});

  String _fmtDateOnly(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalheAsync = ref.watch(entradaDetalheProvider(entradaId));

    return AppPage(
      title: 'Entrada',
      child: detalheAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Erro ao carregar entrada: $e'),
        ),
        data: (detalhe) {
          final e = detalhe.entrada;
          final itens = detalhe.itens;
          final hasFinanceiroAsync = ref.watch(
            contasPagarExisteEntradaProvider(entradaId),
          );
          final subtotal = itens.fold<double>(0, (s, it) => s + it.subtotal);
          final total = e.totalNota.toStringAsFixed(2);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.fornecedorNome ?? 'Fornecedor',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('Status: ${EntradaStatus.label(e.status)}'),
                      if (e.numeroNota != null && e.numeroNota!.trim().isNotEmpty)
                        Text('Nota: ${e.numeroNota}'),
                      if (e.dataNota != null)
                        Text('Data da nota: ${_fmtDateOnly(e.dataNota!)}'),
                      Text('Data de entrada: ${_fmtDateOnly(e.dataEntrada)}'),
                      if (e.observacao != null &&
                          e.observacao!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('Obs: ${e.observacao}'),
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
                        'Itens',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (itens.isEmpty)
                        const Text('Nenhum item.')
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: itens.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final it = itens[i];
                            return ListTile(
                              title: Text(it.produtoNome),
                              subtitle: Text(
                                'Qtd: ${it.qtd.toStringAsFixed(2)} | Custo: R\$ ${it.custoUnit.toStringAsFixed(2)}',
                              ),
                              trailing: Text(
                                'R\$ ${it.subtotal.toStringAsFixed(2)}',
                              ),
                            );
                          },
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
                        'Resumo',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Expanded(child: Text('Subtotal itens')),
                          Text('R\$ ${subtotal.toStringAsFixed(2)}'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Expanded(child: Text('Frete')),
                          Text('R\$ ${e.freteTotal.toStringAsFixed(2)}'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Expanded(child: Text('Desconto')),
                          Text('R\$ ${e.descontoTotal.toStringAsFixed(2)}'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Total da nota',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            'R\$ $total',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              hasFinanceiroAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (err, _) => Text('Erro ao checar financeiro: $err'),
                data: (hasFinanceiro) {
                  final podeGerar =
                      e.status == EntradaStatus.confirmada && !hasFinanceiro;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: podeGerar
                            ? () => context.push(
                                  '/entradas/$entradaId/contas-pagar',
                                )
                            : null,
                        icon: const Icon(Icons.payments_outlined),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Gerar contas a pagar'),
                        ),
                      ),
                      if (hasFinanceiro)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'Financeiro ja gerado para esta entrada.',
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
