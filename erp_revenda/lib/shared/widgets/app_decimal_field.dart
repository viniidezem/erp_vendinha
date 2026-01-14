import 'package:flutter/material.dart';

/// Campo numérico (decimal) com comportamento de "zero como hint".
///
/// Regras:
/// - Se o conteúdo for zero (ex.: "0.00" / "0,00" / "0"), ao focar o campo ele limpa.
/// - Se o usuário sair do campo com ele vazio, o texto volta para [zeroText].
///
/// Observação:
/// - O widget não formata o valor digitado; ele apenas aplica o comportamento
///   de limpeza/normalização do zero.
class AppDecimalField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String zeroText;
  final String? hintText;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool autofocus;
  final Widget? prefixIcon;
  final String? helperText;

  const AppDecimalField({
    super.key,
    required this.controller,
    required this.labelText,
    this.zeroText = '0.00',
    this.hintText,
    this.validator,
    this.textInputAction,
    this.onChanged,
    this.enabled = true,
    this.autofocus = false,
    this.prefixIcon,
    this.helperText,
  });

  @override
  State<AppDecimalField> createState() => _AppDecimalFieldState();
}

class _AppDecimalFieldState extends State<AppDecimalField> {
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    _focus.addListener(_onFocusChanged);

    // Se vier inicializado como zero, tratamos como hint.
    final t = widget.controller.text.trim();
    if (_isZeroText(t)) {
      widget.controller.clear();
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    super.dispose();
  }

  bool _isZeroText(String t) {
    final s = t.trim();
    if (s.isEmpty) return false;
    if (s == widget.zeroText) return true;
    // Aceita variações comuns.
    if (s == '0' || s == '0.0' || s == '0.00' || s == '0,00') return true;

    // Se o usuário digitou separadores diferentes, tentamos normalizar.
    final normalized = s.replaceAll(',', '.');
    return normalized == '0' || normalized == '0.0' || normalized == '0.00';
  }

  void _onFocusChanged() {
    if (!widget.enabled) return;

    if (_focus.hasFocus) {
      // Ao focar: se for zero, limpa.
      final t = widget.controller.text.trim();
      if (_isZeroText(t)) {
        widget.controller.clear();
      }
      return;
    }

    // Ao desfocar: se estiver vazio, volta para zero.
    final t = widget.controller.text.trim();
    if (t.isEmpty) {
      widget.controller.text = widget.zeroText;
      widget.controller.selection = TextSelection.collapsed(
        offset: widget.controller.text.length,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: _focus,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText ?? widget.zeroText,
        prefixIcon: widget.prefixIcon,
        helperText: widget.helperText,
      ),
    );
  }
}
