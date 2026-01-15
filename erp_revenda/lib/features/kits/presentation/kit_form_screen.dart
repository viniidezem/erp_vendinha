import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/number_parser.dart';
import '../../../shared/widgets/app_decimal_field.dart';
import '../../../shared/widgets/app_error_dialog.dart';
import '../../../shared/widgets/app_page.dart';
import '../controller/kits_controller.dart';
import '../data/kit_models.dart';

class KitFormScreen extends ConsumerStatefulWidget {
  final int? kitId;
  const KitFormScreen({super.key, this.kitId});

  @override
  ConsumerState<KitFormScreen> createState() => _KitFormScreenState();
}

class _KitFormScreenState extends ConsumerState<KitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _precoCtrl = TextEditingController(text: '0.00');
  bool _ativo = true;
  bool _loading = false;
  DateTime _createdAt = DateTime.now();
  List<KitItem> _itens = [];

  @override
  void initState() {
    super.initState();
    _loadIfEditing();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _precoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadIfEditing() async {
    final kitId = widget.kitId;
    if (kitId == null) return;
    setState(() => _loading = true);
    try {
      final detalhe = await ref.read(kitDetalheProvider(kitId).future);
      if (!mounted) return;
      _nomeCtrl.text = detalhe.kit.nome;
      _precoCtrl.text = detalhe.kit.precoVenda.toStringAsFixed(2);
      _ativo = detalhe.kit.ativo;
      _createdAt = detalhe.kit.createdAt;
      _itens = detalhe.itens;
    } catch (e) {
      if (mounted) {
        await showErrorDialog(context, 'Erro ao carregar kit:\n$e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _parsePreco() {
    try {
      return parseFlexibleNumber(_precoCtrl.text);
    } catch (_) {
      return 0;
    }
  }

  Future<void> _adicionarItem() async {
    final item = await showModalBottomSheet<KitItem>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _SelecionarProdutoSheet(),
    );
    if (!mounted || item == null) return;

    final idx = _itens.indexWhere((e) => e.produtoId == item.produtoId);
    setState(() {
      if (idx >= 0) {
        final existing = _itens[idx];
        _itens[idx] = KitItem(
          produtoId: existing.produtoId,
          produtoNome: existing.produtoNome,
          qtd: existing.qtd + item.qtd,
        );
      } else {
        _itens.add(item);
      }
    });
  }

  Future<void> _editarItem(int index) async {
    final item = _itens[index];
    final updated = await showDialog<KitItem>(
      context: context,
      builder: (_) => _QtdDialog(item: item),
    );
    if (!mounted || updated == null) return;
    setState(() => _itens[index] = updated);
  }

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final nome = _nomeCtrl.text.trim();
    final preco = _parsePreco();
    if (preco <= 0) {
      await showErrorDialog(context, 'Informe o preco do kit.');
      return;
    }
    if (_itens.isEmpty) {
      await showErrorDialog(context, 'Adicione pelo menos um produto ao kit.');
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(kitRepositoryProvider).salvarKit(
            kitId: widget.kitId,
            nome: nome,
            precoVenda: preco,
            ativo: _ativo,
            createdAt: _createdAt,
            itens: _itens,
          );
      await ref.read(kitsControllerProvider.notifier).refresh();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        await showErrorDialog(context, 'Erro ao salvar kit:\n$e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.kitId != null;

    return AppPage(
      title: editando ? 'Editar kit' : 'Novo kit',
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
                            'Dados do kit',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nomeCtrl,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Nome',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Informe o nome.'
                                    : null,
                          ),
                          const SizedBox(height: 12),
                          AppDecimalField(
                            controller: _precoCtrl,
                            labelText: 'Preco fixo (R\$)',
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Checkbox(
                                value: _ativo,
                                onChanged: (v) =>
                                    setState(() => _ativo = v ?? true),
                              ),
                              const Text('Ativo'),
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
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Produtos do kit',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              IconButton(
                                onPressed: _adicionarItem,
                                icon: const Icon(Icons.add_circle_outline),
                                tooltip: 'Adicionar produto',
                              ),
                            ],
                          ),
                          if (_itens.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('Nenhum produto adicionado.'),
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
                                    'Qtd: ${it.qtd.toStringAsFixed(2)}',
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
                                        onPressed: () =>
                                            setState(() => _itens.removeAt(index)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _salvar,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Salvar kit'),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
    );
  }
}

class _SelecionarProdutoSheet extends ConsumerStatefulWidget {
  const _SelecionarProdutoSheet();

  @override
  ConsumerState<_SelecionarProdutoSheet> createState() =>
      _SelecionarProdutoSheetState();
}

class _SelecionarProdutoSheetState
    extends ConsumerState<_SelecionarProdutoSheet> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _search = '';

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
    final asyncProdutos = ref.watch(kitsProdutosProvider(_search));

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
                    'Selecionar produto',
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
                          'Preco atual: R\$ ${p.precoVenda.toStringAsFixed(2)}',
                        ),
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          final item = await showDialog<KitItem>(
                            context: context,
                            builder: (_) => _QtdDialog(
                              item: KitItem(
                                produtoId: p.id!,
                                produtoNome: p.nome,
                                qtd: 1,
                              ),
                            ),
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

class _QtdDialog extends StatefulWidget {
  final KitItem item;
  const _QtdDialog({required this.item});

  @override
  State<_QtdDialog> createState() => _QtdDialogState();
}

class _QtdDialogState extends State<_QtdDialog> {
  late final TextEditingController _qtdCtrl;

  @override
  void initState() {
    super.initState();
    _qtdCtrl = TextEditingController(text: widget.item.qtd.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _qtdCtrl.dispose();
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
      title: const Text('Quantidade'),
      content: AppDecimalField(
        controller: _qtdCtrl,
        labelText: 'Qtd',
        zeroText: '0.00',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final qtd = _parse(_qtdCtrl.text);
            if (qtd <= 0) return;
            Navigator.of(context).pop(
              KitItem(
                produtoId: widget.item.produtoId,
                produtoNome: widget.item.produtoNome,
                qtd: qtd,
              ),
            );
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
