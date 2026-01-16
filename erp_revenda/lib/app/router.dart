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
import '../features/financeiro/contas_pagar/presentation/conta_pagar_form_screen.dart';
import '../features/financeiro/contas_receber/presentation/contas_receber_screen.dart';
import '../features/entradas/presentation/entradas_screen.dart';
import '../features/entradas/presentation/entrada_form_screen.dart';
import '../features/entradas/presentation/entrada_detalhe_screen.dart';
import '../features/entradas/presentation/entrada_contas_pagar_screen.dart';
import '../features/kits/presentation/kits_screen.dart';
import '../features/kits/presentation/kit_form_screen.dart';
import '../features/settings/presentation/backup_screen.dart';
import '../features/settings/presentation/metas_screen.dart';
import '../features/settings/presentation/appearance_screen.dart';
import '../features/settings/presentation/pin_settings_screen.dart';
import '../features/relatorios/presentation/relatorios_screen.dart';
import '../features/relatorios/presentation/relatorio_contas_pagar_screen.dart';
import '../features/relatorios/presentation/relatorio_contas_receber_screen.dart';
import '../features/relatorios/presentation/relatorio_fluxo_caixa_screen.dart';
import '../features/relatorios/presentation/relatorio_vendas_screen.dart';
import '../features/relatorios/presentation/relatorio_produtos_screen.dart';

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
      GoRoute(
        path: '/financeiro/contas-pagar/form',
        builder: (context, state) => const ContaPagarFormScreen(),
      ),
      GoRoute(
        path: '/financeiro/contas-receber',
        builder: (context, state) => const ContasReceberScreen(),
      ),

      // Entradas
      GoRoute(
        path: '/entradas',
        builder: (context, state) => const EntradasScreen(),
      ),
      GoRoute(
        path: '/entradas/form',
        builder: (context, state) {
          final extra = state.extra;
          return EntradaFormScreen(entradaId: extra is int ? extra : null);
        },
      ),
      GoRoute(
        path: '/entradas/:id',
        builder: (context, state) {
          final idStr = state.pathParameters['id'];
          final id = int.tryParse(idStr ?? '');
          if (id == null) return const MainShellScreen();
          return EntradaDetalheScreen(entradaId: id);
        },
      ),
      GoRoute(
        path: '/entradas/:id/contas-pagar',
        builder: (context, state) {
          final idStr = state.pathParameters['id'];
          final id = int.tryParse(idStr ?? '');
          if (id == null) return const MainShellScreen();
          return EntradaContasPagarScreen(entradaId: id);
        },
      ),

      // Kits
      GoRoute(
        path: '/kits',
        builder: (context, state) => const KitsScreen(),
      ),
      GoRoute(
        path: '/kits/form',
        builder: (context, state) {
          final extra = state.extra;
          return KitFormScreen(kitId: extra is int ? extra : null);
        },
      ),

      // Settings / Backup
      GoRoute(
        path: '/settings/backup',
        builder: (context, state) => const BackupScreen(),
      ),
      GoRoute(
        path: '/settings/pin',
        builder: (context, state) => const PinSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/metas',
        builder: (context, state) => const MetasScreen(),
      ),
      GoRoute(
        path: '/settings/aparencia',
        builder: (context, state) => const AppearanceScreen(),
      ),

      // Relatorios
      GoRoute(
        path: '/relatorios',
        builder: (context, state) => const RelatoriosScreen(),
      ),
      GoRoute(
        path: '/relatorios/financeiro/pagar',
        builder: (context, state) => const RelatorioContasPagarScreen(),
      ),
      GoRoute(
        path: '/relatorios/financeiro/receber',
        builder: (context, state) {
          final extra = state.extra;
          final args = extra is RelatorioContasReceberArgs
              ? extra
              : const RelatorioContasReceberArgs();
          return RelatorioContasReceberScreen(args: args);
        },
      ),
      GoRoute(
        path: '/relatorios/financeiro/fluxo-caixa',
        builder: (context, state) => const RelatorioFluxoCaixaScreen(),
      ),
      GoRoute(
        path: '/relatorios/faturamento/vendas',
        builder: (context, state) => const RelatorioVendasScreen(),
      ),
      GoRoute(
        path: '/relatorios/faturamento/produtos',
        builder: (context, state) => const RelatorioProdutosScreen(),
      ),
    ],
  );
});
