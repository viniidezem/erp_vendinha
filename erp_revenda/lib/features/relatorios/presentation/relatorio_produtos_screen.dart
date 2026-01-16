import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/ui/app_colors.dart';
import '../../../shared/widgets/app_page.dart';
import '../../vendas/data/venda_models.dart';
import '../controller/relatorios_controller.dart';
import '../data/relatorio_models.dart';
import 'relatorio_exporter.dart';
import 'relatorio_widgets.dart';
import '../../settings/controller/app_preferences_controller.dart';

class RelatorioProdutosScreen extends ConsumerStatefulWidget {
  const RelatorioProdutosScreen({super.key});

  @override
  ConsumerState<RelatorioProdutosScreen> createState() =>
      _RelatorioProdutosScreenState();
}

class _RelatorioProdutosScreenState
    extends ConsumerState<RelatorioProdutosScreen> {
  static const _statusEfetivos = '__EFETIVOS__';
  static const _kInicio = 'relatorio_produtos_inicio';
  static const _kFim = 'relatorio_produtos_fim';
  static const _kStatus = 'relatorio_produtos_status';
  static const _kPeriodoRapido = 'relatorio_produtos_periodo_rapido';

  late DateTime _inicio;
  late DateTime _fim;
  String _statusFiltro = _statusEfetivos;
  String? _periodoRapido;
  Future<RelatorioProdutosResumo>? _future;

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
    _statusFiltro = _statusEfetivos;
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  Future<void> _loadFiltrosSalvos() async {
    final repo = ref.read(appPreferencesRepositoryProvider);
    final inicioRaw = await repo.getValue(_kInicio);
    final fimRaw = await repo.getValue(_kFim);
    final statusRaw = await repo.getValue(_kStatus);
    final periodoRaw = await repo.getValue(_kPeriodoRapido);

    final inicioMs = int.tryParse(inicioRaw ?? '');
    final fimMs = int.tryParse(fimRaw ?? '');

    if (inicioMs != null) {
      _inicio = DateTime.fromMillisecondsSinceEpoch(inicioMs);
    }
    if (fimMs != null) {
      _fim = DateTime.fromMillisecondsSinceEpoch(fimMs);
    }
    _statusFiltro =
        (statusRaw ?? '').trim().isEmpty ? _statusEfetivos : statusRaw!;
    _periodoRapido =
        (periodoRaw ?? '').trim().isEmpty ? _periodoRapido : periodoRaw;

    if (!mounted) return;
    setState(() {});
    await _carregar();
  }

  Future<void> _persistFiltros() async {
    final repo = ref.read(appPreferencesRepositoryProvider);
    await repo.setValue(_kInicio, _inicio.millisecondsSinceEpoch.toString());
    await repo.setValue(_kFim, _fim.millisecondsSinceEpoch.toString());

    if (_statusFiltro.trim().isEmpty) {
      await repo.removeValue(_kStatus);
    } else {
      await repo.setValue(_kStatus, _statusFiltro);
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
    await repo.removeValue(_kPeriodoRapido);
    await _carregar();
  }

  Future<void> _carregar() async {
    final repo = ref.read(relatoriosRepositoryProvider);
    final somenteEfetivos = _statusFiltro == _statusEfetivos;
    final status = somenteEfetivos ? null : _statusFiltro;
    setState(() {
      _future = repo.produtosResumo(
        inicio: _startOfDay(_inicio),
        fim: _endOfDay(_fim),
        statusFiltro: status,
        somenteEfetivos: somenteEfetivos,
      );
    });
    await _persistFiltros();
  }

  Future<void> _exportRelatorio() async {
    final repo = ref.read(relatoriosRepositoryProvider);
    final somenteEfetivos = _statusFiltro == _statusEfetivos;
    final status = somenteEfetivos ? null : _statusFiltro;
    final resumo = await repo.produtosResumo(
      inicio: _startOfDay(_inicio),
      fim: _endOfDay(_fim),
      statusFiltro: status,
      somenteEfetivos: somenteEfetivos,
    );
    if (!mounted) return;

    final sections = [
      RelatorioExportSection(
        title: 'Ranking por quantidade',
        headers: const ['Produto', 'Quantidade', 'Valor'],
        rows: resumo.porQuantidade
            .map(
              (item) => [
                item.nome,
                item.qtd.toStringAsFixed(2),
                fmtMoney(item.valor),
              ],
            )
            .toList(),
      ),
      RelatorioExportSection(
        title: 'Ranking por valor',
        headers: const ['Produto', 'Quantidade', 'Valor'],
        rows: resumo.porValor
            .map(
              (item) => [
                item.nome,
                item.qtd.toStringAsFixed(2),
                fmtMoney(item.valor),
              ],
            )
            .toList(),
      ),
    ];

    await RelatorioExporter.export(
      context,
      title: 'Relatorio - Produtos',
      fileBaseName: 'relatorio_produtos',
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

  List<String> _statusOptions() {
    return [VendaStatus.aberta, ...VendaStatus.filtros];
  }

  String _statusLabel(String status) => VendaStatus.label(status);

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Relatorio - Produtos',
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
              child: DropdownButton<String>(
                isExpanded: true,
                value: _statusFiltro,
                items: [
                  const DropdownMenuItem<String>(
                    value: _statusEfetivos,
                    child: Text('Efetivos'),
                  ),
                  ..._statusOptions().map(
                    (s) => DropdownMenuItem<String>(
                      value: s,
                      child: Text(_statusLabel(s)),
                    ),
                  ),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  setState(() => _statusFiltro = v);
                  await _carregar();
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          const RelatorioSectionTitle('Rankings'),
          const SizedBox(height: 12),
          FutureBuilder<RelatorioProdutosResumo>(
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
                  const RelatorioSectionTitle('Por quantidade'),
                  const SizedBox(height: 8),
                  _RankingCard(
                    items: r.porQuantidade,
                    valueBuilder: (i) => '${i.qtd.toStringAsFixed(2)} un',
                  ),
                  const SizedBox(height: 16),
                  const RelatorioSectionTitle('Por valor'),
                  const SizedBox(height: 8),
                  _RankingCard(
                    items: r.porValor,
                    valueBuilder: (i) => fmtMoney(i.valor),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RankingCard extends StatelessWidget {
  final List<RelatorioProdutoRanking> items;
  final String Function(RelatorioProdutoRanking) valueBuilder;

  const _RankingCard({
    required this.items,
    required this.valueBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text('Sem dados para o periodo informado.');
    }

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.border,
                child: Text('${i + 1}'),
              ),
              title: Text(items[i].nome),
              trailing: Text(
                valueBuilder(items[i]),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}
