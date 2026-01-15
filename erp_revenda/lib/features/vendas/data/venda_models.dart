class VendaEntregaTipo {
  static const entrega = 'ENTREGA';
  static const retirada = 'RETIRADA';

  static String label(String tipo) {
    switch (tipo) {
      case entrega:
        return 'Entrega';
      case retirada:
        return 'Retirada / sem entrega';
      default:
        return tipo;
    }
  }
}

class VendaStatus {
  // Rascunho / carrinho em andamento (ainda não confirmado como pedido)
  static const aberta = 'ABERTA';

  // Pedido confirmado
  static const pedido = 'PEDIDO';

  // Pagamento
  static const aguardandoPagamento = 'AGUARDANDO_PAGAMENTO';
  static const pagamentoEfetuado = 'PAGAMENTO_EFETUADO';

  // Operacional / expedição
  static const aguardandoMercadoria = 'AGUARDANDO_MERCADORIA';
  static const emExpedicao = 'EM_EXPEDICAO';
  static const entregue = 'ENTREGUE';

  // Finalização
  static const finalizado = 'FINALIZADO';

  // Compatibilidade com versões anteriores
  static const finalizada = 'FINALIZADA';

  static const cancelada = 'CANCELADA';

  static String label(String status) {
    switch (status) {
      case aberta:
        return 'Aberta';
      case pedido:
        return 'Pedido';
      case aguardandoPagamento:
        return 'Aguardando pagamento';
      case pagamentoEfetuado:
        return 'Pagamento efetuado';
      case aguardandoMercadoria:
        return 'Aguardando mercadoria';
      case emExpedicao:
        return 'Em expedição';
      case entregue:
        return 'Entregue';
      case finalizado:
        return 'Finalizado';
      case cancelada:
        return 'Cancelada';
      case finalizada:
        return 'Finalizada';
      default:
        return status;
    }
  }

  /// Ordem sugerida de etapas mais comuns.
  /// Observação: não é uma regra rígida; a UI pode permitir ajustes manuais.
  static const List<String> fluxoOperacional = [
    pedido,
    aguardandoPagamento,
    pagamentoEfetuado,
    aguardandoMercadoria,
    emExpedicao,
    entregue,
    finalizado,
    cancelada,
  ];

  /// Status considerados "abertos" (não concluídos).
  static const List<String> abertos = [
    pedido,
    aguardandoPagamento,
    pagamentoEfetuado,
    aguardandoMercadoria,
    emExpedicao,
  ];

  /// Status mostrados em filtros/seletores padrÇœo.
  static const List<String> filtros = fluxoOperacional;

  static bool isAberto(String status) => abertos.contains(status);
}

class Venda {
  final int? id;
  final int? clienteId;
  final String? clienteNome;
  final double total;
  final String status; // ver VendaStatus
  final DateTime createdAt;

  // Checkout / entrega / pagamento
  final double descontoValor;
  final double? descontoPercentual;
  final String entregaTipo; // ver VendaEntregaTipo
  final int? enderecoEntregaId;
  final int? formaPagamentoId;
  final int? parcelas;
  final String? observacao;

  Venda({
    this.id,
    this.clienteId,
    this.clienteNome,
    required this.total,
    required this.status,
    required this.createdAt,
    this.descontoValor = 0,
    this.descontoPercentual,
    this.entregaTipo = VendaEntregaTipo.entrega,
    this.enderecoEntregaId,
    this.formaPagamentoId,
    this.parcelas,
    this.observacao,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'cliente_id': clienteId,
        'total': total,
        'status': status,
        'created_at': createdAt.millisecondsSinceEpoch,
        'desconto_valor': descontoValor,
        'desconto_percentual': descontoPercentual,
        'entrega_tipo': entregaTipo,
        'endereco_entrega_id': enderecoEntregaId,
        'forma_pagamento_id': formaPagamentoId,
        'parcelas': parcelas,
        'observacao': observacao,
      };

  static Venda fromMap(Map<String, Object?> map) => Venda(
        id: map['id'] as int?,
        clienteId: map['cliente_id'] as int?,
        clienteNome: map['cliente_nome'] as String?,
        total: (map['total'] as num).toDouble(),
        status: map['status'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        descontoValor: (map['desconto_valor'] as num? ?? 0).toDouble(),
        descontoPercentual: (map['desconto_percentual'] as num?)?.toDouble(),
        entregaTipo: (map['entrega_tipo'] as String?) ?? VendaEntregaTipo.entrega,
        enderecoEntregaId: map['endereco_entrega_id'] as int?,
        formaPagamentoId: map['forma_pagamento_id'] as int?,
        parcelas: map['parcelas'] as int?,
        observacao: map['observacao'] as String?,
      );
}

class VendaItem {
  final int? id;
  final int? vendaId;
  final int produtoId;
  final String produtoNome; // para UI (nao precisa persistir)
  final double qtd;
  final double precoUnit;
  final bool isKit;

  VendaItem({
    this.id,
    this.vendaId,
    required this.produtoId,
    required this.produtoNome,
    required this.qtd,
    required this.precoUnit,
    this.isKit = false,
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
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
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
