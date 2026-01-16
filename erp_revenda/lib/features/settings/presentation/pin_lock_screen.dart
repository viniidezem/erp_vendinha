import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/ui/app_colors.dart';
import '../../../shared/widgets/app_error_dialog.dart';
import '../controller/pin_settings_controller.dart';
import '../data/pin_settings.dart';
import '../data/pin_utils.dart';

class PinLockScreen extends ConsumerStatefulWidget {
  const PinLockScreen({super.key});

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen> {
  final _pinCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  String? _error;
  bool _submitting = false;
  _RecoveryStep _recoveryStep = _RecoveryStep.none;
  String? _recoveryError;

  @override
  void dispose() {
    _pinCtrl.dispose();
    _answerCtrl.dispose();
    _newPinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(PinSettings settings) async {
    if (_submitting) return;
    final pin = _pinCtrl.text.trim();
    if (!isValidPin(pin)) {
      setState(() => _error = 'Informe 4 digitos.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    if (hashPin(pin) == settings.pinHash) {
      ref.read(pinSessionUnlockedProvider.notifier).state = true;
      _pinCtrl.clear();
    } else {
      setState(() => _error = 'PIN incorreto.');
    }

    if (mounted) {
      setState(() => _submitting = false);
    }
  }

  Future<void> _forgotPin(PinSettings settings) async {
    final question = settings.securityQuestion;
    final answerHash = settings.securityAnswerHash;
    if ((question ?? '').trim().isEmpty || (answerHash ?? '').trim().isEmpty) {
      await showErrorDialog(context, 'Pergunta de seguranca nao configurada.');
      return;
    }
    setState(() {
      _recoveryStep = _RecoveryStep.question;
      _recoveryError = null;
      _answerCtrl.clear();
      _newPinCtrl.clear();
      _confirmPinCtrl.clear();
    });
  }

  void _cancelRecovery() {
    setState(() {
      _recoveryStep = _RecoveryStep.none;
      _recoveryError = null;
      _answerCtrl.clear();
      _newPinCtrl.clear();
      _confirmPinCtrl.clear();
    });
  }

  void _validateRecoveryAnswer(PinSettings settings) {
    final answer = _answerCtrl.text.trim();
    final hash = settings.securityAnswerHash;
    if (answer.isEmpty || hash == null) {
      setState(() => _recoveryError = 'Informe a resposta.');
      return;
    }
    if (hashSecurityAnswer(answer) != hash) {
      setState(() => _recoveryError = 'Resposta incorreta.');
      return;
    }
    setState(() {
      _recoveryStep = _RecoveryStep.newPin;
      _recoveryError = null;
      _newPinCtrl.clear();
      _confirmPinCtrl.clear();
    });
  }

  Future<void> _saveNewPin() async {
    final pin = _newPinCtrl.text.trim();
    final confirm = _confirmPinCtrl.text.trim();
    if (!isValidPin(pin)) {
      setState(() => _recoveryError = 'Informe 4 digitos.');
      return;
    }
    if (pin != confirm) {
      setState(() => _recoveryError = 'PINs nao conferem.');
      return;
    }
    await ref.read(pinSettingsProvider.notifier).atualizar(
          pinHash: hashPin(pin),
        );
    if (!mounted) return;
    ref.read(pinSessionUnlockedProvider.notifier).state = true;
    _cancelRecovery();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(pinSettingsProvider);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro ao carregar PIN: $e')),
      data: (settings) {
        return Container(
          color: AppColors.surface,
          child: SafeArea(
            child: Center(
              child: Card(
                elevation: 0,
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_recoveryStep == _RecoveryStep.none) ...[
                        const Icon(Icons.lock_outline, size: 42),
                        const SizedBox(height: 8),
                        const Text(
                          'Digite seu PIN',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _pinCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          obscureText: true,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: 'PIN',
                            errorText: _error,
                          ),
                          onSubmitted: (_) => _submit(settings),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed:
                                _submitting ? null : () => _submit(settings),
                            child: Text(_submitting ? 'Entrando...' : 'Entrar'),
                          ),
                        ),
                        const SizedBox(height: 6),
                        if ((settings.securityQuestion ?? '').trim().isNotEmpty)
                          TextButton(
                            onPressed: () => _forgotPin(settings),
                            child: const Text('Esqueci o PIN'),
                          ),
                      ] else if (_recoveryStep == _RecoveryStep.question) ...[
                        const Icon(Icons.help_outline, size: 40),
                        const SizedBox(height: 8),
                        const Text(
                          'Pergunta de seguranca',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          settings.securityQuestion ?? '',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _answerCtrl,
                          decoration: InputDecoration(
                            labelText: 'Resposta',
                            errorText: _recoveryError,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _cancelRecovery,
                                child: const Text('Cancelar'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                onPressed: () =>
                                    _validateRecoveryAnswer(settings),
                                child: const Text('Validar'),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const Icon(Icons.lock_reset_outlined, size: 40),
                        const SizedBox(height: 8),
                        const Text(
                          'Definir novo PIN',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _newPinCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          obscureText: true,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration:
                              const InputDecoration(labelText: 'PIN (4 digitos)'),
                        ),
                        TextField(
                          controller: _confirmPinCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          obscureText: true,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: 'Confirmar PIN',
                            errorText: _recoveryError,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _cancelRecovery,
                                child: const Text('Cancelar'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                onPressed: _saveNewPin,
                                child: const Text('Salvar'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _RecoveryStep { none, question, newPin }
