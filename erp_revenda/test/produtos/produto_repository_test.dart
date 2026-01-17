import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:erp_revenda/features/produtos/data/produto_model.dart';
import 'package:erp_revenda/features/produtos/data/produto_repository.dart';

import '../helpers/mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(<String, Object?>{});
    registerFallbackValue(<Object?>[]);
  });

  Produto buildProduto() => Produto(
        nome: 'Produto',
        precoCusto: 1,
        precoVenda: 2,
        estoque: 0,
        ativo: true,
        createdAt: DateTime(2026, 1, 1),
      );

  test('inserir bloqueia quando limite de produtos estoura', () async {
    final appDb = MockAppDatabase();
    final db = MockDatabase();
    final repo = ProdutoRepository(appDb);

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
          {'c': 50}
        ]);

    expect(() => repo.inserir(buildProduto()), throwsStateError);
  });

  test('inserir permite quando plano pro esta ativo', () async {
    final appDb = MockAppDatabase();
    final txn = MockTransaction();
    final db = TransactionRunnerDatabase(txn);
    final repo = ProdutoRepository(appDb);

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
    when(() => txn.insert(any(), any())).thenAnswer((_) async => 1);

    final id = await repo.inserir(buildProduto());
    expect(id, 1);
  });
}
