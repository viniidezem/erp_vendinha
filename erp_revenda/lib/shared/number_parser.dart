double parseFlexibleNumber(String input) {
  var s = input.trim();
  if (s.isEmpty) throw const FormatException('Número vazio');

  // preserva sinal
  var sign = '';
  if (s.startsWith('-') || s.startsWith('+')) {
    sign = s.substring(0, 1);
    s = s.substring(1);
  }

  // remove espaços
  s = s.replaceAll(RegExp(r'\s+'), '');

  final lastDot = s.lastIndexOf('.');
  final lastComma = s.lastIndexOf(',');

  // sem separador decimal
  if (lastDot == -1 && lastComma == -1) {
    final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
    return double.parse('$sign$digits');
  }

  // o último separador encontrado é o separador decimal
  final sepIndex = (lastDot > lastComma) ? lastDot : lastComma;

  final intPart = s.substring(0, sepIndex).replaceAll(RegExp(r'[^0-9]'), '');
  final fracPart = s.substring(sepIndex + 1).replaceAll(RegExp(r'[^0-9]'), '');

  final normalized = '$sign$intPart.${fracPart.isEmpty ? '0' : fracPart}';
  return double.parse(normalized);
}
