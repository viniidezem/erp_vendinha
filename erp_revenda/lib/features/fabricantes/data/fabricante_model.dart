
class Fabricante {
  final int? id;
  final String nome;
  final DateTime createdAt;

  Fabricante({
    this.id,
    required this.nome,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'nome': nome,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  static Fabricante fromMap(Map<String, Object?> map) => Fabricante(
        id: map['id'] as int?,
        nome: map['nome'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );
}
