enum ClienteStatus {
  ativo('ATIVO', 'Ativo'),
  inativo('INATIVO', 'Inativo'),
  bloqueado('BLOQUEADO', 'Bloqueado');

  final String dbValue;
  final String label;
  const ClienteStatus(this.dbValue, this.label);

  static ClienteStatus fromDb(String? v) {
    return ClienteStatus.values.firstWhere(
      (e) => e.dbValue == v,
      orElse: () => ClienteStatus.ativo,
    );
  }
}

class Cliente {
  final int? id;
  final String nome; // Nome Completo
  final String? apelido;
  final String? telefone;
  final bool telefoneWhatsapp;
  final String? cpf;
  final String? email;
  final ClienteStatus status;
  final DateTime createdAt;
  final DateTime? ultimaCompraAt;

  Cliente({
    this.id,
    required this.nome,
    this.apelido,
    this.telefone,
    required this.telefoneWhatsapp,
    this.cpf,
    this.email,
    required this.status,
    required this.createdAt,
    this.ultimaCompraAt,
  });

  Cliente copyWith({
    int? id,
    String? nome,
    String? apelido,
    String? telefone,
    bool? telefoneWhatsapp,
    String? cpf,
    String? email,
    ClienteStatus? status,
    DateTime? createdAt,
    DateTime? ultimaCompraAt,
  }) {
    return Cliente(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      apelido: apelido ?? this.apelido,
      telefone: telefone ?? this.telefone,
      telefoneWhatsapp: telefoneWhatsapp ?? this.telefoneWhatsapp,
      cpf: cpf ?? this.cpf,
      email: email ?? this.email,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      ultimaCompraAt: ultimaCompraAt ?? this.ultimaCompraAt,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'nome': nome,
    'apelido': apelido,
    'telefone': telefone,
    'telefone_whatsapp': telefoneWhatsapp ? 1 : 0,
    'cpf': cpf,
    'email': email,
    'status': status.dbValue,
    'created_at': createdAt.millisecondsSinceEpoch,
    'ultima_compra_at': ultimaCompraAt?.millisecondsSinceEpoch,
  };

  static Cliente fromMap(Map<String, Object?> map) {
    return Cliente(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      apelido: map['apelido'] as String?,
      telefone: map['telefone'] as String?,
      telefoneWhatsapp: (map['telefone_whatsapp'] as int? ?? 0) == 1,
      cpf: map['cpf'] as String?,
      email: map['email'] as String?,
      status: ClienteStatus.fromDb(map['status'] as String?),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      ultimaCompraAt: map['ultima_compra_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['ultima_compra_at'] as int),
    );
  }
}
