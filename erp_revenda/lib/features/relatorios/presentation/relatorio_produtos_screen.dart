import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/ui/app_colors.dart';
import '../../../shared/widgets/app_page.dart';
import '../../vendas/data/venda_models.dart';
import '../controller/relatorios_controller.dart';
import '../data/relatorio_models.dart';
import 'relatorio_widgets.dart';

class RelatorioProdutosScreen extends ConsumerStatefulWidget {
  const RelatorioProdutosScreen({super.key});

  @override
  ConsumerState<RelatorioProdutosScreen> createState() =>
      _RelatorioProdutosScreenState();
}

class _RelatorioProdutosScreenState
    extends ConsumerState<RelatorioProdutosScreen> {
  static const _statusEfetivos = '__EFETIVOS__';

  late DateTime _inicio;
  late DateTime _fim;
  String _statusFiltro = _statusEfetivos;
  Future<RelatorioProdutosResumo>? _future;

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

  List<String> _statusOptions() {
    return [VendaStatus.aberta, ...VendaStatus.filtros];
  }

  String _statusLabel(String status) => VendaStatus.label(status);

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Relatorio - Produtos',
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
