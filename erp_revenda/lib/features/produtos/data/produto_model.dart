
enum TamanhoUnidade {
  ml('ML', 'ml'),
  g('G', 'g'),
  un('UN', 'un');

  final String db;
  final String label;
  const TamanhoUnidade(this.db, this.label);

  static TamanhoUnidade? fromDb(String? v) {
    if (v == null) return null;
    return TamanhoUnidade.values.firstWhere(
      (e) => e.db == v,
      orElse: () => TamanhoUnidade.ml,
    );
  }
}

class Produto {
  final int? id;
  final String nome;
  final String? refCodigo;

  final int? fabricanteId;
  final int? fornecedorId;

  final double precoCusto;
  final double precoVenda;

  final double? tamanhoValor;
  final TamanhoUnidade? tamanhoUnidade;

  final int? ocasiaoId;
  final int? familiaId;

  final double estoque;
  final bool ativo;
  final DateTime createdAt;

  Produto({
    this.id,
    required this.nome,
    this.refCodigo,
    this.fabricanteId,
    this.fornecedorId,
    required this.precoCusto,
    required this.precoVenda,
    this.tamanhoValor,
    this.tamanhoUnidade,
    this.ocasiaoId,
    this.familiaId,
    required this.estoque,
    required this.ativo,
    required this.createdAt,
  });

  Produto copyWith({
    int? id,
    String? nome,
    String? refCodigo,
    int? fabricanteId,
    int? fornecedorId,
    double? precoCusto,
    double? precoVenda,
    double? tamanhoValor,
    TamanhoUnidade? tamanhoUnidade,
    int? ocasiaoId,
    int? familiaId,
    double? estoque,
    bool? ativo,
    DateTime? createdAt,
  }) {
    return Produto(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      refCodigo: refCodigo ?? this.refCodigo,
      fabricanteId: fabricanteId ?? this.fabricanteId,
      fornecedorId: fornecedorId ?? this.fornecedorId,
      precoCusto: precoCusto ?? this.precoCusto,
      precoVenda: precoVenda ?? this.precoVenda,
      tamanhoValor: tamanhoValor ?? this.tamanhoValor,
      tamanhoUnidade: tamanhoUnidade ?? this.tamanhoUnidade,
      ocasiaoId: ocasiaoId ?? this.ocasiaoId,
      familiaId: familiaId ?? this.familiaId,
      estoque: estoque ?? this.estoque,
      ativo: ativo ?? this.ativo,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'nome': nome,
        'ref_codigo': refCodigo,
        'fabricante_id': fabricanteId,
        'fornecedor_id': fornecedorId,
        'preco_custo': precoCusto,
        'preco_venda': precoVenda,
        'tamanho_valor': tamanhoValor,
        'tamanho_unidade': tamanhoUnidade?.db,
        'ocasiao_id': ocasiaoId,
        'familia_id': familiaId,
        'estoque': estoque,
        'ativo': ativo ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  static Produto fromMap(Map<String, Object?> map) {
    return Produto(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      refCodigo: map['ref_codigo'] as String?,
      fabricanteId: map['fabricante_id'] as int?,
      fornecedorId: map['fornecedor_id'] as int?,
      precoCusto: (map['preco_custo'] as num? ?? 0).toDouble(),
      precoVenda: (map['preco_venda'] as num? ?? 0).toDouble(),
      tamanhoValor: map['tamanho_valor'] == null ? null : (map['tamanho_valor'] as num).toDouble(),
      tamanhoUnidade: TamanhoUnidade.fromDb(map['tamanho_unidade'] as String?),
      ocasiaoId: map['ocasiao_id'] as int?,
      familiaId: map['familia_id'] as int?,
      estoque: (map['estoque'] as num? ?? 0).toDouble(),
      ativo: (map['ativo'] as int? ?? 1) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
