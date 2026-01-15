class EntradaStatus {
  static const rascunho = 'RASCUNHO';
  static const confirmada = 'CONFIRMADA';

  static String label(String status) {
    switch (status) {
      case rascunho:
        return 'Rascunho';
      case confirmada:
        return 'Confirmada';
      default:
        return status;
    }
  }

  static const List<String> filtros = [rascunho, confirmada];
}

class Entrada {
  final int? id;
  final int fornecedorId;
  final String? fornecedorNome;
  final DateTime? dataNota;
  final DateTime dataEntrada;
  final String? numeroNota;
  final String? observacao;
  final double totalNota;
  final double freteTotal;
  final double descontoTotal;
  final String status;
  final DateTime createdAt;

  const Entrada({
    this.id,
    required this.fornecedorId,
    this.fornecedorNome,
    this.dataNota,
    required this.dataEntrada,
    this.numeroNota,
    this.observacao,
    required this.totalNota,
    required this.freteTotal,
    required this.descontoTotal,
    required this.status,
    required this.createdAt,
  });

  static Entrada fromMap(Map<String, Object?> map) {
    return Entrada(
      id: map['id'] as int?,
      fornecedorId: map['fornecedor_id'] as int,
      fornecedorNome: map['fornecedor_nome'] as String?,
      dataNota: map['data_nota'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['data_nota'] as int),
      dataEntrada: DateTime.fromMillisecondsSinceEpoch(map['data_entrada'] as int),
      numeroNota: map['numero_nota'] as String?,
      observacao: map['observacao'] as String?,
      totalNota: (map['total_nota'] as num?)?.toDouble() ?? 0,
      freteTotal: (map['frete_total'] as num?)?.toDouble() ?? 0,
      descontoTotal: (map['desconto_total'] as num?)?.toDouble() ?? 0,
      status: (map['status'] as String?) ?? EntradaStatus.rascunho,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}

class EntradaItem {
  final int? id;
  final int? entradaId;
  final int produtoId;
  final String produtoNome;
  final double qtd;
  final double custoUnit;

  const EntradaItem({
    this.id,
    this.entradaId,
    required this.produtoId,
    required this.produtoNome,
    required this.qtd,
    required this.custoUnit,
  });

  double get subtotal => qtd * custoUnit;
}

class EntradaDetalhe {
  final Entrada entrada;
  final List<EntradaItem> itens;

  const EntradaDetalhe({required this.entrada, required this.itens});
}
