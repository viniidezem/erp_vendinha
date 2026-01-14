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
import '../features/vendas/presentation/checkout_pedido_screen.dart';

import '../features/financeiro/financeiro_screen.dart';

import '../features/formas_pagamento/presentation/formas_pagamento_screen.dart';
import '../features/formas_pagamento/presentation/forma_pagamento_form_screen.dart';
import '../features/formas_pagamento/data/forma_pagamento_model.dart';

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
        path: '/pedidos/:id',
        builder: (context, state) {
          final idStr = state.pathParameters['id'];
          final id = int.tryParse(idStr ?? '');
          if (id == null) {
            return const MainShellScreen();
          }
          return PedidoDetalheScreen(vendaId: id);
        },
      ),
      GoRoute(
        path: '/vendas/nova',
        builder: (context, state) => const NovaVendaScreen(),
      ),

      GoRoute(
        path: '/vendas/checkout',
        builder: (context, state) {
          final args = state.extra as CheckoutArgs;
          return CheckoutPedidoScreen(args: args);
        },
      ),

      // Formas de pagamento
      GoRoute(
        path: '/formas-pagamento',
        builder: (context, state) => const FormasPagamentoScreen(),
      ),
      GoRoute(
        path: '/formas-pagamento/form',
        builder: (context, state) {
          final extra = state.extra;
          return FormaPagamentoFormScreen(
            forma: extra is FormaPagamento ? extra : null,
          );
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
