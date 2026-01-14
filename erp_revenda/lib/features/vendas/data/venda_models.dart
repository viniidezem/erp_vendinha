class VendaStatus {
  // Rascunho / carrinho em andamento (ainda não confirmado como pedido)
  static const aberta = 'ABERTA';

  // Pedido confirmado (aguardando expedição/entrega)
  static const pedido = 'PEDIDO';

  // Pedido aguardando reposição/chegada de mercadoria
  static const aguardandoMercadoria = 'AGUARDANDO_MERCADORIA';

  // Reservado para próxima etapa (expedição/entrega)
  static const emExpedicao = 'EM_EXPEDICAO';
  static const entregue = 'ENTREGUE';

  // Compatibilidade com versões anteriores
  static const finalizada = 'FINALIZADA';

  static const cancelada = 'CANCELADA';

  static String label(String status) {
    switch (status) {
      case aberta:
        return 'Aberta';
      case pedido:
        return 'Pedido';
      case aguardandoMercadoria:
        return 'Aguardando mercadoria';
      case emExpedicao:
        return 'Em expedição';
      case entregue:
        return 'Entregue';
      case cancelada:
        return 'Cancelada';
      case finalizada:
        return 'Finalizada';
      default:
        return status;
    }
  }

  static const List<String> fluxoOperacional = [
    pedido,
    aguardandoMercadoria,
    emExpedicao,
    entregue,
    cancelada,
  ];
}

class Venda {
  final int? id;
  final int? clienteId;
  final String? clienteNome;
  final double total;
  final String status; // ver VendaStatus
  final DateTime createdAt;

  Venda({
    this.id,
    this.clienteId,
    this.clienteNome,
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
    clienteNome: map['cliente_nome'] as String?,
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


class VendaStatusLog {
  final int? id;
  final int vendaId;
  final String status;
  final String? obs;
  final DateTime createdAt;

  VendaStatusLog({
    this.id,
    required this.vendaId,
    required this.status,
    this.obs,
    required this.createdAt,
  });

  static VendaStatusLog fromMap(Map<String, Object?> map) => VendaStatusLog(
        id: map['id'] as int?,
        vendaId: map['venda_id'] as int,
        status: map['status'] as String,
        obs: map['obs'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );
}

class PedidoDetalhe {
  final Venda venda;
  final List<VendaItem> itens;
  final List<VendaStatusLog> historico;

  const PedidoDetalhe({
    required this.venda,
    required this.itens,
    required this.historico,
  });

  double get total => venda.total;
}
