import 'package:sqflite/sqflite.dart';

import '../../../data/db/app_database.dart';
import 'dashboard_resumo.dart';
import '../../vendas/data/venda_models.dart';
import 'dashboard_grafico.dart';
import '../../settings/data/dashboard_settings.dart';

class DashboardRepository {
  final AppDatabase _db;
  DashboardRepository(this._db);

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  Future<DashboardResumo> carregarResumo({
    required String periodoVendas,
  }) async {
    final Database db = await _db.database;
    final now = DateTime.now();

    DateTime periodoInicio;
    DateTime periodoFim;
    switch (periodoVendas) {
      case DashboardResumoPeriodo.ultimos7Dias:
        periodoInicio = _startOfDay(now.subtract(const Duration(days: 6)));
        periodoFim = _endOfDay(now);
        break;
      case DashboardResumoPeriodo.ultimos30Dias:
        periodoInicio = _startOfDay(now.subtract(const Duration(days: 29)));
        periodoFim = _endOfDay(now);
        break;
      case DashboardResumoPeriodo.hoje:
      default:
        periodoInicio = _startOfDay(now);
        periodoFim = _endOfDay(now);
        break;
    }
    final periodoRows = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(total), 0) AS total,
        COUNT(*) AS qtd
      FROM vendas
      WHERE created_at BETWEEN ? AND ?
        AND status NOT IN ('ABERTA', 'CANCELADA');
    ''',
      [periodoInicio.millisecondsSinceEpoch, periodoFim.millisecondsSinceEpoch],
    );
    final vendasPeriodoTotal =
        (periodoRows.first['total'] as num? ?? 0).toDouble();
    final vendasPeriodoQtde = (periodoRows.first['qtd'] as int? ?? 0);

    // Vendas: hoje (timezone local)
    final vendasHojeRows = await db.rawQuery('''
      SELECT
        COALESCE(SUM(total), 0) AS total,
        COUNT(*) AS qtd
      FROM vendas
      WHERE date(datetime(created_at / 1000, 'unixepoch', 'localtime')) = date('now', 'localtime')
        AND status NOT IN ('ABERTA', 'CANCELADA');
    ''');
    final vendasHojeTotal = (vendasHojeRows.first['total'] as num? ?? 0).toDouble();
    final vendasHojeQtde = (vendasHojeRows.first['qtd'] as int? ?? 0);

    // Vendas: mês atual (timezone local)
    final vendasMesRows = await db.rawQuery('''
      SELECT
        COALESCE(SUM(total), 0) AS total,
        COUNT(*) AS qtd
      FROM vendas
      WHERE strftime('%Y-%m', datetime(created_at / 1000, 'unixepoch', 'localtime')) =
            strftime('%Y-%m', 'now', 'localtime')
        AND status NOT IN ('ABERTA', 'CANCELADA');
    ''');
    final vendasMesTotal = (vendasMesRows.first['total'] as num? ?? 0).toDouble();
    final vendasMesQtde = (vendasMesRows.first['qtd'] as int? ?? 0);

    // Clientes ativos
    final clientesRows = await db.rawQuery(
      "SELECT COUNT(*) AS qtd FROM clientes WHERE status = 'ATIVO';",
    );
    final clientesAtivos = (clientesRows.first['qtd'] as int? ?? 0);

    // Produtos ativos
    final produtosAtivosRows = await db.rawQuery(
      'SELECT COUNT(*) AS qtd FROM produtos WHERE ativo = 1;',
    );
    final produtosAtivos = (produtosAtivosRows.first['qtd'] as int? ?? 0);

    // Produtos com saldo
    final produtosComSaldoRows = await db.rawQuery(
      'SELECT COUNT(*) AS qtd FROM produtos WHERE ativo = 1 AND estoque > 0;',
    );
    final produtosComSaldo = (produtosComSaldoRows.first['qtd'] as int? ?? 0);

    // Pedidos abertos (inclui pagamento e expedição, exclui ABERTA/CANCELADA/FINALIZADO)
    final abertos = VendaStatus.abertos;
    final placeholders = List.filled(abertos.length, '?').join(', ');
    final pedidosAbertosRows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS qtd
      FROM vendas
      WHERE status IN ($placeholders);
    ''',
      abertos,
    );
    final pedidosAbertos = (pedidosAbertosRows.first['qtd'] as int? ?? 0);

    // Aguardando pagamento
    final aguardandoPagtoRows = await db.rawQuery(
      "SELECT COUNT(*) AS qtd FROM vendas WHERE status = 'AGUARDANDO_PAGAMENTO';",
    );
    final pedidosAguardandoPagamento = (aguardandoPagtoRows.first['qtd'] as int? ?? 0);

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final vencendoMs =
        DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch;

    final contasReceberRows = await db.rawQuery(
      '''
      SELECT
        SUM(CASE WHEN status = 'ABERTA' AND vencimento_at IS NOT NULL AND vencimento_at < ? THEN 1 ELSE 0 END) AS vencidas,
        SUM(CASE WHEN status = 'ABERTA' AND vencimento_at IS NOT NULL AND vencimento_at >= ? AND vencimento_at <= ? THEN 1 ELSE 0 END) AS vencendo
      FROM contas_receber
    ''',
      [nowMs, nowMs, vencendoMs],
    );
    final contasReceberVencidas =
        (contasReceberRows.first['vencidas'] as num? ?? 0).toInt();
    final contasReceberVencendo =
        (contasReceberRows.first['vencendo'] as num? ?? 0).toInt();

    final contasPagarRows = await db.rawQuery(
      '''
      SELECT
        SUM(CASE WHEN status = 'ABERTA' AND vencimento_at IS NOT NULL AND vencimento_at < ? THEN 1 ELSE 0 END) AS vencidas,
        SUM(CASE WHEN status = 'ABERTA' AND vencimento_at IS NOT NULL AND vencimento_at >= ? AND vencimento_at <= ? THEN 1 ELSE 0 END) AS vencendo
      FROM contas_pagar
    ''',
      [nowMs, nowMs, vencendoMs],
    );
    final contasPagarVencidas =
        (contasPagarRows.first['vencidas'] as num? ?? 0).toInt();
    final contasPagarVencendo =
        (contasPagarRows.first['vencendo'] as num? ?? 0).toInt();

    return DashboardResumo(
      vendasPeriodoTotal: vendasPeriodoTotal,
      vendasPeriodoQtde: vendasPeriodoQtde,
      vendasHojeTotal: vendasHojeTotal,
      vendasHojeQtde: vendasHojeQtde,
      vendasMesTotal: vendasMesTotal,
      vendasMesQtde: vendasMesQtde,
      clientesAtivos: clientesAtivos,
      produtosAtivos: produtosAtivos,
      produtosComSaldo: produtosComSaldo,
      pedidosAbertos: pedidosAbertos,
      pedidosAguardandoPagamento: pedidosAguardandoPagamento,
      contasReceberVencidas: contasReceberVencidas,
      contasReceberVencendo: contasReceberVencendo,
      contasPagarVencidas: contasPagarVencidas,
      contasPagarVencendo: contasPagarVencendo,
    );
  }

  Future<DashboardGrafico> carregarGrafico({
    required String periodo,
  }) async {
    final Database db = await _db.database;

    if (periodo == DashboardGraficoPeriodo.semanaAtual) {
      return _graficoSemanaAtual(db);
    }
    if (periodo == DashboardGraficoPeriodo.diaAtual) {
      return _graficoDiaAtual(db);
    }
    return _graficoMesAtual(db);
  }

  Future<DashboardGrafico> _graficoMesAtual(Database db) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;
    final daysInMonth = end.day;

    final rows = await db.rawQuery(
      '''
      SELECT
        strftime('%d', datetime(created_at / 1000, 'unixepoch', 'localtime')) AS dia,
        SUM(total) AS total
      FROM vendas
      WHERE created_at BETWEEN ? AND ?
        AND status NOT IN ('ABERTA', 'CANCELADA')
      GROUP BY dia
      ORDER BY dia ASC
    ''',
      [startMs, endMs],
    );

    final byDay = <int, double>{};
    for (final r in rows) {
      final d = int.tryParse((r['dia'] as String?) ?? '') ?? 0;
      final total = (r['total'] as num?)?.toDouble() ?? 0;
      if (d > 0) byDay[d] = total;
    }

    final itens = <DashboardGraficoItem>[];
    double totalPeriodo = 0;
    for (var d = 1; d <= daysInMonth; d++) {
      final value = byDay[d] ?? 0;
      totalPeriodo += value;
      itens.add(DashboardGraficoItem(label: d.toString(), valor: value));
    }

    return DashboardGrafico(itens: itens, total: totalPeriodo);
  }

  Future<DashboardGrafico> _graficoSemanaAtual(Database db) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59, milliseconds: 999));
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;

    final rows = await db.rawQuery(
      '''
      SELECT
        date(datetime(created_at / 1000, 'unixepoch', 'localtime')) AS dia,
        SUM(total) AS total
      FROM vendas
      WHERE created_at BETWEEN ? AND ?
        AND status NOT IN ('ABERTA', 'CANCELADA')
      GROUP BY dia
      ORDER BY dia ASC
    ''',
      [startMs, endMs],
    );

    final byDay = <String, double>{};
    for (final r in rows) {
      final d = (r['dia'] as String?) ?? '';
      final total = (r['total'] as num?)?.toDouble() ?? 0;
      if (d.isNotEmpty) byDay[d] = total;
    }

    final labels = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab', 'Dom'];
    final itens = <DashboardGraficoItem>[];
    double totalPeriodo = 0;
    for (var i = 0; i < 7; i++) {
      final date = start.add(Duration(days: i));
      final key =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final value = byDay[key] ?? 0;
      totalPeriodo += value;
      itens.add(DashboardGraficoItem(label: labels[i], valor: value));
    }

    return DashboardGrafico(itens: itens, total: totalPeriodo);
  }

  Future<DashboardGrafico> _graficoDiaAtual(Database db) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(hours: 23, minutes: 59, seconds: 59, milliseconds: 999));
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;

    final rows = await db.rawQuery(
      '''
      SELECT
        strftime('%H', datetime(created_at / 1000, 'unixepoch', 'localtime')) AS hora,
        SUM(total) AS total
      FROM vendas
      WHERE created_at BETWEEN ? AND ?
        AND status NOT IN ('ABERTA', 'CANCELADA')
      GROUP BY hora
      ORDER BY hora ASC
    ''',
      [startMs, endMs],
    );

    final byHour = <int, double>{};
    for (final r in rows) {
      final h = int.tryParse((r['hora'] as String?) ?? '') ?? -1;
      final total = (r['total'] as num?)?.toDouble() ?? 0;
      if (h >= 0) byHour[h] = total;
    }

    final itens = <DashboardGraficoItem>[];
    double totalPeriodo = 0;
    for (var h = 0; h < 24; h++) {
      final value = byHour[h] ?? 0;
      totalPeriodo += value;
      itens.add(
        DashboardGraficoItem(
          label: h.toString().padLeft(2, '0'),
          valor: value,
        ),
      );
    }

    return DashboardGrafico(itens: itens, total: totalPeriodo);
  }
}
