class FormaPagamento {
  final int? id;
  final String nome;
  final bool permiteDesconto;
  final bool permiteParcelamento;
  final bool permiteInformarVencimento;
  final int maxParcelas;
  final bool ativo;
  final DateTime createdAt;

  const FormaPagamento({
    this.id,
    required this.nome,
    required this.permiteDesconto,
    required this.permiteParcelamento,
    required this.permiteInformarVencimento,
    required this.maxParcelas,
    required this.ativo,
    required this.createdAt,
  });

  FormaPagamento copyWith({
    int? id,
    String? nome,
    bool? permiteDesconto,
    bool? permiteParcelamento,
    bool? permiteInformarVencimento,
    int? maxParcelas,
    bool? ativo,
    DateTime? createdAt,
  }) {
    return FormaPagamento(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      permiteDesconto: permiteDesconto ?? this.permiteDesconto,
      permiteParcelamento: permiteParcelamento ?? this.permiteParcelamento,
      permiteInformarVencimento: permiteInformarVencimento ?? this.permiteInformarVencimento,
      maxParcelas: maxParcelas ?? this.maxParcelas,
      ativo: ativo ?? this.ativo,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'nome': nome,
        'permite_desconto': permiteDesconto ? 1 : 0,
        'permite_parcelamento': permiteParcelamento ? 1 : 0,
        'permite_vencimento': permiteInformarVencimento ? 1 : 0,
        'max_parcelas': maxParcelas,
        'ativo': ativo ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  static FormaPagamento fromMap(Map<String, Object?> map) {
    return FormaPagamento(
      id: map['id'] as int?,
      nome: (map['nome'] as String?) ?? '',
      permiteDesconto: (map['permite_desconto'] as int? ?? 0) == 1,
      permiteParcelamento: (map['permite_parcelamento'] as int? ?? 0) == 1,
      permiteInformarVencimento: (map['permite_vencimento'] as int? ?? 0) == 1,
      maxParcelas: map['max_parcelas'] as int? ?? 1,
      ativo: (map['ativo'] as int? ?? 1) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int? ?? 0,
      ),
    );
  }

  @override
  String toString() {
    final parc = permiteParcelamento ? 'até $maxParcelas x' : 'sem parcelas';
    final desc = permiteDesconto ? 'desc ok' : 'sem desc';
    final venc = permiteInformarVencimento ? 'venc ok' : 'sem venc';
    final a = ativo ? 'ativo' : 'inativo';
    return 'FormaPagamento(id=$id, nome=$nome, $parc, $desc, $venc, $a)';
  }
}
