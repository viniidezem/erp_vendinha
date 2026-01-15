import 'package:sqflite/sqflite.dart';

import '../../../data/db/app_database.dart';
import '../../clientes/data/cliente_model.dart';
import '../../fornecedores/data/fornecedor_model.dart';
import '../../financeiro/contas_pagar/data/conta_pagar_model.dart';
import '../../financeiro/contas_receber/data/conta_receber_model.dart';
import '../../vendas/data/venda_models.dart';
import 'relatorio_models.dart';

class RelatoriosRepository {
  final AppDatabase _db;
  RelatoriosRepository(this._db);

  Future<List<Fornecedor>> listarFornecedores() async {
    final db = await _db.database;
    final rows = await db.query(
      'fornecedores',
      orderBy: 'nome COLLATE NOCASE ASC',
    );
    return rows.map((r) => Fornecedor.fromMap(r)).toList();
  }

  Future<List<Cliente>> listarClientes() async {
    final db = await _db.database;
    final rows = await db.query(
      'clientes',
      orderBy: 'nome COLLATE NOCASE ASC',
    );
    return rows.map((r) => Cliente.fromMap(r)).toList();
  }

  Future<RelatorioContasPagarResumo> contasPagarResumo({
    required DateTime inicio,
    required DateTime fim,
    String? status,
    int? fornecedorId,
  }) async {
    final Database db = await _db.database;

    final whereParts = <String>[];
    final whereArgs = <Object?>[];

    whereParts.add('COALESCE(cp.vencimento_at, cp.created_at) BETWEEN ? AND ?');
    whereArgs.addAll([inicio.millisecondsSinceEpoch, fim.millisecondsSinceEpoch]);

    if (status != null && status.isNotEmpty) {
      whereParts.add('cp.status = ?');
      whereArgs.add(status);
    }
    if (fornecedorId != null) {
      whereParts.add('cp.fornecedor_id = ?');
      whereArgs.add(fornecedorId);
    }

    final whereSql = whereParts.isEmpty ? '' : 'WHERE ${whereParts.join(' AND ')}';

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final vencendoMs =
        DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch;

    final rows = await db.rawQuery(
      '''
      SELECT
        SUM(CASE WHEN cp.status = '${ContaPagarStatus.aberta}' THEN cp.valor ELSE 0 END) AS total_aberto,
        SUM(CASE WHEN cp.status = '${ContaPagarStatus.paga}' THEN cp.valor ELSE 0 END) AS total_pago,
        SUM(CASE WHEN cp.status = '${ContaPagarStatus.cancelada}' THEN cp.valor ELSE 0 END) AS total_cancelado,
        SUM(CASE WHEN cp.status = '${ContaPagarStatus.aberta}' AND cp.vencimento_at IS NOT NULL AND cp.vencimento_at < ? THEN cp.valor ELSE 0 END) AS total_vencido,
        SUM(CASE WHEN cp.status = '${ContaPagarStatus.aberta}' AND cp.vencimento_at IS NOT NULL AND cp.vencimento_at >= ? AND cp.vencimento_at <= ? THEN cp.valor ELSE 0 END) AS total_vencendo,
        SUM(CASE WHEN cp.status = '${ContaPagarStatus.aberta}' THEN 1 ELSE 0 END) AS qtd_aberta,
        SUM(CASE WHEN cp.status = '${ContaPagarStatus.paga}' THEN 1 ELSE 0 END) AS qtd_paga,
        SUM(CASE WHEN cp.status = '${ContaPagarStatus.cancelada}' THEN 1 ELSE 0 END) AS qtd_cancelada,
        SUM(CASE WHEN cp.status = '${ContaPagarStatus.aberta}' AND cp.vencimento_at IS NOT NULL AND cp.vencimento_at < ? THEN 1 ELSE 0 END) AS qtd_vencida,
        SUM(CASE WHEN cp.status = '${ContaPagarStatus.aberta}' AND cp.vencimento_at IS NOT NULL AND cp.vencimento_at >= ? AND cp.vencimento_at <= ? THEN 1 ELSE 0 END) AS qtd_vencendo
      FROM contas_pagar cp
      $whereSql
      ''',
      [
        nowMs,
        nowMs,
        vencendoMs,
        nowMs,
        nowMs,
        vencendoMs,
        ...whereArgs,
      ],
    );

    final row = rows.isNotEmpty ? rows.first : const <String, Object?>{};
    double d(String k) => (row[k] as num?)?.toDouble() ?? 0;
    int i(String k) => (row[k] as num?)?.toInt() ?? 0;

    return RelatorioContasPagarResumo(
      totalAberto: d('total_aberto'),
      totalPago: d('total_pago'),
      totalCancelado: d('total_cancelado'),
      totalVencido: d('total_vencido'),
      totalVencendo: d('total_vencendo'),
      qtdAberta: i('qtd_aberta'),
      qtdPaga: i('qtd_paga'),
      qtdCancelada: i('qtd_cancelada'),
      qtdVencida: i('qtd_vencida'),
      qtdVencendo: i('qtd_vencendo'),
    );
  }

