import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';

import 'package:erp_revenda/features/financeiro/contas_pagar/data/conta_pagar_repository.dart';

import '../helpers/mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(<String, Object?>{});
    registerFallbackValue(<Object?>[]);
    registerFallbackValue((Transaction _) async {});
  });

  test('criarLancamento falha com total invalido', () async {
    final appDb = MockAppDatabase();
    final db = MockDatabase();
    final repo = ContaPagarRepository(appDb);

    when(() => appDb.database).thenAnswer((_) async => db);

    expect(
      () => repo.criarLancamento(
        fornecedorId: 1,
        total: 0,
        parcelas: 1,
      ),
      throwsArgumentError,
    );
  });

  test('criarLancamento falha quando entrada ja possui lancamentos', () async {
    final appDb = MockAppDatabase();
    final db = MockDatabase();
    final repo = ContaPagarRepository(appDb);

    when(() => appDb.database).thenAnswer((_) async => db);
    when(() => db.rawQuery(any(), any())).thenAnswer((_) async => [
          {'c': 1}
        ]);

    expect(
      () => repo.criarLancamento(
        entradaId: 5,
        fornecedorId: 1,
        total: 100,
        parcelas: 1,
      ),
      throwsStateError,
    );
  });

  test('criarLancamento distribui residual na primeira parcela', () async {
    final appDb = MockAppDatabase();
    final txn = MockTransaction();
    final db = TransactionRunnerDatabase(txn);
    final repo = ContaPagarRepository(appDb);

    when(() => appDb.database).thenAnswer((_) async => db);
    when(() => db.rawQuery(any(), any())).thenAnswer((_) async => [
          {'c': 0}
        ]);
    final inserts = <Map<String, Object?>>[];
    when(() => txn.insert(any(), any())).thenAnswer((invocation) async {
      inserts.add(
        Map<String, Object?>.from(invocation.positionalArguments[1] as Map),
      );
      return 1;
    });

    await repo.criarLancamento(
      entradaId: 10,
      fornecedorId: 2,
      total: 100,
      parcelas: 3,
    );

    final valores = inserts.map((e) => e['valor'] as double).toList();
    expect(valores, [33.34, 33.33, 33.33]);
    expect(inserts.every((e) => e['parcelas_total'] == 3), isTrue);
  });
}
