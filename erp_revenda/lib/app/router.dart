import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/clientes/presentation/cliente_form_screen.dart';
import '../features/clientes/presentation/clientes_screen.dart';
import '../features/clientes/data/cliente_model.dart';

import '../features/produtos/presentation/produtos_screen.dart';
import '../features/produtos/presentation/produto_form_screen.dart';
import '../features/produtos/presentation/ajuste_estoque_screen.dart';
import '../features/produtos/data/produto_model.dart';

import '../features/vendas/presentation/vendas_screen.dart';
import '../features/vendas/presentation/nova_venda_screen.dart';

import '../features/financeiro/financeiro_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/clientes',
        builder: (context, state) => const ClientesScreen(),
      ),
      GoRoute(
        path: '/clientes/form',
        builder: (context, state) {
          final cliente = state.extra as Cliente?;
          return ClienteFormScreen(cliente: cliente);
        },
      ),

      GoRoute(
        path: '/produtos',
        builder: (context, state) => const ProdutosScreen(),
      ),
      GoRoute(
        path: '/produtos/form',
        builder: (context, state) {
          final produto = state.extra as Produto?;
          return ProdutoFormScreen(produto: produto);
        },
      ),
      GoRoute(
        path: '/produtos/ajuste',
        builder: (context, state) {
          final produto = state.extra as Produto;
          return AjusteEstoqueScreen(produto: produto);
        },
      ),

      GoRoute(
        path: '/vendas',
        builder: (context, state) => const VendasScreen(),
      ),
      GoRoute(
        path: '/financeiro',
        builder: (context, state) => const FinanceiroScreen(),
      ),

      GoRoute(
        path: '/vendas',
        builder: (context, state) => const VendasScreen(),
      ),
      GoRoute(
        path: '/vendas/nova',
        builder: (context, state) => const NovaVendaScreen(),
      ),
    ],
  );
});
