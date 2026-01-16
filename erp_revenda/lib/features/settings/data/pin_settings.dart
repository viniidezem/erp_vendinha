class PinSettings {
  final bool enabled;
  final String? pinHash;
  final String? securityQuestion;
  final String? securityAnswerHash;
  final bool lockOnBackground;
  final int lockTimeoutMinutes;

  const PinSettings({
    required this.enabled,
    required this.lockOnBackground,
    required this.lockTimeoutMinutes,
    this.pinHash,
    this.securityQuestion,
    this.securityAnswerHash,
  });

  bool get hasPin =>
      (pinHash ?? '').trim().isNotEmpty &&
      (securityQuestion ?? '').trim().isNotEmpty &&
      (securityAnswerHash ?? '').trim().isNotEmpty;

  PinSettings copyWith({
    bool? enabled,
    String? pinHash,
    String? securityQuestion,
    String? securityAnswerHash,
    bool? lockOnBackground,
    int? lockTimeoutMinutes,
  }) {
    return PinSettings(
      enabled: enabled ?? this.enabled,
      pinHash: pinHash ?? this.pinHash,
      securityQuestion: securityQuestion ?? this.securityQuestion,
      securityAnswerHash: securityAnswerHash ?? this.securityAnswerHash,
      lockOnBackground: lockOnBackground ?? this.lockOnBackground,
      lockTimeoutMinutes: lockTimeoutMinutes ?? this.lockTimeoutMinutes,
    );
  }

  static PinSettings defaults() {
    return const PinSettings(
      enabled: false,
      lockOnBackground: false,
      lockTimeoutMinutes: 0,
    );
  }
}
