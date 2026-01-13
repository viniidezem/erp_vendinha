class NumberParse {
  /// Aceita:
  /// "10" , "10,5" , "10.5" , "1.234,56" , "1,234.56"
  /// Retorna double ou lança FormatException.
  static double parsePtBrFlexible(String input) {
    var s = input.trim();
    if (s.isEmpty) {
      throw const FormatException('Vazio');
    }

    // Remove espaços internos
    s = s.replaceAll(' ', '');

    final hasComma = s.contains(',');
    final hasDot = s.contains('.');

    if (hasComma && hasDot) {
      // Decide qual é o separador decimal pelo ÚLTIMO separador que aparece
      final lastComma = s.lastIndexOf(',');
      final lastDot = s.lastIndexOf('.');

      if (lastComma > lastDot) {
        // Decimal é vírgula: remove pontos (milhar) e troca vírgula por ponto
        s = s.replaceAll('.', '');
        s = s.replaceAll(',', '.');
      } else {
        // Decimal é ponto: remove vírgulas (milhar)
        s = s.replaceAll(',', '');
      }
    } else if (hasComma && !hasDot) {
      // Só vírgula: decimal pt-BR
      s = s.replaceAll(',', '.');
    } else {
      // Só ponto ou nenhum: já está OK
      // (não remove ponto porque pode ser decimal)
    }

    return double.parse(s);
  }
}
