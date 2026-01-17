import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:erp_revenda/features/vendas/controller/vendas_controller.dart';
import 'package:erp_revenda/features/vendas/data/venda_models.dart';

void main() {
  test('adicionarItem consolida quando produto e preco sao iguais', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(vendaEmAndamentoProvider.notifier);
    notifier.adicionarItem(
      VendaItem(
        produtoId: 1,
        produtoNome: 'Produto',
        qtd: 1,
        precoUnit: 10,
      ),
    );
    notifier.adicionarItem(
      VendaItem(
        produtoId: 1,
        produtoNome: 'Produto',
        qtd: 2,
        precoUnit: 10,
      ),
    );

    final itens = container.read(vendaEmAndamentoProvider);
    expect(itens, hasLength(1));
    expect(itens.first.qtd, 3);
  });

  test('adicionarItem cria nova linha quando preco diferente', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(vendaEmAndamentoProvider.notifier);
    notifier.adicionarItem(
      VendaItem(
        produtoId: 1,
        produtoNome: 'Produto',
        qtd: 1,
        precoUnit: 10,
      ),
    );
    notifier.adicionarItem(
      VendaItem(
        produtoId: 1,
        produtoNome: 'Produto',
        qtd: 1,
        precoUnit: 12,
      ),
    );

    final itens = container.read(vendaEmAndamentoProvider);
    expect(itens, hasLength(2));
  });

  test('atualizarItemAt consolida linhas duplicadas', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(vendaEmAndamentoProvider.notifier);
    notifier.adicionarItem(
      VendaItem(
        produtoId: 1,
        produtoNome: 'Produto',
        qtd: 1,
        precoUnit: 10,
      ),
    );
    notifier.adicionarItem(
      VendaItem(
        produtoId: 1,
        produtoNome: 'Produto',
        qtd: 1,
        precoUnit: 12,
      ),
    );

    notifier.atualizarItemAt(1, precoUnit: 10);

    final itens = container.read(vendaEmAndamentoProvider);
    expect(itens, hasLength(1));
    expect(itens.first.qtd, 2);
  });
}
