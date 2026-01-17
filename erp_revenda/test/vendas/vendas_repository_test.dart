import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';

import 'package:erp_revenda/features/vendas/data/vendas_repository.dart';
import 'package:erp_revenda/features/vendas/data/venda_models.dart';

import '../helpers/mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(<String, Object?>{});
    registerFallbackValue(<Object?>[]);
    registerFallbackValue((Transaction _) async {});
  });

  test('finalizarVenda aplica desconto percentual e gera parcelas com residual', () async {
    final appDb = MockAppDatabase();
    final txn = MockTransaction();
    final db = TransactionRunnerDatabase(txn);
    final produtoRepo = MockProdutoRepository();
    final repo = VendasRepository(appDb, produtoRepo);

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
          {'c': 0}
        ]);
    final vendasInserts = <Map<String, Object?>>[];
    final contasInserts = <Map<String, Object?>>[];
    final statusInserts = <Map<String, Object?>>[];

    when(() => txn.insert(any(), any())).thenAnswer((invocation) async {
      final table = invocation.positionalArguments[0] as String;
      final values = Map<String, Object?>.from(
        invocation.positionalArguments[1] as Map,
      );
      if (table == 'vendas') {
        vendasInserts.add(values);
        return 10;
      }
      if (table == 'contas_receber') {
        contasInserts.add(values);
        return 1;
      }
      if (table == 'venda_status_log') {
        statusInserts.add(values);
        return 1;
      }
      return 1;
    });

    when(() => txn.rawQuery(any(), any())).thenAnswer((_) async => []);
    when(() => txn.rawUpdate(any(), any())).thenAnswer((_) async => 1);
    when(
      () => txn.update(
        any(),
        any(),
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
      ),
    ).thenAnswer((_) async => 1);

    final vencimentos = [
      DateTime(2026, 1, 10),
      DateTime(2026, 2, 10),
      DateTime(2026, 3, 10),
    ];

    await repo.finalizarVenda(
      clienteId: 1,
      itens: [
        VendaItem(
          produtoId: 1,
          produtoNome: 'Produto',
          qtd: 1,
          precoUnit: 100,
        ),
      ],
      total: 100,
      descontoPercentual: 10,
      parcelas: 3,
      vencimentos: vencimentos,
      status: VendaStatus.pedido,
    );

    expect(vendasInserts, hasLength(1));
    final venda = vendasInserts.first;
    expect(venda['total'], 90.0);
    expect(venda['desconto_valor'], 10.0);
    expect(venda['desconto_percentual'], 10.0);

    final valores = contasInserts.map((e) => e['valor'] as double).toList();
    expect(valores, [30.0, 30.0, 30.0]);
    expect(
      contasInserts.map((e) => e['vencimento_at']).toList(),
      vencimentos.map((d) => d.millisecondsSinceEpoch).toList(),
    );
    expect(statusInserts, hasLength(1));
  });

  test('finalizarVenda limita desconto ao total', () async {
    final appDb = MockAppDatabase();
    final txn = MockTransaction();
    final db = TransactionRunnerDatabase(txn);
    final produtoRepo = MockProdutoRepository();
    final repo = VendasRepository(appDb, produtoRepo);

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
          {'c': 0}
        ]);
    final vendasInserts = <Map<String, Object?>>[];

    when(() => txn.insert(any(), any())).thenAnswer((invocation) async {
      final table = invocation.positionalArguments[0] as String;
      final values = Map<String, Object?>.from(
        invocation.positionalArguments[1] as Map,
      );
      if (table == 'vendas') {
        vendasInserts.add(values);
        return 10;
      }
      return 1;
    });

    when(() => txn.rawQuery(any(), any())).thenAnswer((_) async => []);
    when(() => txn.rawUpdate(any(), any())).thenAnswer((_) async => 1);
    when(
      () => txn.update(
        any(),
        any(),
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
      ),
    ).thenAnswer((_) async => 1);

    await repo.finalizarVenda(
      clienteId: 1,
      itens: [
        VendaItem(
          produtoId: 1,
          produtoNome: 'Produto',
          qtd: 1,
          precoUnit: 100,
        ),
      ],
      total: 100,
      descontoValor: 150,
      parcelas: 1,
      status: VendaStatus.pedido,
    );

    final venda = vendasInserts.first;
    expect(venda['desconto_valor'], 100.0);
    expect(venda['total'], 0.0);
  });

  test('finalizarVenda distribui residual na primeira parcela', () async {
    final appDb = MockAppDatabase();
    final txn = MockTransaction();
    final db = TransactionRunnerDatabase(txn);
    final produtoRepo = MockProdutoRepository();
    final repo = VendasRepository(appDb, produtoRepo);

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
          {'c': 0}
        ]);

    final contasInserts = <Map<String, Object?>>[];
    when(() => txn.insert(any(), any())).thenAnswer((invocation) async {
      final table = invocation.positionalArguments[0] as String;
      final values = Map<String, Object?>.from(
        invocation.positionalArguments[1] as Map,
      );
      if (table == 'vendas') return 10;
      if (table == 'contas_receber') {
        contasInserts.add(values);
        return 1;
      }
      return 1;
    });

    when(() => txn.rawQuery(any(), any())).thenAnswer((_) async => []);
    when(() => txn.rawUpdate(any(), any())).thenAnswer((_) async => 1);
    when(
      () => txn.update(
        any(),
        any(),
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
      ),
    ).thenAnswer((_) async => 1);

    await repo.finalizarVenda(
      clienteId: 1,
      itens: [
        VendaItem(
          produtoId: 1,
          produtoNome: 'Produto',
          qtd: 1,
          precoUnit: 100,
        ),
      ],
      total: 100,
      parcelas: 3,
      status: VendaStatus.pedido,
    );

    final valores = contasInserts.map((e) => e['valor'] as double).toList();
    expect(valores, [33.34, 33.33, 33.33]);
  });

  test('finalizarVenda bloqueia quando limite de vendas estoura', () async {
    final appDb = MockAppDatabase();
    final db = MockDatabase();
    final produtoRepo = MockProdutoRepository();
    final repo = VendasRepository(appDb, produtoRepo);

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
          {'c': 200}
        ]);

    expect(
      () => repo.finalizarVenda(
        clienteId: 1,
        itens: [
          VendaItem(
            produtoId: 1,
            produtoNome: 'Produto',
            qtd: 1,
            precoUnit: 100,
          ),
        ],
        total: 100,
        parcelas: 1,
        status: VendaStatus.pedido,
      ),
      throwsStateError,
    );
  });
}
