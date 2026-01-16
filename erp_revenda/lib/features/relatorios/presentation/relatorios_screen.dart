import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/ui/app_colors.dart';
import '../../../shared/widgets/app_page.dart';
import 'relatorio_contas_receber_screen.dart';

class RelatoriosScreen extends StatelessWidget {
  const RelatoriosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Relatorios',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const _SectionTitle('Financeiro'),
          const SizedBox(height: 12),
          _ReportTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Contas a pagar',
            subtitle: 'Status e vencimentos',
            onTap: () => context.push('/relatorios/financeiro/pagar'),
          ),
          const SizedBox(height: 10),
          _ReportTile(
            icon: Icons.trending_up_outlined,
            title: 'Contas a receber',
            subtitle: 'Parcelas e recebimentos',
            onTap: () => context.push('/relatorios/financeiro/receber'),
          ),
          const SizedBox(height: 10),
          _ReportTile(
            icon: Icons.ssid_chart_outlined,
            title: 'Fluxo de caixa',
            subtitle: 'Entradas e saidas previstas',
            onTap: () => context.push('/relatorios/financeiro/fluxo-caixa'),
          ),
          const SizedBox(height: 10),
          _ReportTile(
            icon: Icons.warning_amber_outlined,
            title: 'Prestes a vencer',
            subtitle: 'Clientes e vencimentos',
            onTap: () => context.push(
              '/relatorios/financeiro/receber',
              extra: const RelatorioContasReceberArgs(
                somentePrestesVencer: true,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Faturamento'),
          const SizedBox(height: 12),
          _ReportTile(
            icon: Icons.bar_chart_outlined,
            title: 'Vendas por produto',
            subtitle: 'Ranking e periodo',
            onTap: () => context.push('/relatorios/faturamento/produtos'),
          ),
          const SizedBox(height: 10),
          _ReportTile(
            icon: Icons.receipt_long_outlined,
            title: 'Resumo de vendas',
            subtitle: 'Pedidos e status',
            onTap: () => context.push('/relatorios/faturamento/vendas'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;

  const _SectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ReportTile({
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
