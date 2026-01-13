import 'package:sqflite/sqflite.dart';
import '../../../data/db/app_database.dart';
import 'categoria_model.dart';

class CategoriaRepository {
  final AppDatabase _db;
  CategoriaRepository(this._db);

  Future<List<Categoria>> listarPorTipo(CategoriaTipo tipo) async {
    final Database db = await _db.database;
    final rows = await db.query(
      'categorias',
      where: 'tipo = ?',
      whereArgs: [tipo.db],
      orderBy: 'nome COLLATE NOCASE ASC',
    );
    return rows.map((e) => Categoria.fromMap(e)).toList();
  }

  Future<int> inserir(CategoriaTipo tipo, String nome) async {
    final Database db = await _db.database;
    final cat = Categoria(
      tipo: tipo,
      nome: nome.trim(),
      createdAt: DateTime.now(),
    );
    return db.insert('categorias', cat.toMap());
  }
}
