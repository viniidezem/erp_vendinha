class RelatorioContasPagarResumo {
  final double totalAberto;
  final double totalPago;
  final double totalCancelado;
  final double totalVencido;
  final double totalVencendo;
  final int qtdAberta;
  final int qtdPaga;
  final int qtdCancelada;
  final int qtdVencida;
  final int qtdVencendo;

  const RelatorioContasPagarResumo({
    required this.totalAberto,
    required this.totalPago,
    required this.totalCancelado,
    required this.totalVencido,
    required this.totalVencendo,
    required this.qtdAberta,
    required this.qtdPaga,
    required this.qtdCancelada,
    required this.qtdVencida,
    required this.qtdVencendo,
  });
}

class RelatorioContasReceberResumo {
  final double totalAberto;
  final double totalRecebido;
  final double totalCancelado;
  final double totalVencido;
  final double totalVencendo;
  final int qtdAberta;
  final int qtdRecebida;
  final int qtdCancelada;
  final int qtdVencida;
  final int qtdVencendo;

  const RelatorioContasReceberResumo({
    required this.totalAberto,
    required this.totalRecebido,
    required this.totalCancelado,
    required this.totalVencido,
    required this.totalVencendo,
    required this.qtdAberta,
    required this.qtdRecebida,
    required this.qtdCancelada,
    required this.qtdVencida,
    required this.qtdVencendo,
  });
}

class RelatorioStatusResumo {
  final String status;
  final int qtd;
  final double total;

  const RelatorioStatusResumo({
    required this.status,
    required this.qtd,
    required this.total,
  });
}

class RelatorioVendasResumo {
  final double totalEfetivo;
  final int qtdEfetiva;
  final double ticketMedio;
  final double totalCancelado;
  final int qtdCancelada;
  final List<RelatorioStatusResumo> porStatus;

  const RelatorioVendasResumo({
    required this.totalEfetivo,
    required this.qtdEfetiva,
    required this.ticketMedio,
    required this.totalCancelado,
    required this.qtdCancelada,
    required this.porStatus,
  });
}

class RelatorioProdutoRanking {
  final int produtoId;
  final String nome;
  final double qtd;
  final double valor;

  const RelatorioProdutoRanking({
    required this.produtoId,
    required this.nome,
    required this.qtd,
    required this.valor,
  });
}

class RelatorioProdutosResumo {
  final List<RelatorioProdutoRanking> porQuantidade;
  final List<RelatorioProdutoRanking> porValor;

  const RelatorioProdutosResumo({
    required this.porQuantidade,
    required this.porValor,
  });
}

class RelatorioFluxoCaixaItem {
  final DateTime data;
  final double entradas;
  final double saidas;
  final double saldo;

  const RelatorioFluxoCaixaItem({
    required this.data,
    required this.entradas,
    required this.saidas,
    required this.saldo,
  });
}

class RelatorioFluxoCaixaResumo {
  final double totalEntradas;
  final double totalSaidas;
  final double saldo;
  final List<RelatorioFluxoCaixaItem> itens;

  const RelatorioFluxoCaixaResumo({
    required this.totalEntradas,
    required this.totalSaidas,
    required this.saldo,
    required this.itens,
  });
}
