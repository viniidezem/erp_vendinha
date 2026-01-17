import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';

import 'package:erp_revenda/data/db/app_database.dart';
import 'package:erp_revenda/features/financeiro/contas_pagar/data/conta_pagar_repository.dart';
import 'package:erp_revenda/features/financeiro/contas_receber/data/conta_receber_repository.dart';
import 'package:erp_revenda/features/produtos/data/produto_repository.dart';
import 'package:erp_revenda/features/vendas/data/vendas_repository.dart';

class MockDatabase extends Mock implements Database {}

class MockTransaction extends Mock implements Transaction {}

class TransactionRunnerDatabase extends MockDatabase {
  TransactionRunnerDatabase(this.txn);

  final Transaction txn;

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) {
    return action(txn);
  }
}

class MockAppDatabase extends Mock implements AppDatabase {}

class MockProdutoRepository extends Mock implements ProdutoRepository {}

class MockContaPagarRepository extends Mock implements ContaPagarRepository {}

class MockContaReceberRepository extends Mock implements ContaReceberRepository {}

class MockVendasRepository extends Mock implements VendasRepository {}
