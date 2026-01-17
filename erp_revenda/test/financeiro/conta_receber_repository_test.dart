import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:erp_revenda/features/financeiro/contas_receber/data/conta_receber_model.dart';
import 'package:erp_revenda/features/financeiro/contas_receber/data/conta_receber_repository.dart';

import '../helpers/mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(<String, Object?>{});
    registerFallbackValue(<Object?>[]);
  });

  test('atualizarStatus define valor_recebido=0 ao cancelar', () async {
    final appDb = MockAppDatabase();
    final db = MockDatabase();
    final repo = ContaReceberRepository(appDb);

    when(() => appDb.database).thenAnswer((_) async => db);
    when(
      () => db.update(
        any(),
        any(),
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
      ),
    ).thenAnswer((_) async => 1);

    await repo.atualizarStatus(
      id: 1,
      status: ContaReceberStatus.cancelada,
    );

    final captured = verify(
      () => db.update(
        'contas_receber',
        captureAny(),
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
      ),
    ).captured.single as Map<String, Object?>;

    expect(captured['valor_recebido'], 0);
  });

  test('todasRecebidas retorna true quando todas parcelas estao recebidas', () async {
    final appDb = MockAppDatabase();
    final db = MockDatabase();
    final repo = ContaReceberRepository(appDb);

    when(() => appDb.database).thenAnswer((_) async => db);
    when(() => db.rawQuery(any(), any())).thenAnswer((_) async => [
          {'total': 3, 'recebidas': 3}
        ]);

    final ok = await repo.todasRecebidas(10);
    expect(ok, isTrue);
  });

  test('todasRecebidas retorna false quando ha parcelas em aberto', () async {
    final appDb = MockAppDatabase();
    final db = MockDatabase();
    final repo = ContaReceberRepository(appDb);

    when(() => appDb.database).thenAnswer((_) async => db);
    when(() => db.rawQuery(any(), any())).thenAnswer((_) async => [
          {'total': 3, 'recebidas': 2}
        ]);

    final ok = await repo.todasRecebidas(10);
    expect(ok, isFalse);
  });
}
