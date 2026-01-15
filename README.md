# ERP Revenda

ERP offline-first para revenda de cosmeticos, pensado para usuarios com baixo
conhecimento tecnico. Os dados ficam locais (SQLite) e o app funciona sem
internet.

## Stack
- Flutter / Dart (SDK >= 3.9.2)
- Riverpod
- GoRouter
- Sqflite (SQLite)

## Funcionalidades
- Dashboard com indicadores (vendas, clientes, estoque, pedidos)
- Clientes + enderecos (multi-enderecos)
- Produtos + categorias dinamicas
- Vendas/pedidos com checkout completo
- Formas de pagamento com configuracoes (desconto, parcelas, vencimento)
- Financeiro: contas a receber geradas por parcela

## Regras de negocio
- Pedido sempre inicia com status PEDIDO
- Endereco de entrega nao e pre-selecionado
- Se cliente nao tiver endereco, Retirada/sem entrega e valida
- Itens do carrinho separados por preco (mesmo produto + preco diferente)
- Parcelas com duas casas decimais e residual na primeira parcela

## Fluxo de venda
1) Selecionar cliente e itens
2) Checkout: entrega/retirada, forma de pagamento, desconto, parcelas, vencimentos
3) Pedido gravado com log de status e contas a receber

## Banco de dados
- Versao atual: v12
- Auto-repair em onOpen para garantir schema minimo
- Tabelas: clientes, produtos, vendas, venda_itens, venda_status_log,
  formas_pagamento, contas_receber, categorias e relacionamentos

## Execucao local
```bash
flutter pub get
flutter run
```

## Build release (APK)
```bash
flutter build apk --release
```

## Estrutura do projeto
- lib/features: modulos (clientes, produtos, vendas, cadastros, etc.)
- lib/shared: widgets e utilitarios compartilhados
- lib/data: banco e repositorios base

## Patches recentes
- 2A-FIX: Formas de pagamento
- 2B-1 / 2B-1.1 / 2B-2 / 2B-2.1: Checkout, status e auto-repair

## Roadmap (exemplos)
- Financeiro completo (baixas/recebimentos)
- Relatorios basicos
- Exportacao/importacao de dados
