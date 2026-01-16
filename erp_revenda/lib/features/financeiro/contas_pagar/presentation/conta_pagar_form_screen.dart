import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/number_parser.dart';
import '../../../../shared/widgets/app_decimal_field.dart';
import '../../../../shared/widgets/app_error_dialog.dart';
import '../../../../shared/widgets/app_page.dart';
import '../controller/contas_pagar_controller.dart';

class ContaPagarFormScreen extends ConsumerStatefulWidget {
  const ContaPagarFormScreen({super.key});

  @override
  ConsumerState<ContaPagarFormScreen> createState() => _ContaPagarFormScreenState();
}

class _ContaPagarFormScreenState extends ConsumerState<ContaPagarFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _descricaoCtrl = TextEditingController();
  final _totalCtrl = TextEditingController(text: '0.00');

  int? _fornecedorId;
  int _parcelas = 1;
  List<DateTime?> _vencimentos = <DateTime?>[];
  bool _submitAttempted = false;

  @override
  void initState() {
    super.initState();
    _syncVencimentos(_parcelas);
  }

  @override
  void dispose() {
    _descricaoCtrl.dispose();
    _totalCtrl.dispose();
    super.dispose();
  }

  double _parseTotal() {
    try {
      return parseFlexibleNumber(_totalCtrl.text);
    } catch (_) {
      return 0;
    }
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
    if (_vencimentos.length == count) return;

    final next = List<DateTime?>.filled(count, null);
    final limit = _vencimentos.length < count ? _vencimentos.length : count;
    for (var i = 0; i < limit; i++) {
      next[i] = _vencimentos[i];
    }
    _vencimentos = next;
  }

  String _fmtDateOnly(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year}';
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

  Future<void> _salvar() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitAttempted = true);

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if (_fornecedorId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Selecione um fornecedor.')),
      );
      return;
    }

    final total = _parseTotal();
    if (total <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Informe um valor total valido.')),
      );
      return;
    }

    try {
      await ref.read(contasPagarControllerProvider.notifier).criarLancamento(
            fornecedorId: _fornecedorId!,
            total: total,
            parcelas: _parcelas,
            descricao: _descricaoCtrl.text.trim().isEmpty
                ? null
                : _descricaoCtrl.text.trim(),
            vencimentos: _vencimentos,
          );
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(context, 'Erro ao salvar conta a pagar:\n$e');
      return;
    }

    if (!mounted) return;
    context.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Conta a pagar criada.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fornecedoresAsync = ref.watch(contasPagarFornecedoresProvider);
    final total = _parseTotal();
    final parcelasValores = _parcelasValores(total, _parcelas);

    return AppPage(
      title: 'Nova conta a pagar',
      child: Form(
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
                      error: (e, _) => Text('Erro ao carregar fornecedores: $e'),
                      data: (fornecedores) {
                        if (fornecedores.isEmpty) {
                          return const Text(
                            'Nenhum fornecedor cadastrado. Crie um fornecedor antes.',
                          );
                        }

                        return InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Fornecedor',
                            border: const OutlineInputBorder(),
                            errorText: _submitAttempted && _fornecedorId == null
                                ? 'Selecione um fornecedor.'
                                : null,
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
                                setState(() => _fornecedorId = v);
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
                      'Detalhes',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descricaoCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Descricao (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppDecimalField(
                      controller: _totalCtrl,
                      labelText: 'Valor total (R\$)',
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        final parsed = _parseTotal();
                        if (parsed <= 0) return 'Informe um valor valido.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
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
                            12,
                            (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text('${i + 1}x'),
                            ),
                          ),
                          onChanged: (v) {
                            setState(() {
                              _parcelas = v ?? 1;
                              _syncVencimentos(_parcelas);
                            });
                          },
                        ),
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
                      'Vencimentos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    for (var i = 0; i < _parcelas; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Parcela ${i + 1}: R\$ ${parcelasValores[i].toStringAsFixed(2)}',
                        ),
                        trailing: OutlinedButton(
                          onPressed: () => _selecionarVencimento(i),
                          child: Text(
                            (i < _vencimentos.length && _vencimentos[i] != null)
                                ? _fmtDateOnly(_vencimentos[i]!)
                                : 'Selecionar',
                          ),
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
                      'Resumo',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text('Total: R\$ ${total.toStringAsFixed(2)}'),
                    const SizedBox(height: 4),
                    Text('Parcelas: ${_parcelas}x'),
                    const SizedBox(height: 6),
                    for (var i = 0; i < parcelasValores.length; i++)
                      Text(
                        (i < _vencimentos.length && _vencimentos[i] != null)
                            ? 'Parcela ${i + 1}: R\$ ${parcelasValores[i].toStringAsFixed(2)} - vence ${_fmtDateOnly(_vencimentos[i]!)}'
                            : 'Parcela ${i + 1}: R\$ ${parcelasValores[i].toStringAsFixed(2)}',
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
                child: Text('Salvar conta a pagar'),
              ),
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}
