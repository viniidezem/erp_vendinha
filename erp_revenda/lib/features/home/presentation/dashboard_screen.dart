import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/ui/app_colors.dart';
import '../../../shared/widgets/app_page.dart';
import '../controller/dashboard_controller.dart';
import '../data/dashboard_grafico.dart';
import '../data/dashboard_resumo.dart';
import '../../settings/controller/dashboard_settings_controller.dart';
import '../../settings/data/dashboard_settings.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumoAsync = ref.watch(dashboardControllerProvider);
    final settingsAsync = ref.watch(dashboardSettingsProvider);

    return AppPage(
      title: 'Dashboard',
      showBack: false,
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: () => ref.read(dashboardControllerProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh),
          color: Colors.white,
        ),
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: CircleAvatar(
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            child: const Icon(Icons.person, color: Colors.white),
          ),
        ),
      ],
      child: resumoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Erro ao carregar dashboard:\n$e'),
        ),
        data: (r) {
          return settingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Erro ao carregar configuracoes:\n$e'),
            ),
            data: (settings) {
              final showGraficos = settings.mostrarGraficos;
              return RefreshIndicator(
                onRefresh: () =>
                    ref.read(dashboardControllerProvider.notifier).refresh(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    if (!showGraficos) ...[
                      const Text(
                        'Resumo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _KpiCard(
                              title: 'Vendas hoje',
                              value: _money(r.vendasHojeTotal),
                              subtitle: '${r.vendasHojeQtde} venda(s)',
                              icon: Icons.attach_money,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _KpiCard(
                              title: 'Vendas no mes',
                              value: _money(r.vendasMesTotal),
                              subtitle: '${r.vendasMesQtde} venda(s)',
                              icon: Icons.calendar_month_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _KpiCard(
                              title: 'Clientes ativos',
                              value: r.clientesAtivos.toString(),
                              subtitle: 'Status ATIVO',
                              icon: Icons.people_outline,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _KpiCard(
                              title: 'Estoque',
                              value: '${r.produtosComSaldo}',
                              subtitle: '${r.produtosAtivos} produtos ativos',
                              icon: Icons.inventory_2_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _KpiCard(
                              title: 'Pedidos abertos',
                              value: r.pedidosAbertos.toString(),
                              subtitle: 'Em andamento',
                              icon: Icons.receipt_long_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _KpiCard(
                              title: 'Aguardando pagto',
                              value: r.pedidosAguardandoPagamento.toString(),
                              subtitle: 'Cobranca pendente',
                              icon: Icons.payments_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                    ] else ...[
                      _GraficosSection(resumo: r, settings: settings),
                      const SizedBox(height: 22),
                    ],
                    const Text(
                      'Modulos',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.35,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _ModuleCard(
                          icon: Icons.add_shopping_cart_outlined,
                          title: 'Nova venda',
                          subtitle: 'Adicionar itens',
                          onTap: _goNovaVenda,
                        ),
                        _ModuleCard(
                          icon: Icons.people_outline,
                          title: 'Clientes',
                          subtitle: 'Cadastro e consulta',
                          onTap: _goClientes,
                        ),
                        _ModuleCard(
                          icon: Icons.inventory_2_outlined,
                          title: 'Produtos',
                          subtitle: 'Estoque e precos',
                          onTap: _goProdutos,
                        ),
                        _ModuleCard(
                          icon: Icons.receipt_long_outlined,
                          title: 'Vendas',
                          subtitle: 'Historico',
                          onTap: _goVendas,
                        ),
                        _ModuleCard(
                          icon: Icons.inventory_outlined,
                          title: 'Entradas',
                          subtitle: 'Mercadorias',
                          onTap: _goEntradas,
                        ),
                        _ModuleCard(
                          icon: Icons.assessment_outlined,
                          title: 'Relatorios',
                          subtitle: 'Financeiro e faturamento',
                          onTap: _goRelatorios,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _QuickTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Contas a pagar',
                      subtitle: 'Lancamentos e vencimentos',
                      onTap: () => context.push('/financeiro'),
                    ),
                    const SizedBox(height: 12),
                    _QuickTile(
                      icon: Icons.trending_up_outlined,
                      title: 'Contas a receber',
                      subtitle: 'Parcelas e recebimentos',
                      onTap: () => context.push('/financeiro/contas-receber'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  static void _goNovaVenda(BuildContext context) => context.push('/vendas/nova');
  static void _goClientes(BuildContext context) => context.push('/clientes');
  static void _goProdutos(BuildContext context) => context.push('/produtos');
  static void _goVendas(BuildContext context) => context.push('/vendas');
  static void _goEntradas(BuildContext context) => context.push('/entradas');
  static void _goRelatorios(BuildContext context) => context.push('/relatorios');
  // Contas a receber agora possui tela propria.
}

String _money(double v) {
  final s = v.toStringAsFixed(2).replaceAll('.', ',');
  return 'R\$ $s';
}

class _GraficosSection extends ConsumerWidget {
  final DashboardResumo resumo;
  final DashboardSettings settings;

  const _GraficosSection({
    required this.resumo,
    required this.settings,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final graficoAsync =
        ref.watch(dashboardGraficoProvider(settings.periodoGrafico));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Graficos',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        _MetaCard(
          metaMensal: settings.metaFaturamentoMensal,
          atualMes: resumo.vendasMesTotal,
        ),
        const SizedBox(height: 12),
        _PeriodoChips(
          value: settings.periodoGrafico,
          onChanged: (p) => ref
              .read(dashboardSettingsProvider.notifier)
              .atualizar(periodoGrafico: p),
        ),
        const SizedBox(height: 12),
        graficoAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Erro ao carregar grafico: $e'),
          data: (grafico) => _GraficoCard(
            titulo: DashboardGraficoPeriodo.label(settings.periodoGrafico),
            total: grafico.total,
            itens: grafico.itens,
          ),
        ),
      ],
    );
  }
}

class _MetaCard extends StatelessWidget {
  final double metaMensal;
  final double atualMes;

  const _MetaCard({
    required this.metaMensal,
    required this.atualMes,
  });

  @override
  Widget build(BuildContext context) {
    final hasMeta = metaMensal > 0;
    final progresso =
        hasMeta ? (atualMes / metaMensal).clamp(0.0, 1.0) : 0.0;
    final percent = hasMeta ? (progresso * 100).toStringAsFixed(1) : '0';

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Meta mensal',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Meta: ${_money(metaMensal)}',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ),
                Text(
                  'Atual: ${_money(atualMes)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: hasMeta ? progresso : 0,
              minHeight: 8,
              backgroundColor: AppColors.border,
              color: AppColors.primary,
            ),
            const SizedBox(height: 6),
            Text(
              hasMeta ? '$percent% da meta' : 'Defina a meta em Configuracoes.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodoChips extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _PeriodoChips({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: DashboardGraficoPeriodo.values.map((p) {
        final selected = p == value;
        return ChoiceChip(
          label: Text(DashboardGraficoPeriodo.label(p)),
          selected: selected,
          onSelected: (_) => onChanged(p),
        );
      }).toList(),
    );
  }
}

class _GraficoCard extends StatelessWidget {
  final String titulo;
  final double total;
  final List<DashboardGraficoItem> itens;

  const _GraficoCard({
    required this.titulo,
    required this.total,
    required this.itens,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Periodo: $titulo',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  _money(total),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _BarChart(itens: itens),
          ],
        ),
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<DashboardGraficoItem> itens;

  const _BarChart({
    required this.itens,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = itens.fold<double>(
      0,
      (max, e) => e.valor > max ? e.valor : max,
    );
    final maxValue = maxVal <= 0 ? 1 : maxVal;

    return SizedBox(
      height: 150,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: itens.map((e) {
            final ratio = e.valor / maxValue;
            final barHeight = 110 * ratio;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    height: 120,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: barHeight < 2 ? 2 : barHeight,
                        width: 14,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    e.label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final void Function(BuildContext context) onTap;

  const _ModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => onTap(context),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
