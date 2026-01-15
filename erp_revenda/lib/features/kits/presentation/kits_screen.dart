import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_page.dart';
import '../controller/kits_controller.dart';

class KitsScreen extends ConsumerStatefulWidget {
  const KitsScreen({super.key});

  @override
  ConsumerState<KitsScreen> createState() => _KitsScreenState();
}

class _KitsScreenState extends ConsumerState<KitsScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () {
        ref.read(kitsSearchProvider.notifier).state = _searchCtrl.text;
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openForm({int? kitId}) {
    context.push('/kits/form', extra: kitId);
  }

  @override
  Widget build(BuildContext context) {
    final asyncLista = ref.watch(kitsControllerProvider);
    final onlyActive = ref.watch(kitsSomenteAtivosProvider);

    return AppPage(
      title: 'Kits',
      actions: [
        IconButton(
          tooltip: 'Novo kit',
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
                hintText: 'Buscar por nome',
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
                  onChanged: (v) =>
                      ref.read(kitsSomenteAtivosProvider.notifier).state =
                          v ?? true,
                ),
                const Expanded(child: Text('Mostrar somente ativos')),
                TextButton.icon(
                  onPressed: () =>
                      ref.read(kitsControllerProvider.notifier).refresh(),
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
                  return const Center(child: Text('Nenhum kit encontrado.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: lista.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final kit = lista[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(kit.nome),
                      subtitle:
                          Text('Preço: R\$ ${kit.precoVenda.toStringAsFixed(2)}'),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _openForm(kitId: kit.id),
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
