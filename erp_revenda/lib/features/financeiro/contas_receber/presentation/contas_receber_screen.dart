import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/ui/app_colors.dart';
import '../../../../shared/widgets/app_error_dialog.dart';
import '../../../../shared/widgets/app_page.dart';
import '../../../settings/controller/app_preferences_controller.dart';
import '../controller/contas_receber_controller.dart';
import '../data/conta_receber_model.dart';
import '../../../vendas/controller/vendas_controller.dart';
import '../../../vendas/data/venda_models.dart';

class ContasReceberScreen extends ConsumerStatefulWidget {
  const ContasReceberScreen({super.key});

  @override
  ConsumerState<ContasReceberScreen> createState() =>
      _ContasReceberScreenState();
}

class _ContasReceberScreenState extends ConsumerState<ContasReceberScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () {
        ref.read(contasReceberSearchProvider.notifier).state = _searchCtrl.text;
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _fmtDateOnly(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year}';
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _venceAmanha(DateTime? vencimento) {
    if (vencimento == null) return false;
    final now = DateTime.now();
    final tomorrow = _startOfDay(now).add(const Duration(days: 1));
    return _startOfDay(vencimento) == tomorrow;
  }

  bool _podeLembrar(ContaReceber conta) {
    final hasPhone = (conta.clienteTelefone ?? '').trim().isNotEmpty;
    return conta.status == ContaReceberStatus.aberta &&
        conta.clienteWhatsApp &&
        hasPhone &&
        _venceAmanha(conta.vencimentoAt);
  }

  String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  String _buildMensagem(
    ContaReceber conta,
    PedidoDetalhe detalhe, {
    String? storeName,
  }) {
    final cliente = (conta.clienteNome ?? '').trim();
    final loja = (storeName ?? '').trim();
    final venc = conta.vencimentoAt != null ? _fmtDateOnly(conta.vencimentoAt!) : '';
    final lines = <String>[];

    if (cliente.isNotEmpty && loja.isNotEmpty) {
      lines.add('Ola $cliente, aqui e $loja.');
    } else if (cliente.isNotEmpty) {
      lines.add('Ola $cliente.');
    } else if (loja.isNotEmpty) {
      lines.add('Ola! Aqui e $loja.');
    } else {
      lines.add('Ola!');
    }

    lines.add(
      'Lembrete: sua parcela ${conta.parcelaNumero}/${conta.parcelasTotal} '
      'do pedido #${conta.vendaId} vence em ${venc.isEmpty ? 'breve' : venc}.',
    );
    lines.add('Valor da parcela: R\$ ${conta.valor.toStringAsFixed(2)}.');
    lines.add('Resumo do pedido:');
    for (final item in detalhe.itens) {
      lines.add(
        '- ${item.produtoNome} x${item.qtd.toStringAsFixed(2)} '
        '(R\$ ${item.subtotal.toStringAsFixed(2)})',
      );
    }
    lines.add('Total do pedido: R\$ ${detalhe.total.toStringAsFixed(2)}.');

    return lines.join('\n');
  }

