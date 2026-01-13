
import 'package:sqflite/sqflite.dart';
import '../../../data/db/app_database.dart';
import 'produto_model.dart';

class ProdutoRepository {
  final AppDatabase _db;
  ProdutoRepository(this._db);

  Future<List<Produto>> listar({
    String search = '',
    bool onlyActive = true,
    bool onlyWithStock = false,
  }) async {
    final Database db = await _db.database;

    final whereParts = <String>[];
    final args = <Object?>[];

    if (onlyActive) {
      whereParts.add('ativo = 1');
    }
    if (onlyWithStock) {
      whereParts.add('estoque > 0');
    }

    final term = search.trim();
    if (term.isNotEmpty) {
      whereParts.add('(LOWER(nome) LIKE LOWER(?) OR LOWER(ref_codigo) LIKE LOWER(?))');
      args.add('%$term%');
      args.add('%$term%');
    }

    final where = whereParts.isEmpty ? null : whereParts.join(' AND ');

    final rows = await db.query(
      'produtos',
      where: where,
      whereArgs: where == null ? null : args,
      orderBy: 'nome COLLATE NOCASE ASC',
    );

    return rows.map((e) => Produto.fromMap(e)).toList();
  }

  /// Compatibilidade com versões anteriores
  Future<List<Produto>> listarTodos() async {
    return listar(search: '', onlyActive: true, onlyWithStock: false);
  }

  Future<int> inserir(Produto p, {List<int> propriedadesIds = const []}) async {
    final db = await _db.database;

    return db.transaction<int>((txn) async {
      final id = await txn.insert('produtos', p.toMap());

      for (final catId in propriedadesIds) {
        await txn.insert('produto_propriedades', {'produto_id': id, 'categoria_id': catId});
      }

      return id;
    });
  }

  Future<int> atualizar(Produto p, {List<int> propriedadesIds = const []}) async {
    final db = await _db.database;
    if (p.id == null) {
      throw ArgumentError('Produto.id não pode ser nulo ao atualizar.');
    }

    return db.transaction<int>((txn) async {
      final count = await txn.update(
        'produtos',
        p.toMap(),
        where: 'id = ?',
        whereArgs: [p.id],
      );

      await txn.delete('produto_propriedades', where: 'produto_id = ?', whereArgs: [p.id]);

      for (final catId in propriedadesIds) {
        await txn.insert('produto_propriedades', {'produto_id': p.id, 'categoria_id': catId});
      }

      return count;
    });
  }

  Future<List<int>> listarPropriedadesIds(int produtoId) async {
    final db = await _db.database;
    final rows = await db.query(
      'produto_propriedades',
      columns: ['categoria_id'],
      where: 'produto_id = ?',
      whereArgs: [produtoId],
    );
    return rows.map((e) => e['categoria_id'] as int).toList();
  }

  Future<void> ajustarEstoque({required int id, required double delta}) async {
    final db = await _db.database;
    await db.rawUpdate('UPDATE produtos SET estoque = estoque + ? WHERE id = ?', [delta, id]);
  }
}
