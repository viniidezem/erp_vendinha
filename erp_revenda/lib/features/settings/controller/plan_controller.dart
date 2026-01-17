import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../clientes/controller/clientes_controller.dart'
    show appDatabaseProvider;
import '../data/app_settings_repository.dart';
import '../data/plan_info.dart';
import '../../../shared/plan/app_plan.dart';
import '../../vendas/data/venda_models.dart';

final planSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return AppSettingsRepository(ref.watch(appDatabaseProvider));
});

final planInfoProvider =
    AsyncNotifierProvider<PlanInfoController, PlanInfo>(PlanInfoController.new);

class PlanInfoController extends AsyncNotifier<PlanInfo> {
  AppSettingsRepository get _settings =>
      ref.read(planSettingsRepositoryProvider);

  @override
  Future<PlanInfo> build() async {
    final db = await ref.read(appDatabaseProvider).database;
    return _load(db);
  }

  Future<void> refresh() async {
    final db = await ref.read(appDatabaseProvider).database;
    state = const AsyncLoading();
    state = AsyncData(await _load(db));
  }

  Future<void> definirPlano(AppPlan plan) async {
    await _settings.salvarPlano(plan);
    await refresh();
  }

  Future<PlanInfo> _load(Database db) async {
    final plan = await _settings.carregarPlano();

    Future<int> count(String sql, [List<Object?> args = const []]) async {
      final rows = await db.rawQuery(sql, args);
      final v = rows.isEmpty ? null : rows.first.values.first;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    final clientes = await count('SELECT COUNT(*) AS c FROM clientes');
    final produtos = await count('SELECT COUNT(*) AS c FROM produtos');
    final vendas = await count(
      'SELECT COUNT(*) AS c FROM vendas WHERE status <> ?',
      [VendaStatus.aberta],
    );

    return PlanInfo(
      plan: plan,
      clientes: clientes,
      produtos: produtos,
      vendas: vendas,
    );
  }
}