  Future<void> _enviarWhatsapp(
    ContaReceber conta,
    String? storeName,
  ) async {
    final telefone = (conta.clienteTelefone ?? '').trim();
    final digits = _normalizePhone(telefone);
    if (digits.isEmpty) {
      if (!mounted) return;
      await showErrorDialog(context, 'Cliente sem telefone valido.');
      return;
    }
    if (!conta.clienteWhatsApp) {
      if (!mounted) return;
      await showErrorDialog(context, 'Telefone nao marcado como WhatsApp.');
      return;
    }
    final repo = ref.read(vendasRepositoryProvider);
    PedidoDetalhe detalhe;
    try {
      detalhe = await repo.carregarPedidoDetalhe(conta.vendaId);
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(context, 'Erro ao carregar pedido:\n$e');
      return;
    }
    if (!mounted) return;

    final texto = _buildMensagem(
      conta,
      detalhe,
      storeName: storeName,
    );
    final uri = Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(texto)}');
    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel abrir o WhatsApp.')),
      );
    }
  }

  Future<void> _mostrarLembretesAmanha(
    List<ContaReceber> contas,
    String? storeName,
  ) async {
    final itens = contas.where(_podeLembrar).toList();
    if (itens.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma parcela vence amanha.')),
      );
      return;
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lembretes para amanha',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Toque em cada cliente para abrir o WhatsApp com a mensagem pronta.',
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: itens.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final conta = itens[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(conta.clienteNome ?? 'Cliente'),
                      subtitle: Text(
                        'Pedido #${conta.vendaId} - '
                        'Parcela ${conta.parcelaNumero}/${conta.parcelasTotal} '
                        '- R\$ ${conta.valor.toStringAsFixed(2)}',
                      ),
                      trailing: TextButton(
                        onPressed: () => _enviarWhatsapp(conta, storeName),
                        child: const Text('Abrir'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(ContaReceber conta) {
    if (conta.status == ContaReceberStatus.recebida) return AppColors.success;
    if (conta.status == ContaReceberStatus.cancelada) return AppColors.textMuted;
    if (conta.isVencida) return AppColors.danger;
    return AppColors.primary;
  }

  String _statusLabel(ContaReceber conta) {
    if (conta.isVencida) return 'Vencida';
    return ContaReceberStatus.label(conta.status);
  }

  Future<void> _atualizarStatus(
    ContaReceber conta,
    String status,
  ) async {
    try {
      await ref
          .read(contasReceberControllerProvider.notifier)
          .atualizarStatus(
            id: conta.id!,
            status: status,
            vendaId: conta.vendaId,
            valorRecebido: status == ContaReceberStatus.recebida
                ? conta.valor
                : status == ContaReceberStatus.cancelada
                    ? 0
                    : null,
          );
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(context, 'Erro ao atualizar status:\n$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncLista = ref.watch(contasReceberControllerProvider);
    final statusFiltro = ref.watch(contasReceberStatusFiltroProvider);
    final prefsAsync = ref.watch(appPreferencesProvider);
    final storeName = prefsAsync.value?.storeName;
    final listaAtual = asyncLista.asData?.value ?? const <ContaReceber>[];
    final temLembretes = listaAtual.any(_podeLembrar);

    return AppPage(
      title: 'Contas a receber',
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: () =>
              ref.read(contasReceberControllerProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh, color: Colors.white),
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por cliente ou pedido',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: statusFiltro,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Todos'),
                          ),
                          ...ContaReceberStatus.filtros.map(
                            (s) => DropdownMenuItem<String?>(
                              value: s,
                              child: Text(ContaReceberStatus.label(s)),
                            ),
                          ),
                        ],
                        onChanged: (v) => ref
                            .read(contasReceberStatusFiltroProvider.notifier)
                            .state = v,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => ref
                          .read(contasReceberControllerProvider.notifier)
                          .refresh(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Atualizar'),
                    ),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: temLembretes ? () => _mostrarLembretesAmanha(
                                listaAtual,
                                storeName,
                              )
                          : null,
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Lembrar todos'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: asyncLista.when(
              data: (lista) {
                if (lista.isEmpty) {
                  return const Center(
                    child: Text('Nenhum recebimento encontrado.'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: lista.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final conta = lista[i];
                    final podeLembrar = _podeLembrar(conta);
                    final parts = <String>[
                      'Pedido #${conta.vendaId}',
                      'Parcela ${conta.parcelaNumero}/${conta.parcelasTotal}',
                    ];
                    if (conta.vencimentoAt != null) {
                      parts.add('Venc: ${_fmtDateOnly(conta.vencimentoAt!)}');
                    }

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () => context.push('/pedidos/${conta.vendaId}'),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              conta.clienteNome ?? 'Cliente nao informado',
                            ),
                          ),
                          Text(
                            'R\$ ${conta.valor.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(parts.join(' - ')),
                          const SizedBox(height: 2),
                          Text(
                            'Status: ${_statusLabel(conta)}',
                            style: TextStyle(
                              color: _statusColor(conta),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      trailing: conta.status == ContaReceberStatus.aberta
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (podeLembrar)
                                  IconButton(
                                    tooltip: 'Lembrar no WhatsApp',
                                    icon: Icon(
                                      Icons.chat_bubble_outline,
                                      color: AppColors.success,
                                    ),
                                    onPressed: () =>
                                        _enviarWhatsapp(conta, storeName),
                                  ),
                                PopupMenuButton<String>(
                                  onSelected: (v) => _atualizarStatus(conta, v),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: ContaReceberStatus.recebida,
                                      child: Text('Marcar como recebida'),
                                    ),
                                    PopupMenuItem(
                                      value: ContaReceberStatus.cancelada,
                                      child: Text('Cancelar'),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : null,
                    );
                  },
                );
              },
              error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }
}
