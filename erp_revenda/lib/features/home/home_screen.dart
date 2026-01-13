import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/app_page.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'ERP Revenda',
      showBack: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: CircleAvatar(
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            child: const Icon(Icons.person, color: Colors.white),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              const Text(
                'Olá!',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Selecione um módulo para continuar',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.15,
                children: [
                  _ModuleCard(
                    icon: Icons.people_alt_outlined,
                    label: 'Clientes',
                    onTap: () => context.push('/clientes'),
                  ),
                  _ModuleCard(
                    icon: Icons.inventory_2_outlined,
                    label: 'Produtos / Estoque',
                    onTap: () => context.push('/produtos'),
                  ),
                  _ModuleCard(
                    icon: Icons.point_of_sale_outlined,
                    label: 'Vendas',
                    onTap: () => context.push('/vendas'),
                  ),
                  _ModuleCard(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Financeiro',
                    onTap: () => context.push('/financeiro'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 34),
              const Spacer(),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
