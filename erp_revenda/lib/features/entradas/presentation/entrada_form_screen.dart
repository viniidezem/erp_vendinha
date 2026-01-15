import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/number_parser.dart';
import '../../../shared/widgets/app_decimal_field.dart';
import '../../../shared/widgets/app_error_dialog.dart';
import '../../../shared/widgets/app_page.dart';
import '../../produtos/data/produto_model.dart';
import '../controller/entradas_controller.dart';
import '../data/entrada_models.dart';

class EntradaFormScreen extends ConsumerStatefulWidget {
  final int? entradaId;
  const EntradaFormScreen({super.key, this.entradaId});

  @override
  ConsumerState<EntradaFormScreen> createState() => _EntradaFormScreenState();
}

class _EntradaFormScreenState extends ConsumerState<EntradaFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _numeroCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  final _totalNotaCtrl = TextEditingController(text: '0.00');
  final _freteCtrl = TextEditingController(text: '0.00');
  final _descontoCtrl = TextEditingController(text: '0.00');

  DateTime? _dataNota;
  DateTime _dataEntrada = DateTime.now();
  int? _fornecedorId;
  bool _atualizarCusto = true;

  bool _loading = false;
  bool _totalNotaAuto = true;
  String _status = EntradaStatus.rascunho;
  DateTime _createdAt = DateTime.now();
  List<EntradaItem> _itens = [];

  @override
  void initState() {
    super.initState();
    _loadIfEditing();
  }

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _obsCtrl.dispose();
    _totalNotaCtrl.dispose();
    _freteCtrl.dispose();
    _descontoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadIfEditing() async {
    final entradaId = widget.entradaId;
    if (entradaId == null) return;

    setState(() => _loading = true);
    try {
      final detalhe = await ref.read(entradaDetalheProvider(entradaId).future);
      if (!mounted) return;

      final e = detalhe.entrada;
      _fornecedorId = e.fornecedorId;
      _dataNota = e.dataNota;
      _dataEntrada = e.dataEntrada;
      _numeroCtrl.text = e.numeroNota ?? '';
      _obsCtrl.text = e.observacao ?? '';
      _totalNotaCtrl.text = e.totalNota.toStringAsFixed(2);
      _freteCtrl.text = e.freteTotal.toStringAsFixed(2);
      _descontoCtrl.text = e.descontoTotal.toStringAsFixed(2);
      _status = e.status;
      _createdAt = e.createdAt;
      _totalNotaAuto = false;
      _itens = detalhe.itens;
    } catch (e) {
      if (mounted) {
        await showErrorDialog(context, 'Erro ao carregar entrada:\n$e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _parseCtrl(TextEditingController ctrl) {
    try {
      return parseFlexibleNumber(ctrl.text);
    } catch (_) {
      return 0;
    }
  }

  double get _subtotalItens =>
      _itens.fold<double>(0, (sum, it) => sum + it.subtotal);
  double get _frete => _parseCtrl(_freteCtrl);
  double get _desconto => _parseCtrl(_descontoCtrl);
  double get _totalNota => _parseCtrl(_totalNotaCtrl);
  double get _totalCalculado => _subtotalItens + _frete - _desconto;

  void _maybeAutoTotalNota() {
    if (!_totalNotaAuto) return;
    _totalNotaCtrl.text = _totalCalculado.toStringAsFixed(2);
  }

  String _fmtDateOnly(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year}';
  }

  Future<void> _pickDataNota() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataNota ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _dataNota = picked);
  }

  Future<void> _pickDataEntrada() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataEntrada,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _dataEntrada = picked);
  }

  Future<void> _adicionarItem() async {
    if (_fornecedorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um fornecedor primeiro.')),
      );
      return;
    }

    final item = await showModalBottomSheet<EntradaItem>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AdicionarEntradaItemSheet(fornecedorId: _fornecedorId!),
    );
    if (item == null) return;
    setState(() {
      _itens.add(item);
      _maybeAutoTotalNota();
    });
  }

  Future<void> _editarItem(int index) async {
    final item = _itens[index];
    final updated = await showModalBottomSheet<EntradaItem>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditarEntradaItemSheet(item: item),
    );
    if (updated == null) return;
    setState(() {
      _itens[index] = updated;
      _maybeAutoTotalNota();
    });
  }

  Future<void> _salvar({required bool confirmar}) async {
    if (_status == EntradaStatus.confirmada) {
      await showErrorDialog(context, 'Entrada ja confirmada.');
      return;
    }

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if (_fornecedorId == null) {
      await showErrorDialog(context, 'Selecione um fornecedor.');
      return;
    }

    if (_itens.isEmpty) {
      await showErrorDialog(context, 'Adicione pelo menos um item.');
      return;
    }

    if (confirmar && _totalNota <= 0) {
      await showErrorDialog(context, 'Informe o total da nota.');
      return;
    }

    final entrada = Entrada(
      id: widget.entradaId,
      fornecedorId: _fornecedorId!,
      fornecedorNome: null,
      dataNota: _dataNota,
      dataEntrada: _dataEntrada,
      numeroNota: _numeroCtrl.text.trim().isEmpty ? null : _numeroCtrl.text.trim(),
      observacao: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
      totalNota: _totalNota,
      freteTotal: _frete,
      descontoTotal: _desconto,
      status: confirmar ? EntradaStatus.confirmada : EntradaStatus.rascunho,
      createdAt: _createdAt,
    );

    try {
      final id = await ref.read(entradasControllerProvider.notifier).salvarEntrada(
            entradaId: widget.entradaId,
            entrada: entrada,
            itens: _itens,
            confirmar: confirmar,
            atualizarCusto: _atualizarCusto,
          );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            confirmar ? 'Entrada confirmada.' : 'Rascunho salvo.',
          ),
        ),
      );

      if (confirmar) {
        final gerar = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Gerar contas a pagar'),
            content: const Text('Deseja gerar contas a pagar para esta entrada?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Agora nao'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Gerar'),
              ),
            ],
          ),
        );

        if (!mounted) return;
        if (gerar == true) {
          await context.push('/entradas/$id/contas-pagar');
          if (mounted) {
            Navigator.of(context).pop();
          }
          return;
        }
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(context, 'Erro ao salvar entrada:\n$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final fornecedoresAsync = ref.watch(entradasFornecedoresProvider);

    return AppPage(
      title: widget.entradaId == null ? 'Nova entrada' : 'Entrada',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fornecedor',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          fornecedoresAsync.when(
                            loading: () => const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            error: (e, _) =>
                                Text('Erro ao carregar fornecedores: $e'),
                            data: (fornecedores) {
                              if (fornecedores.isEmpty) {
                                return const Text(
                                  'Nenhum fornecedor cadastrado.',
                                );
                              }
                              return InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Fornecedor',
                                  border: OutlineInputBorder(),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int?>(
                                    isExpanded: true,
                                    value: _fornecedorId,
                                    hint: const Text('Selecione'),
                                    items: fornecedores
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
                                        _fornecedorId = v;
                                        _itens = [];
                                        _maybeAutoTotalNota();
                                      });
                                    },
                                  ),
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
                            'Cabecalho',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _numeroCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Numero da nota',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Data da nota',
                                    border: OutlineInputBorder(),
                                  ),
                                  child: InkWell(
                                    onTap: _pickDataNota,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Text(
                                        _dataNota == null
                                            ? 'Selecionar'
                                            : _fmtDateOnly(_dataNota!),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Data de entrada',
                                    border: OutlineInputBorder(),
                                  ),
                                  child: InkWell(
                                    onTap: _pickDataEntrada,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Text(_fmtDateOnly(_dataEntrada)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _obsCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Observacao',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          AppDecimalField(
                            controller: _freteCtrl,
                            labelText: 'Total do frete (R\$)',
                            onChanged: (_) => setState(() => _maybeAutoTotalNota()),
                          ),
                          const SizedBox(height: 12),
                          AppDecimalField(
                            controller: _descontoCtrl,
                            labelText: 'Desconto (R\$)',
                            onChanged: (_) => setState(() => _maybeAutoTotalNota()),
                          ),
                          const SizedBox(height: 12),
                          AppDecimalField(
                            controller: _totalNotaCtrl,
                            labelText: 'Valor total da nota (R\$)',
                            onChanged: (_) {
                              if (_totalNotaAuto) _totalNotaAuto = false;
                            },
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Total dos produtos: R\$ ${_subtotalItens.toStringAsFixed(2)}',
                          ),
                          Text(
                            'Total calculado: R\$ ${_totalCalculado.toStringAsFixed(2)}',
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _totalNotaAuto = true;
                                  _maybeAutoTotalNota();
                                });
                              },
                              child: const Text('Usar total calculado'),
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
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Itens',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              IconButton(
                                onPressed: _adicionarItem,
                                icon: const Icon(Icons.add_circle_outline),
                                tooltip: 'Adicionar item',
                              ),
                            ],
                          ),
                          if (_itens.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('Nenhum item adicionado.'),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _itens.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final it = _itens[index];
                                return ListTile(
                                  title: Text(it.produtoNome),
                                  subtitle: Text(
                                    'Qtd: ${it.qtd.toStringAsFixed(2)} | Custo: R\$ ${it.custoUnit.toStringAsFixed(2)}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () => _editarItem(index),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () {
                                          setState(() {
                                            _itens.removeAt(index);
                                            _maybeAutoTotalNota();
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Checkbox(
                                value: _atualizarCusto,
                                onChanged: (v) => setState(
                                  () => _atualizarCusto = v ?? true,
                                ),
                              ),
                              const Expanded(
                                child: Text('Atualizar preco de custo dos produtos'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _salvar(confirmar: false),
                    icon: const Icon(Icons.save_outlined),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Salvar rascunho'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _salvar(confirmar: true),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Confirmar entrada'),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
    );
  }
}

class _AdicionarEntradaItemSheet extends ConsumerStatefulWidget {
  final int fornecedorId;
  const _AdicionarEntradaItemSheet({required this.fornecedorId});

  @override
  ConsumerState<_AdicionarEntradaItemSheet> createState() =>
      _AdicionarEntradaItemSheetState();
}

class _AdicionarEntradaItemSheetState
    extends ConsumerState<_AdicionarEntradaItemSheet> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _search = '';
  bool _filtrarFornecedor = true;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      setState(() => _search = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final fornecedorFiltro = _filtrarFornecedor ? widget.fornecedorId : null;
    final asyncProdutos = ref.watch(
      entradaProdutosProvider(
        EntradaProdutosArgs(
          fornecedorId: fornecedorFiltro,
          search: _search,
        ),
      ),
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Adicionar item',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                labelText: 'Buscar produto',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _filtrarFornecedor,
              onChanged: (v) => setState(() => _filtrarFornecedor = v ?? true),
              title: const Text('Filtrar por fornecedor'),
              subtitle: const Text('Desmarque para ver todos os produtos'),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: asyncProdutos.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erro: $e')),
                data: (produtos) {
                  if (produtos.isEmpty) {
                    return const Center(
                      child: Text('Nenhum produto encontrado.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: produtos.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = produtos[i];
                      return ListTile(
                        title: Text(p.nome),
                        subtitle: Text(
                          'Custo atual: R\$ ${p.precoCusto.toStringAsFixed(2)}',
                        ),
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          final item = await showDialog<EntradaItem>(
                            context: context,
                            builder: (_) => _EntradaItemDialog(produto: p),
                          );
                          if (!mounted) return;
                          if (item != null) {
                            navigator.pop(item);
                          }
                        },
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

class _EntradaItemDialog extends StatefulWidget {
  final Produto produto;
  const _EntradaItemDialog({required this.produto});

  @override
  State<_EntradaItemDialog> createState() => _EntradaItemDialogState();
}

class _EntradaItemDialogState extends State<_EntradaItemDialog> {
  late final TextEditingController _qtdCtrl;
  late final TextEditingController _custoCtrl;

  @override
  void initState() {
    super.initState();
    _qtdCtrl = TextEditingController(text: '1.00');
    _custoCtrl = TextEditingController(
      text: widget.produto.precoCusto.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _qtdCtrl.dispose();
    _custoCtrl.dispose();
    super.dispose();
  }

  double _parse(String v) {
    try {
      return parseFlexibleNumber(v);
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Item da entrada'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.produto.nome),
          const SizedBox(height: 10),
          AppDecimalField(
            controller: _qtdCtrl,
            labelText: 'Quantidade',
            zeroText: '0.00',
          ),
          const SizedBox(height: 10),
          AppDecimalField(
            controller: _custoCtrl,
            labelText: 'Custo unitario (R\$)',
            zeroText: '0.00',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final qtd = _parse(_qtdCtrl.text);
            final custo = _parse(_custoCtrl.text);
            if (qtd <= 0 || custo < 0) return;
            Navigator.of(context).pop(
              EntradaItem(
                produtoId: widget.produto.id!,
                produtoNome: widget.produto.nome,
                qtd: qtd,
                custoUnit: custo,
              ),
            );
          },
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}

class _EditarEntradaItemSheet extends StatefulWidget {
  final EntradaItem item;
  const _EditarEntradaItemSheet({required this.item});

  @override
  State<_EditarEntradaItemSheet> createState() => _EditarEntradaItemSheetState();
}

class _EditarEntradaItemSheetState extends State<_EditarEntradaItemSheet> {
  late final TextEditingController _qtdCtrl;
  late final TextEditingController _custoCtrl;

  @override
  void initState() {
    super.initState();
    _qtdCtrl = TextEditingController(text: widget.item.qtd.toStringAsFixed(2));
    _custoCtrl =
        TextEditingController(text: widget.item.custoUnit.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _qtdCtrl.dispose();
    _custoCtrl.dispose();
    super.dispose();
  }

  double _parse(String v) {
    try {
      return parseFlexibleNumber(v);
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Editar item',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            AppDecimalField(
              controller: _qtdCtrl,
              labelText: 'Quantidade',
              zeroText: '0.00',
            ),
            const SizedBox(height: 12),
            AppDecimalField(
              controller: _custoCtrl,
              labelText: 'Custo unitario (R\$)',
              zeroText: '0.00',
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final qtd = _parse(_qtdCtrl.text);
                final custo = _parse(_custoCtrl.text);
                if (qtd <= 0 || custo < 0) return;
                Navigator.of(context).pop(
                  EntradaItem(
                    id: widget.item.id,
                    entradaId: widget.item.entradaId,
                    produtoId: widget.item.produtoId,
                    produtoNome: widget.item.produtoNome,
                    qtd: qtd,
                    custoUnit: custo,
                  ),
                );
              },
              child: const Text('Atualizar'),
            ),
          ],
        ),
      ),
    );
  }
}
