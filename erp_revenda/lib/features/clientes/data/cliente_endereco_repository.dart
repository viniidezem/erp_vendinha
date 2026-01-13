import 'package:sqflite/sqflite.dart';
import '../../../data/db/app_database.dart';
import 'cliente_endereco_model.dart';

class ClienteEnderecoRepository {
  final AppDatabase _db;
  ClienteEnderecoRepository(this._db);

  Future<List<ClienteEndereco>> listarPorCliente(int clienteId) async {
    final Database db = await _db.database;
    final rows = await db.query(
      'cliente_enderecos',
      where: 'cliente_id = ?',
      whereArgs: [clienteId],
      orderBy: 'principal DESC, created_at DESC',
    );
    return rows.map((e) => ClienteEndereco.fromMap(e)).toList();
  }

  Future<int> inserir(ClienteEndereco endereco) async {
    final db = await _db.database;

    return db.transaction<int>((txn) async {
      if (endereco.principal) {
        await txn.update(
          'cliente_enderecos',
          {'principal': 0},
          where: 'cliente_id = ?',
          whereArgs: [endereco.clienteId],
        );
      }
      return txn.insert('cliente_enderecos', endereco.toMap());
    });
  }

  Future<int> atualizar(ClienteEndereco endereco) async {
    final db = await _db.database;
    if (endereco.id == null) {
      throw ArgumentError('Endereco.id não pode ser nulo ao atualizar.');
    }

    return db.transaction<int>((txn) async {
      if (endereco.principal) {
        await txn.update(
          'cliente_enderecos',
          {'principal': 0},
          where: 'cliente_id = ?',
          whereArgs: [endereco.clienteId],
        );
      }
      return txn.update(
        'cliente_enderecos',
        endereco.toMap(),
        where: 'id = ?',
        whereArgs: [endereco.id],
      );
    });
  }

  Future<int> remover(int id) async {
    final db = await _db.database;
    return db.delete('cliente_enderecos', where: 'id = ?', whereArgs: [id]);
  }
}
