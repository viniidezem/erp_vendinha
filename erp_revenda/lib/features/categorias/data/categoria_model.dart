enum CategoriaTipo {
  tipoProduto('TIPO_PRODUTO', 'Tipo de produto'),
  ocasiao('OCASIAO', 'Ocasião'),
  familia('FAMILIA', 'Família Olfativa'),
  propriedade('PROPRIEDADE', 'Propriedades');

  final String db;
  final String label;
  const CategoriaTipo(this.db, this.label);
}

class Categoria {
  final int? id;
  final CategoriaTipo tipo;
  final String nome;
  final DateTime createdAt;

  Categoria({
    this.id,
    required this.tipo,
    required this.nome,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'tipo': tipo.db,
    'nome': nome,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  static Categoria fromMap(Map<String, Object?> map) {
    final tipoDb = map['tipo'] as String;
    final tipo = CategoriaTipo.values.firstWhere((e) => e.db == tipoDb);
    return Categoria(
      id: map['id'] as int?,
      tipo: tipo,
      nome: map['nome'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
