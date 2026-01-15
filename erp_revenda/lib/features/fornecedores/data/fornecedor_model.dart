class Fornecedor {
  final int? id;
  final String nome;
  final String? telefone;
  final String? email;
  final String? contatoNome;
  final String? contatoTelefone;
  final DateTime createdAt;

  Fornecedor({
    this.id,
    required this.nome,
    this.telefone,
    this.email,
    this.contatoNome,
    this.contatoTelefone,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'nome': nome,
    'telefone': telefone,
    'email': email,
    'contato_nome': contatoNome,
    'contato_telefone': contatoTelefone,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  static Fornecedor fromMap(Map<String, Object?> map) => Fornecedor(
    id: map['id'] as int?,
    nome: map['nome'] as String,
    telefone: map['telefone'] as String?,
    email: map['email'] as String?,
    contatoNome: map['contato_nome'] as String?,
    contatoTelefone: map['contato_telefone'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
  );
}
