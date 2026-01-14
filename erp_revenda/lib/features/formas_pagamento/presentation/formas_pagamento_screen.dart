import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_page.dart';
import '../controller/formas_pagamento_controller.dart';
import '../data/forma_pagamento_model.dart';

class FormasPagamentoScreen extends ConsumerStatefulWidget {
  const FormasPagamentoScreen({super.key});

  @override
  ConsumerState<FormasPagamentoScreen> createState() => _FormasPagamentoScreenState();
}

class _FormasPagamentoScreenState extends ConsumerState<FormasPagamentoScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () {
        ref.read(formasPagamentoSearchProvider.notifier).state = _searchCtrl.text;
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openForm({FormaPagamento? forma}) {
    context.push('/formas-pagamento/form', extra: forma);
  }

  @override
  Widget build(BuildContext context) {
    final onlyActive = ref.watch(formasPagamentoSomenteAtivasProvider);
    final asyncLista = ref.watch(formasPagamentoControllerProvider);

    return AppPage(
      title: 'Formas de pagamento',
      actions: [
        IconButton(
          tooltip: 'Nova forma',
          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
          onPressed: () => _openForm(),
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
                hintText: 'Buscar por nome…',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Checkbox(
                  value: onlyActive,
                  onChanged: (v) => ref.read(formasPagamentoSomenteAtivasProvider.notifier).state = v ?? true,
                ),
                const Expanded(child: Text('Mostrar somente ativas')),
                TextButton.icon(
                  onPressed: () => ref.read(formasPagamentoControllerProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Atualizar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: asyncLista.when(
              data: (lista) {
                if (lista.isEmpty) {
                  return const Center(child: Text('Nenhuma forma encontrada.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: lista.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final fp = lista[i];

                    final parts = <String>[];
                    parts.add(fp.permiteDesconto ? 'Permite desconto' : 'Sem desconto');
                    if (fp.permiteParcelamento) {
                      parts.add('Parcelamento até ${fp.maxParcelas}x');
                    } else {
                      parts.add('Sem parcelamento');
                    }

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(fp.nome),
                      subtitle: Text(parts.join(' • ')),
                      onTap: () => _openForm(forma: fp),
                      trailing: Switch(
                        value: fp.ativo,
                        onChanged: (v) {
                          if (fp.id == null) return;
                          ref.read(formasPagamentoControllerProvider.notifier).setAtivo(fp.id!, v);
                        },
                      ),
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
