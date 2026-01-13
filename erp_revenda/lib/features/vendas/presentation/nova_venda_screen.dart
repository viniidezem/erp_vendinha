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

    return AppPage(
      title: 'Nova venda',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
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
                                .removerItem(it.produtoId),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            AppGradientButton(
              label: 'Finalizar venda',
              trailingIcon: Icons.arrow_forward,
              onPressed: itens.isEmpty
                  ? null
                  : () async {
                      final repo = ref.read(vendasRepositoryProvider);

                      await repo.finalizarVenda(clienteId: null, itens: itens);

                      ref.read(vendaEmAndamentoProvider.notifier).limpar();
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

class _AdicionarItemSheet extends ConsumerStatefulWidget {
  const _AdicionarItemSheet();

  @override
  ConsumerState<_AdicionarItemSheet> createState() =>
      _AdicionarItemSheetState();
}

class _AdicionarItemSheetState extends ConsumerState<_AdicionarItemSheet> {
  int? _produtoId;
  final _qtdCtrl = TextEditingController(text: '1');
  final _precoCtrl = TextEditingController();

  @override
  void dispose() {
    _qtdCtrl.dispose();
    _precoCtrl.dispose();
    super.dispose();
  }

  double _parsePtBrNumber(String s) {
    final t = s.trim();
    if (t.isEmpty) throw FormatException('Número vazio');

    if (t.contains(',') && t.contains('.')) {
      final noThousands = t.replaceAll('.', '');
      return double.parse(noThousands.replaceAll(',', '.'));
    }
    if (t.contains(',')) return double.parse(t.replaceAll(',', '.'));
    return double.parse(t);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(vendasRepositoryProvider);

    return SafeArea(
      top: false, // importante para não “cortar” no topo
      child: FutureBuilder<List<Produto>>(
        future: repo.listarProdutosAtivos(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const SizedBox(
              height: 280,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final produtos = snap.data!;

          if (_produtoId != null && !produtos.any((p) => p.id == _produtoId)) {
            _produtoId = null;
          }

          // Altura alvo do sheet: 60% da tela (ajuda a caber o botão)
          final height = MediaQuery.of(context).size.height * 0.60;
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;

          return SizedBox(
            height: height + bottomInset, // cresce quando teclado abre
            child: Column(
              children: [
                const SizedBox(height: 10),
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

                // Conteúdo rolável
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        DropdownButtonFormField<int>(
                          // value: _produtoId,
                          items: produtos.map((p) {
                            return DropdownMenuItem<int>(
                              value: p.id!,
                              child: Text(
                                '${p.nome} (Est: ${p.estoque.toStringAsFixed(2)})',
                              ),
                            );
                          }).toList(),
                          onChanged: (id) {
                            setState(() => _produtoId = id);

                            final p = produtos.firstWhere((x) => x.id == id);
                            _precoCtrl.text = p.precoVenda.toStringAsFixed(2);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Produto',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _qtdCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
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
                                keyboardType:
                                    const TextInputType.numberWithOptions(
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

                // Botão fixo sempre visível
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    16 +
                        MediaQuery.of(
                          context,
                        ).padding.bottom, // safe area inferior real
                  ),
                  child: AppGradientButton(
                    label: 'Adicionar',
                    trailingIcon: Icons.arrow_forward,
                    onPressed: () {
                      if (_produtoId == null) return;

                      final produto = produtos.firstWhere(
                        (p) => p.id == _produtoId,
                      );

                      final qtd = _parsePtBrNumber(_qtdCtrl.text);
                      final preco = _parsePtBrNumber(_precoCtrl.text);

                      final item = VendaItem(
                        produtoId: produto.id!,
                        produtoNome: produto.nome,
                        qtd: qtd,
                        precoUnit: preco,
                      );

                      Navigator.of(context).pop(item);
                    },
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
