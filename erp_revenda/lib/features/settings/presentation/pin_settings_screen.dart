import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_page.dart';
import '../controller/pin_settings_controller.dart';
import '../data/pin_settings.dart';
import '../data/pin_utils.dart';

class PinSettingsScreen extends ConsumerStatefulWidget {
  const PinSettingsScreen({super.key});

  @override
  ConsumerState<PinSettingsScreen> createState() => _PinSettingsScreenState();
}

class _PinSettingsScreenState extends ConsumerState<PinSettingsScreen> {
  final _currentPinCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  final _questionCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();

  _InlineAction _inlineAction = _InlineAction.none;
  _InlineStep _inlineStep = _InlineStep.confirmPin;
  String? _inlineError;

  @override
  void dispose() {
    _currentPinCtrl.dispose();
    _newPinCtrl.dispose();
    _confirmPinCtrl.dispose();
    _questionCtrl.dispose();
    _answerCtrl.dispose();
    super.dispose();
  }

  void _handleTogglePin(PinSettings settings, bool enable) {
    if (enable) {
      _startInlineAction(_InlineAction.enablePin, settings);
      return;
    }
    _startInlineAction(_InlineAction.disablePin, settings);
  }

  void _startInlineAction(_InlineAction action, PinSettings settings) {
    setState(() {
      _inlineAction = action;
      _inlineStep = action == _InlineAction.enablePin
          ? _InlineStep.edit
          : _InlineStep.confirmPin;
      _inlineError = null;
      _currentPinCtrl.clear();
      _newPinCtrl.clear();
      _confirmPinCtrl.clear();
      _questionCtrl.text = action == _InlineAction.changeQuestion
          ? (settings.securityQuestion ?? '')
          : '';
      _answerCtrl.clear();
    });
  }

  void _cancelInlineAction() {
    setState(() {
      _inlineAction = _InlineAction.none;
      _inlineStep = _InlineStep.confirmPin;
      _inlineError = null;
      _currentPinCtrl.clear();
      _newPinCtrl.clear();
      _confirmPinCtrl.clear();
      _questionCtrl.clear();
      _answerCtrl.clear();
    });
  }

  void _setInlineError(String message) {
    setState(() => _inlineError = message);
  }

  void _clearInlineError() {
    if (_inlineError == null) return;
    setState(() => _inlineError = null);
  }

  bool _validateCurrentPin(PinSettings settings) {
    final pin = _currentPinCtrl.text;
    if (!isValidPin(pin)) {
      _setInlineError('Informe 4 digitos.');
      return false;
    }
    if (hashPin(pin) != settings.pinHash) {
      _setInlineError('PIN incorreto.');
      return false;
    }
    return true;
  }

  bool _validateNewPin() {
    final pin = _newPinCtrl.text;
    final confirm = _confirmPinCtrl.text;
    if (!isValidPin(pin)) {
      _setInlineError('Informe 4 digitos.');
      return false;
    }
    if (pin != confirm) {
      _setInlineError('PINs nao conferem.');
      return false;
    }
    return true;
  }

  bool _validateSecurityQuestion() {
    final question = _questionCtrl.text.trim();
    final answer = _answerCtrl.text.trim();
    if (question.isEmpty) {
      _setInlineError('Informe a pergunta.');
      return false;
    }
    if (answer.isEmpty) {
      _setInlineError('Informe a resposta.');
      return false;
    }
    return true;
  }

  Future<void> _continueInline(PinSettings settings) async {
    if (!_validateCurrentPin(settings)) return;
    if (_inlineAction == _InlineAction.disablePin) {
      await _disablePin(settings);
      return;
    }
    setState(() {
      _inlineStep = _InlineStep.edit;
      _inlineError = null;
      _currentPinCtrl.clear();
    });
  }

  Future<void> _disablePin(PinSettings settings) async {
    final cleared = settings.copyWith(
      enabled: false,
      pinHash: null,
      securityQuestion: null,
      securityAnswerHash: null,
      lockOnBackground: false,
    );
    await ref.read(pinSettingsProvider.notifier).salvar(cleared);
    if (!mounted) return;
    ref.read(pinSessionUnlockedProvider.notifier).state = true;
    if (mounted) {
      _cancelInlineAction();
    }
  }

  Future<void> _saveInlinePin(PinSettings settings) async {
    if (!_validateNewPin()) return;
    if (_inlineAction == _InlineAction.enablePin && !_validateSecurityQuestion()) {
      return;
    }
    final pinHashValue = hashPin(_newPinCtrl.text);
    if (_inlineAction == _InlineAction.enablePin) {
      final updated = settings.copyWith(
        enabled: true,
        pinHash: pinHashValue,
        securityQuestion: _questionCtrl.text.trim(),
        securityAnswerHash: hashSecurityAnswer(_answerCtrl.text.trim()),
        lockOnBackground: false,
      );
      await ref.read(pinSettingsProvider.notifier).salvar(updated);
    } else {
      await ref
          .read(pinSettingsProvider.notifier)
          .atualizar(pinHash: pinHashValue);
    }
    if (!mounted) return;
    ref.read(pinSessionUnlockedProvider.notifier).state = true;
    if (mounted) {
      _cancelInlineAction();
    }
  }

  Future<void> _saveInlineQuestion() async {
    if (!_validateSecurityQuestion()) return;
    await ref.read(pinSettingsProvider.notifier).atualizar(
          securityQuestion: _questionCtrl.text.trim(),
          securityAnswerHash: hashSecurityAnswer(_answerCtrl.text.trim()),
        );
    if (!mounted) return;
    ref.read(pinSessionUnlockedProvider.notifier).state = true;
    if (mounted) {
      _cancelInlineAction();
    }
  }

