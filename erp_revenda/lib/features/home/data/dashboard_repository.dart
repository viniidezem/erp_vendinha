import 'package:sqflite/sqflite.dart';

import '../../../data/db/app_database.dart';
import 'dashboard_resumo.dart';
import '../../vendas/data/venda_models.dart';

class DashboardRepository {
  final AppDatabase _db;
  DashboardRepository(this._db);

  Future<DashboardResumo> carregarResumo() async {
    final Database db = await _db.database;

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

    return DashboardResumo(
      vendasHojeTotal: vendasHojeTotal,
      vendasHojeQtde: vendasHojeQtde,
      vendasMesTotal: vendasMesTotal,
      vendasMesQtde: vendasMesQtde,
      clientesAtivos: clientesAtivos,
      produtosAtivos: produtosAtivos,
      produtosComSaldo: produtosComSaldo,
      pedidosAbertos: pedidosAbertos,
      pedidosAguardandoPagamento: pedidosAguardandoPagamento,
    );
  }
}
