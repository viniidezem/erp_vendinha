import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_page.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../controller/produtos_controller.dart';
import '../data/produto_model.dart';

class ProdutoFormScreen extends ConsumerStatefulWidget {
  final Produto? produto;

  const ProdutoFormScreen({super.key, this.produto});

  @override
  ConsumerState<ProdutoFormScreen> createState() => _ProdutoFormScreenState();
}

class _ProdutoFormScreenState extends ConsumerState<ProdutoFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nomeCtrl;
  late final TextEditingController _precoCtrl;
  late final TextEditingController _estoqueCtrl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController(text: widget.produto?.nome ?? '');
    _precoCtrl = TextEditingController(
      text: widget.produto != null
          ? widget.produto!.precoVenda.toStringAsFixed(2)
          : '',
    );
    _estoqueCtrl = TextEditingController(
      text: widget.produto != null
          ? widget.produto!.estoque.toStringAsFixed(2)
          : '0',
    );
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _precoCtrl.dispose();
    _estoqueCtrl.dispose();
    super.dispose();
  }

  double _parsePtBrNumber(String s) {
    final t = s.trim();
    if (t.isEmpty) throw FormatException('Número vazio');

    // Se tiver vírgula e ponto, assumimos pt-BR: ponto milhar e vírgula decimal.
    if (t.contains(',') && t.contains('.')) {
      final noThousands = t.replaceAll('.', '');
      return double.parse(noThousands.replaceAll(',', '.'));
    }

    // Se tiver só vírgula: decimal pt-BR
    if (t.contains(',')) {
      return double.parse(t.replaceAll(',', '.'));
    }

    // Se tiver só ponto: decimal padrão
    return double.parse(t);
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final nome = _nomeCtrl.text.trim();
    final preco = _parsePtBrNumber(_precoCtrl.text);
    final estoque = _parsePtBrNumber(_estoqueCtrl.text);

    final notifier = ref.read(produtosControllerProvider.notifier);

    try {
      if (widget.produto == null) {
        await notifier.adicionar(
          nome: nome,
          precoVenda: preco,
          estoqueInicial: estoque,
        );
      } else {
        final atualizado = widget.produto!.copyWith(
          nome: nome,
          precoVenda: preco,
          estoque: estoque,
        );
        await notifier.editar(atualizado);
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.produto != null;

    return AppPage(
      title: editando ? 'Editar produto' : 'Novo produto',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nomeCtrl,
                decoration: const InputDecoration(labelText: 'Nome'),
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe o nome';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _precoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Preço de venda',
                  hintText: 'Ex: 10,50',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe o preço';
                  try {
                    _parsePtBrNumber(v);
                    return null;
                  } catch (_) {
                    return 'Preço inválido';
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _estoqueCtrl,
                decoration: const InputDecoration(
                  labelText: 'Estoque',
                  hintText: 'Ex: 5 ou 2,5',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                textInputAction: TextInputAction.done,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe o estoque';
                  try {
                    _parsePtBrNumber(v);
                    return null;
                  } catch (_) {
                    return 'Estoque inválido';
                  }
                },
              ),
              const SizedBox(height: 16),
              AppGradientButton(
                label: _saving ? 'Salvando...' : 'Salvar',
                trailingIcon: _saving ? null : Icons.arrow_forward,
                onPressed: _saving ? null : _salvar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
