import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/ui/app_colors.dart';
import '../../../shared/widgets/app_page.dart';
import '../../vendas/data/venda_models.dart';
import '../controller/relatorios_controller.dart';
import '../data/relatorio_models.dart';
import 'relatorio_widgets.dart';

class RelatorioVendasScreen extends ConsumerStatefulWidget {
  const RelatorioVendasScreen({super.key});

  @override
  ConsumerState<RelatorioVendasScreen> createState() =>
      _RelatorioVendasScreenState();
}

class _RelatorioVendasScreenState extends ConsumerState<RelatorioVendasScreen> {
  static const _statusEfetivos = '__EFETIVOS__';

  late DateTime _inicio;
  late DateTime _fim;
  String _statusFiltro = _statusEfetivos;
  Future<RelatorioVendasResumo>? _future;

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
      _future = repo.vendasResumo(
        inicio: _startOfDay(_inicio),
        fim: _endOfDay(_fim),
        status: status,
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
      title: 'Relatorio - Vendas',
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
          const RelatorioSectionTitle('Totalizadores'),
          const SizedBox(height: 12),
          FutureBuilder<RelatorioVendasResumo>(
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
                          title: 'Total efetivo',
                          value: fmtMoney(r.totalEfetivo),
                          subtitle: '${r.qtdEfetiva} pedidos',
                          icon: Icons.receipt_long_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RelatorioKpiCard(
                          title: 'Ticket medio',
                          value: fmtMoney(r.ticketMedio),
                          subtitle: 'Media por pedido',
                          icon: Icons.trending_up_outlined,
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
                          subtitle: '${r.qtdCancelada} pedidos',
                          icon: Icons.remove_circle_outline,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const RelatorioSectionTitle('Por status'),
                  const SizedBox(height: 10),
                  if (r.porStatus.isEmpty)
                    const Text('Sem dados para o periodo informado.')
                  else
                    Card(
                      elevation: 0,
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: Column(
                        children: r.porStatus.map((s) {
                          return ListTile(
                            title: Text(_statusLabel(s.status)),
                            subtitle: Text('${s.qtd} pedido(s)'),
                            trailing: Text(
                              fmtMoney(s.total),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          );
                        }).toList(),
                      ),
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
