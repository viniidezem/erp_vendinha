import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/ui/app_colors.dart';
import '../../../../shared/widgets/app_error_dialog.dart';
import '../../../../shared/widgets/app_page.dart';
import '../controller/contas_receber_controller.dart';
import '../data/conta_receber_model.dart';

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
                TextButton.icon(
                  onPressed: () => ref
                      .read(contasReceberControllerProvider.notifier)
                      .refresh(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Atualizar'),
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
                          ? PopupMenuButton<String>(
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
