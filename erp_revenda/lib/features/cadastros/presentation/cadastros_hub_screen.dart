import 'package:erp_revenda/features/categorias/data/categoria_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_error_dialog.dart';
import '../../../shared/widgets/app_page.dart';
import '../../../app/ui/app_colors.dart';

import '../controller/cadastros_resumo_controller.dart';
import '../data/cadastros_resumo.dart';
import '../../fornecedores/data/fornecedor_model.dart';

class CadastrosHubScreen extends ConsumerWidget {
  const CadastrosHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumoAsync = ref.watch(cadastrosResumoProvider);

    // Mostra “—” enquanto carrega / se der erro, sem quebrar tela.
    CadastrosResumo? resumo;
    resumoAsync.whenData((v) => resumo = v);

    return AppPage(
      title: 'Cadastros',
      showBack: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _SectionTitle('Principais'),
          const SizedBox(height: 12),
          _HubCard(
            icon: Icons.people_outline,
            title: 'Clientes',
            subtitle: 'Cadastrar, editar e consultar',
            countText: resumo == null
                ? '—'
                : '${resumo!.clientesAtivos}/${resumo!.clientesTotal} ativos',
            onTap: () => context.push('/clientes'),
            onNew: () => context.push('/clientes/form'),
          ),
          const SizedBox(height: 12),
          _HubCard(
            icon: Icons.inventory_2_outlined,
            title: 'Produtos',
            subtitle: 'Cadastrar, editar e controlar estoque',
            countText: resumo == null
                ? '—'
                : '${resumo!.produtosAtivos} ativos • ${resumo!.produtosComSaldo} c/ saldo',
            onTap: () => context.push('/produtos'),
            onNew: () => context.push('/produtos/form'),
          ),
          const SizedBox(height: 24),
          _SectionTitle('Complementares'),
          const SizedBox(height: 12),
          _HubCard(
            icon: Icons.inventory_outlined,
            title: 'Kits',
            subtitle: 'Combos com preco fixo',
            countText: null,
            onTap: () => context.push('/kits'),
            onNew: () => context.push('/kits/form'),
          ),
          const SizedBox(height: 12),
          _HubCard(
            icon: Icons.local_shipping_outlined,
            title: 'Fornecedores',
            subtitle: 'Cadastro rapido (nome, contato, telefone, e-mail)',
            countText: resumo == null ? '—' : '${resumo!.fornecedores}',
            onTap: () => _openSheet(context, const _FornecedoresSheet()),
            onNew: () =>
                _openSheet(context, const _FornecedoresSheet(openCreate: true)),
          ),
          const SizedBox(height: 12),
          _HubCard(
            icon: Icons.factory_outlined,
            title: 'Fabricantes',
            subtitle: 'Lista e criação rápida',
            countText: resumo == null ? '—' : '${resumo!.fabricantes}',
            onTap: () => _openSheet(context, const _FabricantesSheet()),
            onNew: () =>
                _openSheet(context, const _FabricantesSheet(openCreate: true)),
          ),
          const SizedBox(height: 12),
          _HubCard(
            icon: Icons.category_outlined,
            title: 'Categorias',
            subtitle: 'Ocasião • Família • Propriedades',
            countText: resumo == null
                ? '—'
                : '${resumo!.categoriasOcasiao} • ${resumo!.categoriasFamilia} • ${resumo!.categoriasPropriedade}',
            onTap: () => _openSheet(context, const _CategoriasSheet()),
            onNew: () =>
                _openSheet(context, const _CategoriasSheet(openCreate: true)),
          ),
          const SizedBox(height: 24),
          _SectionTitle('Financeiro'),
          const SizedBox(height: 12),
                    _HubCard(
            icon: Icons.payments_outlined,
            title: 'Formas de pagamento',
            subtitle: 'Desconto • Parcelamento',
            countText: resumo == null
                ? '—'
                : '${resumo!.formasPagamentoAtivas}/${resumo!.formasPagamentoTotal} ativas',
            onTap: () => context.push('/formas-pagamento'),
            onNew: () => context.push('/formas-pagamento/form'),
          ),
          const SizedBox(height: 12),

_HubCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Contas a pagar/receber',
            subtitle: 'Lançamentos e visão geral',
            countText: null,
            onTap: () => context.push('/financeiro'),
          ),
          const SizedBox(height: 16),
          // Atualização manual (útil após criar itens)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => ref.invalidate(cadastrosResumoProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Atualizar contadores'),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _openSheet(BuildContext context, Widget child) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (_) => child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _HubCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? countText;
  final VoidCallback onTap;
  final VoidCallback? onNew;

  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.countText,
    this.onNew,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (countText != null) ...[
                      const SizedBox(height: 10),
                      _CountPill(text: countText!),
                    ],
                  ],
                ),
              ),
              if (onNew != null) ...[
                const SizedBox(width: 10),
                Column(
                  children: [
                    OutlinedButton.icon(
                      onPressed: onNew,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Novo'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  final String text;
  const _CountPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ======================================================
// Fornecedores (modal)
// ======================================================
class _FornecedoresSheet extends ConsumerStatefulWidget {
  final bool openCreate;
  const _FornecedoresSheet({this.openCreate = false});

  @override
  ConsumerState<_FornecedoresSheet> createState() => _FornecedoresSheetState();
}

class _FornecedoresSheetState extends ConsumerState<_FornecedoresSheet> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.openCreate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openFornecedorDialog();
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openFornecedorDialog({Fornecedor? fornecedor}) async {
    final isEdit = fornecedor != null;
    final nomeCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final contatoNomeCtrl = TextEditingController();
    final contatoTelCtrl = TextEditingController();

    if (fornecedor != null) {
      nomeCtrl.text = fornecedor.nome;
      telCtrl.text = fornecedor.telefone ?? '';
      emailCtrl.text = fornecedor.email ?? '';
      contatoNomeCtrl.text = fornecedor.contatoNome ?? '';
      contatoTelCtrl.text = fornecedor.contatoTelefone ?? '';
    }

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isEdit ? 'Editar fornecedor' : 'Novo fornecedor'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeCtrl,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: telCtrl,
                  decoration: const InputDecoration(labelText: 'Telefone'),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contatoNomeCtrl,
                  decoration: const InputDecoration(labelText: 'Contato (nome)'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contatoTelCtrl,
                  decoration: const InputDecoration(labelText: 'Telefone contato'),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final nome = nomeCtrl.text.trim();
                if (nome.isEmpty) return;
                final repo = ref.read(cadFornecedorRepositoryProvider);
                final telefone = telCtrl.text.trim();
                final email = emailCtrl.text.trim();
                final contatoNome = contatoNomeCtrl.text.trim();
                final contatoTel = contatoTelCtrl.text.trim();
                final telefoneValue = telefone.isEmpty ? null : telefone;
                final emailValue = email.isEmpty ? null : email;
                final contatoNomeValue = contatoNome.isEmpty ? null : contatoNome;
                final contatoTelValue = contatoTel.isEmpty ? null : contatoTel;

                try {
                  if (isEdit) {
                    await repo.atualizar(
                      Fornecedor(
                        id: fornecedor.id,
                        nome: nome,
                        telefone: telefoneValue,
                        email: emailValue,
                        contatoNome: contatoNomeValue,
                        contatoTelefone: contatoTelValue,
                        createdAt: fornecedor.createdAt,
                      ),
                    );
                  } else {
                    await repo.inserirCompleto(
                      nome: nome,
                      telefone: telefoneValue,
                      email: emailValue,
                      contatoNome: contatoNomeValue,
                      contatoTelefone: contatoTelValue,
                    );
                  }
                  ref.invalidate(cadFornecedoresProvider);
                  ref.invalidate(cadastrosResumoProvider);
                } catch (e) {
                  if (!mounted) return;
                  await showErrorDialog(
                    context,
                    'Erro ao salvar fornecedor:\n$e',
                  );
                  return;
                }
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isEdit ? 'Fornecedor atualizado.' : 'Fornecedor criado.',
                    ),
                  ),
                );
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    nomeCtrl.dispose();
    telCtrl.dispose();
    emailCtrl.dispose();
    contatoNomeCtrl.dispose();
    contatoTelCtrl.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final asyncList = ref.watch(cadFornecedoresProvider);
    final q = _searchCtrl.text.trim().toLowerCase();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Fornecedores',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: _openFornecedorDialog,
                icon: const Icon(Icons.add),
                tooltip: 'Novo fornecedor',
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              labelText: 'Buscar por nome',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: asyncList.when(
              data: (items) {
                final filtered = q.isEmpty
                    ? items
                    : items
                          .where((e) => e.nome.toLowerCase().contains(q))
                          .toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Nenhum fornecedor encontrado.'),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final f = filtered[i];
                    final parts = <String>[];
                    if (f.telefone != null && f.telefone!.isNotEmpty) {
                      parts.add('Tel: ${f.telefone!}');
                    }
                    final contatoParts = <String>[];
                    if (f.contatoNome != null && f.contatoNome!.isNotEmpty) {
                      contatoParts.add(f.contatoNome!);
                    }
                    if (f.contatoTelefone != null &&
                        f.contatoTelefone!.isNotEmpty) {
                      contatoParts.add(f.contatoTelefone!);
                    }
                    if (contatoParts.isNotEmpty) {
                      parts.add('Contato: ${contatoParts.join(' - ')}');
                    }
                    if (f.email != null && f.email!.isNotEmpty) {
                      parts.add(f.email!);
                    }
                    return ListTile(
                      title: Text(f.nome),
                      subtitle: parts.isEmpty ? null : Text(parts.join(' - ')),
                      onTap: () => _openFornecedorDialog(fornecedor: f),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Editar fornecedor',
                        onPressed: () => _openFornecedorDialog(fornecedor: f),
                      ),
                    );
                  },
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Erro ao carregar fornecedores.')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// Fabricantes (modal)
// ======================================================
class _FabricantesSheet extends ConsumerStatefulWidget {
  final bool openCreate;
  const _FabricantesSheet({this.openCreate = false});

  @override
  ConsumerState<_FabricantesSheet> createState() => _FabricantesSheetState();
}

class _FabricantesSheetState extends ConsumerState<_FabricantesSheet> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.openCreate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openCreateDialog();
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openCreateDialog() async {
    final nomeCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Novo fabricante'),
          content: TextField(
            controller: nomeCtrl,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final nome = nomeCtrl.text.trim();
                if (nome.isEmpty) return;
                final repo = ref.read(cadFabricanteRepositoryProvider);
                try {
                  await repo.inserir(nome);
                  ref.invalidate(cadFabricantesProvider);
                  ref.invalidate(cadastrosResumoProvider);
                } catch (e) {
                  if (!mounted) return;
                  await showErrorDialog(
                    context,
                    'Erro ao salvar fabricante:\n$e',
                  );
                  return;
                }
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fabricante criado.')),
                );
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    nomeCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncList = ref.watch(cadFabricantesProvider);
    final q = _searchCtrl.text.trim().toLowerCase();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Fabricantes',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: _openCreateDialog,
                icon: const Icon(Icons.add),
                tooltip: 'Novo fabricante',
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              labelText: 'Buscar por nome',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: asyncList.when(
              data: (items) {
                final filtered = q.isEmpty
                    ? items
                    : items
                          .where((e) => e.nome.toLowerCase().contains(q))
                          .toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Nenhum fabricante encontrado.'),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final f = filtered[i];
                    return ListTile(
                      title: Text(f.nome),
                      subtitle: Text('Criado em ${_fmtDate(f.createdAt)}'),
                    );
                  },
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Erro ao carregar fabricantes.')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// Categorias (modal) - Ocasião / Família / Propriedades
// ======================================================
class _CategoriasSheet extends ConsumerStatefulWidget {
  final bool openCreate;
  const _CategoriasSheet({this.openCreate = false});

  @override
  ConsumerState<_CategoriasSheet> createState() => _CategoriasSheetState();
}

class _CategoriasSheetState extends ConsumerState<_CategoriasSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    if (widget.openCreate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openCreateDialog(_currentTipo());
      });
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  CategoriaTipo _currentTipo() {
    return switch (_tab.index) {
      0 => CategoriaTipo.ocasiao,
      1 => CategoriaTipo.familia,
      _ => CategoriaTipo.propriedade,
    };
  }

  Future<void> _openCreateDialog(CategoriaTipo tipo) async {
    final nomeCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Nova ${tipo.label.toLowerCase()}'),
          content: TextField(
            controller: nomeCtrl,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final nome = nomeCtrl.text.trim();
                if (nome.isEmpty) return;
                final repo = ref.read(cadCategoriaRepositoryProvider);
                try {
                  await repo.inserir(tipo, nome);
                  ref.invalidate(cadCategoriasPorTipoProvider(tipo));
                  ref.invalidate(cadastrosResumoProvider);
                } catch (e) {
                  if (!mounted) return;
                  await showErrorDialog(
                    context,
                    'Erro ao salvar categoria:\n$e',
                  );
                  return;
                }
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Categoria criada.')),
                );
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    nomeCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchCtrl.text.trim().toLowerCase();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Categorias',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () => _openCreateDialog(_currentTipo()),
                icon: const Icon(Icons.add),
                tooltip: 'Nova categoria',
              ),
            ],
          ),
          const SizedBox(height: 8),
          TabBar(
            controller: _tab,
            tabs: const [
              Tab(text: 'Ocasião'),
              Tab(text: 'Família'),
              Tab(text: 'Propriedades'),
            ],
            onTap: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              labelText: 'Buscar',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: TabBarView(
              controller: _tab,
              children: [
                _CategoriasLista(tipo: CategoriaTipo.ocasiao, query: q),
                _CategoriasLista(tipo: CategoriaTipo.familia, query: q),
                _CategoriasLista(tipo: CategoriaTipo.propriedade, query: q),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoriasLista extends ConsumerWidget {
  final CategoriaTipo tipo;
  final String query;
  const _CategoriasLista({required this.tipo, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(cadCategoriasPorTipoProvider(tipo));

    return asyncList.when(
      data: (items) {
        final filtered = query.isEmpty
            ? items
            : items.where((e) => e.nome.toLowerCase().contains(query)).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Nenhuma ${tipo.label.toLowerCase()} encontrada.'),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final c = filtered[i];
            return ListTile(
              title: Text(c.nome),
              subtitle: Text('Criado em ${_fmtDate(c.createdAt)}'),
            );
          },
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('Erro ao carregar categorias.')),
      ),
    );
  }
}

String _fmtDate(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year}';
}
