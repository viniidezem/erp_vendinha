
import 'package:sqflite/sqflite.dart';
import '../../../data/db/app_database.dart';
import 'produto_model.dart';

class ProdutoRepository {
  final AppDatabase _db;
  ProdutoRepository(this._db);

  Future<List<Produto>> listar({
    String search = '',
    bool onlyActive = true,
    bool onlyWithStock = false,
    int? fornecedorId,
    bool includeKits = false,
  }) async {
    final Database db = await _db.database;

    final whereParts = <String>[];
    final args = <Object?>[];

    if (onlyActive) {
      whereParts.add('ativo = 1');
    }
    if (onlyWithStock) {
      if (includeKits) {
        whereParts.add('(estoque > 0 OR is_kit = 1)');
      } else {
        whereParts.add('estoque > 0');
      }
    }
    if (!includeKits) {
      whereParts.add('(is_kit IS NULL OR is_kit = 0)');
    }
    if (fornecedorId != null) {
      whereParts.add('fornecedor_id = ?');
      args.add(fornecedorId);
    }

    final term = search.trim();
    if (term.isNotEmpty) {
      // Busca avançada:
      // - aceita múltiplas palavras (AND)
      // - cada termo pode bater no nome/ref do produto OU em nomes de categorias
      //   (tipo, ocasião, família, propriedades)
      final stopWords = <String>{
        'categoria',
        'categorias',
        'cat',
      };

      final tokens = term
          .split(RegExp(r'\s+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .where((e) => !stopWords.contains(e.toLowerCase()))
          .toList();

      for (final t in tokens) {
        whereParts.add(
          '('
          "LOWER(COALESCE(nome, '')) LIKE LOWER(?) OR "
          "LOWER(COALESCE(ref_codigo, '')) LIKE LOWER(?) OR "
          "EXISTS (SELECT 1 FROM categorias c WHERE c.id = produtos.tipo_id AND LOWER(c.nome) LIKE LOWER(?)) OR "
          "EXISTS (SELECT 1 FROM categorias c WHERE c.id = produtos.ocasiao_id AND LOWER(c.nome) LIKE LOWER(?)) OR "
          "EXISTS (SELECT 1 FROM categorias c WHERE c.id = produtos.familia_id AND LOWER(c.nome) LIKE LOWER(?)) OR "
          "EXISTS (SELECT 1 FROM produto_propriedades pp "
          "JOIN categorias c ON c.id = pp.categoria_id "
          "WHERE pp.produto_id = produtos.id AND LOWER(c.nome) LIKE LOWER(?))"
          ')',
        );

        final like = '%$t%';
        args.add(like); // nome
        args.add(like); // ref
        args.add(like); // tipo
        args.add(like); // ocasiao
        args.add(like); // familia
        args.add(like); // propriedades
      }
    }


    final where = whereParts.isEmpty ? null : whereParts.join(' AND ');

    final rows = await db.query(
      'produtos',
      where: where,
      whereArgs: where == null ? null : args,
      orderBy: 'nome COLLATE NOCASE ASC',
    );

    return rows.map((e) => Produto.fromMap(e)).toList();
  }

  /// Compatibilidade com versões anteriores
  Future<List<Produto>> listarTodos() async {
    return listar(search: '', onlyActive: true, onlyWithStock: false);
  }

  Future<int> inserir(Produto p, {List<int> propriedadesIds = const []}) async {
    final db = await _db.database;

    return db.transaction<int>((txn) async {
      final id = await txn.insert('produtos', p.toMap());

      for (final catId in propriedadesIds) {
        await txn.insert('produto_propriedades', {'produto_id': id, 'categoria_id': catId});
      }

      return id;
    });
  }

  Future<int> atualizar(Produto p, {List<int> propriedadesIds = const []}) async {
    final db = await _db.database;
    if (p.id == null) {
      throw ArgumentError('Produto.id não pode ser nulo ao atualizar.');
    }

    return db.transaction<int>((txn) async {
      final count = await txn.update(
        'produtos',
        p.toMap(),
        where: 'id = ?',
        whereArgs: [p.id],
      );

      await txn.delete('produto_propriedades', where: 'produto_id = ?', whereArgs: [p.id]);

      for (final catId in propriedadesIds) {
        await txn.insert('produto_propriedades', {'produto_id': p.id, 'categoria_id': catId});
      }

      return count;
    });
  }

  Future<List<int>> listarPropriedadesIds(int produtoId) async {
    final db = await _db.database;
    final rows = await db.query(
      'produto_propriedades',
      columns: ['categoria_id'],
      where: 'produto_id = ?',
      whereArgs: [produtoId],
    );
    return rows.map((e) => e['categoria_id'] as int).toList();
  }

  Future<void> ajustarEstoque({required int id, required double delta}) async {
    final db = await _db.database;
    await db.rawUpdate('UPDATE produtos SET estoque = estoque + ? WHERE id = ?', [delta, id]);
  }
}
