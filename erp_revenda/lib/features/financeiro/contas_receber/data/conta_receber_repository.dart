import 'package:sqflite/sqflite.dart';

import '../../../../data/db/app_database.dart';
import 'conta_receber_model.dart';

class ContaReceberRepository {
  final AppDatabase _db;
  ContaReceberRepository(this._db);

  Future<List<ContaReceber>> listar({
    String search = '',
    String? statusFiltro,
    bool somenteAbertas = false,
  }) async {
    final Database db = await _db.database;

    final whereParts = <String>[];
    final args = <Object?>[];

    if (somenteAbertas) {
      whereParts.add('cr.status = ?');
      args.add(ContaReceberStatus.aberta);
    } else if (statusFiltro != null && statusFiltro.isNotEmpty) {
      whereParts.add('cr.status = ?');
      args.add(statusFiltro);
    }

    final q = search.trim();
    if (q.isNotEmpty) {
      whereParts.add(
        '(c.nome LIKE ? OR CAST(cr.venda_id AS TEXT) LIKE ?)',
      );
      args.add('%$q%');
      args.add('%$q%');
    }

    final whereSql = whereParts.isEmpty ? '' : 'WHERE ${whereParts.join(' AND ')}';

    final rows = await db.rawQuery('''
      SELECT 
        cr.*,
        v.cliente_id,
        c.nome AS cliente_nome
      FROM contas_receber cr
      LEFT JOIN vendas v ON v.id = cr.venda_id
      LEFT JOIN clientes c ON c.id = v.cliente_id
      $whereSql
      ORDER BY COALESCE(cr.vencimento_at, cr.created_at) ASC, cr.id ASC
    ''', args);

    return rows.map((e) => ContaReceber.fromMap(e)).toList();
  }

  Future<void> atualizarStatus({
    required int id,
    required String status,
    double? valorRecebido,
  }) async {
    final db = await _db.database;
    final values = <String, Object?>{
      'status': status,
    };
    if (valorRecebido != null) {
      values['valor_recebido'] = valorRecebido;
    } else if (status == ContaReceberStatus.cancelada) {
      values['valor_recebido'] = 0;
    }
    await db.update(
      'contas_receber',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
