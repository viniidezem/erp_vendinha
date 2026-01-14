import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/presentation/main_shell_screen.dart';

import '../features/clientes/presentation/cliente_form_screen.dart';
import '../features/clientes/presentation/clientes_screen.dart';
import '../features/clientes/data/cliente_model.dart';

import '../features/produtos/presentation/produtos_screen.dart';
import '../features/produtos/presentation/produto_form_screen.dart';
import '../features/produtos/presentation/ajuste_estoque_screen.dart';
import '../features/produtos/data/produto_model.dart';

import '../features/vendas/presentation/vendas_screen.dart';
import '../features/vendas/presentation/nova_venda_screen.dart';
import '../features/vendas/presentation/pedido_detalhe_screen.dart';

import '../features/financeiro/financeiro_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      // Shell (Bottom Bar)
      GoRoute(path: '/', builder: (context, state) => const MainShellScreen()),

      // Clientes
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

      // Produtos
      GoRoute(
        path: '/produtos',
        builder: (context, state) => const ProdutosScreen(),
      ),
      GoRoute(
        path: '/produtos/form',
        builder: (context, state) {
          final extra = state.extra;
          return ProdutoFormScreen(produto: extra is Produto ? extra : null);
        },
      ),
      GoRoute(
        path: '/produtos/ajuste',
        builder: (context, state) {
          final produto = state.extra as Produto;
          return AjusteEstoqueScreen(produto: produto);
        },
      ),

      // Vendas
      GoRoute(
        path: '/vendas',
        builder: (context, state) => const VendasScreen(showBack: true),
      ),
      GoRoute(
        path: '/vendas/nova',
        builder: (context, state) => const NovaVendaScreen(),
      ),


      // Pedidos / Expedição
      GoRoute(
        path: '/pedidos',
        builder: (context, state) => const VendasScreen(),
      ),
      GoRoute(
        path: '/pedidos/:id',
        builder: (context, state) {
          final id = int.tryParse(state.uri.pathSegments.isNotEmpty
              ? state.uri.pathSegments.last
              : '') ??
          0;
          return PedidoDetalheScreen(vendaId: id);
        },
      ),

      // Financeiro
      GoRoute(
        path: '/financeiro',
        builder: (context, state) => const FinanceiroScreen(),
      ),
    ],
  );
});
