class ClienteEndereco {
  final int? id;
  final int clienteId;
  final String? rotulo; // ex: Casa, Trabalho
  final String? cep;
  final String? logradouro;
  final String? numero;
  final String? complemento;
  final String? bairro;
  final String? cidade;
  final String? uf;
  final bool principal;
  final DateTime createdAt;

  ClienteEndereco({
    this.id,
    required this.clienteId,
    this.rotulo,
    this.cep,
    this.logradouro,
    this.numero,
    this.complemento,
    this.bairro,
    this.cidade,
    this.uf,
    required this.principal,
    required this.createdAt,
  });

  ClienteEndereco copyWith({
    int? id,
    int? clienteId,
    String? rotulo,
    String? cep,
    String? logradouro,
    String? numero,
    String? complemento,
    String? bairro,
    String? cidade,
    String? uf,
    bool? principal,
    DateTime? createdAt,
  }) {
    return ClienteEndereco(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      rotulo: rotulo ?? this.rotulo,
      cep: cep ?? this.cep,
      logradouro: logradouro ?? this.logradouro,
      numero: numero ?? this.numero,
      complemento: complemento ?? this.complemento,
      bairro: bairro ?? this.bairro,
      cidade: cidade ?? this.cidade,
      uf: uf ?? this.uf,
      principal: principal ?? this.principal,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'cliente_id': clienteId,
    'rotulo': rotulo,
    'cep': cep,
    'logradouro': logradouro,
    'numero': numero,
    'complemento': complemento,
    'bairro': bairro,
    'cidade': cidade,
    'uf': uf,
    'principal': principal ? 1 : 0,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  static ClienteEndereco fromMap(Map<String, Object?> map) {
    return ClienteEndereco(
      id: map['id'] as int?,
      clienteId: map['cliente_id'] as int,
      rotulo: map['rotulo'] as String?,
      cep: map['cep'] as String?,
      logradouro: map['logradouro'] as String?,
      numero: map['numero'] as String?,
      complemento: map['complemento'] as String?,
      bairro: map['bairro'] as String?,
      cidade: map['cidade'] as String?,
      uf: map['uf'] as String?,
      principal: (map['principal'] as int? ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  String resumo() {
    final parts = <String>[];
    if ((logradouro ?? '').trim().isNotEmpty) parts.add(logradouro!.trim());
    if ((numero ?? '').trim().isNotEmpty) parts.add(numero!.trim());
    if ((bairro ?? '').trim().isNotEmpty) parts.add(bairro!.trim());
    if ((cidade ?? '').trim().isNotEmpty) parts.add(cidade!.trim());
    if ((uf ?? '').trim().isNotEmpty) parts.add(uf!.trim());
    if ((cep ?? '').trim().isNotEmpty) parts.add('CEP ${cep!.trim()}');
    return parts.join(' • ');
  }
}
