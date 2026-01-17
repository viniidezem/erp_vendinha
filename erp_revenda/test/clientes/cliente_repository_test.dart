import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:erp_revenda/features/clientes/data/cliente_model.dart';
import 'package:erp_revenda/features/clientes/data/cliente_repository.dart';

import '../helpers/mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(<String, Object?>{});
    registerFallbackValue(<Object?>[]);
  });

  Cliente buildCliente() => Cliente(
        nome: 'Cliente',
        telefoneWhatsapp: false,
        status: ClienteStatus.ativo,
        createdAt: DateTime(2026, 1, 1),
      );

  test('inserir bloqueia quando limite de clientes estoura', () async {
    final appDb = MockAppDatabase();
    final db = MockDatabase();
    final repo = ClienteRepository(appDb);

    when(() => appDb.database).thenAnswer((_) async => db);
    when(
      () => db.query(
        'app_settings',
        columns: any(named: 'columns'),
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => []);
    when(() => db.rawQuery(any(), any())).thenAnswer((_) async => [
          {'c': 20}
        ]);

    expect(() => repo.inserir(buildCliente()), throwsStateError);
  });

  test('inserir permite quando plano pro esta ativo', () async {
    final appDb = MockAppDatabase();
    final db = MockDatabase();
    final repo = ClienteRepository(appDb);

    when(() => appDb.database).thenAnswer((_) async => db);
    when(
      () => db.query(
        'app_settings',
        columns: any(named: 'columns'),
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => [
          {'value': 'pro'}
        ]);
    when(() => db.rawQuery(any(), any())).thenAnswer((_) async => [
          {'c': 999}
        ]);
    when(() => db.insert(any(), any())).thenAnswer((_) async => 1);

    final id = await repo.inserir(buildCliente());
    expect(id, 1);
  });
}
