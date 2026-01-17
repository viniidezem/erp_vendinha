import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:erp_revenda/features/financeiro/contas_receber/controller/contas_receber_controller.dart';
import 'package:erp_revenda/features/financeiro/contas_receber/data/conta_receber_model.dart';
import 'package:erp_revenda/features/vendas/controller/vendas_controller.dart';

import '../helpers/mocks.dart';

void main() {
  test('build usa filtros atuais para listar', () async {
    final repo = MockContaReceberRepository();
    final vendasRepo = MockVendasRepository();

    when(
      () => repo.listar(
        search: any(named: 'search'),
        statusFiltro: any(named: 'statusFiltro'),
      ),
    ).thenAnswer((_) async => []);

    final container = ProviderContainer(
      overrides: [
        contasReceberRepositoryProvider.overrideWithValue(repo),
        vendasRepositoryProvider.overrideWithValue(vendasRepo),
      ],
    );
    addTearDown(container.dispose);

    container.read(contasReceberSearchProvider.notifier).state = 'ana';
    container.read(contasReceberStatusFiltroProvider.notifier).state =
        ContaReceberStatus.aberta;

    await container.read(contasReceberControllerProvider.future);

    verify(
      () => repo.listar(
        search: 'ana',
        statusFiltro: ContaReceberStatus.aberta,
      ),
    ).called(1);
  });

  test('atualizarStatus marca pagamento quando todas recebidas', () async {
    final repo = MockContaReceberRepository();
    final vendasRepo = MockVendasRepository();

    when(
      () => repo.listar(
        search: any(named: 'search'),
        statusFiltro: any(named: 'statusFiltro'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => repo.atualizarStatus(
        id: any(named: 'id'),
        status: any(named: 'status'),
        valorRecebido: any(named: 'valorRecebido'),
      ),
    ).thenAnswer((_) async {});
    when(() => repo.todasRecebidas(10)).thenAnswer((_) async => true);
    when(() => vendasRepo.marcarPagamentoEfetuadoSePossivel(10))
        .thenAnswer((_) async {});

    final container = ProviderContainer(
      overrides: [
        contasReceberRepositoryProvider.overrideWithValue(repo),
        vendasRepositoryProvider.overrideWithValue(vendasRepo),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(contasReceberControllerProvider.notifier)
        .atualizarStatus(
          id: 1,
          status: ContaReceberStatus.recebida,
          vendaId: 10,
          valorRecebido: 10,
        );

    verify(() => vendasRepo.marcarPagamentoEfetuadoSePossivel(10)).called(1);
  });
}
