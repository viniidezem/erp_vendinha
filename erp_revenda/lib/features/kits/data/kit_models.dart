import '../../produtos/data/produto_model.dart';

class KitItem {
  final int produtoId;
  final String produtoNome;
  final double qtd;

  const KitItem({
    required this.produtoId,
    required this.produtoNome,
    required this.qtd,
  });
}

class KitDetalhe {
  final Produto kit;
  final List<KitItem> itens;

  const KitDetalhe({required this.kit, required this.itens});
}
