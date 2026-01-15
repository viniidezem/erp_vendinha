import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_error_dialog.dart';
import '../../../shared/widgets/app_page.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../controller/produtos_controller.dart';
import '../data/produto_model.dart';

class AjusteEstoqueScreen extends ConsumerStatefulWidget {
  final Produto produto;

  const AjusteEstoqueScreen({super.key, required this.produto});

  @override
  ConsumerState<AjusteEstoqueScreen> createState() =>
      _AjusteEstoqueScreenState();
}

class _AjusteEstoqueScreenState extends ConsumerState<AjusteEstoqueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _deltaCtrl = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _deltaCtrl.dispose();
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

  Future<void> _aplicar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final delta = _parsePtBrNumber(_deltaCtrl.text);

    try {
      await ref
          .read(produtosControllerProvider.notifier)
          .ajustarEstoque(id: widget.produto.id!, delta: delta);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        await showErrorDialog(context, 'Erro ao ajustar estoque:\n$e');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.produto;

    return AppPage(
      title: 'Ajuste de estoque',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.nome,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Estoque atual: ${p.estoque.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _deltaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Quantidade',
                      hintText: 'Ex: 5  |  -2  |  1,5  |  -0,5',
                      helperText:
                          'Use valor positivo para entrada e negativo para saída.',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Informe a quantidade';
                      }
                      try {
                        _parsePtBrNumber(v);
                        return null;
                      } catch (_) {
                        return 'Quantidade inválida';
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  AppGradientButton(
                    label: _saving ? 'Aplicando...' : 'Aplicar ajuste',
                    trailingIcon: _saving ? null : Icons.arrow_forward,
                    onPressed: _saving ? null : _aplicar,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
