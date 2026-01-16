import 'package:sqflite/sqflite.dart';

import '../../../../data/db/app_database.dart';
import 'conta_pagar_model.dart';

class ContaPagarRepository {
  final AppDatabase _db;
  ContaPagarRepository(this._db);

  Future<List<ContaPagar>> listar({
    String search = '',
    String? statusFiltro,
    bool somenteAbertas = false,
  }) async {
    final Database db = await _db.database;

    final whereParts = <String>[];
    final args = <Object?>[];

    if (somenteAbertas) {
      whereParts.add('cp.status = ?');
      args.add(ContaPagarStatus.aberta);
    } else if (statusFiltro != null && statusFiltro.isNotEmpty) {
      whereParts.add('cp.status = ?');
      args.add(statusFiltro);
    }

    final q = search.trim();
    if (q.isNotEmpty) {
      whereParts.add('(f.nome LIKE ? OR cp.descricao LIKE ?)');
      args.add('%$q%');
      args.add('%$q%');
    }

    final whereSql = whereParts.isEmpty ? '' : 'WHERE ${whereParts.join(' AND ')}';

    final rows = await db.rawQuery('''
      SELECT 
        cp.*,
        f.nome AS fornecedor_nome
      FROM contas_pagar cp
      LEFT JOIN fornecedores f ON f.id = cp.fornecedor_id
      $whereSql
      ORDER BY COALESCE(cp.vencimento_at, cp.created_at) ASC, cp.id ASC
    ''', args);

    return rows.map((e) => ContaPagar.fromMap(e)).toList();
  }

  Future<void> criarLancamento({
    int? entradaId,
    required int fornecedorId,
    required double total,
    required int parcelas,
    String? descricao,
    List<DateTime?>? vencimentos,
  }) async {
    final db = await _db.database;

    if (total <= 0) {
      throw ArgumentError('Valor total invalido.');
    }

    if (entradaId != null) {
      final exists = await existeParaEntrada(entradaId);
      if (exists) {
        throw StateError('Contas a pagar ja geradas para esta entrada.');
      }
    }

    final parcelasSafe = parcelas < 1 ? 1 : parcelas;
    final totalFinal = _round2(total);
    final totalCents = (totalFinal * 100).round();
    final baseCents = totalCents ~/ parcelasSafe;
    final residual = totalCents % parcelasSafe;

    final createdAtMs = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      for (var i = 1; i <= parcelasSafe; i++) {
        final cents = baseCents + (i == 1 ? residual : 0);
        final valor = cents / 100.0;
        final vencimento = (vencimentos != null && (i - 1) < vencimentos.length)
            ? vencimentos[i - 1]
            : null;

        await txn.insert('contas_pagar', {
          'entrada_id': entradaId,
          'fornecedor_id': fornecedorId,
          'descricao': descricao,
          'total': totalFinal,
          'parcela_numero': i,
          'parcelas_total': parcelasSafe,
          'valor': valor,
          'status': ContaPagarStatus.aberta,
          'vencimento_at': vencimento?.millisecondsSinceEpoch,
          'pago_at': null,
          'created_at': createdAtMs,
        });
      }
    });
  }

  Future<bool> existeParaEntrada(int entradaId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(1) AS c FROM contas_pagar WHERE entrada_id = ?',
      [entradaId],
    );
    final count = (rows.first['c'] as int?) ?? 0;
    return count > 0;
  }

  Future<void> atualizarStatus({
    required int id,
    required String status,
  }) async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'contas_pagar',
      {
        'status': status,
        'pago_at': status == ContaPagarStatus.paga ? now : null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static double _round2(double v) => (v * 100).round() / 100.0;
}