  Future<List<ContaPagar>> contasPagarDocumentos({
    required DateTime inicio,
    required DateTime fim,
    String? status,
    int? fornecedorId,
  }) async {
    final Database db = await _db.database;

    final whereParts = <String>[];
    final whereArgs = <Object?>[];

    whereParts.add('COALESCE(cp.vencimento_at, cp.created_at) BETWEEN ? AND ?');
    whereArgs.addAll([inicio.millisecondsSinceEpoch, fim.millisecondsSinceEpoch]);

    if (status != null && status.isNotEmpty) {
      whereParts.add('cp.status = ?');
      whereArgs.add(status);
    }
    if (fornecedorId != null) {
      whereParts.add('cp.fornecedor_id = ?');
      whereArgs.add(fornecedorId);
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
    ''', whereArgs);

    return rows.map((e) => ContaPagar.fromMap(e)).toList();
  }

  Future<RelatorioContasReceberResumo> contasReceberResumo({
    required DateTime inicio,
    required DateTime fim,
    String? status,
    int? clienteId,
  }) async {
    final Database db = await _db.database;

    final whereParts = <String>[];
    final whereArgs = <Object?>[];

    whereParts.add('COALESCE(cr.vencimento_at, cr.created_at) BETWEEN ? AND ?');
    whereArgs.addAll([inicio.millisecondsSinceEpoch, fim.millisecondsSinceEpoch]);

    if (status != null && status.isNotEmpty) {
      whereParts.add('cr.status = ?');
      whereArgs.add(status);
    }
    if (clienteId != null) {
      whereParts.add('v.cliente_id = ?');
      whereArgs.add(clienteId);
    }

    final whereSql = whereParts.isEmpty ? '' : 'WHERE ${whereParts.join(' AND ')}';

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final vencendoMs =
        DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch;

    final rows = await db.rawQuery(
      '''
      SELECT
        SUM(CASE WHEN cr.status = '${ContaReceberStatus.aberta}' THEN cr.valor ELSE 0 END) AS total_aberto,
        SUM(CASE WHEN cr.status = '${ContaReceberStatus.recebida}' THEN cr.valor_recebido ELSE 0 END) AS total_recebido,
        SUM(CASE WHEN cr.status = '${ContaReceberStatus.cancelada}' THEN cr.valor ELSE 0 END) AS total_cancelado,
        SUM(CASE WHEN cr.status = '${ContaReceberStatus.aberta}' AND cr.vencimento_at IS NOT NULL AND cr.vencimento_at < ? THEN cr.valor ELSE 0 END) AS total_vencido,
        SUM(CASE WHEN cr.status = '${ContaReceberStatus.aberta}' AND cr.vencimento_at IS NOT NULL AND cr.vencimento_at >= ? AND cr.vencimento_at <= ? THEN cr.valor ELSE 0 END) AS total_vencendo,
        SUM(CASE WHEN cr.status = '${ContaReceberStatus.aberta}' THEN 1 ELSE 0 END) AS qtd_aberta,
        SUM(CASE WHEN cr.status = '${ContaReceberStatus.recebida}' THEN 1 ELSE 0 END) AS qtd_recebida,
        SUM(CASE WHEN cr.status = '${ContaReceberStatus.cancelada}' THEN 1 ELSE 0 END) AS qtd_cancelada,
        SUM(CASE WHEN cr.status = '${ContaReceberStatus.aberta}' AND cr.vencimento_at IS NOT NULL AND cr.vencimento_at < ? THEN 1 ELSE 0 END) AS qtd_vencida,
        SUM(CASE WHEN cr.status = '${ContaReceberStatus.aberta}' AND cr.vencimento_at IS NOT NULL AND cr.vencimento_at >= ? AND cr.vencimento_at <= ? THEN 1 ELSE 0 END) AS qtd_vencendo
      FROM contas_receber cr
      LEFT JOIN vendas v ON v.id = cr.venda_id
      $whereSql
      ''',
      [
        nowMs,
        nowMs,
        vencendoMs,
        nowMs,
        nowMs,
        vencendoMs,
        ...whereArgs,
      ],
    );

    final row = rows.isNotEmpty ? rows.first : const <String, Object?>{};
    double d(String k) => (row[k] as num?)?.toDouble() ?? 0;
    int i(String k) => (row[k] as num?)?.toInt() ?? 0;

    return RelatorioContasReceberResumo(
      totalAberto: d('total_aberto'),
      totalRecebido: d('total_recebido'),
      totalCancelado: d('total_cancelado'),
      totalVencido: d('total_vencido'),
      totalVencendo: d('total_vencendo'),
      qtdAberta: i('qtd_aberta'),
      qtdRecebida: i('qtd_recebida'),
      qtdCancelada: i('qtd_cancelada'),
      qtdVencida: i('qtd_vencida'),
      qtdVencendo: i('qtd_vencendo'),
    );
  }

  Future<List<ContaReceber>> contasReceberDocumentos({
    required DateTime inicio,
    required DateTime fim,
    String? status,
    int? clienteId,
  }) async {
    final Database db = await _db.database;

    final whereParts = <String>[];
    final whereArgs = <Object?>[];

    whereParts.add('COALESCE(cr.vencimento_at, cr.created_at) BETWEEN ? AND ?');
    whereArgs.addAll([inicio.millisecondsSinceEpoch, fim.millisecondsSinceEpoch]);

    if (status != null && status.isNotEmpty) {
      whereParts.add('cr.status = ?');
      whereArgs.add(status);
    }
    if (clienteId != null) {
      whereParts.add('v.cliente_id = ?');
      whereArgs.add(clienteId);
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
    ''', whereArgs);

    return rows.map((e) => ContaReceber.fromMap(e)).toList();
  }

