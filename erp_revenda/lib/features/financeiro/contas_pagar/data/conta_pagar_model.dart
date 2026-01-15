class ContaPagarStatus {
  static const aberta = 'ABERTA';
  static const paga = 'PAGA';
  static const cancelada = 'CANCELADA';

  static String label(String status) {
    switch (status) {
      case aberta:
        return 'Aberta';
      case paga:
        return 'Paga';
      case cancelada:
        return 'Cancelada';
      default:
        return status;
    }
  }

  static const List<String> filtros = [aberta, paga, cancelada];
}

class ContaPagar {
  final int? id;
  final int? entradaId;
  final int fornecedorId;
  final String fornecedorNome;
  final String? descricao;
  final double total;
  final int parcelaNumero;
  final int parcelasTotal;
  final double valor;
  final String status;
  final DateTime? vencimentoAt;
  final DateTime? pagoAt;
  final DateTime createdAt;

  const ContaPagar({
    this.id,
    this.entradaId,
    required this.fornecedorId,
    required this.fornecedorNome,
    this.descricao,
    required this.total,
    required this.parcelaNumero,
    required this.parcelasTotal,
    required this.valor,
    required this.status,
    required this.createdAt,
    this.vencimentoAt,
    this.pagoAt,
  });

  bool get isVencida {
    if (status != ContaPagarStatus.aberta) return false;
    if (vencimentoAt == null) return false;
    return vencimentoAt!.isBefore(DateTime.now());
  }

  static ContaPagar fromMap(Map<String, Object?> map) {
    return ContaPagar(
      id: map['id'] as int?,
      entradaId: map['entrada_id'] as int?,
      fornecedorId: map['fornecedor_id'] as int,
      fornecedorNome: (map['fornecedor_nome'] as String?) ?? 'Fornecedor',
      descricao: map['descricao'] as String?,
      total: (map['total'] as num?)?.toDouble() ?? 0,
      parcelaNumero: map['parcela_numero'] as int? ?? 1,
      parcelasTotal: map['parcelas_total'] as int? ?? 1,
      valor: (map['valor'] as num?)?.toDouble() ?? 0,
      status: (map['status'] as String?) ?? ContaPagarStatus.aberta,
      vencimentoAt: map['vencimento_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['vencimento_at'] as int),
      pagoAt: map['pago_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['pago_at'] as int),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
