import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/app_error_dialog.dart';
import '../../shared/widgets/app_page.dart';
import '../../app/ui/app_colors.dart';
import 'contas_pagar/controller/contas_pagar_controller.dart';
import 'contas_pagar/data/conta_pagar_model.dart';

class FinanceiroScreen extends ConsumerStatefulWidget {
  const FinanceiroScreen({super.key});

  @override
  ConsumerState<FinanceiroScreen> createState() => _FinanceiroScreenState();
}

class _FinanceiroScreenState extends ConsumerState<FinanceiroScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () {
        ref.read(contasPagarSearchProvider.notifier).state = _searchCtrl.text;
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

  Color _statusColor(ContaPagar conta) {
    if (conta.status == ContaPagarStatus.paga) return AppColors.success;
    if (conta.status == ContaPagarStatus.cancelada) return AppColors.textMuted;
    if (conta.isVencida) return AppColors.danger;
    return AppColors.primary;
  }

  String _statusLabel(ContaPagar conta) {
    if (conta.isVencida) return 'Vencida';
    return ContaPagarStatus.label(conta.status);
  }

  Future<void> _atualizarStatus(
    ContaPagar conta,
    String status,
  ) async {
    try {
      await ref
          .read(contasPagarControllerProvider.notifier)
          .atualizarStatus(id: conta.id!, status: status);
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(context, 'Erro ao atualizar status:\n$e');
    }
  }

  void _openForm() {
    context.push('/financeiro/contas-pagar/form');
  }

  @override
  Widget build(BuildContext context) {
    final asyncLista = ref.watch(contasPagarControllerProvider);
    final statusFiltro = ref.watch(contasPagarStatusFiltroProvider);

    return AppPage(
      title: 'Financeiro',
      actions: [
        IconButton(
          tooltip: 'Nova conta a pagar',
          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
          onPressed: _openForm,
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
                hintText: 'Buscar por fornecedor ou descricao',
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
                          ...ContaPagarStatus.filtros.map(
                            (s) => DropdownMenuItem<String?>(
                              value: s,
                              child: Text(ContaPagarStatus.label(s)),
                            ),
                          ),
                        ],
                        onChanged: (v) => ref
                            .read(contasPagarStatusFiltroProvider.notifier)
                            .state = v,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton.icon(
                  onPressed: () => ref
                      .read(contasPagarControllerProvider.notifier)
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
                  return const Center(child: Text('Nenhum lancamento encontrado.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: lista.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final conta = lista[i];
                    final parts = <String>[
                      'Parcela ${conta.parcelaNumero}/${conta.parcelasTotal}',
                      'Total R\$ ${conta.total.toStringAsFixed(2)}',
                    ];
                    if (conta.descricao != null &&
                        conta.descricao!.trim().isNotEmpty) {
                      parts.add(conta.descricao!.trim());
                    }
                    if (conta.vencimentoAt != null) {
                      parts.add('Venc: ${_fmtDateOnly(conta.vencimentoAt!)}');
                    }

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Row(
                        children: [
                          Expanded(child: Text(conta.fornecedorNome)),
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
                          if (conta.pagoAt != null) ...[
                            const SizedBox(height: 2),
                            Text('Pago em: ${_fmtDateOnly(conta.pagoAt!)}'),
                          ],
                        ],
                      ),
                      trailing: conta.status == ContaPagarStatus.aberta
                          ? PopupMenuButton<String>(
                              onSelected: (v) => _atualizarStatus(conta, v),
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: ContaPagarStatus.paga,
                                  child: Text('Marcar como paga'),
                                ),
                                const PopupMenuItem(
                                  value: ContaPagarStatus.cancelada,
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
