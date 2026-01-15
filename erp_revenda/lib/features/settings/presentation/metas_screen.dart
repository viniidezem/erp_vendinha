import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_decimal_field.dart';
import '../../../shared/widgets/app_error_dialog.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_page.dart';
import '../controller/dashboard_settings_controller.dart';
import '../data/dashboard_settings.dart';

class MetasScreen extends ConsumerStatefulWidget {
  const MetasScreen({super.key});

  @override
  ConsumerState<MetasScreen> createState() => _MetasScreenState();
}

class _MetasScreenState extends ConsumerState<MetasScreen> {
  final _metaCtrl = TextEditingController();
  bool _mostrarGraficos = false;
  String _periodo = DashboardGraficoPeriodo.mesAtual;
  bool _iniciado = false;

  @override
  void dispose() {
    _metaCtrl.dispose();
    super.dispose();
  }

  double _parsePtBrNumber(String text) {
    final t = text.trim();
    if (t.isEmpty) return 0;

    final hasComma = t.contains(',');
    final hasDot = t.contains('.');

    if (hasComma && hasDot) {
      final cleaned = t.replaceAll('.', '').replaceAll(',', '.');
      return double.tryParse(cleaned) ?? 0;
    }

    if (hasComma && !hasDot) {
      return double.tryParse(t.replaceAll(',', '.')) ?? 0;
    }

    return double.tryParse(t) ?? 0;
  }

  Future<void> _salvarMeta() async {
    try {
      final valor = _parsePtBrNumber(_metaCtrl.text);
      await ref
          .read(dashboardSettingsProvider.notifier)
          .atualizar(metaFaturamentoMensal: valor);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Metas atualizadas.')),
      );
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(context, 'Erro ao salvar metas:\n$e');
    }
  }

  Future<void> _salvarPeriodo(String periodo) async {
    setState(() => _periodo = periodo);
    await ref.read(dashboardSettingsProvider.notifier).atualizar(
          periodoGrafico: periodo,
        );
  }

  Future<void> _salvarMostrarGraficos(bool v) async {
    setState(() => _mostrarGraficos = v);
    await ref.read(dashboardSettingsProvider.notifier).atualizar(
          mostrarGraficos: v,
        );
  }

  @override
  Widget build(BuildContext context) {
    final asyncSettings = ref.watch(dashboardSettingsProvider);

    return AppPage(
      title: 'Metas',
      child: asyncSettings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar metas: $e')),
        data: (settings) {
          if (!_iniciado) {
            _mostrarGraficos = settings.mostrarGraficos;
            _periodo = settings.periodoGrafico;
            _metaCtrl.text = settings.metaFaturamentoMensal.toStringAsFixed(2);
            _iniciado = true;
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              SwitchListTile(
                value: _mostrarGraficos,
                title: const Text('Mostrar graficos no dashboard'),
                subtitle: const Text('Substitui os KPIs por graficos'),
                onChanged: _salvarMostrarGraficos,
              ),
              const SizedBox(height: 10),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Periodo do grafico',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _periodo,
                    items: DashboardGraficoPeriodo.values
                        .map(
                          (p) => DropdownMenuItem<String>(
                            value: p,
                            child: Text(DashboardGraficoPeriodo.label(p)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      _salvarPeriodo(v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AppDecimalField(
                controller: _metaCtrl,
                labelText: 'Meta de faturamento mensal (R\$)',
              ),
              const SizedBox(height: 16),
              AppGradientButton(
                label: 'Salvar metas',
                trailingIcon: Icons.check,
                onPressed: _salvarMeta,
              ),
            ],
          );
        },
      ),
    );
  }
}
