import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/ui/app_colors.dart';
import '../../../shared/widgets/app_page.dart';
import '../controller/relatorios_controller.dart';
import '../data/relatorio_models.dart';
import 'relatorio_exporter.dart';
import 'relatorio_widgets.dart';
import '../../settings/controller/app_preferences_controller.dart';

class RelatorioFluxoCaixaScreen extends ConsumerStatefulWidget {
  const RelatorioFluxoCaixaScreen({super.key});

  @override
  ConsumerState<RelatorioFluxoCaixaScreen> createState() =>
      _RelatorioFluxoCaixaScreenState();
}

class _RelatorioFluxoCaixaScreenState
    extends ConsumerState<RelatorioFluxoCaixaScreen> {
  static const _kInicio = 'relatorio_fluxo_caixa_inicio';
  static const _kFim = 'relatorio_fluxo_caixa_fim';
  static const _kPeriodoRapido = 'relatorio_fluxo_caixa_periodo_rapido';
  static const _kAgruparMes = 'relatorio_fluxo_caixa_agrupar_mes';

  late DateTime _inicio;
  late DateTime _fim;
  String? _periodoRapido;
  bool _agruparPorMes = false;
  Future<RelatorioFluxoCaixaResumo>? _future;

  @override
  void initState() {
    super.initState();
    _setDefaults();
    _loadFiltrosSalvos();
  }

  void _setDefaults() {
    final now = DateTime.now();
    _fim = now;
    _inicio = now.subtract(const Duration(days: 30));
    _periodoRapido = RelatorioPeriodoRapido.ultimos30Dias;
    _agruparPorMes = false;
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  Future<void> _loadFiltrosSalvos() async {
    final repo = ref.read(appPreferencesRepositoryProvider);
    final inicioRaw = await repo.getValue(_kInicio);
    final fimRaw = await repo.getValue(_kFim);
    final periodoRaw = await repo.getValue(_kPeriodoRapido);
    final agruparRaw = await repo.getValue(_kAgruparMes);

    final inicioMs = int.tryParse(inicioRaw ?? '');
    final fimMs = int.tryParse(fimRaw ?? '');

    if (inicioMs != null) {
      _inicio = DateTime.fromMillisecondsSinceEpoch(inicioMs);
    }
    if (fimMs != null) {
      _fim = DateTime.fromMillisecondsSinceEpoch(fimMs);
    }
    _periodoRapido =
        (periodoRaw ?? '').trim().isEmpty ? _periodoRapido : periodoRaw;
    _agruparPorMes = agruparRaw == '1';

    if (!mounted) return;
    setState(() {});
    await _carregar();
  }

  Future<void> _persistFiltros() async {
    final repo = ref.read(appPreferencesRepositoryProvider);
    await repo.setValue(_kInicio, _inicio.millisecondsSinceEpoch.toString());
    await repo.setValue(_kFim, _fim.millisecondsSinceEpoch.toString());
    await repo.setValue(_kAgruparMes, _agruparPorMes ? '1' : '0');

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
    await repo.removeValue(_kPeriodoRapido);
    await repo.removeValue(_kAgruparMes);
    await _carregar();
  }

  Future<void> _carregar() async {
    final repo = ref.read(relatoriosRepositoryProvider);
    setState(() {
      _future = repo.fluxoCaixaResumo(
        inicio: _startOfDay(_inicio),
        fim: _endOfDay(_fim),
        agruparPorMes: _agruparPorMes,
      );
    });
    await _persistFiltros();
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

  String _formatPeriodo(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    if (_agruparPorMes) {
      return '${two(dt.month)}/${dt.year}';
    }
    return fmtDate(dt);
  }

  Future<void> _exportRelatorio(RelatorioFluxoCaixaResumo resumo) async {
    final sections = [
      RelatorioExportSection(
        title: 'Totalizadores',
        headers: const ['Indicador', 'Valor'],
        rows: [
          ['Entradas', fmtMoney(resumo.totalEntradas)],
          ['Saidas', fmtMoney(resumo.totalSaidas)],
          ['Saldo', fmtMoney(resumo.saldo)],
        ],
      ),
      RelatorioExportSection(
        title: 'Movimentacao',
        headers: const ['Periodo', 'Entradas', 'Saidas', 'Saldo'],
        rows: resumo.itens
            .map(
              (item) => [
                _formatPeriodo(item.data),
                fmtMoney(item.entradas),
                fmtMoney(item.saidas),
                fmtMoney(item.saldo),
              ],
            )
            .toList(),
      ),
    ];

    await RelatorioExporter.export(
      context,
      title: 'Relatorio - Fluxo de caixa',
      fileBaseName: 'relatorio_fluxo_caixa',
      sections: sections,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Relatorio - Fluxo de caixa',
      actions: [
        IconButton(
          onPressed: () async {
            final data = await _future;
            if (data == null) return;
            await _exportRelatorio(data);
          },
          icon: const Icon(Icons.download_outlined, color: Colors.white),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const RelatorioSectionTitle('Periodo'),
              TextButton(
                onPressed: _limparFiltros,
                child: const Text('Limpar filtros'),
              ),
            ],
          ),
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
          const RelatorioSectionTitle('Agrupar por'),
          const SizedBox(height: 10),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Periodo',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<bool>(
                isExpanded: true,
                value: _agruparPorMes,
                items: const [
                  DropdownMenuItem<bool>(
                    value: false,
                    child: Text('Dia'),
                  ),
                  DropdownMenuItem<bool>(
                    value: true,
                    child: Text('Mes'),
                  ),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  setState(() => _agruparPorMes = v);
                  await _carregar();
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          const RelatorioSectionTitle('Totalizadores'),
          const SizedBox(height: 12),
          FutureBuilder<RelatorioFluxoCaixaResumo>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('Erro ao carregar relatorio: ${snapshot.error}');
              }
              final resumo = snapshot.data;
              if (resumo == null) {
                return const Text('Sem dados para o periodo informado.');
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: RelatorioKpiCard(
                          title: 'Entradas',
                          value: fmtMoney(resumo.totalEntradas),
                          subtitle: 'Previsto no periodo',
                          icon: Icons.call_received_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RelatorioKpiCard(
                          title: 'Saidas',
                          value: fmtMoney(resumo.totalSaidas),
                          subtitle: 'Previsto no periodo',
                          icon: Icons.call_made_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RelatorioKpiCard(
                    title: 'Saldo',
                    value: fmtMoney(resumo.saldo),
                    subtitle: 'Entradas - saidas',
                    icon: Icons.account_balance_outlined,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          const RelatorioSectionTitle('Movimentacao'),
          const SizedBox(height: 10),
          FutureBuilder<RelatorioFluxoCaixaResumo>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('Erro ao carregar movimentacao: ${snapshot.error}');
              }
              final resumo = snapshot.data;
              final itens = resumo?.itens ?? const [];
              if (itens.isEmpty) {
                return const Text('Nenhuma movimentacao encontrada.');
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: itens.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = itens[index];
                  final saldoColor = item.saldo >= 0
                      ? AppColors.success
                      : AppColors.danger;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_formatPeriodo(item.data)),
                    subtitle: Text(
                      'Entradas: ${fmtMoney(item.entradas)}  '
                      'Saidas: ${fmtMoney(item.saidas)}',
                    ),
                    trailing: Text(
                      fmtMoney(item.saldo),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: saldoColor,
                      ),
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
