import 'package:bottom_bar/bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/ui/app_colors.dart';
import '../../cadastros/presentation/cadastros_hub_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../vendas/presentation/vendas_screen.dart';
import 'dashboard_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _index = 0;

  void _setIndex(int i) {
    if (i == _index) return;
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const DashboardScreen(),
      const CadastrosHubScreen(),
      const VendasScreen(showBack: false),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),

      // Botão central: Nova Venda
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/vendas/nova'),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: SafeArea(
        top: false,
        child: BottomBar(
          selectedIndex: _index,
          onTap: _setIndex,
          showActiveBackgroundColor: true,
          itemPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          items: const <BottomBarItem>[
            BottomBarItem(
              icon: Icon(Icons.home_outlined),
              title: Text('Home'),
              activeColor: AppColors.primary,
            ),
            BottomBarItem(
              icon: Icon(Icons.dashboard_customize_outlined),
              title: Text('Cadastros'),
              activeColor: AppColors.primary,
            ),
            BottomBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              title: Text('Pedidos'),
              activeColor: AppColors.primary,
            ),
            BottomBarItem(
              icon: Icon(Icons.settings_outlined),
              title: Text('Config'),
              activeColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
