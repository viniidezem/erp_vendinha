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
  Future<List<Venda>> listarVendas({
    bool somenteAbertas = false,
    String? statusFiltro,
    String search = '',
    bool excluirAbertas = true,
  }) async {
    final db = await _db.database;

    final whereParts = <String>[];
    final args = <Object?>[];

    if (somenteAbertas) {
      whereParts.add('v.status = ?');
      args.add(VendaStatus.aberta);
    } else if (statusFiltro != null && statusFiltro.isNotEmpty) {
      whereParts.add('v.status = ?');
      args.add(statusFiltro);
    } else if (excluirAbertas) {
      whereParts.add('v.status <> ?');
      args.add(VendaStatus.aberta);
    }

    final q = search.trim();
    if (q.isNotEmpty) {
      whereParts.add('(c.nome LIKE ? OR CAST(v.id AS TEXT) LIKE ?)');
      args.add('%$q%');
      args.add('%$q%');
    }

    final whereSql = whereParts.isEmpty ? '' : 'WHERE ${whereParts.join(' AND ')}';

    final rows = await db.rawQuery('''
      SELECT 
        v.id,
        v.cliente_id,
        v.total,
        v.status,
        v.created_at,
        c.nome AS cliente_nome
      FROM vendas v
      LEFT JOIN clientes c ON c.id = v.cliente_id
      $whereSql
      ORDER BY v.created_at DESC
    ''', args);

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
    String status = VendaStatus.pedido,
    bool ajustarEstoque = true,
  }) async {
    final db = await _db.database;

    // Regra de negócio: não permitir finalizar venda sem cliente.
    if (status != VendaStatus.aberta && vendaId == null && clienteId == null) {
      throw ArgumentError('Selecione um cliente para concluir o pedido.');
    }

    await db.transaction((txn) async {
      // Para logar mudanças de status (histórico do pedido)
      String? previousStatus;
      if (vendaId != null) {
        final prev = await txn.query(
          'vendas',
          columns: ['status'],
          where: 'id = ?',
          whereArgs: [vendaId],
          limit: 1,
        );
        if (prev.isNotEmpty) {
          previousStatus = prev.first['status'] as String?;
        }
      }

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
        final computedTotal = total ?? itens?.fold<double>(0, (s, i) => s + i.subtotal);

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

            // 2.5) Histórico de status (apenas quando muda)
      if (previousStatus != status) {
        await _insertStatusLog(txn, vendaId: id, status: status);
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
      // Regra de negócio: pedidos (não-abertos) precisam estar vinculados a um cliente.
      if (status != VendaStatus.aberta && status != VendaStatus.cancelada) {
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
          throw ArgumentError('Selecione um cliente para concluir o pedido.');
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


  Future<PedidoDetalhe> carregarPedidoDetalhe(int vendaId) async {
    final db = await _db.database;

    final vendaRows = await db.rawQuery('''
      SELECT 
        v.id,
        v.cliente_id,
        v.total,
        v.status,
        v.created_at,
        c.nome AS cliente_nome
      FROM vendas v
      LEFT JOIN clientes c ON c.id = v.cliente_id
      WHERE v.id = ?
      LIMIT 1
    ''', [vendaId]);

    if (vendaRows.isEmpty) {
      throw StateError('Pedido não encontrado: $vendaId');
    }

    final venda = Venda.fromMap(vendaRows.first);

    final itensRows = await db.rawQuery('''
      SELECT 
        vi.id,
        vi.venda_id,
        vi.produto_id,
        p.nome AS produto_nome,
        vi.qtd,
        vi.preco_unit
      FROM venda_itens vi
      LEFT JOIN produtos p ON p.id = vi.produto_id
      WHERE vi.venda_id = ?
      ORDER BY vi.id ASC
    ''', [vendaId]);

    final itens = itensRows
        .map(
          (m) => VendaItem(
            id: m['id'] as int?,
            vendaId: m['venda_id'] as int?,
            produtoId: m['produto_id'] as int,
            produtoNome: (m['produto_nome'] as String?) ?? 'Produto',
            qtd: (m['qtd'] as num).toDouble(),
            precoUnit: (m['preco_unit'] as num).toDouble(),
          ),
        )
        .toList();

    final historico = await listarStatusLog(vendaId);

    return PedidoDetalhe(
      venda: venda,
      itens: itens,
      historico: historico,
    );
  }

  Future<List<VendaStatusLog>> listarStatusLog(int vendaId) async {
    final db = await _db.database;
    final rows = await db.query(
      'venda_status_log',
      where: 'venda_id = ?',
      whereArgs: [vendaId],
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map((r) => VendaStatusLog.fromMap(r)).toList();
  }

  Future<void> atualizarStatus({
    required int vendaId,
    required String status,
    String? obs,
  }) async {
    final db = await _db.database;

    await db.transaction((txn) async {
      // Evita log duplicado quando não há mudança
      final prev = await txn.query(
        'vendas',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [vendaId],
        limit: 1,
      );
      final previous = prev.isEmpty ? null : (prev.first['status'] as String?);

      if (previous == status) return;

      await txn.update(
        'vendas',
        {'status': status},
        where: 'id = ?',
        whereArgs: [vendaId],
      );

      await _insertStatusLog(
        txn,
        vendaId: vendaId,
        status: status,
        obs: obs,
      );
    });
  }

  Future<void> _insertStatusLog(
    dynamic txn, {
    required int vendaId,
    required String status,
    String? obs,
  }) async {
    await txn.insert('venda_status_log', {
      'venda_id': vendaId,
      'status': status,
      'obs': obs,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

}
