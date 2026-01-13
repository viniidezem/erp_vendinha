//import 'package:sqflite/sqflite.dart';

import '../../../data/db/app_database.dart';
import '../../produtos/data/produto_model.dart';
import '../../produtos/data/produto_repository.dart';
import 'venda_models.dart';

class VendasRepository {
  final AppDatabase _db;
  final ProdutoRepository _prodRepo;

  VendasRepository(this._db, this._prodRepo);

  Future<List<Venda>> listarVendas() async {
    final db = await _db.database;
    final rows = await db.query('vendas', orderBy: 'created_at DESC');
    return rows.map((e) => Venda.fromMap(e)).toList();
  }

  Future<int> finalizarVenda({
    int? clienteId,
    required List<VendaItem> itens,
  }) async {
    final db = await _db.database;

    return db.transaction<int>((txn) async {
      final total = itens.fold<double>(0, (sum, i) => sum + i.subtotal);

      final vendaId = await txn.insert('vendas', {
        'cliente_id': clienteId,
        'total': total,
        'status': 'FINALIZADA',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      // Grava itens
      for (final item in itens) {
        await txn.insert('venda_itens', item.toDbMap(vendaId: vendaId));
      }

      // Baixa estoque
      for (final item in itens) {
        await txn.rawUpdate(
          'UPDATE produtos SET estoque = estoque - ? WHERE id = ?',
          [item.qtd, item.produtoId],
        );
      }

      return vendaId;
    });
  }

  Future<List<Produto>> listarProdutosAtivos() async {
    return _prodRepo.listarTodos();
  }
}
