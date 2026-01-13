class Produto {
  final int? id;
  final String nome;
  final double precoVenda;
  final double estoque;
  final bool ativo;
  final DateTime createdAt;

  Produto({
    this.id,
    required this.nome,
    required this.precoVenda,
    required this.estoque,
    required this.ativo,
    required this.createdAt,
  });

  Produto copyWith({
    int? id,
    String? nome,
    double? precoVenda,
    double? estoque,
    bool? ativo,
    DateTime? createdAt,
  }) {
    return Produto(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      precoVenda: precoVenda ?? this.precoVenda,
      estoque: estoque ?? this.estoque,
      ativo: ativo ?? this.ativo,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nome': nome,
      'preco_venda': precoVenda,
      'estoque': estoque,
      'ativo': ativo ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  static Produto fromMap(Map<String, Object?> map) {
    return Produto(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      precoVenda: (map['preco_venda'] as num).toDouble(),
      estoque: (map['estoque'] as num).toDouble(),
      ativo: (map['ativo'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
