import 'package:sqflite/sqflite.dart';

import '../../../data/db/app_database.dart';
import 'produto_model.dart';

class ProdutoRepository {
  final AppDatabase _db;

  ProdutoRepository(this._db);

  Future<List<Produto>> listarTodos({bool incluirInativos = false}) async {
    final Database db = await _db.database;

    final where = incluirInativos ? null : 'ativo = 1';
    final rows = await db.query(
      'produtos',
      where: where,
      orderBy: 'nome COLLATE NOCASE ASC',
    );

    return rows.map((e) => Produto.fromMap(e)).toList();
  }

  Future<int> inserir(Produto produto) async {
    final Database db = await _db.database;
    return db.insert('produtos', produto.toMap());
  }

  Future<int> atualizar(Produto produto) async {
    final Database db = await _db.database;
    if (produto.id == null) {
      throw ArgumentError('Produto.id não pode ser nulo ao atualizar.');
    }

    return db.update(
      'produtos',
      produto.toMap(),
      where: 'id = ?',
      whereArgs: [produto.id],
    );
  }

  Future<int> excluir(int id) async {
    final Database db = await _db.database;
    return db.delete('produtos', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> ajustarEstoque({required int id, required double delta}) async {
    final Database db = await _db.database;

    // Atualiza em SQL para evitar race conditions e manter atomicidade
    await db.rawUpdate(
      'UPDATE produtos SET estoque = estoque + ? WHERE id = ?',
      [delta, id],
    );
  }
}
