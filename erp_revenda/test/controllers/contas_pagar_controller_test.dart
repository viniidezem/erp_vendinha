import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:erp_revenda/features/financeiro/contas_pagar/controller/contas_pagar_controller.dart';
import 'package:erp_revenda/features/financeiro/contas_pagar/data/conta_pagar_model.dart';

import '../helpers/mocks.dart';

void main() {
  test('build usa filtros atuais para listar', () async {
    final repo = MockContaPagarRepository();

    when(
      () => repo.listar(
        search: any(named: 'search'),
        statusFiltro: any(named: 'statusFiltro'),
      ),
    ).thenAnswer((_) async => []);

    final container = ProviderContainer(
      overrides: [
        contasPagarRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    container.read(contasPagarSearchProvider.notifier).state = 'nota';
    container.read(contasPagarStatusFiltroProvider.notifier).state =
        ContaPagarStatus.aberta;

    await container.read(contasPagarControllerProvider.future);

    verify(
      () => repo.listar(
        search: 'nota',
        statusFiltro: ContaPagarStatus.aberta,
      ),
    ).called(1);
  });

  test('criarLancamento chama repo e atualiza lista', () async {
    final repo = MockContaPagarRepository();

    when(
      () => repo.listar(
        search: any(named: 'search'),
        statusFiltro: any(named: 'statusFiltro'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => repo.criarLancamento(
        entradaId: any(named: 'entradaId'),
        fornecedorId: any(named: 'fornecedorId'),
        total: any(named: 'total'),
        parcelas: any(named: 'parcelas'),
        descricao: any(named: 'descricao'),
        vencimentos: any(named: 'vencimentos'),
      ),
    ).thenAnswer((_) async {});

    final container = ProviderContainer(
      overrides: [
        contasPagarRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    await container.read(contasPagarControllerProvider.notifier).criarLancamento(
          fornecedorId: 1,
          total: 100,
          parcelas: 1,
        );

    verify(() => repo.criarLancamento(
          entradaId: null,
          fornecedorId: 1,
          total: 100,
          parcelas: 1,
          descricao: null,
          vencimentos: null,
        )).called(1);
  });
}
