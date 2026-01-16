import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../data/db/app_database.dart';
import 'dashboard_settings.dart';
import 'app_preferences.dart';
import '../../../app/ui/app_colors.dart';
import 'pin_settings.dart';

class AppSettingsRepository {
  final AppDatabase _db;

  AppSettingsRepository(this._db);

  Future<String?> getValue(String key) async {
    final Database db = await _db.database;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setValue(String key, String value) async {
    final Database db = await _db.database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeValue(String key) async {
    final Database db = await _db.database;
    await db.delete(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  Future<DashboardSettings> carregarDashboardSettings() async {
    final show = await getValue(_kMostrarGraficos);
    final meta = await getValue(_kMetaMensal);
    final periodo = await getValue(_kPeriodoGrafico);

    final mostrarGraficos = show == '1';
    final metaMensal = double.tryParse(meta ?? '') ?? 0;
    final periodoFinal = DashboardGraficoPeriodo.values.contains(periodo)
        ? periodo!
        : DashboardGraficoPeriodo.mesAtual;

    return DashboardSettings(
      mostrarGraficos: mostrarGraficos,
      metaFaturamentoMensal: metaMensal,
      periodoGrafico: periodoFinal,
    );
  }

  Future<void> salvarDashboardSettings(DashboardSettings settings) async {
    await setValue(_kMostrarGraficos, settings.mostrarGraficos ? '1' : '0');
    await setValue(
      _kMetaMensal,
      settings.metaFaturamentoMensal.toStringAsFixed(2),
    );
    await setValue(_kPeriodoGrafico, settings.periodoGrafico);
  }

  Future<AppPreferences> carregarPreferencias() async {
    final name = await getValue(_kStoreName);
    final paletteId = await getValue(_kPaletteId) ?? AppColors.defaultPaletteId;
    final trimmed = (name ?? '').trim();

    return AppPreferences(
      storeName: trimmed.isEmpty ? null : trimmed,
      paletteId: paletteId,
    );
  }

  Future<void> salvarPreferencias(AppPreferences prefs) async {
    final name = (prefs.storeName ?? '').trim();
    await setValue(_kStoreName, name);
    await setValue(_kPaletteId, prefs.paletteId);
  }

  Future<void> salvarNomeLoja(String nome) async {
    await setValue(_kStoreName, nome.trim());
  }

  Future<void> salvarPaleta(String paletteId) async {
    await setValue(_kPaletteId, paletteId);
  }

  Future<PinSettings> carregarPinSettings() async {
    final enabledRaw = await getValue(_kPinEnabled);
    final pinHash = _normalize(await getValue(_kPinHash));
    final question = _normalize(await getValue(_kPinQuestion));
    final answerHash = _normalize(await getValue(_kPinAnswerHash));
    final lockRaw = await getValue(_kPinLockOnBackground);
    final timeoutRaw = await getValue(_kPinTimeoutMinutes);

    final enabled = enabledRaw == '1' && pinHash != null;
    final lockOnBackground = lockRaw == '1';
    final timeoutMinutes = int.tryParse(timeoutRaw ?? '') ?? 0;

    return PinSettings(
      enabled: enabled,
      pinHash: pinHash,
      securityQuestion: question,
      securityAnswerHash: answerHash,
      lockOnBackground: lockOnBackground,
      lockTimeoutMinutes: timeoutMinutes,
    );
  }

  Future<void> salvarPinSettings(PinSettings settings) async {
    await setValue(_kPinEnabled, settings.enabled ? '1' : '0');
    if (!settings.enabled) {
      await removeValue(_kPinHash);
      await removeValue(_kPinQuestion);
      await removeValue(_kPinAnswerHash);
      await removeValue(_kPinLockOnBackground);
      await removeValue(_kPinTimeoutMinutes);
      return;
    }

    if ((settings.pinHash ?? '').trim().isNotEmpty) {
      await setValue(_kPinHash, settings.pinHash!.trim());
    }
    if ((settings.securityQuestion ?? '').trim().isNotEmpty) {
      await setValue(_kPinQuestion, settings.securityQuestion!.trim());
    }
    if ((settings.securityAnswerHash ?? '').trim().isNotEmpty) {
      await setValue(_kPinAnswerHash, settings.securityAnswerHash!.trim());
    }
    await setValue(_kPinLockOnBackground, settings.lockOnBackground ? '1' : '0');
    await setValue(
      _kPinTimeoutMinutes,
      settings.lockTimeoutMinutes.toString(),
    );
  }

  Future<BackupInfo?> carregarBackupInfo() async {
    final name = await getValue(_kBackupLastName);
    final at = await getValue(_kBackupLastAt);
    final size = await getValue(_kBackupLastSize);

    if (name == null && at == null && size == null) return null;

    final createdAtMs = int.tryParse(at ?? '');
    final sizeBytes = int.tryParse(size ?? '');
    if (createdAtMs == null || sizeBytes == null || name == null) return null;

    return BackupInfo(
      fileName: name,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs),
      sizeBytes: sizeBytes,
    );
  }

  Future<List<BackupInfo>> carregarBackupHistorico() async {
    final raw = await getValue(_kBackupHistory);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final list = <BackupInfo>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final info = BackupInfo.fromMap(item);
          if (info != null) list.add(info);
        }
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> salvarBackupHistorico(List<BackupInfo> items) async {
    final payload = items.map((e) => e.toMap()).toList();
    await setValue(_kBackupHistory, jsonEncode(payload));
  }

  Future<List<BackupInfo>> adicionarBackupHistorico(
    BackupInfo info, {
    int maxItems = 10,
  }) async {
    final list = await carregarBackupHistorico();
    list.removeWhere((e) => e.fileName == info.fileName);
    list.insert(0, info);
    if (list.length > maxItems) {
      list.removeRange(maxItems, list.length);
    }
    await salvarBackupHistorico(list);
    return list;
  }

  Future<void> salvarBackupInfo({
    required String fileName,
    required DateTime createdAt,
    required int sizeBytes,
  }) async {
    await setValue(_kBackupLastName, fileName);
    await setValue(_kBackupLastAt, createdAt.millisecondsSinceEpoch.toString());
    await setValue(_kBackupLastSize, sizeBytes.toString());
  }

  static const String _kMostrarGraficos = 'dashboard_mostrar_graficos';
  static const String _kMetaMensal = 'dashboard_meta_mensal';
  static const String _kPeriodoGrafico = 'dashboard_periodo_grafico';
  static const String _kStoreName = 'app_store_name';
  static const String _kPaletteId = 'app_palette_id';
  static const String _kBackupLastName = 'backup_last_name';
  static const String _kBackupLastAt = 'backup_last_at';
  static const String _kBackupLastSize = 'backup_last_size';
  static const String _kBackupHistory = 'backup_history';
  static const String _kPinEnabled = 'pin_enabled';
  static const String _kPinHash = 'pin_hash';
  static const String _kPinQuestion = 'pin_question';
  static const String _kPinAnswerHash = 'pin_answer_hash';
  static const String _kPinLockOnBackground = 'pin_lock_on_background';
  static const String _kPinTimeoutMinutes = 'pin_timeout_minutes';
}

String? _normalize(String? v) {
  if (v == null) return null;
  final trimmed = v.trim();
  return trimmed.isEmpty ? null : trimmed;
}

class BackupInfo {
  final String fileName;
  final DateTime createdAt;
  final int sizeBytes;

  const BackupInfo({
    required this.fileName,
    required this.createdAt,
    required this.sizeBytes,
  });

  Map<String, Object?> toMap() => {
        'fileName': fileName,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'sizeBytes': sizeBytes,
      };

  static BackupInfo? fromMap(Map<String, dynamic> map) {
    final name = map['fileName'] as String?;
    final createdAtRaw = map['createdAt'];
    final sizeRaw = map['sizeBytes'];
    if (name == null) return null;
    final createdAtMs = createdAtRaw is int
        ? createdAtRaw
        : int.tryParse('$createdAtRaw') ?? 0;
    final sizeBytes = sizeRaw is int ? sizeRaw : int.tryParse('$sizeRaw') ?? 0;
    return BackupInfo(
      fileName: name,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs),
      sizeBytes: sizeBytes,
    );
  }
}