  Future<RelatorioVendasResumo> vendasResumo({
    required DateTime inicio,
    required DateTime fim,
    String? status,
    bool somenteEfetivos = false,
  }) async {
    final db = await _db.database;

    final whereParts = <String>[];
    final whereArgs = <Object?>[];

    whereParts.add('created_at BETWEEN ? AND ?');
    whereArgs.addAll([inicio.millisecondsSinceEpoch, fim.millisecondsSinceEpoch]);

    if (status != null && status.isNotEmpty) {
      whereParts.add('status = ?');
      whereArgs.add(status);
    } else if (somenteEfetivos) {
      whereParts.add('status <> ?');
      whereArgs.add(VendaStatus.aberta);
      whereParts.add('status <> ?');
      whereArgs.add(VendaStatus.cancelada);
    }

    final whereSql = whereParts.isEmpty ? '' : 'WHERE ${whereParts.join(' AND ')}';

    final rows = await db.rawQuery(
      '''
      SELECT status, COUNT(*) AS qtd, SUM(total) AS total
      FROM vendas
      $whereSql
      GROUP BY status
      ORDER BY status
      ''',
      whereArgs,
    );

    double totalEfetivo = 0;
    int qtdEfetiva = 0;
    double totalCancelado = 0;
    int qtdCancelada = 0;
    final porStatus = <RelatorioStatusResumo>[];

    for (final r in rows) {
      final st = (r['status'] as String?) ?? '';
      final qtd = (r['qtd'] as num?)?.toInt() ?? 0;
      final total = (r['total'] as num?)?.toDouble() ?? 0;

      porStatus.add(
        RelatorioStatusResumo(status: st, qtd: qtd, total: total),
      );

      if (st == VendaStatus.cancelada) {
        totalCancelado += total;
        qtdCancelada += qtd;
      } else if (st != VendaStatus.aberta) {
        totalEfetivo += total;
        qtdEfetiva += qtd;
      }
    }

    final ticket = qtdEfetiva == 0 ? 0.0 : totalEfetivo / qtdEfetiva;

    return RelatorioVendasResumo(
      totalEfetivo: totalEfetivo,
      qtdEfetiva: qtdEfetiva,
      ticketMedio: ticket,
      totalCancelado: totalCancelado,
      qtdCancelada: qtdCancelada,
      porStatus: porStatus,
    );
  }

