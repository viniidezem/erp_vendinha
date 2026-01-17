import 'package:sqflite/sqflite.dart';

import '../../../data/db/app_database.dart';
import '../../produtos/data/produto_model.dart';
import 'kit_models.dart';
import '../../../shared/plan/app_plan.dart';

class KitRepository {
  final AppDatabase _db;
  KitRepository(this._db);

  Future<List<Produto>> listarKits({String search = '', bool onlyActive = true}) async {
    final Database db = await _db.database;
    final whereParts = <String>['is_kit = 1'];
    final args = <Object?>[];

    if (onlyActive) {
      whereParts.add('ativo = 1');
    }

    final q = search.trim();
    if (q.isNotEmpty) {
      whereParts.add('nome LIKE ?');
      args.add('%$q%');
    }

    final rows = await db.query(
      'produtos',
      where: whereParts.join(' AND '),
      whereArgs: args,
      orderBy: 'nome COLLATE NOCASE ASC',
    );

    return rows.map((e) => Produto.fromMap(e)).toList();
  }

  Future<KitDetalhe> carregarKit(int kitId) async {
    final db = await _db.database;
    final kitRows = await db.query(
      'produtos',
      where: 'id = ? AND is_kit = 1',
      whereArgs: [kitId],
      limit: 1,
    );

    if (kitRows.isEmpty) {
      throw StateError('Kit nao encontrado: $kitId');
    }

    final kit = Produto.fromMap(kitRows.first);

    final itensRows = await db.rawQuery('''
      SELECT 
        ki.produto_id,
        ki.qtd,
        p.nome AS produto_nome
      FROM kit_itens ki
      LEFT JOIN produtos p ON p.id = ki.produto_id
      WHERE ki.kit_id = ?
      ORDER BY p.nome COLLATE NOCASE ASC
    ''', [kitId]);

    final itens = itensRows
        .map(
          (m) => KitItem(
            produtoId: m['produto_id'] as int,
            produtoNome: (m['produto_nome'] as String?) ?? 'Produto',
            qtd: (m['qtd'] as num).toDouble(),
          ),
        )
        .toList();

    return KitDetalhe(kit: kit, itens: itens);
  }

  Future<int> salvarKit({
    int? kitId,
    required String nome,
    required double precoVenda,
    required bool ativo,
    required DateTime createdAt,
    required List<KitItem> itens,
  }) async {
    final db = await _db.database;
    if (itens.isEmpty) {
      throw ArgumentError('Adicione pelo menos um produto ao kit.');
    }
    if (kitId == null) {
      final plan = await carregarAppPlan(db);
      await validarLimitePlano(
        db,
        max: plan.maxProdutos,
        table: 'produtos',
        label: 'produtos',
      );
    }

    return db.transaction<int>((txn) async {
      final map = <String, Object?>{
        'nome': nome,
        'preco_venda': precoVenda,
        'preco_custo': 0,
        'estoque': 0,
        'ativo': ativo ? 1 : 0,
        'is_kit': 1,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

      final int id;
      if (kitId == null) {
        id = await txn.insert('produtos', map);
      } else {
        id = kitId;
        final updateMap = Map<String, Object?>.from(map);
        updateMap.remove('created_at');
        await txn.update(
          'produtos',
          updateMap,
          where: 'id = ?',
          whereArgs: [id],
        );
      }

      await txn.delete('kit_itens', where: 'kit_id = ?', whereArgs: [id]);
      for (final it in itens) {
        await txn.insert('kit_itens', {
          'kit_id': id,
          'produto_id': it.produtoId,
          'qtd': it.qtd,
        });
      }

      return id;
    });
  }
}
