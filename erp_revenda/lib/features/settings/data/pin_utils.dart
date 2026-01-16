import 'dart:convert';

import 'package:crypto/crypto.dart';

String hashPin(String pin) {
  return sha256.convert(utf8.encode(pin)).toString();
}

String normalizeAnswer(String answer) {
  return answer.trim().toLowerCase();
}

String hashSecurityAnswer(String answer) {
  return sha256.convert(utf8.encode(normalizeAnswer(answer))).toString();
}

bool isValidPin(String pin) {
  return RegExp(r'^\d{4}$').hasMatch(pin);
}
