import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_page.dart';
import '../../../app/ui/app_colors.dart';
import '../../financeiro/contas_pagar/data/conta_pagar_model.dart';
import '../controller/relatorios_controller.dart';
import '../data/relatorio_models.dart';
import 'relatorio_widgets.dart';

class RelatorioContasPagarScreen extends ConsumerStatefulWidget {
  const RelatorioContasPagarScreen({super.key});

  @override
  ConsumerState<RelatorioContasPagarScreen> createState() =>
      _RelatorioContasPagarScreenState();
}

class _RelatorioContasPagarScreenState
    extends ConsumerState<RelatorioContasPagarScreen> {
  late DateTime _inicio;
  late DateTime _fim;
  String? _status;
  int? _fornecedorId;
  Future<RelatorioContasPagarResumo>? _future;
  Future<List<ContaPagar>>? _docsFuture;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fim = now;
    _inicio = now.subtract(const Duration(days: 30));
    _carregar();
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  Future<void> _carregar() async {
    final repo = ref.read(relatoriosRepositoryProvider);
    final inicio = _startOfDay(_inicio);
    final fim = _endOfDay(_fim);
    setState(() {
      _future = repo.contasPagarResumo(
        inicio: inicio,
        fim: fim,
        status: _status,
        fornecedorId: _fornecedorId,
      );
      _docsFuture = repo.contasPagarDocumentos(
        inicio: inicio,
        fim: fim,
        status: _status,
        fornecedorId: _fornecedorId,
      );
    });
  }

  Future<void> _pickInicio() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _inicio,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 1, 1),
    );
    if (picked == null) return;
    setState(() => _inicio = picked);
    await _carregar();
  }

  Future<void> _pickFim() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fim,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 1, 1),
    );
    if (picked == null) return;
    setState(() => _fim = picked);
    await _carregar();
  }

  String _statusLabel(ContaPagar conta) {
    if (conta.isVencida) return 'Vencida';
    return ContaPagarStatus.label(conta.status);
  }

  Color _statusColor(ContaPagar conta) {
    if (conta.status == ContaPagarStatus.paga) return AppColors.success;
    if (conta.status == ContaPagarStatus.cancelada) return AppColors.textMuted;
    if (conta.isVencida) return AppColors.danger;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final fornecedoresAsync = ref.watch(relatorioFornecedoresProvider);

    return AppPage(
      title: 'Relatorio - Contas a pagar',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const RelatorioSectionTitle('Periodo'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: RelatorioDateField(
                  label: 'Inicio',
                  value: _inicio,
                  onTap: _pickInicio,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RelatorioDateField(
                  label: 'Fim',
                  value: _fim,
                  onTap: _pickFim,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const RelatorioSectionTitle('Filtros'),
          const SizedBox(height: 10),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                isExpanded: true,
                value: _status,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todos'),
                  ),
                  ...ContaPagarStatus.filtros.map(
                    (s) => DropdownMenuItem<String?>(
                      value: s,
                      child: Text(ContaPagarStatus.label(s)),
                    ),
                  ),
                ],
                onChanged: (v) async {
                  setState(() => _status = v);
                  await _carregar();
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          fornecedoresAsync.when(
            data: (list) {
              return InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fornecedor',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    isExpanded: true,
                    value: _fornecedorId,
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Todos'),
                      ),
                      ...list.map(
                        (f) => DropdownMenuItem<int?>(
                          value: f.id,
                          child: Text(f.nome),
                        ),
                      ),
                    ],
                    onChanged: (v) async {
                      setState(() => _fornecedorId = v);
                      await _carregar();
                    },
                  ),
                ),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Erro ao carregar fornecedores: $e'),
          ),
          const SizedBox(height: 16),
          const RelatorioSectionTitle('Totalizadores'),
          const SizedBox(height: 12),
          FutureBuilder<RelatorioContasPagarResumo>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('Erro ao carregar relatorio: ${snapshot.error}');
              }
              final r = snapshot.data;
              if (r == null) {
                return const Text('Sem dados para o periodo informado.');
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: RelatorioKpiCard(
                          title: 'Aberto',
                          value: fmtMoney(r.totalAberto),
                          subtitle: '${r.qtdAberta} lancamentos',
                          icon: Icons.pending_actions_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RelatorioKpiCard(
                          title: 'Pago',
                          value: fmtMoney(r.totalPago),
                          subtitle: '${r.qtdPaga} lancamentos',
                          icon: Icons.check_circle_outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: RelatorioKpiCard(
                          title: 'Vencido',
                          value: fmtMoney(r.totalVencido),
                          subtitle: '${r.qtdVencida} lancamentos',
                          icon: Icons.warning_amber_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RelatorioKpiCard(
                          title: 'Vencendo 7d',
                          value: fmtMoney(r.totalVencendo),
                          subtitle: '${r.qtdVencendo} lancamentos',
                          icon: Icons.schedule_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: RelatorioKpiCard(
                          title: 'Cancelado',
                          value: fmtMoney(r.totalCancelado),
                          subtitle: '${r.qtdCancelada} lancamentos',
                          icon: Icons.remove_circle_outline,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          const RelatorioSectionTitle('Documentos'),
          const SizedBox(height: 10),
          FutureBuilder<List<ContaPagar>>(
            future: _docsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('Erro ao carregar documentos: ${snapshot.error}');
              }
              final docs = snapshot.data ?? const [];
              if (docs.isEmpty) {
                return const Text('Nenhum documento encontrado.');
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final conta = docs[i];
                  final parts = <String>[
                    'Parcela ${conta.parcelaNumero}/${conta.parcelasTotal}',
                    'Total ${fmtMoney(conta.total)}',
                  ];
                  if (conta.descricao != null &&
                      conta.descricao!.trim().isNotEmpty) {
                    parts.add(conta.descricao!.trim());
                  }
                  if (conta.vencimentoAt != null) {
                    parts.add('Venc: ${fmtDate(conta.vencimentoAt!)}');
                  }

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      children: [
                        Expanded(child: Text(conta.fornecedorNome)),
                        Text(
                          fmtMoney(conta.valor),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(parts.join(' - ')),
                        const SizedBox(height: 2),
                        Text(
                          'Status: ${_statusLabel(conta)}',
                          style: TextStyle(
                            color: _statusColor(conta),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (conta.pagoAt != null) ...[
                          const SizedBox(height: 2),
                          Text('Pago em: ${fmtDate(conta.pagoAt!)}'),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
