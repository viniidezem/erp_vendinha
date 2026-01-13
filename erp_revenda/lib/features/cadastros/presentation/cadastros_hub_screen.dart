import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_page.dart';
import '../../../app/ui/app_colors.dart';

class CadastrosHubScreen extends StatelessWidget {
  const CadastrosHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Cadastros',
      showBack: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _HubCard(
            icon: Icons.people_outline,
            title: 'Clientes',
            subtitle: 'Cadastrar, editar e consultar',
            onTap: () => context.push('/clientes'),
          ),
          const SizedBox(height: 12),
          _HubCard(
            icon: Icons.inventory_2_outlined,
            title: 'Produtos',
            subtitle: 'Cadastrar, editar e controlar estoque',
            onTap: () => context.push('/produtos'),
          ),
          const SizedBox(height: 12),
          _HubCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Financeiro',
            subtitle: 'Contas a pagar e receber',
            onTap: () => context.push('/financeiro'),
          ),
          const SizedBox(height: 24),
          const Text(
            'Observação',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Aqui entra tudo que é cadastro (fornecedor, fabricante, categorias, propriedades...). '
            'Vamos adicionando conforme você criar as telas.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HubCard({
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
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                      ),
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
