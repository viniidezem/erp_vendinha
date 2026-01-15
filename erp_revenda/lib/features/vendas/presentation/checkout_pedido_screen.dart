import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_page.dart';
import '../../clientes/controller/clientes_controller.dart';
import '../../formas_pagamento/controller/formas_pagamento_controller.dart';
import '../../formas_pagamento/data/forma_pagamento_model.dart';
import '../controller/vendas_controller.dart';
import '../data/venda_models.dart';

class CheckoutArgs {
  final int clienteId;
  final List<VendaItem> itens;

  const CheckoutArgs({required this.clienteId, required this.itens});
}

class CheckoutPedidoScreen extends ConsumerStatefulWidget {
  final CheckoutArgs args;

  const CheckoutPedidoScreen({super.key, required this.args});

  @override
  ConsumerState<CheckoutPedidoScreen> createState() => _CheckoutPedidoScreenState();
}

class _CheckoutPedidoScreenState extends ConsumerState<CheckoutPedidoScreen> {
  String _entregaTipo = VendaEntregaTipo.entrega;
  int? _enderecoId;
  int? _formaPagamentoId;
  int _parcelas = 1;

  final _obsCtrl = TextEditingController();

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  double get _total => widget.args.itens.fold<double>(0, (s, i) => s + i.subtotal);

  FormaPagamento? _findForma(List<FormaPagamento> list, int? id) {
    if (id == null) return null;
    try {
      return list.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _salvar() async {
    // Captura dependências antes de awaits para evitar warnings de BuildContext em async gaps.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final enderecos = await ref.read(clienteEnderecosProvider(widget.args.clienteId).future);
    if (!mounted) return;

    void toast(String msg) {
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }

    if (_formaPagamentoId == null) {
      toast('Selecione uma forma de pagamento.');
      return;
    }

    if (_entregaTipo == VendaEntregaTipo.entrega) {
      if (enderecos.isEmpty) {
        toast('Cliente sem endereço. Selecione Retirada / sem entrega.');
        return;
      }
      if (_enderecoId == null) {
        toast('Selecione um endereço de entrega.');
        return;
      }
    }

    final repo = ref.read(vendasRepositoryProvider);

    await repo.finalizarVenda(
      clienteId: widget.args.clienteId,
      itens: widget.args.itens,
      status: VendaStatus.pedido, // regra: sempre inicia como PEDIDO
      entregaTipo: _entregaTipo,
      enderecoEntregaId: _entregaTipo == VendaEntregaTipo.entrega ? _enderecoId : null,
      formaPagamentoId: _formaPagamentoId,
      parcelas: _parcelas,
      observacao: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
    );
    if (!mounted) return;

    // Limpa estado da venda em andamento
    ref.read(vendaEmAndamentoProvider.notifier).limpar();
    ref.read(vendaClienteSelecionadoIdProvider.notifier).state = null;

    // Atualiza lista
    await ref.read(vendasListProvider.notifier).refresh();
    if (!mounted) return;

    toast('Pedido registrado com sucesso.');
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final enderecosAsync = ref.watch(clienteEnderecosProvider(widget.args.clienteId));
    final formasAsync = ref.watch(formasPagamentoControllerProvider);

    return AppPage(
      title: 'Checkout',
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumo do pedido',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('Itens: ${widget.args.itens.length}'),
                  const SizedBox(height: 4),
                  Text('Total: R\$ ${_total.toStringAsFixed(2)}'),
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
                    'Entrega',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Entrega (selecionar endereço)'),
                        selected: _entregaTipo == VendaEntregaTipo.entrega,
                        onSelected: (_) => setState(() {
                          _entregaTipo = VendaEntregaTipo.entrega;
                          _enderecoId = null; // nunca pré-seleciona
                        }),
                      ),
                      ChoiceChip(
                        label: const Text('Retirada / sem entrega'),
                        selected: _entregaTipo == VendaEntregaTipo.retirada,
                        onSelected: (_) => setState(() {
                          _entregaTipo = VendaEntregaTipo.retirada;
                          _enderecoId = null;
                        }),
                      ),
                    ],
                  ),
                  if (_entregaTipo == VendaEntregaTipo.entrega) ...[
                    const Divider(height: 24),
                    enderecosAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Text('Erro ao carregar endereços: $e'),
                      data: (enderecos) {
                        if (enderecos.isEmpty) {
                          return const Text(
                            'Este cliente não possui endereços cadastrados. Use Retirada / sem entrega.',
                          );
                        }

                        return Column(
                          children: [
                            for (final e in enderecos)
                              _EnderecoTile(
                                title: (e.rotulo ?? '').trim().isEmpty ? 'Endereço' : e.rotulo!.trim(),
                                subtitle: e.resumo(),
                                selected: _enderecoId == e.id,
                                onTap: () => setState(() => _enderecoId = e.id),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
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
                    'Pagamento',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  formasAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Erro ao carregar formas: $e'),
                    data: (formas) {
                      final formaSel = _findForma(formas, _formaPagamentoId);

                      // Ajusta parcelas quando forma não permite
                      if (formaSel != null && !formaSel.permiteParcelamento && _parcelas != 1) {
                        // evita setState durante build; agenda no próximo microtask
                        Future.microtask(() {
                          if (mounted) setState(() => _parcelas = 1);
                        });
                      }

                      final formasAtivas = formas.where((f) => f.ativo).toList();

                      return Column(
                        children: [
                          InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Forma de pagamento',
                              border: OutlineInputBorder(),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int?>(
                                isExpanded: true,
                                value: _formaPagamentoId,
                                hint: const Text('Selecione'),
                                items: formasAtivas
                                    .where((f) => f.id != null)
                                    .map(
                                      (f) => DropdownMenuItem<int?>(
                                        value: f.id,
                                        child: Text(f.nome),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  setState(() {
                                    _formaPagamentoId = v;
                                    final fp = _findForma(formasAtivas, v);
                                    if (fp == null || !fp.permiteParcelamento) {
                                      _parcelas = 1;
                                    } else {
                                      final max = fp.maxParcelas;
                                      if (_parcelas < 1) _parcelas = 1;
                                      if (_parcelas > max) _parcelas = max;
                                    }
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (formaSel != null && formaSel.permiteParcelamento) ...[
                            InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Parcelas',
                                border: OutlineInputBorder(),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  isExpanded: true,
                                  value: _parcelas,
                                  items: List.generate(
                                    formaSel.maxParcelas,
                                    (i) => DropdownMenuItem(
                                      value: i + 1,
                                      child: Text('${i + 1}x'),
                                    ),
                                  ),
                                  onChanged: (v) => setState(() => _parcelas = v ?? 1),
                                ),
                              ),
                            ),
                          ] else ...[
                            TextFormField(
                              enabled: false,
                              initialValue: '1x',
                              decoration: const InputDecoration(
                                labelText: 'Parcelas',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ],
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
                    'Observações',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _obsCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Ex.: entregar após 18h, deixar na portaria, etc.',
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _salvar,
            icon: const Icon(Icons.check_circle_outline),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Concluir checkout e gravar pedido'),
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class _EnderecoTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _EnderecoTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Icon(
          selected ? Icons.check_circle : Icons.radio_button_unchecked,
        ),
      ),
    );
  }
}
