import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/number_parser.dart';
import '../../../shared/widgets/app_decimal_field.dart';
import '../../../shared/widgets/app_error_dialog.dart';
import '../../../shared/widgets/app_page.dart';
import '../../financeiro/contas_pagar/controller/contas_pagar_controller.dart';
import '../controller/entradas_controller.dart';
import '../data/entrada_models.dart';

class EntradaContasPagarScreen extends ConsumerStatefulWidget {
  final int entradaId;
  const EntradaContasPagarScreen({super.key, required this.entradaId});

  @override
  ConsumerState<EntradaContasPagarScreen> createState() =>
      _EntradaContasPagarScreenState();
}

class _EntradaContasPagarScreenState
    extends ConsumerState<EntradaContasPagarScreen> {
  final _totalCtrl = TextEditingController(text: '0.00');
  int _parcelas = 1;
  List<DateTime?> _vencimentos = <DateTime?>[];
  bool _init = false;

  @override
  void initState() {
    super.initState();
    _syncVencimentos(_parcelas);
  }

  @override
  void dispose() {
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

  Future<void> _gerarContas(Entrada entrada) async {
    final total = _parseTotal();
    if (total <= 0) {
      await showErrorDialog(context, 'Informe o valor total.');
      return;
    }

    try {
      await ref.read(contasPagarControllerProvider.notifier).criarLancamento(
            entradaId: entrada.id,
            fornecedorId: entrada.fornecedorId,
            total: total,
            parcelas: _parcelas,
            descricao: entrada.numeroNota == null
                ? 'Entrada #${entrada.id}'
                : 'Entrada ${entrada.numeroNota}',
            vencimentos: _vencimentos,
          );
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(context, 'Erro ao gerar contas a pagar:\n$e');
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contas a pagar geradas.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final detalheAsync = ref.watch(entradaDetalheProvider(widget.entradaId));
    final total = _parseTotal();
    final parcelasValores = _parcelasValores(total, _parcelas);

    return AppPage(
      title: 'Gerar contas a pagar',
      child: detalheAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Erro ao carregar entrada: $e'),
        ),
        data: (detalhe) {
          final entrada = detalhe.entrada;

          if (!_init) {
            _totalCtrl.text = entrada.totalNota.toStringAsFixed(2);
            _init = true;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entrada.fornecedorNome ?? 'Fornecedor',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        entrada.numeroNota == null
                            ? 'Entrada #${entrada.id}'
                            : 'Nota ${entrada.numeroNota}',
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
                        'Valores',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      AppDecimalField(
                        controller: _totalCtrl,
                        labelText: 'Valor total (R\$)',
                        onChanged: (_) => setState(() {}),
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
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: entrada.status == EntradaStatus.confirmada
                    ? () => _gerarContas(entrada)
                    : null,
                icon: const Icon(Icons.check_circle_outline),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Gerar contas a pagar'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
