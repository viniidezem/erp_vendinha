import 'package:sqflite/sqflite.dart';
import '../../../data/db/app_database.dart';
import 'fornecedor_model.dart';

class FornecedorRepository {
  final AppDatabase _db;
  FornecedorRepository(this._db);

  Future<List<Fornecedor>> listar() async {
    final Database db = await _db.database;
    final rows = await db.query(
      'fornecedores',
      orderBy: 'nome COLLATE NOCASE ASC',
    );
    return rows.map((e) => Fornecedor.fromMap(e)).toList();
  }

  Future<int> inserir(String nome, {String? telefone, String? email}) async {
    final db = await _db.database;
    final f = Fornecedor(
      nome: nome.trim(),
      telefone: (telefone ?? '').trim().isEmpty ? null : telefone!.trim(),
      email: (email ?? '').trim().isEmpty ? null : email!.trim(),
      createdAt: DateTime.now(),
    );
    return db.insert('fornecedores', f.toMap());
  }
}
