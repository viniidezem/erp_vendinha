class DashboardResumoPeriodo {
  static const hoje = 'HOJE';
  static const ultimos7Dias = 'ULTIMOS_7_DIAS';
  static const ultimos30Dias = 'ULTIMOS_30_DIAS';

  static const List<String> values = [hoje, ultimos7Dias, ultimos30Dias];

  static String label(String value) {
    switch (value) {
      case hoje:
        return 'Hoje';
      case ultimos7Dias:
        return 'Últimos 7 dias';
      case ultimos30Dias:
        return 'Últimos 30 dias';
      default:
        return value;
    }
  }
}

class DashboardResumo {
  final double vendasPeriodoTotal;
  final int vendasPeriodoQtde;

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
  final int contasReceberVencidas;
  final int contasReceberVencendo;
  final int contasPagarVencidas;
  final int contasPagarVencendo;

  const DashboardResumo({
    required this.vendasPeriodoTotal,
    required this.vendasPeriodoQtde,
    required this.vendasHojeTotal,
    required this.vendasHojeQtde,
    required this.vendasMesTotal,
    required this.vendasMesQtde,
    required this.clientesAtivos,
    required this.produtosAtivos,
    required this.produtosComSaldo,
    required this.pedidosAbertos,
    required this.pedidosAguardandoPagamento,
    required this.contasReceberVencidas,
    required this.contasReceberVencendo,
    required this.contasPagarVencidas,
    required this.contasPagarVencendo,
  });

  factory DashboardResumo.empty() => const DashboardResumo(
        vendasPeriodoTotal: 0,
        vendasPeriodoQtde: 0,
        vendasHojeTotal: 0,
        vendasHojeQtde: 0,
        vendasMesTotal: 0,
        vendasMesQtde: 0,
        clientesAtivos: 0,
        produtosAtivos: 0,
        produtosComSaldo: 0,
        pedidosAbertos: 0,
        pedidosAguardandoPagamento: 0,
        contasReceberVencidas: 0,
        contasReceberVencendo: 0,
        contasPagarVencidas: 0,
        contasPagarVencendo: 0,
      );
}
