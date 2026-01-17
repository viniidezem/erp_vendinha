import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/number_parser.dart';
import '../../../shared/widgets/app_error_dialog.dart';
import '../../../shared/widgets/app_decimal_field.dart';
import '../../../shared/widgets/app_page.dart';
import '../../clientes/controller/clientes_controller.dart';
import '../../formas_pagamento/controller/formas_pagamento_controller.dart';
import '../../formas_pagamento/data/forma_pagamento_model.dart';
import '../../settings/controller/plan_controller.dart';
import '../controller/vendas_controller.dart';
import '../data/venda_models.dart';

class CheckoutArgs {
  final int clienteId;
  final List<VendaItem> itens;

  const CheckoutArgs({required this.clienteId, required this.itens});
}

enum _DescontoTipo { valor, percentual }

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
  bool _permiteDesconto = false;
  bool _permiteInformarVencimento = false;
  _DescontoTipo _descontoTipo = _DescontoTipo.valor;
  List<DateTime?> _vencimentos = <DateTime?>[];
  bool _submitAttempted = false;

  final _obsCtrl = TextEditingController();
  final _descontoCtrl = TextEditingController(text: '0.00');

  @override
  void dispose() {
    _obsCtrl.dispose();
    _descontoCtrl.dispose();
    super.dispose();
  }

  double get _subtotal => widget.args.itens.fold<double>(0, (s, i) => s + i.subtotal);

  double _round2(double v) => (v * 100).round() / 100.0;

  double _parseDescontoInput() {
    try {
      return parseFlexibleNumber(_descontoCtrl.text);
    } catch (_) {
      return 0;
    }
  }

  double _descontoAplicado(double total) {
    if (!_permiteDesconto) return 0;
    final input = _parseDescontoInput();
    if (input <= 0) return 0;

    if (_descontoTipo == _DescontoTipo.percentual) {
      final pct = input.clamp(0.0, 100.0).toDouble();
      final valor = _round2(total * pct / 100);
      return valor > total ? total : valor;
    }

    final valor = input.clamp(0.0, total).toDouble();
    return _round2(valor);
  }

  bool _descontoExcedido(double total) {
    if (!_permiteDesconto) return false;
    final input = _parseDescontoInput();
    if (input <= 0) return false;
    if (_descontoTipo == _DescontoTipo.percentual) {
      return input > 100;
    }
    return input > total;
  }

  double? _descontoPercentualSelecionado() {
    if (!_permiteDesconto || _descontoTipo != _DescontoTipo.percentual) return null;
    final input = _parseDescontoInput();
    if (input <= 0) return null;
    final pct = input.clamp(0.0, 100.0).toDouble();
    return _round2(pct);
  }

  double? _descontoValorSelecionado() {
    if (!_permiteDesconto || _descontoTipo != _DescontoTipo.valor) return null;
    final input = _parseDescontoInput();
    if (input <= 0) return null;
    return _round2(input);
  }

  String _fmtDateOnly(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year}';
  }

  List<double> _parcelasValores(double total, int parcelas) {
    final parcelasSafe = parcelas < 1 ? 1 : parcelas;
    final totalCents = (total * 100).round();
    final baseCents = totalCents ~/ parcelasSafe;
    final residual = totalCents % parcelasSafe;

    return List.generate(parcelasSafe, (i) {
      final cents = baseCents + (i == 0 ? residual : 0);
      return cents / 100.0;
    });
  }

  void _syncVencimentos(int parcelas) {
    final count = parcelas < 1 ? 1 : parcelas;
    if (!_permiteInformarVencimento) {
      _vencimentos = List<DateTime?>.filled(count, null);
      return;
    }
    if (_vencimentos.length == count) return;
    final next = List<DateTime?>.filled(count, null);
    final limit = _vencimentos.length < count ? _vencimentos.length : count;
    for (var i = 0; i < limit; i++) {
      next[i] = _vencimentos[i];
    }
    _vencimentos = next;
  }

  Future<void> _selecionarVencimento(int index) async {
    final initial = (index < _vencimentos.length && _vencimentos[index] != null)
        ? _vencimentos[index]!
        : DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked == null || !mounted) return;
    setState(() => _vencimentos[index] = picked);
  }

  FormaPagamento? _findForma(List<FormaPagamento> list, int? id) {
    if (id == null) return null;
    try {
      return list.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _salvar() async {
    setState(() => _submitAttempted = true);

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

    final vencimentos = _permiteInformarVencimento
        ? (_vencimentos.length == _parcelas
            ? _vencimentos
            : List<DateTime?>.filled(_parcelas, null))
        : null;
    final repo = ref.read(vendasRepositoryProvider);

    try {
      await repo.finalizarVenda(
        clienteId: widget.args.clienteId,
        itens: widget.args.itens,
        status: VendaStatus.pedido, // regra: sempre inicia como PEDIDO
        entregaTipo: _entregaTipo,
        enderecoEntregaId: _entregaTipo == VendaEntregaTipo.entrega ? _enderecoId : null,
        formaPagamentoId: _formaPagamentoId,
        parcelas: _parcelas,
        vencimentos: vencimentos,
        descontoValor: _descontoValorSelecionado(),
        descontoPercentual: _descontoPercentualSelecionado(),
        observacao: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
      );
    } catch (e) {
      if (mounted) {
        await showErrorDialog(context, 'Erro ao concluir checkout:\n$e');
      }
      return;
    }
    if (!mounted) return;

    // Limpa estado da venda em andamento
    ref.read(vendaEmAndamentoProvider.notifier).limpar();
    ref.read(vendaClienteSelecionadoIdProvider.notifier).state = null;

    // Atualiza lista
    await ref.read(vendasListProvider.notifier).refresh();
    ref.invalidate(planInfoProvider);
    if (!mounted) return;

    toast('Pedido registrado com sucesso.');
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final enderecosAsync = ref.watch(clienteEnderecosProvider(widget.args.clienteId));
    final formasAsync = ref.watch(formasPagamentoControllerProvider);
    final subtotal = _subtotal;
    final descontoAplicado = _descontoAplicado(subtotal);
    final totalFinal = _round2(subtotal - descontoAplicado);
    final descontoPct = _descontoPercentualSelecionado();
    final descontoExcedido = _descontoExcedido(subtotal);
    final parcelasValores = _parcelasValores(totalFinal, _parcelas);
    final enderecoErro = _submitAttempted &&
        _entregaTipo == VendaEntregaTipo.entrega &&
        _enderecoId == null;
    final pagamentoErro =
        _submitAttempted && _formaPagamentoId == null ? 'Selecione uma forma de pagamento.' : null;
    final errorColor = Theme.of(context).colorScheme.error;

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
                    'Resumo rapido',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _ResumoCompactoItem(
                          label: 'Subtotal',
                          value: 'R\$ ${subtotal.toStringAsFixed(2)}',
                        ),
                      ),
                      Expanded(
                        child: _ResumoCompactoItem(
                          label: 'Desconto',
                          value: descontoAplicado <= 0
                              ? 'R\$ 0,00'
                              : 'R\$ ${descontoAplicado.toStringAsFixed(2)}',
                          helper: descontoPct == null || descontoAplicado <= 0
                              ? null
                              : '${descontoPct.toStringAsFixed(2)}%',
                        ),
                      ),
                      Expanded(
                        child: _ResumoCompactoItem(
                          label: 'Total',
                          value: 'R\$ ${totalFinal.toStringAsFixed(2)}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Parcelas: ${_parcelas}x'),
                  if (descontoExcedido) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Desconto acima do permitido. Valor ajustado automaticamente.',
                      style: TextStyle(color: errorColor),
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
                            if (enderecoErro)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Selecione um endereço de entrega.',
                                  style: TextStyle(color: errorColor),
                                ),
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

                      final permiteDesconto = formaSel?.permiteDesconto ?? false;
                      final permiteVencimento =
                          formaSel?.permiteInformarVencimento ?? false;
                      if (permiteDesconto != _permiteDesconto ||
                          permiteVencimento != _permiteInformarVencimento) {
                        Future.microtask(() {
                          if (!mounted) return;
                          setState(() {
                            _permiteDesconto = permiteDesconto;
                            _permiteInformarVencimento = permiteVencimento;
                            if (!permiteDesconto) {
                              _descontoTipo = _DescontoTipo.valor;
                              _descontoCtrl.text = '0.00';
                            }
                            if (!permiteVencimento) {
                              _vencimentos =
                                  List<DateTime?>.filled(_parcelas, null);
                            } else {
                              _syncVencimentos(_parcelas);
                            }
                          });
                        });
                      }


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
                            decoration: InputDecoration(
                              labelText: 'Forma de pagamento',
                              border: const OutlineInputBorder(),
                              errorText: pagamentoErro,
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
                                    _permiteDesconto = fp?.permiteDesconto ?? false;
                                    _permiteInformarVencimento =
                                        fp?.permiteInformarVencimento ?? false;
                                    if (!_permiteDesconto) {
                                      _descontoTipo = _DescontoTipo.valor;
                                      _descontoCtrl.text = '0.00';
                                    }
                                    if (!_permiteInformarVencimento) {
                                      _vencimentos =
                                          List<DateTime?>.filled(_parcelas, null);
                                    }
                                    if (fp == null || !fp.permiteParcelamento) {
                                      _parcelas = 1;
                                    } else {
                                      final max = fp.maxParcelas;
                                      if (_parcelas < 1) _parcelas = 1;
                                      if (_parcelas > max) _parcelas = max;
                                    }
                                    _syncVencimentos(_parcelas);
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
                                  onChanged: (v) => setState(() {
                                    _parcelas = v ?? 1;
                                    _syncVencimentos(_parcelas);
                                  }),
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
                          const SizedBox(height: 12),
                          if (formaSel != null && formaSel.permiteDesconto) ...[
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Desconto',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('Valor (R\$)'),
                                  selected: _descontoTipo == _DescontoTipo.valor,
                                  onSelected: (_) {
                                    if (_descontoTipo == _DescontoTipo.valor) return;
                                    setState(() {
                                      _descontoTipo = _DescontoTipo.valor;
                                      _descontoCtrl.text = '0.00';
                                    });
                                  },
                                ),
                                ChoiceChip(
                                  label: const Text('Percentual (%)'),
                                  selected: _descontoTipo == _DescontoTipo.percentual,
                                  onSelected: (_) {
                                    if (_descontoTipo == _DescontoTipo.percentual) return;
                                    setState(() {
                                      _descontoTipo = _DescontoTipo.percentual;
                                      _descontoCtrl.text = '0';
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            AppDecimalField(
                              controller: _descontoCtrl,
                              labelText: _descontoTipo == _DescontoTipo.valor
                                  ? 'Desconto (R\$)'
                                  : 'Desconto (%)',
                              zeroText: _descontoTipo == _DescontoTipo.valor ? '0.00' : '0',
                              helperText: _descontoTipo == _DescontoTipo.valor
                                  ? 'Informe o valor do desconto.'
                                  : 'Informe o percentual (0 a 100).',
                              onChanged: (_) => setState(() {}),
                            ),
                            if (descontoExcedido) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Desconto acima do permitido. Valor ajustado automaticamente.',
                                style: TextStyle(color: errorColor),
                              ),
                            ],
                          ],
                          if (formaSel != null && formaSel.permiteInformarVencimento) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Vencimento das parcelas',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (var i = 0; i < parcelasValores.length; i++)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'Parcela ${i + 1}: R\$ ${parcelasValores[i].toStringAsFixed(2)}',
                                ),
                                trailing: OutlinedButton(
                                  onPressed: () => _selecionarVencimento(i),
                                  child: Text(
                                    (i < _vencimentos.length &&
                                            _vencimentos[i] != null)
                                        ? _fmtDateOnly(_vencimentos[i]!)
                                        : 'Selecionar',
                                  ),
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

          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumo financeiro',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Itens:'),
                  const SizedBox(height: 6),
                  const _ResumoHeaderRow(),
                  const Divider(height: 16),
                  for (final it in widget.args.itens) _ResumoItemRow(item: it),
                  const Divider(height: 20),
                  Row(
                    children: [
                      const Expanded(child: Text('Total Itens')),
                      Text('R\$ ${subtotal.toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Expanded(child: Text('Desconto')),
                      Text('R\$ ${descontoAplicado.toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Total Final',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        'R\$ ${totalFinal.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('Parcelas: ${_parcelas}x'),
                  if (parcelasValores.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    for (var i = 0; i < parcelasValores.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          _permiteInformarVencimento &&
                                  i < _vencimentos.length &&
                                  _vencimentos[i] != null
                              ? 'Parcela ${i + 1}: R\$ ${parcelasValores[i].toStringAsFixed(2)} - vence ${_fmtDateOnly(_vencimentos[i]!)}'
                              : 'Parcela ${i + 1}: R\$ ${parcelasValores[i].toStringAsFixed(2)}',
                        ),
                      ),
                  ],
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

class _ResumoHeaderRow extends StatelessWidget {
  const _ResumoHeaderRow();

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(fontWeight: FontWeight.w700, fontSize: 12);

    return Row(
      children: const [
        Expanded(child: Text('Produto', style: headerStyle)),
        SizedBox(width: 60, child: Text('QTD', textAlign: TextAlign.right, style: headerStyle)),
        SizedBox(width: 90, child: Text('Valor', textAlign: TextAlign.right, style: headerStyle)),
      ],
    );
  }
}

class _ResumoCompactoItem extends StatelessWidget {
  final String label;
  final String value;
  final String? helper;

  const _ResumoCompactoItem({
    required this.label,
    required this.value,
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (helper != null) ...[
          const SizedBox(height: 2),
          Text(
            helper!,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ],
    );
  }
}

class _ResumoItemRow extends StatelessWidget {
  final VendaItem item;

  const _ResumoItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(item.produtoNome)),
          SizedBox(
            width: 60,
            child: Text(
              item.qtd.toStringAsFixed(2),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              'R\$ ${item.subtotal.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
            ),
          ),
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
