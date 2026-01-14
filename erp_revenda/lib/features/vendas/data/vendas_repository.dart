import '../../../data/db/app_database.dart';
import '../../produtos/data/produto_model.dart';
import '../../produtos/data/produto_repository.dart';
import 'venda_models.dart';

class VendasRepository {
  final AppDatabase _db;
  final ProdutoRepository _produtoRepo;

  VendasRepository(this._db, this._produtoRepo);

  /// Lista vendas registradas.
  /// Ordena por data desc.
  Future<List<Venda>> listarVendas({bool somenteAbertas = false}) async {
    final db = await _db.database;

    final where = somenteAbertas ? 'status = ?' : null;
    final args = somenteAbertas ? ['ABERTA'] : null;

    final rows = await db.query(
      'vendas',
      where: where,
      whereArgs: args,
      orderBy: 'created_at DESC',
    );

    return rows.map((r) => Venda.fromMap(r)).toList();
  }

  /// Produtos ativos para seleção (opcionalmente somente com saldo).
  Future<List<Produto>> listarProdutosAtivos({
    bool somenteComSaldo = true,
    String search = '',
  }) {
    return _produtoRepo.listar(
      search: search,
      onlyActive: true,
      onlyWithStock: somenteComSaldo,
    );
  }

  /// Finaliza uma venda.
  ///
  /// - Caso [vendaId] seja informado: atualiza a venda existente (e opcionalmente ajusta estoque).
  /// - Caso [vendaId] seja nulo: cria a venda + grava itens + ajusta estoque.
  ///
  /// A tela atual usa: `finalizarVenda(clienteId: ..., itens: ...)`.
  Future<void> finalizarVenda({
    int? vendaId,
    int? clienteId,
    List<VendaItem>? itens,
    double? total,
    String status = 'FINALIZADA',
    bool ajustarEstoque = true,
  }) async {
    final db = await _db.database;

    // Regra de negócio: não permitir finalizar venda sem cliente.
    if (status == 'FINALIZADA' && vendaId == null && clienteId == null) {
      throw ArgumentError('Selecione um cliente para finalizar a venda.');
    }

    await db.transaction((txn) async {
      // 1) Garante vendaId (cria se necessário)
      final int id;
      if (vendaId == null) {
        final computedTotal =
            total ?? (itens?.fold<double>(0, (s, i) => s + i.subtotal) ?? 0.0);

        id = await txn.insert('vendas', {
          'cliente_id': clienteId,
          'total': computedTotal,
          'status': status,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        id = vendaId;

        // Atualiza header se tiver info nova
        final values = <String, Object?>{'status': status};

        // Se não veio total explícito, calcula a partir dos itens (quando fornecidos).
        final computedTotal = total ??
            (itens == null
                ? null
                : itens.fold<double>(0, (s, i) => s + i.subtotal));

        if (computedTotal != null) values['total'] = computedTotal;
        if (clienteId != null) values['cliente_id'] = clienteId;

        await txn.update(
          'vendas',
          values,
          where: 'id = ?',
          whereArgs: [id],
        );
      }

      // 2) Se vier itens, grava itens vinculados à venda
      if (itens != null && itens.isNotEmpty) {
        for (final it in itens) {
          await txn.insert(
            'venda_itens',
            it.toDbMap(vendaId: id),
          );
        }
      }

      // 3) Ajusta estoque (subtrai qtd)
      if (ajustarEstoque) {
        // Se itens foram passados, usa eles (mais rápido).
        // Senão, busca itens no banco.
        final sourceItens = (itens != null)
            ? itens
            : (await txn.query(
                'venda_itens',
                columns: ['produto_id', 'qtd'],
                where: 'venda_id = ?',
                whereArgs: [id],
              ))
                .map(
                  (r) => VendaItem(
                    produtoId: r['produto_id'] as int,
                    produtoNome: '',
                    qtd: (r['qtd'] as num).toDouble(),
                    precoUnit: 0.0,
                  ),
                )
                .toList();

        for (final it in sourceItens) {
          await txn.rawUpdate(
            'UPDATE produtos SET estoque = estoque - ? WHERE id = ?',
            [it.qtd, it.produtoId],
          );
        }
      }

      // 4) Atualiza a data da última compra do cliente.
      // Regra de negócio: venda finalizada precisa estar vinculada a um cliente.
      if (status == 'FINALIZADA') {
        int? finalClienteId = clienteId;

        // Se não veio clienteId no parâmetro (ex.: atualização), tenta ler do header.
        if (finalClienteId == null) {
          final rows = await txn.query(
            'vendas',
            columns: ['cliente_id'],
            where: 'id = ?',
            whereArgs: [id],
            limit: 1,
          );
          if (rows.isNotEmpty) {
            finalClienteId = rows.first['cliente_id'] as int?;
          }
        }

        if (finalClienteId == null) {
          throw ArgumentError('Selecione um cliente para finalizar a venda.');
        }

        await txn.update(
          'clientes',
          {'ultima_compra_at': DateTime.now().millisecondsSinceEpoch},
          where: 'id = ?',
          whereArgs: [finalClienteId],
        );
      }


    });
  }
}
