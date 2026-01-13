class Fornecedor {
  final int? id;
  final String nome;
  final String? telefone;
  final String? email;
  final DateTime createdAt;

  Fornecedor({
    this.id,
    required this.nome,
    this.telefone,
    this.email,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'nome': nome,
    'telefone': telefone,
    'email': email,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  static Fornecedor fromMap(Map<String, Object?> map) => Fornecedor(
    id: map['id'] as int?,
    nome: map['nome'] as String,
    telefone: map['telefone'] as String?,
    email: map['email'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
  );
}
