import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_page.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../produtos/data/produto_model.dart';
import '../controller/vendas_controller.dart';
import '../data/venda_models.dart';

class NovaVendaScreen extends ConsumerWidget {
  const NovaVendaScreen({super.key});

  double _total(List<VendaItem> itens) =>
      itens.fold<double>(0, (sum, i) => sum + i.subtotal);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itens = ref.watch(vendaEmAndamentoProvider);
    final clienteSelecionadoId = ref.watch(vendaClienteSelecionadoIdProvider);
    final asyncClientes = ref.watch(clientesAtivosParaVendaProvider);

    return AppPage(
      title: 'Nova venda',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                title: const Text('Cliente'),
                subtitle: Text(
                  asyncClientes.when(
                    data: (clientes) {
                      if (clienteSelecionadoId == null)
                        return 'Selecione um cliente';
                      final match = clientes.where(
                        (c) => c.id == clienteSelecionadoId,
                      );
                      if (match.isEmpty)
                        return 'Cliente #$clienteSelecionadoId';
                      final c = match.first;
                      final apelido = (c.apelido ?? '').trim();
                      return apelido.isEmpty ? c.nome : '${c.nome} ($apelido)';
                    },
                    loading: () => clienteSelecionadoId == null
                        ? 'Selecione um cliente'
                        : 'Cliente #$clienteSelecionadoId',
                    error: (_, __) => clienteSelecionadoId == null
                        ? 'Selecione um cliente'
                        : 'Cliente #$clienteSelecionadoId',
                  ),
                ),
                trailing: const Icon(Icons.person_search),
                onTap: () async {
                  final result = await showModalBottomSheet<int?>(
                    context: context,
                    isScrollControlled: true,
                    builder: (ctx) => _SelecionarClienteSheet(
                      selectedId: clienteSelecionadoId,
                    ),
                  );

                  if (result != null) {
                    ref.read(vendaClienteSelecionadoIdProvider.notifier).state =
                        result;
                  }
                },
              ),
            ),
            const SizedBox(height: 12),

            Card(
              child: ListTile(
                title: const Text('Total'),
                subtitle: Text('R\$ ${_total(itens).toStringAsFixed(2)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Adicionar item',
                  onPressed: () async {
                    final item = await showModalBottomSheet<VendaItem>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const _AdicionarItemSheet(),
                    );
                    if (item != null) {
                      ref
                          .read(vendaEmAndamentoProvider.notifier)
                          .adicionarItem(item);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: itens.isEmpty
                  ? const Center(child: Text('Adicione itens para continuar.'))
                  : ListView.separated(
                      itemCount: itens.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final it = itens[i];
                        return ListTile(
                          title: Text(it.produtoNome),
                          subtitle: Text(
                            'Qtd: ${it.qtd.toStringAsFixed(2)} • Unit: R\$ ${it.precoUnit.toStringAsFixed(2)}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => ref
                                .read(vendaEmAndamentoProvider.notifier)
                                .removerItem(
                                  produtoId: it.produtoId,
                                  precoUnit: it.precoUnit,
                                ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            if (clienteSelecionadoId == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Selecione um cliente para finalizar a venda.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ),
            AppGradientButton(
              label: 'Finalizar venda',
              trailingIcon: Icons.arrow_forward,
              onPressed: (itens.isEmpty || clienteSelecionadoId == null)
                  ? null
                  : () async {
                      final repo = ref.read(vendasRepositoryProvider);

                      final cid = ref.read(vendaClienteSelecionadoIdProvider);
                      await repo.finalizarVenda(clienteId: cid, itens: itens);

                      ref.read(vendaEmAndamentoProvider.notifier).limpar();
                      ref
                              .read(vendaClienteSelecionadoIdProvider.notifier)
                              .state =
                          null;
                      await ref.read(vendasListProvider.notifier).refresh();

                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _SelecionarClienteSheet extends ConsumerStatefulWidget {
  final int? selectedId;
  const _SelecionarClienteSheet({this.selectedId});

  @override
  ConsumerState<_SelecionarClienteSheet> createState() =>
      _SelecionarClienteSheetState();
}

class _SelecionarClienteSheetState
    extends ConsumerState<_SelecionarClienteSheet> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncClientes = ref.watch(clientesAtivosParaVendaProvider);
    final q = _searchCtrl.text.trim().toLowerCase();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Selecionar cliente',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar por nome, apelido ou telefone...',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 8),

              Expanded(
                child: asyncClientes.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text('Erro ao carregar clientes: $e')),
                  data: (clientes) {
                    final filtrados = q.isEmpty
                        ? clientes
                        : clientes.where((c) {
                            final nome = c.nome.toLowerCase();
                            final apelido = (c.apelido ?? '').toLowerCase();
                            final tel = (c.telefone ?? '').toLowerCase();
                            return nome.contains(q) ||
                                apelido.contains(q) ||
                                tel.contains(q);
                          }).toList();

                    if (filtrados.isEmpty) {
                      return const Center(
                        child: Text('Nenhum cliente encontrado.'),
                      );
                    }

                    return ListView.separated(
                      itemCount: filtrados.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final c = filtrados[i];
                        final id = c.id;
                        final apelido = (c.apelido ?? '').trim();
                        final subtitleParts = <String>[];
                        if (apelido.isNotEmpty) subtitleParts.add(apelido);
                        if ((c.telefone ?? '').trim().isNotEmpty) {
                          subtitleParts.add(c.telefone!.trim());
                        }
                        return ListTile(
                          leading: Radio<int?>(
                            value: id,
                            groupValue: widget.selectedId,
                            onChanged: id == null
                                ? null
                                : (_) => Navigator.of(context).pop(id),
                          ),
                          title: Text(c.nome),
                          subtitle: subtitleParts.isEmpty
                              ? null
                              : Text(subtitleParts.join(' • ')),
                          onTap: id == null
                              ? null
                              : () => Navigator.of(context).pop(id),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdicionarItemSheet extends ConsumerStatefulWidget {
  const _AdicionarItemSheet();

  @override
  ConsumerState<_AdicionarItemSheet> createState() =>
      _AdicionarItemSheetState();
}

class _AdicionarItemSheetState extends ConsumerState<_AdicionarItemSheet> {
  int? _produtoId;

  final _buscaCtrl = TextEditingController();
  final _qtdCtrl = TextEditingController(text: '1');
  final _precoCtrl = TextEditingController();

  bool _somenteComSaldo = true;
  bool _carregando = true;
  String? _erro;
  List<Produto> _produtos = const [];

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _carregarProdutos();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _buscaCtrl.dispose();
    _qtdCtrl.dispose();
    _precoCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarProdutos() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final repo = ref.read(vendasRepositoryProvider);
      final list = await repo.listarProdutosAtivos(
        somenteComSaldo: _somenteComSaldo,
        search: _buscaCtrl.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _produtos = list;
        _carregando = false;
      });

      // Se o produto selecionado não existir mais após filtrar, limpa seleção.
      if (_produtoId != null && !_produtos.any((p) => p.id == _produtoId)) {
        setState(() {
          _produtoId = null;
          _precoCtrl.clear();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.toString();
        _carregando = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _carregarProdutos);
  }

  Future<void> _onToggleSomenteSaldo(bool? v) async {
    final novo = v ?? true;
    if (novo == _somenteComSaldo) return;

    setState(() {
      _somenteComSaldo = novo;

      // Se o usuário estava com um produto "sem saldo" selecionado e voltou
      // para "somente com saldo", limpamos para evitar inconsistência.
      _produtoId = null;
      _precoCtrl.clear();
    });

    await _carregarProdutos();
  }

  double _parsePtBrNumber(String text) {
    // Aceita:
    //  - 10
    //  - 10,5
    //  - 1.234,56
    //  - 1234.56
    final t = text.trim();
    if (t.isEmpty) return 0;

    final hasComma = t.contains(',');
    final hasDot = t.contains('.');

    if (hasComma && hasDot) {
      // Assume dot milhar e comma decimal: 1.234,56
      final noThousands = t.replaceAll('.', '');
      return double.parse(noThousands.replaceAll(',', '.'));
    }
    if (hasComma) return double.parse(t.replaceAll(',', '.'));
    return double.parse(t);
  }

  @override
  Widget build(BuildContext context) {
    // Ajusta layout quando teclado abre (quantidade/preço)
    final keyboardBottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardBottom),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Adicionar item',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _somenteComSaldo,
                          onChanged: _onToggleSomenteSaldo,
                        ),
                        const Expanded(
                          child: Text('Mostrar somente produtos com saldo'),
                        ),
                        IconButton(
                          tooltip: 'Recarregar',
                          onPressed: _carregarProdutos,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _buscaCtrl,
                      onChanged: (v) {
                        setState(() {});
                        _onSearchChanged(v);
                      },
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        labelText: 'Buscar produto',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _buscaCtrl.text.trim().isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _buscaCtrl.clear();
                                  _onSearchChanged('');
                                  setState(() {}); // atualiza suffixIcon
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Expanded(child: _buildListaProdutos(context)),

                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _qtdCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Quantidade',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _precoCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Preço unitário',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16 + MediaQuery.of(context).padding.bottom,
              ),
              child: AppGradientButton(
                label: 'Adicionar',
                trailingIcon: Icons.arrow_forward,
                onPressed: () {
                  if (_produtoId == null) return;

                  final matches = _produtos
                      .where((p) => p.id == _produtoId)
                      .toList();

                  if (matches.isEmpty) {
                    // Protege contra o caso do produto “sumir” após trocar filtros.
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'O produto selecionado não está disponível com o filtro atual.',
                        ),
                      ),
                    );
                    setState(() {
                      _produtoId = null;
                      _precoCtrl.clear();
                    });
                    return;
                  }

                  final produto = matches.first;

                  final qtd = _parsePtBrNumber(_qtdCtrl.text);
                  final preco = _parsePtBrNumber(_precoCtrl.text);

                  final item = VendaItem(
                    produtoId: produto.id!,
                    produtoNome: produto.nome,
                    qtd: qtd <= 0 ? 1 : qtd,
                    precoUnit: preco <= 0 ? produto.precoVenda : preco,
                  );

                  Navigator.of(context).pop(item);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaProdutos(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_erro != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Erro ao carregar produtos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _erro!,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _carregarProdutos,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_produtos.isEmpty) {
      return const Center(child: Text('Nenhum produto encontrado.'));
    }

    return ListView.separated(
      itemCount: _produtos.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final p = _produtos[index];
        final selected = p.id == _produtoId;

        final ref = (p.refCodigo ?? '').trim();
        final estoque = p.estoque.toStringAsFixed(2);
        final precoVenda = p.precoVenda.toStringAsFixed(2);

        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            selected ? Icons.check_circle : Icons.circle_outlined,
            size: 20,
          ),
          title: Text(p.nome, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${ref.isEmpty ? '' : 'Ref: $ref  •  '}Est: $estoque',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            precoVenda,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () {
            setState(() => _produtoId = p.id);
            _precoCtrl.text = p.precoVenda.toStringAsFixed(2);
          },
        );
      },
    );
  }
}
