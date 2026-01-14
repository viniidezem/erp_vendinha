class VendaStatus {
  // Rascunho / carrinho em andamento (ainda não confirmado como pedido)
  static const aberta = 'ABERTA';

  // Pedido confirmado (aguardando expedição/entrega)
  static const pedido = 'PEDIDO';

  // Reservado para próxima etapa (expedição/entrega)
  static const emExpedicao = 'EM_EXPEDICAO';
  static const entregue = 'ENTREGUE';

  // Compatibilidade com versões anteriores
  static const finalizada = 'FINALIZADA';

  static const cancelada = 'CANCELADA';
}

class Venda {
  final int? id;
  final int? clienteId;
  final double total;
  final String status; // ver VendaStatus
  final DateTime createdAt;

  Venda({
    this.id,
    this.clienteId,
    required this.total,
    required this.status,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'cliente_id': clienteId,
    'total': total,
    'status': status,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  static Venda fromMap(Map<String, Object?> map) => Venda(
    id: map['id'] as int?,
    clienteId: map['cliente_id'] as int?,
    total: (map['total'] as num).toDouble(),
    status: map['status'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
  );
}

class VendaItem {
  final int? id;
  final int? vendaId;
  final int produtoId;
  final String produtoNome; // para UI (não precisa persistir)
  final double qtd;
  final double precoUnit;

  VendaItem({
    this.id,
    this.vendaId,
    required this.produtoId,
    required this.produtoNome,
    required this.qtd,
    required this.precoUnit,
  });

  double get subtotal => qtd * precoUnit;

  Map<String, Object?> toDbMap({required int vendaId}) => {
    'id': id,
    'venda_id': vendaId,
    'produto_id': produtoId,
    'qtd': qtd,
    'preco_unit': precoUnit,
    'subtotal': subtotal,
  };
}
