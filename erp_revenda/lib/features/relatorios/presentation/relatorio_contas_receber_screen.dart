import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_page.dart';
import '../../../app/ui/app_colors.dart';
import '../../financeiro/contas_receber/data/conta_receber_model.dart';
import '../controller/relatorios_controller.dart';
import '../data/relatorio_models.dart';
import 'relatorio_widgets.dart';

class RelatorioContasReceberArgs {
  final bool somentePrestesVencer;

  const RelatorioContasReceberArgs({this.somentePrestesVencer = false});
}

class RelatorioContasReceberScreen extends ConsumerStatefulWidget {
  final RelatorioContasReceberArgs args;

  const RelatorioContasReceberScreen({
    super.key,
    this.args = const RelatorioContasReceberArgs(),
  });

  @override
  ConsumerState<RelatorioContasReceberScreen> createState() =>
      _RelatorioContasReceberScreenState();
}

class _RelatorioContasReceberScreenState
    extends ConsumerState<RelatorioContasReceberScreen> {
  late DateTime _inicio;
  late DateTime _fim;
  String? _status;
  int? _clienteId;
  Future<RelatorioContasReceberResumo>? _future;
  Future<List<ContaReceber>>? _docsFuture;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    if (widget.args.somentePrestesVencer) {
      _inicio = now;
      _fim = now.add(const Duration(days: 7));
      _status = ContaReceberStatus.aberta;
    } else {
      _fim = now;
      _inicio = now.subtract(const Duration(days: 30));
    }
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
      _future = repo.contasReceberResumo(
        inicio: inicio,
        fim: fim,
        status: _status,
        clienteId: _clienteId,
      );
      _docsFuture = repo.contasReceberDocumentos(
        inicio: inicio,
        fim: fim,
        status: _status,
        clienteId: _clienteId,
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

  String _statusLabel(ContaReceber conta) {
    if (conta.isVencida) return 'Vencida';
    return ContaReceberStatus.label(conta.status);
  }

  Color _statusColor(ContaReceber conta) {
    if (conta.status == ContaReceberStatus.recebida) {
      return AppColors.success;
    }
    if (conta.status == ContaReceberStatus.cancelada) {
      return AppColors.textMuted;
    }
    if (conta.isVencida) return AppColors.danger;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final clientesAsync = ref.watch(relatorioClientesProvider);

    return AppPage(
      title: 'Relatorio - Contas a receber',
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
                  ...ContaReceberStatus.filtros.map(
                    (s) => DropdownMenuItem<String?>(
                      value: s,
                      child: Text(ContaReceberStatus.label(s)),
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
          clientesAsync.when(
            data: (list) {
              return InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Cliente',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    isExpanded: true,
                    value: _clienteId,
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Todos'),
                      ),
                      ...list.map(
                        (c) => DropdownMenuItem<int?>(
                          value: c.id,
                          child: Text(c.nome),
                        ),
                      ),
                    ],
                    onChanged: (v) async {
                      setState(() => _clienteId = v);
                      await _carregar();
                    },
                  ),
                ),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Erro ao carregar clientes: $e'),
          ),
          const SizedBox(height: 16),
          const RelatorioSectionTitle('Totalizadores'),
          const SizedBox(height: 12),
          FutureBuilder<RelatorioContasReceberResumo>(
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
                          subtitle: '${r.qtdAberta} parcelas',
                          icon: Icons.pending_actions_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RelatorioKpiCard(
                          title: 'Recebido',
                          value: fmtMoney(r.totalRecebido),
                          subtitle: '${r.qtdRecebida} parcelas',
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
                          subtitle: '${r.qtdVencida} parcelas',
                          icon: Icons.warning_amber_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RelatorioKpiCard(
                          title: 'Vencendo 7d',
                          value: fmtMoney(r.totalVencendo),
                          subtitle: '${r.qtdVencendo} parcelas',
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
                          subtitle: '${r.qtdCancelada} parcelas',
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
          FutureBuilder<List<ContaReceber>>(
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
                    'Pedido #${conta.vendaId}',
                    'Parcela ${conta.parcelaNumero}/${conta.parcelasTotal}',
                  ];
                  if (conta.vencimentoAt != null) {
                    parts.add('Venc: ${fmtDate(conta.vencimentoAt!)}');
                  }

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            conta.clienteNome ?? 'Cliente nao informado',
                          ),
                        ),
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
