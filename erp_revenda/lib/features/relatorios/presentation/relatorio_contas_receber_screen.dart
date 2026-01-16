import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_page.dart';
import '../../../app/ui/app_colors.dart';
import '../../financeiro/contas_receber/data/conta_receber_model.dart';
import '../controller/relatorios_controller.dart';
import '../data/relatorio_models.dart';
import 'relatorio_exporter.dart';
import 'relatorio_widgets.dart';
import '../../settings/controller/app_preferences_controller.dart';

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
  static const _kInicio = 'relatorio_contas_receber_inicio';
  static const _kFim = 'relatorio_contas_receber_fim';
  static const _kStatus = 'relatorio_contas_receber_status';
  static const _kCliente = 'relatorio_contas_receber_cliente';
  static const _kPeriodoRapido = 'relatorio_contas_receber_periodo_rapido';

  late DateTime _inicio;
  late DateTime _fim;
  String? _status;
  int? _clienteId;
  String? _periodoRapido;
  Future<RelatorioContasReceberResumo>? _future;
  Future<List<ContaReceber>>? _docsFuture;

  @override
  void initState() {
    super.initState();
    _setDefaults();
    if (widget.args.somentePrestesVencer) {
      _carregar();
    } else {
      _loadFiltrosSalvos();
    }
  }

  void _setDefaults() {
    final now = DateTime.now();
    if (widget.args.somentePrestesVencer) {
      _inicio = now;
      _fim = now.add(const Duration(days: 7));
      _status = ContaReceberStatus.aberta;
      _periodoRapido = null;
      _clienteId = null;
      return;
    }
    _fim = now;
    _inicio = now.subtract(const Duration(days: 30));
    _status = null;
    _clienteId = null;
    _periodoRapido = RelatorioPeriodoRapido.ultimos30Dias;
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  Future<void> _loadFiltrosSalvos() async {
    final repo = ref.read(appPreferencesRepositoryProvider);
    final inicioRaw = await repo.getValue(_kInicio);
    final fimRaw = await repo.getValue(_kFim);
    final statusRaw = await repo.getValue(_kStatus);
    final clienteRaw = await repo.getValue(_kCliente);
    final periodoRaw = await repo.getValue(_kPeriodoRapido);

    final inicioMs = int.tryParse(inicioRaw ?? '');
    final fimMs = int.tryParse(fimRaw ?? '');
    final clienteId = int.tryParse(clienteRaw ?? '');

    if (inicioMs != null) {
      _inicio = DateTime.fromMillisecondsSinceEpoch(inicioMs);
    }
    if (fimMs != null) {
      _fim = DateTime.fromMillisecondsSinceEpoch(fimMs);
    }
    _status = (statusRaw ?? '').trim().isEmpty ? null : statusRaw;
    _clienteId = clienteId;
    _periodoRapido =
        (periodoRaw ?? '').trim().isEmpty ? _periodoRapido : periodoRaw;

    if (!mounted) return;
    setState(() {});
    await _carregar();
  }

  Future<void> _persistFiltros() async {
    if (widget.args.somentePrestesVencer) return;
    final repo = ref.read(appPreferencesRepositoryProvider);
    await repo.setValue(_kInicio, _inicio.millisecondsSinceEpoch.toString());
    await repo.setValue(_kFim, _fim.millisecondsSinceEpoch.toString());

    if (_status == null || _status!.trim().isEmpty) {
      await repo.removeValue(_kStatus);
    } else {
      await repo.setValue(_kStatus, _status!);
    }

    if (_clienteId == null) {
      await repo.removeValue(_kCliente);
    } else {
      await repo.setValue(_kCliente, _clienteId.toString());
    }

    if (_periodoRapido == null || _periodoRapido!.trim().isEmpty) {
      await repo.removeValue(_kPeriodoRapido);
    } else {
      await repo.setValue(_kPeriodoRapido, _periodoRapido!);
    }
  }

  Future<void> _limparFiltros() async {
    _setDefaults();
    if (!mounted) return;
    setState(() {});
    final repo = ref.read(appPreferencesRepositoryProvider);
    await repo.removeValue(_kInicio);
    await repo.removeValue(_kFim);
    await repo.removeValue(_kStatus);
    await repo.removeValue(_kCliente);
    await repo.removeValue(_kPeriodoRapido);
    await _carregar();
  }

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
    await _persistFiltros();
  }

  Future<void> _exportRelatorio() async {
    final repo = ref.read(relatoriosRepositoryProvider);
    final inicio = _startOfDay(_inicio);
    final fim = _endOfDay(_fim);
    final resumo = await repo.contasReceberResumo(
      inicio: inicio,
      fim: fim,
      status: _status,
      clienteId: _clienteId,
    );
    final docs = await repo.contasReceberDocumentos(
      inicio: inicio,
      fim: fim,
      status: _status,
      clienteId: _clienteId,
    );
    if (!mounted) return;

    final sections = [
      RelatorioExportSection(
        title: 'Totalizadores',
        headers: const ['Indicador', 'Valor', 'Quantidade'],
        rows: [
          ['Aberto', fmtMoney(resumo.totalAberto), resumo.qtdAberta.toString()],
          [
            'Recebido',
            fmtMoney(resumo.totalRecebido),
            resumo.qtdRecebida.toString(),
          ],
          [
            'Cancelado',
            fmtMoney(resumo.totalCancelado),
            resumo.qtdCancelada.toString(),
          ],
          ['Vencido', fmtMoney(resumo.totalVencido), resumo.qtdVencida.toString()],
          [
            'Vencendo 7d',
            fmtMoney(resumo.totalVencendo),
            resumo.qtdVencendo.toString(),
          ],
        ],
      ),
      RelatorioExportSection(
        title: 'Documentos',
        headers: const [
          'Cliente',
          'Parcela',
          'Valor',
          'Recebido',
          'Status',
          'Vencimento',
        ],
        rows: docs
            .map(
              (conta) => [
                conta.clienteNome ?? 'Cliente',
                '${conta.parcelaNumero}/${conta.parcelasTotal}',
                fmtMoney(conta.valor),
                fmtMoney(conta.valorRecebido),
                _statusLabel(conta),
                conta.vencimentoAt == null ? '-' : fmtDate(conta.vencimentoAt!),
              ],
            )
            .toList(),
      ),
    ];

    await RelatorioExporter.export(
      context,
      title: 'Relatorio - Contas a receber',
      fileBaseName: 'relatorio_contas_receber',
      sections: sections,
    );
  }

  Future<void> _pickInicio() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _inicio,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 1, 1),
    );
    if (picked == null) return;
    setState(() {
      _inicio = picked;
      _periodoRapido = null;
    });
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
    setState(() {
      _fim = picked;
      _periodoRapido = null;
    });
    await _carregar();
  }

  Future<void> _aplicarPeriodoRapido(String periodo) async {
    final now = DateTime.now();
    setState(() {
      _periodoRapido = periodo;
      switch (periodo) {
        case RelatorioPeriodoRapido.hoje:
          _inicio = now;
          _fim = now;
          break;
        case RelatorioPeriodoRapido.ultimos7Dias:
          _inicio = now.subtract(const Duration(days: 6));
          _fim = now;
          break;
        case RelatorioPeriodoRapido.ultimos30Dias:
        default:
          _inicio = now.subtract(const Duration(days: 29));
          _fim = now;
          break;
      }
    });
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
      actions: [
        IconButton(
          onPressed: _exportRelatorio,
          icon: const Icon(Icons.download_outlined, color: Colors.white),
        ),
      ],
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
          const SizedBox(height: 10),
          RelatorioQuickPeriodChips(
            value: _periodoRapido,
            onChanged: _aplicarPeriodoRapido,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const RelatorioSectionTitle('Filtros'),
              if (!widget.args.somentePrestesVencer)
                TextButton(
                  onPressed: _limparFiltros,
                  child: const Text('Limpar filtros'),
                ),
            ],
          ),
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
