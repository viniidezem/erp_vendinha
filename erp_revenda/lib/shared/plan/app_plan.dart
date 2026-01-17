import 'package:sqflite/sqflite.dart';

class AppPlan {
  static const String settingsKey = 'app_plan';
  static const String freeId = 'free';
  static const String proId = 'pro';

  final String id;
  final int? maxClientes;
  final int? maxProdutos;
  final int? maxVendas;

  const AppPlan._(
    this.id, {
    required this.maxClientes,
    required this.maxProdutos,
    required this.maxVendas,
  });

  bool get isPro => id == proId;

  static const AppPlan free = AppPlan._(
    freeId,
    maxClientes: 20,
    maxProdutos: 50,
    maxVendas: 200,
  );

  static const AppPlan pro = AppPlan._(
    proId,
    maxClientes: null,
    maxProdutos: null,
    maxVendas: null,
  );

  static AppPlan fromId(String? id) {
    if (id == proId) return pro;
    return free;
  }

  static String limitMessage(String label, int max) {
    return 'Limite da versao gratuita: $max $label. '
        'Ative o plano Pro para liberar ilimitado.';
  }
}

Future<AppPlan> carregarAppPlan(Database db) async {
  final rows = await db.query(
    'app_settings',
    columns: ['value'],
    where: 'key = ?',
    whereArgs: [AppPlan.settingsKey],
    limit: 1,
  );
  final id = rows.isEmpty ? null : rows.first['value'] as String?;
  return AppPlan.fromId(id);
}

Future<void> validarLimitePlano(
  Database db, {
  required int? max,
  required String table,
  required String label,
  String? where,
  List<Object?>? whereArgs,
}) async {
  if (max == null) return;
  final whereSql = where == null ? '' : ' WHERE $where';
  final rows = await db.rawQuery(
    'SELECT COUNT(*) AS c FROM $table$whereSql',
    whereArgs ?? const [],
  );
  final count = Sqflite.firstIntValue(rows) ?? 0;
  if (count >= max) {
    throw StateError(AppPlan.limitMessage(label, max));
  }
}
