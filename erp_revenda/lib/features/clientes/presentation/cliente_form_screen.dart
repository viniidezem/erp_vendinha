import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_page.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../controller/clientes_controller.dart';
import '../data/cliente_model.dart';
import '../data/cliente_endereco_model.dart';

class ClienteFormScreen extends ConsumerStatefulWidget {
  final Cliente? cliente;
  const ClienteFormScreen({super.key, this.cliente});

  @override
  ConsumerState<ClienteFormScreen> createState() => _ClienteFormScreenState();
}

class _ClienteFormScreenState extends ConsumerState<ClienteFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nomeCtrl;
  late final TextEditingController _apelidoCtrl;
  late final TextEditingController _telefoneCtrl;
  late final TextEditingController _cpfCtrl;
  late final TextEditingController _emailCtrl;

  bool _whats = false;
  ClienteStatus _status = ClienteStatus.ativo;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController(text: widget.cliente?.nome ?? '');
    _apelidoCtrl = TextEditingController(text: widget.cliente?.apelido ?? '');
    _telefoneCtrl = TextEditingController(text: widget.cliente?.telefone ?? '');
    _cpfCtrl = TextEditingController(text: widget.cliente?.cpf ?? '');
    _emailCtrl = TextEditingController(text: widget.cliente?.email ?? '');
    _whats = widget.cliente?.telefoneWhatsapp ?? false;
    _status = widget.cliente?.status ?? ClienteStatus.ativo;
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _apelidoCtrl.dispose();
    _telefoneCtrl.dispose();
    _cpfCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  String _digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  String _fmtDateTime(DateTime? dt) {
    if (dt == null) return '-';
    final d = dt;
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$mi';
  }

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final nome = _nomeCtrl.text.trim();
    final apelido = _apelidoCtrl.text.trim();
    final telefone = _telefoneCtrl.text.trim();
    final cpfDigits = _digitsOnly(_cpfCtrl.text);

    final email = _emailCtrl.text.trim();

    final notifier = ref.read(clientesControllerProvider.notifier);

    try {
      if (widget.cliente == null) {
        await notifier.adicionar(
          nomeCompleto: nome,
          apelido: apelido.isEmpty ? null : apelido,
          telefone: telefone.isEmpty ? null : telefone,
          whatsapp: _whats,
          cpf: cpfDigits,
          email: email.isEmpty ? null : email,
          status: _status,
        );
      } else {
        final atualizado = widget.cliente!.copyWith(
          nome: nome,
          apelido: apelido.isEmpty ? null : apelido,
          telefone: telefone.isEmpty ? null : telefone,
          telefoneWhatsapp: _whats,
          cpf: cpfDigits.isEmpty ? null : cpfDigits,
          email: email.isEmpty ? null : email,
          status: _status,
          // createdAt mantém
        );
        await notifier.editar(atualizado);
      }

      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.cliente != null;
    final clienteId = widget.cliente?.id;

    return AppPage(
      title: editando ? 'Editar cliente' : 'Novo cliente',
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
                      const Text(
                        'Dados do cliente',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nomeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome completo',
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Informe o nome completo';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _apelidoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Apelido (opcional)',
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _cpfCtrl,
                        decoration: const InputDecoration(labelText: 'CPF'),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          final digits = _digitsOnly(v ?? '');
                          if (digits.isEmpty) return 'Informe o CPF';
                          if (digits.length != 11) {
                            return 'CPF deve ter 11 dígitos';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ClienteStatus>(
                        // value: _status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: ClienteStatus.values
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.label),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _status = v ?? ClienteStatus.ativo),
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
                      const Text(
                        'Contato',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _telefoneCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Telefone',
                        ),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: _whats,
                        onChanged: (v) => setState(() => _whats = v ?? false),
                        title: const Text('É WhatsApp'),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'E-mail (opcional)',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
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
                      const Text(
                        'Datas',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Expanded(child: Text('Data de cadastro')),
                          Text(
                            editando
                                ? _fmtDateTime(widget.cliente!.createdAt)
                                : 'Automático',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Expanded(child: Text('Data da última compra')),
                          Text(
                            editando
                                ? _fmtDateTime(widget.cliente!.ultimaCompraAt)
                                : '-',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ENDEREÇOS
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Endereços',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: clienteId == null
                                ? null
                                : () async {
                                    final novo =
                                        await showModalBottomSheet<
                                          ClienteEndereco
                                        >(
                                          context: context,
                                          isScrollControlled: true,
                                          builder: (_) => _EnderecoSheet(
                                            clienteId: clienteId,
                                          ),
                                        );
                                    if (novo != null) {
                                      final repo = ref.read(
                                        clienteEnderecoRepositoryProvider,
                                      );
                                      await repo.inserir(novo);
                                      ref.invalidate(
                                        clienteEnderecosProvider(clienteId),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.add),
                            label: const Text('Adicionar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (clienteId == null)
                        const Text(
                          'Salve o cliente para cadastrar endereços.',
                          style: TextStyle(color: Colors.black54),
                        )
                      else
                        _EnderecosList(clienteId: clienteId),
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

class _EnderecosList extends ConsumerWidget {
  final int clienteId;
  const _EnderecosList({required this.clienteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final endAsync = ref.watch(clienteEnderecosProvider(clienteId));
    final repo = ref.read(clienteEnderecoRepositoryProvider);

    return endAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text('Erro ao carregar endereços:\n$e'),
      ),
      data: (enderecos) {
        if (enderecos.isEmpty) {
          return const Text(
            'Nenhum endereço cadastrado.',
            style: TextStyle(color: Colors.black54),
          );
        }

        return Column(
          children: enderecos.map((e) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                e.principal ? Icons.star : Icons.location_on_outlined,
              ),
              title: Text(
                (e.rotulo ?? '').trim().isEmpty ? 'Endereço' : e.rotulo!.trim(),
              ),
              subtitle: Text(e.resumo().isEmpty ? '-' : e.resumo()),
              onTap: () async {
                final atualizado = await showModalBottomSheet<ClienteEndereco>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) =>
                      _EnderecoSheet(clienteId: clienteId, endereco: e),
                );
                if (atualizado != null) {
                  await repo.atualizar(atualizado);
                  ref.invalidate(clienteEnderecosProvider(clienteId));
                }
              },
              trailing: IconButton(
                tooltip: 'Remover endereço',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Remover endereço'),
                      content: const Text('Deseja remover este endereço?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Remover'),
                        ),
                      ],
                    ),
                  );

                  if (ok == true) {
                    await repo.remover(e.id!);
                    ref.invalidate(clienteEnderecosProvider(clienteId));
                  }
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _EnderecoSheet extends StatefulWidget {
  final int clienteId;
  final ClienteEndereco? endereco;
  const _EnderecoSheet({required this.clienteId, this.endereco});

  @override
  State<_EnderecoSheet> createState() => _EnderecoSheetState();
}

class _EnderecoSheetState extends State<_EnderecoSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _rotuloCtrl;
  late final TextEditingController _cepCtrl;
  late final TextEditingController _logCtrl;
  late final TextEditingController _numCtrl;
  late final TextEditingController _compCtrl;
  late final TextEditingController _bairroCtrl;
  late final TextEditingController _cidadeCtrl;
  late final TextEditingController _ufCtrl;

  bool _principal = false;

  @override
  void initState() {
    super.initState();
    final e = widget.endereco;
    _rotuloCtrl = TextEditingController(text: e?.rotulo ?? '');
    _cepCtrl = TextEditingController(text: e?.cep ?? '');
    _logCtrl = TextEditingController(text: e?.logradouro ?? '');
    _numCtrl = TextEditingController(text: e?.numero ?? '');
    _compCtrl = TextEditingController(text: e?.complemento ?? '');
    _bairroCtrl = TextEditingController(text: e?.bairro ?? '');
    _cidadeCtrl = TextEditingController(text: e?.cidade ?? '');
    _ufCtrl = TextEditingController(text: e?.uf ?? '');
    _principal = e?.principal ?? false;
  }

  @override
  void dispose() {
    _rotuloCtrl.dispose();
    _cepCtrl.dispose();
    _logCtrl.dispose();
    _numCtrl.dispose();
    _compCtrl.dispose();
    _bairroCtrl.dispose();
    _cidadeCtrl.dispose();
    _ufCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + bottomInset,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                widget.endereco == null ? 'Novo endereço' : 'Editar endereço',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _rotuloCtrl,
                decoration: const InputDecoration(
                  labelText: 'Rótulo (ex: Casa, Trabalho)',
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cepCtrl,
                      decoration: const InputDecoration(labelText: 'CEP'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _ufCtrl,
                      decoration: const InputDecoration(labelText: 'UF'),
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              TextFormField(
                controller: _logCtrl,
                decoration: const InputDecoration(labelText: 'Logradouro'),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _numCtrl,
                      decoration: const InputDecoration(labelText: 'Número'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _compCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Complemento',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              TextFormField(
                controller: _bairroCtrl,
                decoration: const InputDecoration(labelText: 'Bairro'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cidadeCtrl,
                decoration: const InputDecoration(labelText: 'Cidade'),
              ),

              const SizedBox(height: 8),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _principal,
                onChanged: (v) => setState(() => _principal = v ?? false),
                title: const Text('Definir como principal'),
                controlAffinity: ListTileControlAffinity.leading,
              ),

              const SizedBox(height: 12),

              AppGradientButton(
                label: 'Salvar endereço',
                trailingIcon: Icons.arrow_forward,
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;

                  final now = DateTime.now();
                  final base = widget.endereco;

                  final endereco = ClienteEndereco(
                    id: base?.id,
                    clienteId: widget.clienteId,
                    rotulo: _rotuloCtrl.text.trim().isEmpty
                        ? null
                        : _rotuloCtrl.text.trim(),
                    cep: _cepCtrl.text.trim().isEmpty
                        ? null
                        : _cepCtrl.text.trim(),
                    logradouro: _logCtrl.text.trim().isEmpty
                        ? null
                        : _logCtrl.text.trim(),
                    numero: _numCtrl.text.trim().isEmpty
                        ? null
                        : _numCtrl.text.trim(),
                    complemento: _compCtrl.text.trim().isEmpty
                        ? null
                        : _compCtrl.text.trim(),
                    bairro: _bairroCtrl.text.trim().isEmpty
                        ? null
                        : _bairroCtrl.text.trim(),
                    cidade: _cidadeCtrl.text.trim().isEmpty
                        ? null
                        : _cidadeCtrl.text.trim(),
                    uf: _ufCtrl.text.trim().isEmpty
                        ? null
                        : _ufCtrl.text.trim(),
                    principal: _principal,
                    createdAt: base?.createdAt ?? now,
                  );

                  Navigator.of(context).pop(endereco);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
