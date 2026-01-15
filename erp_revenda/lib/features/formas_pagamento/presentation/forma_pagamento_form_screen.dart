import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_error_dialog.dart';
import '../../../shared/widgets/app_page.dart';
import '../controller/formas_pagamento_controller.dart';
import '../data/forma_pagamento_model.dart';

class FormaPagamentoFormScreen extends ConsumerStatefulWidget {
  final FormaPagamento? forma;
  const FormaPagamentoFormScreen({super.key, this.forma});

  @override
  ConsumerState<FormaPagamentoFormScreen> createState() => _FormaPagamentoFormScreenState();
}

class _FormaPagamentoFormScreenState extends ConsumerState<FormaPagamentoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeCtrl;
  final _maxParcelasCtrl = TextEditingController();

  bool _permiteDesconto = false;
  bool _permiteParcelamento = false;
  bool _permiteInformarVencimento = false;
  bool _ativo = true;

  @override
  void initState() {
    super.initState();
    final f = widget.forma;
    _nomeCtrl = TextEditingController(text: f?.nome ?? '');
    _permiteDesconto = f?.permiteDesconto ?? false;
    _permiteParcelamento = f?.permiteParcelamento ?? false;
    _permiteInformarVencimento = f?.permiteInformarVencimento ?? false;
    _ativo = f?.ativo ?? true;
    if (f != null) {
      _maxParcelasCtrl.text = '${f.maxParcelas}';
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _maxParcelasCtrl.dispose();
    super.dispose();
  }

  int? _parseMaxParcelas() {
    final t = _maxParcelasCtrl.text.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  Future<void> _salvar() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final now = DateTime.now();
    final max = _permiteParcelamento ? (_parseMaxParcelas() ?? 1) : 1;

    final base = widget.forma;
    final fp = (base ?? FormaPagamento(
      nome: '',
      permiteDesconto: false,
      permiteParcelamento: false,
      permiteInformarVencimento: false,
      maxParcelas: 1,
      ativo: true,
      createdAt: now,
    ))
        .copyWith(
      nome: _nomeCtrl.text.trim(),
      permiteDesconto: _permiteDesconto,
      permiteParcelamento: _permiteParcelamento,
      permiteInformarVencimento: _permiteInformarVencimento,
      maxParcelas: max,
      ativo: _ativo,
      // se for edição, mantém createdAt
      createdAt: base?.createdAt ?? now,
    );

    try {
      await ref.read(formasPagamentoControllerProvider.notifier).salvar(fp);
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) {
        await showErrorDialog(context, 'Erro ao salvar forma de pagamento:\n$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.forma != null;

    return AppPage(
      title: isEdit ? 'Editar forma' : 'Nova forma',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nomeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe o nome';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Permite desconto'),
                value: _permiteDesconto,
                onChanged: (v) => setState(() => _permiteDesconto = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Permite parcelamento'),
                value: _permiteParcelamento,
                onChanged: (v) {
                  setState(() {
                    _permiteParcelamento = v;
                    if (!v) {
                      _maxParcelasCtrl.text = '1';
                    }
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Permitir informar data de vencimento'),
                value: _permiteInformarVencimento,
                onChanged: (v) => setState(() => _permiteInformarVencimento = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ativa'),
                value: _ativo,
                onChanged: (v) => setState(() => _ativo = v),
              ),
              if (_permiteParcelamento) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _maxParcelasCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Máximo de parcelas',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (!_permiteParcelamento) return null;
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n < 1) return 'Informe um número válido (>= 1)';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _salvar,
                  icon: const Icon(Icons.save),
                  label: const Text('Salvar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
