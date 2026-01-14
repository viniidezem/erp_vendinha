class CadastrosResumo {
  final int clientesTotal;
  final int clientesAtivos;

  final int produtosAtivos;
  final int produtosComSaldo;

  final int fornecedores;
  final int fabricantes;

  final int formasPagamentoTotal;
  final int formasPagamentoAtivas;

  final int categoriasOcasiao;
  final int categoriasFamilia;
  final int categoriasPropriedade;

  const CadastrosResumo({
    required this.clientesTotal,
    required this.clientesAtivos,
    required this.produtosAtivos,
    required this.produtosComSaldo,
    required this.fornecedores,
    required this.fabricantes,
    required this.formasPagamentoTotal,
    required this.formasPagamentoAtivas,
    required this.categoriasOcasiao,
    required this.categoriasFamilia,
    required this.categoriasPropriedade,
  });

  int get categoriasTotal =>
      categoriasOcasiao + categoriasFamilia + categoriasPropriedade;
}
