import 'package:sqflite/sqflite.dart';

import '../../../data/db/app_database.dart';
import 'dashboard_settings.dart';

class AppSettingsRepository {
  final AppDatabase _db;

  AppSettingsRepository(this._db);

  Future<String?> getValue(String key) async {
    final Database db = await _db.database;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setValue(String key, String value) async {
    final Database db = await _db.database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DashboardSettings> carregarDashboardSettings() async {
    final show = await getValue(_kMostrarGraficos);
    final meta = await getValue(_kMetaMensal);
    final periodo = await getValue(_kPeriodoGrafico);

    final mostrarGraficos = show == '1';
    final metaMensal = double.tryParse(meta ?? '') ?? 0;
    final periodoFinal = DashboardGraficoPeriodo.values.contains(periodo)
        ? periodo!
        : DashboardGraficoPeriodo.mesAtual;

    return DashboardSettings(
      mostrarGraficos: mostrarGraficos,
      metaFaturamentoMensal: metaMensal,
      periodoGrafico: periodoFinal,
    );
  }

  Future<void> salvarDashboardSettings(DashboardSettings settings) async {
    await setValue(_kMostrarGraficos, settings.mostrarGraficos ? '1' : '0');
    await setValue(
      _kMetaMensal,
      settings.metaFaturamentoMensal.toStringAsFixed(2),
    );
    await setValue(_kPeriodoGrafico, settings.periodoGrafico);
  }

  static const String _kMostrarGraficos = 'dashboard_mostrar_graficos';
  static const String _kMetaMensal = 'dashboard_meta_mensal';
  static const String _kPeriodoGrafico = 'dashboard_periodo_grafico';
}
