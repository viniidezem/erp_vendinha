import 'package:sqflite/sqflite.dart';
import '../../../data/db/app_database.dart';
import 'cliente_model.dart';
import '../../../shared/plan/app_plan.dart';

class ClienteRepository {
  final AppDatabase _db;
  ClienteRepository(this._db);

  Future<List<Cliente>> listar({
    String search = '',
    bool onlyActive = true,
  }) async {
    final Database db = await _db.database;

    final whereParts = <String>[];
    final args = <Object?>[];

    if (onlyActive) {
      whereParts.add("status = ?");
      args.add(ClienteStatus.ativo.dbValue);
    }

    final term = search.trim();
    if (term.isNotEmpty) {
      whereParts.add(
        "(LOWER(nome) LIKE LOWER(?) OR LOWER(apelido) LIKE LOWER(?))",
      );
      args.add('%$term%');
      args.add('%$term%');
    }

    final where = whereParts.isEmpty ? null : whereParts.join(' AND ');

    final rows = await db.query(
      'clientes',
      where: where,
      whereArgs: where == null ? null : args,
      orderBy: 'nome COLLATE NOCASE ASC',
    );

    return rows.map((e) => Cliente.fromMap(e)).toList();
  }

  Future<int> inserir(Cliente cliente) async {
    final db = await _db.database;
    final plan = await carregarAppPlan(db);
    await validarLimitePlano(
      db,
      max: plan.maxClientes,
      table: 'clientes',
      label: 'clientes',
    );
    return db.insert('clientes', cliente.toMap());
  }

  Future<int> atualizar(Cliente cliente) async {
    final db = await _db.database;
    if (cliente.id == null) {
      throw ArgumentError('Cliente.id não pode ser nulo ao atualizar.');
    }
    return db.update(
      'clientes',
      cliente.toMap(),
      where: 'id = ?',
      whereArgs: [cliente.id],
    );
  }

  Future<void> atualizarUltimaCompra(int clienteId, DateTime dt) async {
    final db = await _db.database;
    await db.update(
      'clientes',
      {'ultima_compra_at': dt.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [clienteId],
    );
  }
}