  Future<RelatorioProdutosResumo> produtosResumo({
    required DateTime inicio,
    required DateTime fim,
    String? statusFiltro,
    bool somenteEfetivos = true,
    int limit = 10,
  }) async {
    final db = await _db.database;

    final whereParts = <String>[];
    final whereArgs = <Object?>[];

    whereParts.add('v.created_at BETWEEN ? AND ?');
    whereArgs.addAll([inicio.millisecondsSinceEpoch, fim.millisecondsSinceEpoch]);

    if (statusFiltro != null && statusFiltro.isNotEmpty) {
      whereParts.add('v.status = ?');
      whereArgs.add(statusFiltro);
    } else if (somenteEfetivos) {
      whereParts.add('v.status <> ?');
      whereArgs.add(VendaStatus.aberta);
      whereParts.add('v.status <> ?');
      whereArgs.add(VendaStatus.cancelada);
    }

    final whereSql = whereParts.isEmpty ? '' : 'WHERE ${whereParts.join(' AND ')}';

    final baseQuery = '''
      SELECT
        p.id AS produto_id,
        p.nome AS produto_nome,
        SUM(vi.qtd) AS qtd_total,
        SUM(vi.subtotal) AS valor_total
      FROM venda_itens vi
      INNER JOIN vendas v ON v.id = vi.venda_id
      INNER JOIN produtos p ON p.id = vi.produto_id
      $whereSql
      GROUP BY p.id, p.nome
    ''';

    final qtdRows = await db.rawQuery(
      '$baseQuery ORDER BY qtd_total DESC LIMIT $limit',
      whereArgs,
    );
    final valorRows = await db.rawQuery(
      '$baseQuery ORDER BY valor_total DESC LIMIT $limit',
      whereArgs,
    );

    List<RelatorioProdutoRanking> mapRows(List<Map<String, Object?>> rows) {
      return rows
          .map(
            (r) => RelatorioProdutoRanking(
              produtoId: (r['produto_id'] as num?)?.toInt() ?? 0,
              nome: (r['produto_nome'] as String?) ?? 'Produto',
              qtd: (r['qtd_total'] as num?)?.toDouble() ?? 0,
              valor: (r['valor_total'] as num?)?.toDouble() ?? 0,
            ),
          )
          .toList();
    }

    return RelatorioProdutosResumo(
      porQuantidade: mapRows(qtdRows),
      porValor: mapRows(valorRows),
    );
  }
}
