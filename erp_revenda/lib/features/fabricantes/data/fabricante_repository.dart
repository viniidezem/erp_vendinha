
import 'package:sqflite/sqflite.dart';
import '../../../data/db/app_database.dart';
import 'fabricante_model.dart';

class FabricanteRepository {
  final AppDatabase _db;
  FabricanteRepository(this._db);

  Future<List<Fabricante>> listar() async {
    final Database db = await _db.database;
    final rows = await db.query('fabricantes', orderBy: 'nome COLLATE NOCASE ASC');
    return rows.map((e) => Fabricante.fromMap(e)).toList();
  }

  Future<int> inserir(String nome) async {
    final db = await _db.database;
    final f = Fabricante(nome: nome.trim(), createdAt: DateTime.now());
    return db.insert('fabricantes', f.toMap());
  }
}
