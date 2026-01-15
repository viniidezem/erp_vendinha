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
        v.desconto_valor,
        v.desconto_percentual,
        v.entrega_tipo,
        v.endereco_entrega_id,
        v.forma_pagamento_id,
        v.parcelas,
        v.observacao,
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
      includeKits: true,
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
    double? descontoValor,
    double? descontoPercentual,
    List<DateTime?>? vencimentos,
    String status = VendaStatus.pedido,
    bool ajustarEstoque = true,
    // Checkout
    String entregaTipo = VendaEntregaTipo.entrega,
    int? enderecoEntregaId,
    int? formaPagamentoId,
    int? parcelas,
    String? observacao,
  }) async {
    final db = await _db.database;

    // Regra de negocio: nao permitir finalizar venda sem cliente.
    if (status != VendaStatus.aberta && vendaId == null && clienteId == null) {
      throw ArgumentError('Selecione um cliente para concluir o pedido.');
    }

    await db.transaction((txn) async {
      // Para logar mudancas de status (historico do pedido)
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

      final createdAtMs = DateTime.now().millisecondsSinceEpoch;
      final computedTotal = total ?? itens?.fold<double>(0, (s, i) => s + i.subtotal);
      final hasTotal = computedTotal != null;
      final totalBase = computedTotal ?? 0.0;
      final descontoAplicado = hasTotal
          ? _calcularDesconto(
              totalBase,
              descontoValor: descontoValor,
              descontoPercentual: descontoPercentual,
            )
          : 0.0;
      final totalFinal = hasTotal ? _round2(totalBase - descontoAplicado) : 0.0;

      // 1) Garante vendaId (cria se necessario)
      final int id;
      if (vendaId == null) {
        id = await txn.insert('vendas', {
          'cliente_id': clienteId,
          'total': totalFinal,
          'status': status,
          'created_at': createdAtMs,
          'desconto_valor': descontoAplicado,
          'desconto_percentual': _descontoPercentualDb(descontoPercentual),
          'entrega_tipo': entregaTipo,
          'endereco_entrega_id': enderecoEntregaId,
          'forma_pagamento_id': formaPagamentoId,
          'parcelas': parcelas,
          'observacao': observacao,
        });
      } else {
        id = vendaId;

        // Atualiza header se tiver info nova
        final values = <String, Object?>{'status': status};

        // Checkout (somente quando informado)
        values['entrega_tipo'] = entregaTipo;
        values['endereco_entrega_id'] = enderecoEntregaId;
        values['forma_pagamento_id'] = formaPagamentoId;
        values['parcelas'] = parcelas;
        values['observacao'] = observacao;
        if (hasTotal) {
          values['total'] = totalFinal;
          values['desconto_valor'] = descontoAplicado;
          values['desconto_percentual'] = _descontoPercentualDb(descontoPercentual);
        }

        if (clienteId != null) values['cliente_id'] = clienteId;

        await txn.update(
          'vendas',
          values,
          where: 'id = ?',
          whereArgs: [id],
        );
      }

      // 2) Se vier itens, grava itens vinculados a venda
      if (itens != null && itens.isNotEmpty) {
        for (final it in itens) {
          await txn.insert(
            'venda_itens',
            it.toDbMap(vendaId: id),
          );
        }
      }

      // 2.5) Historico de status (apenas quando muda)
      if (previousStatus != status) {
        await _insertStatusLog(txn, vendaId: id, status: status);
      }

      // 2.6) Contas a receber (apenas para novos pedidos)
      if (vendaId == null && status != VendaStatus.aberta && totalFinal > 0) {
        await _gerarContasReceber(
          txn,
          vendaId: id,
          total: totalFinal,
          parcelas: parcelas ?? 1,
          vencimentos: vencimentos,
          createdAtMs: createdAtMs,
        );
      }

      // 3) Ajusta estoque (subtrai qtd)
      if (ajustarEstoque) {
        // Se itens foram passados, usa eles (mais rapido).
        // Senao, busca itens no banco.
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

        final ids = sourceItens.map((e) => e.produtoId).toSet().toList();
        final isKitById = <int, bool>{};
        if (ids.isNotEmpty) {
          final rows = await txn.rawQuery(
            'SELECT id, is_kit FROM produtos WHERE id IN (${List.filled(ids.length, '?').join(',')})',
            ids,
          );
          for (final r in rows) {
            final id = r['id'] as int?;
            if (id == null) continue;
            isKitById[id] = (r['is_kit'] as int? ?? 0) == 1;
          }
        }

        for (final it in sourceItens) {
          final isKit = isKitById[it.produtoId] ?? false;
          if (!isKit) {
            await txn.rawUpdate(
              'UPDATE produtos SET estoque = estoque - ? WHERE id = ?',
              [it.qtd, it.produtoId],
            );
            continue;
          }

          final kitItens = await txn.query(
            'kit_itens',
            columns: ['produto_id', 'qtd'],
            where: 'kit_id = ?',
            whereArgs: [it.produtoId],
          );
          for (final ki in kitItens) {
            final produtoId = ki['produto_id'] as int?;
            if (produtoId == null) continue;
            final qtd = (ki['qtd'] as num).toDouble();
            final totalQtd = it.qtd * qtd;
            await txn.rawUpdate(
              'UPDATE produtos SET estoque = estoque - ? WHERE id = ?',
              [totalQtd, produtoId],
            );
          }
        }
      }

      // 4) Atualiza a data da ultima compra do cliente.
      // Regra de negocio: pedidos (nao-abertos) precisam estar vinculados a um cliente.
      if (status != VendaStatus.aberta && status != VendaStatus.cancelada) {
        int? finalClienteId = clienteId;

        // Se nao veio clienteId no parametro (ex.: atualizacao), tenta ler do header.
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
        v.desconto_valor,
        v.desconto_percentual,
        v.entrega_tipo,
        v.endereco_entrega_id,
        v.forma_pagamento_id,
        v.parcelas,
        v.observacao,
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
      orderBy: 'created_at ASC, id ASC',
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

  static double _round2(double v) => (v * 100).round() / 100.0;

  static double _calcularDesconto(
    double total, {
    double? descontoValor,
    double? descontoPercentual,
  }) {
    final pct = (descontoPercentual ?? 0);
    if (pct > 0) {
      final pctClamped = pct.clamp(0.0, 100.0).toDouble();
      final valor = _round2(total * pctClamped / 100);
      return valor > total ? total : valor;
    }

    final valor = (descontoValor ?? 0);
    if (valor <= 0) return 0;

    final valorClamped = valor.clamp(0.0, total).toDouble();
    return _round2(valorClamped);
  }

  static double? _descontoPercentualDb(double? descontoPercentual) {
    if (descontoPercentual == null || descontoPercentual <= 0) return null;
    final pct = descontoPercentual.clamp(0.0, 100.0).toDouble();
    return _round2(pct);
  }

  static Future<void> _gerarContasReceber(
    dynamic txn, {
    required int vendaId,
    required double total,
    required int parcelas,
    List<DateTime?>? vencimentos,
    required int createdAtMs,
  }) async {
    final totalCents = (total * 100).round();
    final parcelasSafe = parcelas < 1 ? 1 : parcelas;
    final baseCents = totalCents ~/ parcelasSafe;
    final residual = totalCents % parcelasSafe;

    for (var i = 1; i <= parcelasSafe; i++) {
      final cents = baseCents + (i == 1 ? residual : 0);
      final valor = cents / 100.0;
      final vencimento = (vencimentos != null && (i - 1) < vencimentos.length)
          ? vencimentos[i - 1]
          : null;
      await txn.insert('contas_receber', {
        'venda_id': vendaId,
        'parcela_numero': i,
        'parcelas_total': parcelasSafe,
        'valor': valor,
        'valor_recebido': 0,
        'status': 'ABERTA',
        'vencimento_at': vencimento?.millisecondsSinceEpoch,
        'created_at': createdAtMs,
      });
    }
  }

  Future<void> cancelarFinanceiroPorVenda(int vendaId) async {
    final db = await _db.database;
    await db.update(
      'contas_receber',
      {
        'status': 'CANCELADA',
        'valor_recebido': 0,
      },
      where: 'venda_id = ? AND status = ?',
      whereArgs: [vendaId, 'ABERTA'],
    );
  }

}