  Widget _buildInlineCard(PinSettings settings) {
    final theme = Theme.of(context);
    final isConfirm = _inlineStep == _InlineStep.confirmPin;
    final isEnable = _inlineAction == _InlineAction.enablePin;
    final isChangePin = _inlineAction == _InlineAction.changePin;
    final isChangeQuestion = _inlineAction == _InlineAction.changeQuestion;
    final isDisable = _inlineAction == _InlineAction.disablePin;

    String title;
    if (isEnable) {
      title = 'Configurar PIN';
    } else if (isChangePin) {
      title = 'Alterar PIN';
    } else if (isChangeQuestion) {
      title = 'Pergunta de seguranca';
    } else {
      title = 'Desativar PIN';
    }

    String primaryLabel;
    VoidCallback? primaryAction;
    if (isConfirm) {
      primaryLabel = isDisable ? 'Desativar' : 'Continuar';
      primaryAction = () => _continueInline(settings);
    } else {
      if (isChangeQuestion) {
        primaryLabel = 'Salvar';
        primaryAction = _saveInlineQuestion;
      } else {
        primaryLabel = isEnable ? 'Ativar' : 'Salvar';
        primaryAction = () => _saveInlinePin(settings);
      }
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (isConfirm) ...[
              Text(
                isDisable
                    ? 'Confirme o PIN atual para desativar.'
                    : 'Confirme o PIN atual para continuar.',
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _currentPinCtrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'PIN atual'),
                onChanged: (_) => _clearInlineError(),
              ),
            ] else ...[
              if (isEnable || isChangePin) ...[
                TextField(
                  controller: _newPinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Novo PIN (4 digitos)'),
                  onChanged: (_) => _clearInlineError(),
                ),
                TextField(
                  controller: _confirmPinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Confirmar PIN'),
                  onChanged: (_) => _clearInlineError(),
                ),
              ],
              if (isEnable || isChangeQuestion) ...[
                TextField(
                  controller: _questionCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Pergunta de seguranca',
                  ),
                  onChanged: (_) => _clearInlineError(),
                ),
                TextField(
                  controller: _answerCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Resposta de seguranca',
                  ),
                  onChanged: (_) => _clearInlineError(),
                ),
              ],
            ],
            if (_inlineError != null) ...[
              const SizedBox(height: 8),
              Text(
                _inlineError!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: _cancelInlineAction,
                  child: const Text('Cancelar'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: primaryAction,
                  child: Text(primaryLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeoutLabel(int minutes) {
    if (minutes <= 0) return 'Nunca';
    if (minutes == 1) return '1 minuto';
    return '$minutes minutos';
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(pinSettingsProvider);

    return AppPage(
      title: 'PIN de acesso',
      showBack: true,
      child: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Erro ao carregar configuracoes: $e'),
        ),
        data: (settings) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              SwitchListTile(
                value: settings.enabled,
                onChanged: _inlineAction == _InlineAction.none
                    ? (v) => _handleTogglePin(settings, v)
                    : null,
                title: const Text('Proteger com PIN'),
                subtitle: const Text('Ative para exigir PIN ao abrir o app'),
              ),
              const SizedBox(height: 12),
              if (settings.enabled) ...[
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Acoes',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.lock_reset_outlined),
                          title: const Text('Alterar PIN'),
                          onTap: _inlineAction == _InlineAction.none
                              ? () => _startInlineAction(
                                    _InlineAction.changePin,
                                    settings,
                                  )
                              : null,
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.question_answer_outlined),
                          title: const Text('Pergunta de seguranca'),
                          subtitle: Text(
                            settings.securityQuestion?.trim().isEmpty ?? true
                                ? 'Nao configurada'
                                : settings.securityQuestion!,
                          ),
                          onTap: _inlineAction == _InlineAction.none
                              ? () => _startInlineAction(
                                    _InlineAction.changeQuestion,
                                    settings,
                                  )
                              : null,
                        ),
                        SwitchListTile(
                          value: settings.lockOnBackground,
                          onChanged: (v) {
                            ref
                                .read(pinSettingsProvider.notifier)
                                .atualizar(lockOnBackground: v);
                          },
                          title: const Text('Bloquear ao sair do app'),
                          subtitle:
                              const Text('Pede PIN ao voltar para o app'),
                        ),
                        const SizedBox(height: 8),
                        InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Bloqueio por inatividade',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              isExpanded: true,
                              value: [0, 1, 5, 10, 15]
                                      .contains(settings.lockTimeoutMinutes)
                                  ? settings.lockTimeoutMinutes
                                  : 0,
                              items: const [0, 1, 5, 10, 15]
                                  .map(
                                    (m) => DropdownMenuItem<int>(
                                      value: m,
                                      child: Text(_timeoutLabel(m)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                ref
                                    .read(pinSettingsProvider.notifier)
                                    .atualizar(lockTimeoutMinutes: v);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Card(
                  elevation: 0,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Quando ativado, o app pedira um PIN de 4 digitos para abrir.',
                    ),
                  ),
                ),
              ],
              if (_inlineAction != _InlineAction.none) ...[
                const SizedBox(height: 12),
                _buildInlineCard(settings),
              ],
            ],
          );
        },
      ),
    );
  }
}

enum _InlineAction {
  none,
  enablePin,
  changePin,
  changeQuestion,
  disablePin,
}

enum _InlineStep {
  confirmPin,
  edit,
}
