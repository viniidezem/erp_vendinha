
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_page.dart';
import '../../categorias/data/categoria_model.dart';
import '../controller/produtos_controller.dart';
import '../data/produto_model.dart';

class ProdutoFormScreen extends ConsumerStatefulWidget {
  final Produto? produto;
  const ProdutoFormScreen({super.key, this.produto});

  @override
  ConsumerState<ProdutoFormScreen> createState() => _ProdutoFormScreenState();
}

class _ProdutoFormScreenState extends ConsumerState<ProdutoFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nomeCtrl;
  late final TextEditingController _refCtrl;
  late final TextEditingController _precoCustoCtrl;
  late final TextEditingController _precoVendaCtrl;
  late final TextEditingController _tamanhoCtrl;

  bool _ativo = true;

  int? _fornecedorId;
  int? _fabricanteId;

  int? _tipoId;
  int? _ocasiaoId;
  int? _familiaId;
  final Set<int> _propsIds = {};

  TamanhoUnidade _unidade = TamanhoUnidade.ml;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final p = widget.produto;

    _nomeCtrl = TextEditingController(text: p?.nome ?? '');
    _refCtrl = TextEditingController(text: p?.refCodigo ?? '');
    _precoCustoCtrl = TextEditingController(text: (p?.precoCusto ?? 0).toStringAsFixed(2));
    _precoVendaCtrl = TextEditingController(text: (p?.precoVenda ?? 0).toStringAsFixed(2));
    _tamanhoCtrl = TextEditingController(
      text: p?.tamanhoValor == null ? '' : p!.tamanhoValor!.toStringAsFixed(0),
    );

    _ativo = p?.ativo ?? true;

    _fornecedorId = p?.fornecedorId;
    _fabricanteId = p?.fabricanteId;

    _tipoId = p?.tipoId;

    _ocasiaoId = p?.ocasiaoId;
    _familiaId = p?.familiaId;

    if (p?.tamanhoUnidade != null) {
      _unidade = p!.tamanhoUnidade!;
    }

    if (p?.id != null) {
      Future.microtask(() async {
        final repo = ref.read(produtoRepositoryProvider);
        final ids = await repo.listarPropriedadesIds(p!.id!);
        if (!mounted) return;
        setState(() => _propsIds.addAll(ids));
      });
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _refCtrl.dispose();
    _precoCustoCtrl.dispose();
    _precoVendaCtrl.dispose();
    _tamanhoCtrl.dispose();
    super.dispose();
  }

  double _parsePtBrNumber(String s) {
    final t = s.trim();
    if (t.isEmpty) return 0;

    if (t.contains(',') && t.contains('.')) {
      final noThousands = t.replaceAll('.', '');
      return double.parse(noThousands.replaceAll(',', '.'));
    }
    if (t.contains(',')) return double.parse(t.replaceAll(',', '.'));
    return double.parse(t);
  }

  double? _parseNullable(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return _parsePtBrNumber(t);
  }

  Future<void> _criarFornecedor() async {
    final newId = await showDialog<int?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _NovoFornecedorDialog(),
    );

    if (!mounted || newId == null) return;

    ref.invalidate(fornecedoresProvider);
    setState(() => _fornecedorId = newId);
  }

  Future<void> _criarFabricante() async {
    final newId = await showDialog<int?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _NovoFabricanteDialog(),
    );

    if (!mounted || newId == null) return;

    ref.invalidate(fabricantesProvider);
    setState(() => _fabricanteId = newId);
  }

  Future<void> _criarCategoria(CategoriaTipo tipo) async {
    final id = await showDialog<int?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _NovaCategoriaDialog(tipo: tipo),
    );

    if (!mounted || id == null) return;

    ref.invalidate(categoriasPorTipoProvider(tipo));
    setState(() {
      if (tipo == CategoriaTipo.tipoProduto) _tipoId = id;
      if (tipo == CategoriaTipo.ocasiao) _ocasiaoId = id;
      if (tipo == CategoriaTipo.familia) _familiaId = id;
      if (tipo == CategoriaTipo.propriedade) _propsIds.add(id);
    });
  }

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final nome = _nomeCtrl.text.trim();
      final refCodigo = _refCtrl.text.trim();
      final pc = _parsePtBrNumber(_precoCustoCtrl.text);
      final pv = _parsePtBrNumber(_precoVendaCtrl.text);

      final tamanhoValor = _parseNullable(_tamanhoCtrl.text);

      final produto = Produto(
        id: widget.produto?.id,
        nome: nome,
        refCodigo: refCodigo.isEmpty ? null : refCodigo,
        fabricanteId: _fabricanteId,
        fornecedorId: _fornecedorId,
        precoCusto: pc,
        precoVenda: pv,
        tamanhoValor: tamanhoValor,
        tamanhoUnidade: tamanhoValor == null ? null : _unidade,
        tipoId: _tipoId,
        ocasiaoId: _ocasiaoId,
        familiaId: _familiaId,
        estoque: widget.produto?.estoque ?? 0,
        ativo: _ativo,
        createdAt: widget.produto?.createdAt ?? DateTime.now(),
      );

      final notifier = ref.read(produtosControllerProvider.notifier);

      if (widget.produto == null) {
        await notifier.adicionar(produto, propriedadesIds: _propsIds.toList());
      } else {
        await notifier.editar(produto, propriedadesIds: _propsIds.toList());
      }

      if (!mounted) return;
      context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.produto != null;

    final fornecedoresAsync = ref.watch(fornecedoresProvider);
    final fabricantesAsync = ref.watch(fabricantesProvider);
    final tiposAsync = ref.watch(categoriasPorTipoProvider(CategoriaTipo.tipoProduto));
    final ocasioesAsync = ref.watch(categoriasPorTipoProvider(CategoriaTipo.ocasiao));
    final familiasAsync = ref.watch(categoriasPorTipoProvider(CategoriaTipo.familia));
    final propsAsync = ref.watch(categoriasPorTipoProvider(CategoriaTipo.propriedade));

    return AppPage(
      title: editando ? 'Editar produto' : 'Novo produto',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dados do produto', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nomeCtrl,
                        decoration: const InputDecoration(labelText: 'Nome'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _refCtrl,
                        decoration: const InputDecoration(labelText: 'Código referência'),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Produto ativo'),
                        value: _ativo,
                        onChanged: (v) => setState(() => _ativo = v),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Fornecedor', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      fornecedoresAsync.when(
                        loading: () => const Center(child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(),
                        )),
                        error: (e, st) => Text('Erro: $e'),
                        data: (fornecedores) {
                          if (_fornecedorId != null &&
                              !fornecedores.any((f) => f.id == _fornecedorId)) {
                            _fornecedorId = null;
                          }

                          return Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: _fornecedorId,
                                  items: [
                                    const DropdownMenuItem<int>(
                                      value: null,
                                      child: Text('— Sem fornecedor —'),
                                    ),
                                    ...fornecedores.map((f) => DropdownMenuItem<int>(
                                          value: f.id!,
                                          child: Text(f.nome),
                                        )),
                                  ],
                                  onChanged: (id) => setState(() => _fornecedorId = id),
                                  decoration: const InputDecoration(labelText: 'Fornecedor'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                tooltip: 'Novo fornecedor',
                                onPressed: _criarFornecedor,
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Fabricante', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      fabricantesAsync.when(
                        loading: () => const Center(child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(),
                        )),
                        error: (e, st) => Text('Erro: $e'),
                        data: (fabricantes) {
                          if (_fabricanteId != null &&
                              !fabricantes.any((f) => f.id == _fabricanteId)) {
                            _fabricanteId = null;
                          }

                          return Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: _fabricanteId,
                                  items: [
                                    const DropdownMenuItem<int>(
                                      value: null,
                                      child: Text('— Sem fabricante —'),
                                    ),
                                    ...fabricantes.map((f) => DropdownMenuItem<int>(
                                          value: f.id!,
                                          child: Text(f.nome),
                                        )),
                                  ],
                                  onChanged: (id) => setState(() => _fabricanteId = id),
                                  decoration: const InputDecoration(labelText: 'Fabricante'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                tooltip: 'Novo fabricante',
                                onPressed: _criarFabricante,
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Preços', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _precoCustoCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Preço de custo'),
                              validator: (v) {
                                final val = (v ?? '').trim();
                                if (val.isEmpty) return 'Informe o custo';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _precoVendaCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Preço de venda'),
                              validator: (v) {
                                final val = (v ?? '').trim();
                                if (val.isEmpty) return 'Informe a venda';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tamanho', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _tamanhoCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Valor (opcional)'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 120,
                            child: DropdownButtonFormField<TamanhoUnidade>(
                              initialValue: _unidade,
                              items: TamanhoUnidade.values
                                  .map((u) => DropdownMenuItem(value: u, child: Text(u.label)))
                                  .toList(),
                              onChanged: (v) => setState(() => _unidade = v ?? TamanhoUnidade.ml),
                              decoration: const InputDecoration(labelText: 'Unidade'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ex.: 100 ml (para filtros no futuro). Se não informar valor, unidade não será salva.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
const Text('Categorias', style: TextStyle(fontWeight: FontWeight.w700)),
const SizedBox(height: 12),

tiposAsync.when(
  loading: () => const Padding(
    padding: EdgeInsets.all(8),
    child: Center(child: CircularProgressIndicator()),
  ),
  error: (e, st) => Text('Erro tipos: $e'),
  data: (cats) {
    if (_tipoId != null && !cats.any((c) => c.id == _tipoId)) {
      _tipoId = null;
    }

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: _tipoId,
            items: [
              const DropdownMenuItem<int>(value: null, child: Text('— Sem tipo —')),
              ...cats.map((c) => DropdownMenuItem<int>(
                    value: c.id!,
                    child: Text(c.nome),
                  )),
            ],
            onChanged: (id) => setState(() => _tipoId = id),
            decoration: const InputDecoration(labelText: 'Tipo de produto'),
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          tooltip: 'Novo tipo',
          onPressed: () => _criarCategoria(CategoriaTipo.tipoProduto),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  },
),

const SizedBox(height: 12),

ocasioesAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(8),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, st) => Text('Erro ocasiões: $e'),
                        data: (cats) {
                          if (_ocasiaoId != null && !cats.any((c) => c.id == _ocasiaoId)) {
                            _ocasiaoId = null;
                          }

                          return Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: _ocasiaoId,
                                  items: [
                                    const DropdownMenuItem<int>(value: null, child: Text('— Sem ocasião —')),
                                    ...cats.map((c) => DropdownMenuItem<int>(
                                          value: c.id!,
                                          child: Text(c.nome),
                                        )),
                                  ],
                                  onChanged: (id) => setState(() => _ocasiaoId = id),
                                  decoration: const InputDecoration(labelText: 'Ocasião'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                tooltip: 'Nova ocasião',
                                onPressed: () => _criarCategoria(CategoriaTipo.ocasiao),
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      familiasAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(8),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, st) => Text('Erro famílias: $e'),
                        data: (cats) {
                          if (_familiaId != null && !cats.any((c) => c.id == _familiaId)) {
                            _familiaId = null;
                          }

                          return Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: _familiaId,
                                  items: [
                                    const DropdownMenuItem<int>(value: null, child: Text('— Sem família —')),
                                    ...cats.map((c) => DropdownMenuItem<int>(
                                          value: c.id!,
                                          child: Text(c.nome),
                                        )),
                                  ],
                                  onChanged: (id) => setState(() => _familiaId = id),
                                  decoration: const InputDecoration(labelText: 'Família olfativa'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                tooltip: 'Nova família',
                                onPressed: () => _criarCategoria(CategoriaTipo.familia),
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      propsAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(8),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, st) => Text('Erro propriedades: $e'),
                        data: (cats) {
                          _propsIds.removeWhere((id) => !cats.any((c) => c.id == id));

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text('Propriedades', style: TextStyle(fontWeight: FontWeight.w600)),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _criarCategoria(CategoriaTipo.propriedade),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Criar'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: cats.map((c) {
                                  final selected = _propsIds.contains(c.id);
                                  return FilterChip(
                                    label: Text(c.nome),
                                    selected: selected,
                                    onSelected: (v) {
                                      setState(() {
                                        if (v) {
                                          _propsIds.add(c.id!);
                                        } else {
                                          _propsIds.remove(c.id);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              AppGradientButton(
                label: _saving ? 'Salvando...' : 'Salvar',
                trailingIcon: _saving ? null : Icons.arrow_forward,
                onPressed: _saving ? null : _salvar,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _NovoFornecedorDialog extends ConsumerStatefulWidget {
  const _NovoFornecedorDialog();

  @override
  ConsumerState<_NovoFornecedorDialog> createState() => _NovoFornecedorDialogState();
}

class _NovoFornecedorDialogState extends ConsumerState<_NovoFornecedorDialog> {
  final nomeCtrl = TextEditingController();
  final telCtrl = TextEditingController();
  final emailCtrl = TextEditingController();

  bool saving = false;

  @override
  void dispose() {
    nomeCtrl.dispose();
    telCtrl.dispose();
    emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final nome = nomeCtrl.text.trim();
    final tel = telCtrl.text.trim();
    final email = emailCtrl.text.trim();

    if (nome.isEmpty) return;

    setState(() => saving = true);
    try {
      final repo = ref.read(fornecedorRepositoryProvider);
      final id = await repo.inserir(nome, telefone: tel, email: email);

      if (!mounted) return;
      Navigator.of(context).pop(id);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo fornecedor'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: nomeCtrl,
              decoration: const InputDecoration(labelText: 'Nome'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: telCtrl,
              decoration: const InputDecoration(labelText: 'Telefone'),
            ),
            const SizedBox(height: 8),
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
          onPressed: saving ? null : () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: saving ? null : _salvar,
          child: Text(saving ? 'Salvando...' : 'Salvar'),
        ),
      ],
    );
  }
}

class _NovoFabricanteDialog extends ConsumerStatefulWidget {
  const _NovoFabricanteDialog();

  @override
  ConsumerState<_NovoFabricanteDialog> createState() => _NovoFabricanteDialogState();
}

class _NovoFabricanteDialogState extends ConsumerState<_NovoFabricanteDialog> {
  final ctrl = TextEditingController();
  bool saving = false;

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final nome = ctrl.text.trim();
    if (nome.isEmpty) return;

    setState(() => saving = true);
    try {
      final repo = ref.read(fabricanteRepositoryProvider);
      final id = await repo.inserir(nome);

      if (!mounted) return;
      Navigator.of(context).pop(id);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo fabricante'),
      content: TextField(
        controller: ctrl,
        decoration: const InputDecoration(labelText: 'Nome'),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: saving ? null : _salvar,
          child: Text(saving ? 'Salvando...' : 'Salvar'),
        ),
      ],
    );
  }
}

class _NovaCategoriaDialog extends ConsumerStatefulWidget {
  final CategoriaTipo tipo;
  const _NovaCategoriaDialog({required this.tipo});

  @override
  ConsumerState<_NovaCategoriaDialog> createState() => _NovaCategoriaDialogState();
}

class _NovaCategoriaDialogState extends ConsumerState<_NovaCategoriaDialog> {
  final ctrl = TextEditingController();
  bool saving = false;

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final nome = ctrl.text.trim();
    if (nome.isEmpty) return;

    setState(() => saving = true);
    try {
      final repo = ref.read(categoriaRepositoryProvider);
      final id = await repo.inserir(widget.tipo, nome);

      if (!mounted) return;
      Navigator.of(context).pop(id);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Nova ${widget.tipo.label}'),
      content: TextField(
        controller: ctrl,
        decoration: const InputDecoration(labelText: 'Nome'),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: saving ? null : _salvar,
          child: Text(saving ? 'Salvando...' : 'Salvar'),
        ),
      ],
    );
  }
}
