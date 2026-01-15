import 'package:sqflite/sqflite.dart';

import '../../../data/db/app_database.dart';
import 'entrada_models.dart';

class EntradaRepository {
  final AppDatabase _db;
  EntradaRepository(this._db);

  Future<List<Entrada>> listarEntradas({
    String search = '',
    String? statusFiltro,
  }) async {
    final Database db = await _db.database;

    final whereParts = <String>[];
    final args = <Object?>[];

    if (statusFiltro != null && statusFiltro.isNotEmpty) {
      whereParts.add('e.status = ?');
      args.add(statusFiltro);
    }

    final q = search.trim();
    if (q.isNotEmpty) {
      whereParts.add('(f.nome LIKE ? OR e.numero_nota LIKE ?)');
      args.add('%$q%');
      args.add('%$q%');
    }

    final whereSql = whereParts.isEmpty ? '' : 'WHERE ${whereParts.join(' AND ')}';

    final rows = await db.rawQuery('''
      SELECT 
        e.*,
        f.nome AS fornecedor_nome
      FROM entradas e
      LEFT JOIN fornecedores f ON f.id = e.fornecedor_id
      $whereSql
      ORDER BY e.data_entrada DESC, e.id DESC
    ''', args);

    return rows.map((e) => Entrada.fromMap(e)).toList();
  }

  Future<EntradaDetalhe> carregarDetalhe(int entradaId) async {
    final db = await _db.database;

    final entradaRows = await db.rawQuery('''
      SELECT 
        e.*,
        f.nome AS fornecedor_nome
      FROM entradas e
      LEFT JOIN fornecedores f ON f.id = e.fornecedor_id
      WHERE e.id = ?
      LIMIT 1
    ''', [entradaId]);

    if (entradaRows.isEmpty) {
      throw StateError('Entrada nao encontrada: $entradaId');
    }

    final entrada = Entrada.fromMap(entradaRows.first);

    final itensRows = await db.rawQuery('''
      SELECT 
        ei.*,
        p.nome AS produto_nome
      FROM entrada_itens ei
      LEFT JOIN produtos p ON p.id = ei.produto_id
      WHERE ei.entrada_id = ?
      ORDER BY ei.id ASC
    ''', [entradaId]);

    final itens = itensRows
        .map(
          (m) => EntradaItem(
            id: m['id'] as int?,
            entradaId: m['entrada_id'] as int?,
            produtoId: m['produto_id'] as int,
            produtoNome: (m['produto_nome'] as String?) ?? 'Produto',
            qtd: (m['qtd'] as num).toDouble(),
            custoUnit: (m['custo_unit'] as num).toDouble(),
          ),
        )
        .toList();

    return EntradaDetalhe(entrada: entrada, itens: itens);
  }

  Future<int> salvarEntrada({
    int? entradaId,
    required Entrada entrada,
    required List<EntradaItem> itens,
    required bool confirmar,
    required bool atualizarCusto,
  }) async {
    final db = await _db.database;

    if (itens.isEmpty) {
      throw ArgumentError('Adicione pelo menos um item.');
    }

    return db.transaction<int>((txn) async {
      String? previousStatus;
      int? createdAtMs;

      if (entradaId != null) {
        final prevRows = await txn.query(
          'entradas',
          columns: ['status', 'created_at'],
          where: 'id = ?',
          whereArgs: [entradaId],
          limit: 1,
        );
        if (prevRows.isNotEmpty) {
          previousStatus = prevRows.first['status'] as String?;
          createdAtMs = prevRows.first['created_at'] as int?;
        }
      }

      if (previousStatus == EntradaStatus.confirmada) {
        throw StateError('Entrada ja confirmada. Edicao bloqueada.');
      }

      final statusFinal =
          confirmar ? EntradaStatus.confirmada : EntradaStatus.rascunho;

      final entradaMap = <String, Object?>{
        'fornecedor_id': entrada.fornecedorId,
        'data_nota': entrada.dataNota?.millisecondsSinceEpoch,
        'data_entrada': entrada.dataEntrada.millisecondsSinceEpoch,
        'numero_nota': entrada.numeroNota,
        'observacao': entrada.observacao,
        'total_nota': entrada.totalNota,
        'frete_total': entrada.freteTotal,
        'desconto_total': entrada.descontoTotal,
        'status': statusFinal,
        'created_at': createdAtMs ?? entrada.createdAt.millisecondsSinceEpoch,
      };

      final int id;
      if (entradaId == null) {
        id = await txn.insert('entradas', entradaMap);
      } else {
        id = entradaId;
        await txn.update(
          'entradas',
          entradaMap,
          where: 'id = ?',
          whereArgs: [id],
        );
      }

      await txn.delete('entrada_itens', where: 'entrada_id = ?', whereArgs: [id]);

      for (final it in itens) {
        await txn.insert('entrada_itens', {
          'entrada_id': id,
          'produto_id': it.produtoId,
          'qtd': it.qtd,
          'custo_unit': it.custoUnit,
          'subtotal': it.subtotal,
        });
      }

      final shouldConfirm = statusFinal == EntradaStatus.confirmada &&
          previousStatus != EntradaStatus.confirmada;

      if (shouldConfirm) {
        for (final it in itens) {
          await txn.rawUpdate(
            'UPDATE produtos SET estoque = estoque + ? WHERE id = ?',
            [it.qtd, it.produtoId],
          );
          if (atualizarCusto) {
            await txn.update(
              'produtos',
              {'preco_custo': it.custoUnit},
              where: 'id = ?',
              whereArgs: [it.produtoId],
            );
          }
        }
      }

      return id;
    });
  }
}
