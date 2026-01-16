class ContaReceberStatus {
  static const aberta = 'ABERTA';
  static const recebida = 'RECEBIDA';
  static const cancelada = 'CANCELADA';

  static String label(String status) {
    switch (status) {
      case aberta:
        return 'Aberta';
      case recebida:
        return 'Recebida';
      case cancelada:
        return 'Cancelada';
      default:
        return status;
    }
  }

  static const List<String> filtros = [aberta, recebida, cancelada];
}

class ContaReceber {
  final int? id;
  final int vendaId;
  final int? clienteId;
  final String? clienteNome;
  final String? clienteTelefone;
  final bool clienteWhatsApp;
  final int parcelaNumero;
  final int parcelasTotal;
  final double valor;
  final double valorRecebido;
  final String status;
  final DateTime? vencimentoAt;
  final DateTime createdAt;

  const ContaReceber({
    this.id,
    required this.vendaId,
    this.clienteId,
    this.clienteNome,
    this.clienteTelefone,
    this.clienteWhatsApp = false,
    required this.parcelaNumero,
    required this.parcelasTotal,
    required this.valor,
    required this.valorRecebido,
    required this.status,
    required this.createdAt,
    this.vencimentoAt,
  });

  bool get isVencida {
    if (status != ContaReceberStatus.aberta) return false;
    if (vencimentoAt == null) return false;
    return vencimentoAt!.isBefore(DateTime.now());
  }

  static ContaReceber fromMap(Map<String, Object?> map) {
    return ContaReceber(
      id: map['id'] as int?,
      vendaId: map['venda_id'] as int,
      clienteId: map['cliente_id'] as int?,
      clienteNome: map['cliente_nome'] as String?,
      clienteTelefone: map['cliente_telefone'] as String?,
      clienteWhatsApp: (map['cliente_whatsapp'] as int? ?? 0) == 1,
      parcelaNumero: map['parcela_numero'] as int? ?? 1,
      parcelasTotal: map['parcelas_total'] as int? ?? 1,
      valor: (map['valor'] as num?)?.toDouble() ?? 0,
      valorRecebido: (map['valor_recebido'] as num?)?.toDouble() ?? 0,
      status: (map['status'] as String?) ?? ContaReceberStatus.aberta,
      vencimentoAt: map['vencimento_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['vencimento_at'] as int),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
