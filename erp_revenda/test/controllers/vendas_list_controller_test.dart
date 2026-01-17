import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:erp_revenda/features/vendas/controller/vendas_controller.dart';
import 'package:erp_revenda/features/vendas/data/venda_models.dart';

import '../helpers/mocks.dart';

void main() {
  test('build usa filtros atuais para listar vendas', () async {
    final repo = MockVendasRepository();

    when(
      () => repo.listarVendas(
        statusFiltro: any(named: 'statusFiltro'),
        search: any(named: 'search'),
      ),
    ).thenAnswer((_) async => <Venda>[]);

    final container = ProviderContainer(
      overrides: [
        vendasRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    container.read(pedidosSearchProvider.notifier).state = 'joao';
    container.read(pedidosStatusFiltroProvider.notifier).state = VendaStatus.pedido;

    await container.read(vendasListProvider.future);

    verify(
      () => repo.listarVendas(
        statusFiltro: VendaStatus.pedido,
        search: 'joao',
      ),
    ).called(1);
  });
}
