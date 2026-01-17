import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/ui/app_colors.dart';
import '../../../shared/plan/plan_limit_banner.dart';
import '../../../shared/widgets/app_page.dart';
import '../controller/clientes_controller.dart';
import '../../settings/controller/plan_controller.dart';

class ClientesScreen extends ConsumerStatefulWidget {
  const ClientesScreen({super.key});

  @override
  ConsumerState<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends ConsumerState<ClientesScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Estado inicial do campo (mantém se já havia filtro)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = ref.read(clientesSearchProvider);
      _searchCtrl.text = current;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(clientesSearchProvider.notifier).state = v.trim();
    });
  }

  String _normalizePhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits;
  }

  Future<void> _openWhatsApp(String? phone) async {
    final value = (phone ?? '').trim();
    if (value.isEmpty) return;
    final digits = _normalizePhone(value);
    if (digits.isEmpty) return;
    final uri = Uri.parse('https://wa.me/$digits');
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

  @override
  Widget build(BuildContext context) {
    final onlyActive = ref.watch(clientesSomenteAtivosProvider);
    final asyncClientes = ref.watch(clientesControllerProvider);
    final planAsync = ref.watch(planInfoProvider);

    return AppPage(
      title: 'Clientes',
      actions: [
        IconButton(
          tooltip: 'Novo cliente',
          icon: const Icon(Icons.add),
          onPressed: () => context.push('/clientes/form'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              onChanged: (v) {
                _onSearchChanged(v);
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: 'Buscar clientes...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearchChanged('');
                          setState(() {});
                        },
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Somente ativos'),
                    selected: onlyActive,
                    onSelected: (v) {
                      ref.read(clientesSomenteAtivosProvider.notifier).state =
                          v;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            planAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (info) {
                final max = info.maxClientes;
                if (info.isPro || max == null || !info.nearClientes()) {
                  return const SizedBox.shrink();
                }
                return PlanLimitBanner(
                  label: 'clientes',
                  used: info.clientes,
                  max: max,
                  onTap: () => context.push('/settings/plano'),
                );
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: asyncClientes.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Erro ao carregar clientes: $e')),
                data: (clientes) {
                  if (clientes.isEmpty) {
                    return const Center(
                      child: Text('Nenhum cliente encontrado.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: clientes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final c = clientes[i];

                      final telefone = (c.telefone ?? '').trim();
                      final hasPhone = telefone.isNotEmpty;
                      final showWhatsBadge = c.telefoneWhatsapp;
                      final canOpenWhats = c.telefoneWhatsapp && hasPhone;

                      final subtitleParts = <String>[];
                      if ((c.apelido ?? '').trim().isNotEmpty) {
                        subtitleParts.add('Apelido: ${c.apelido}');
                      }
                      if (hasPhone) {
                        subtitleParts.add('Tel: ${c.telefone}');
                      }
                      if ((c.cpf ?? '').trim().isNotEmpty) {
                        subtitleParts.add('CPF: ${c.cpf}');
                      }

                      return Card(
                        child: ListTile(
                          title: Text(
                            c.nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: (subtitleParts.isEmpty && !showWhatsBadge)
                              ? null
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (subtitleParts.isNotEmpty)
                                      Text(
                                        subtitleParts.join(' - '),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if (showWhatsBadge) ...[
                                      const SizedBox(height: 4),
                                      const _WhatsBadge(),
                                    ],
                                  ],
                                ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (canOpenWhats)
                                IconButton(
                                  tooltip: 'WhatsApp',
                                  icon: const Icon(Icons.chat_bubble_outline),
                                  onPressed: () => _openWhatsApp(telefone),
                                ),
                              Chip(label: Text(c.status.label)),
                            ],
                          ),

                          onTap: () => context.push('/clientes/form', extra: c),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhatsBadge extends StatelessWidget {
  const _WhatsBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
      ),
      child: const Text(
        'WhatsApp',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.success,
        ),
      ),
    );
  }
}
