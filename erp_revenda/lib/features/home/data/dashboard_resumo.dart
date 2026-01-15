class DashboardResumo {
  final double vendasHojeTotal;
  final int vendasHojeQtde;

  final double vendasMesTotal;
  final int vendasMesQtde;

  final int clientesAtivos;
  final int produtosAtivos;
  final int produtosComSaldo;

  // Pedidos
  final int pedidosAbertos;
  final int pedidosAguardandoPagamento;

  const DashboardResumo({
    required this.vendasHojeTotal,
    required this.vendasHojeQtde,
    required this.vendasMesTotal,
    required this.vendasMesQtde,
    required this.clientesAtivos,
    required this.produtosAtivos,
    required this.produtosComSaldo,
    required this.pedidosAbertos,
    required this.pedidosAguardandoPagamento,
  });

  factory DashboardResumo.empty() => const DashboardResumo(
        vendasHojeTotal: 0,
        vendasHojeQtde: 0,
        vendasMesTotal: 0,
        vendasMesQtde: 0,
        clientesAtivos: 0,
        produtosAtivos: 0,
        produtosComSaldo: 0,
        pedidosAbertos: 0,
        pedidosAguardandoPagamento: 0,
      );
}
