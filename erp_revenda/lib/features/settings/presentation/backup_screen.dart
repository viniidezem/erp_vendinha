import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../../app/ui/app_colors.dart';
import '../../../shared/widgets/app_error_dialog.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_page.dart';
import '../../clientes/controller/clientes_controller.dart'
    show appDatabaseProvider;
import '../controller/app_preferences_controller.dart';
import '../data/app_settings_repository.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _exporting = false;
  bool _importing = false;
  BackupInfo? _backupInfo;
  List<BackupInfo> _backupHistory = [];

  @override
  void initState() {
    super.initState();
    _loadBackupInfo();
    _loadBackupHistory();
  }

  String _timestamp() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    return '$y$m${d}_$hh$mm$ss';
  }

  Future<void> _loadBackupInfo() async {
    final repo = ref.read(appPreferencesRepositoryProvider);
    final info = await repo.carregarBackupInfo();
    if (!mounted) return;
    setState(() => _backupInfo = info);
  }

  Future<void> _loadBackupHistory() async {
    final repo = ref.read(appPreferencesRepositoryProvider);
    final list = await repo.carregarBackupHistorico();
    if (!mounted) return;
    setState(() => _backupHistory = list);
  }

  String _fmtDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _fmtBytes(int bytes) {
    const k = 1024;
    if (bytes < k) return '$bytes B';
    final kb = bytes / k;
    if (kb < k) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / k;
    if (mb < k) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / k;
    return '${gb.toStringAsFixed(1)} GB';
  }

  bool _isDbFile(PlatformFile file) {
    final name = file.name.toLowerCase();
    if (name.endsWith('.db')) return true;
    final ext = file.extension?.toLowerCase();
    if (ext == 'db') return true;
    final path = file.path?.toLowerCase();
    if (path != null && path.endsWith('.db')) return true;
    return false;
  }

  String _hashShort(String input) {
    if (input.length <= 8) return input;
    return input.substring(0, 8);
  }

  String _checksumBytes(Uint8List bytes) {
    return sha256.convert(bytes).toString();
  }

  bool _isSqliteHeader(Uint8List bytes) {
    if (bytes.length < 16) return false;
    const header = 'SQLite format 3';
    final text = String.fromCharCodes(bytes.take(header.length));
    return text == header;
  }

  String? _extractHashFromName(String name) {
    final match = RegExp(r'_h([0-9a-fA-F]{8})_').firstMatch(name);
    return match?.group(1);
  }

  int? _extractVersionFromName(String name) {
    final match = RegExp(r'_v(\d+)_h').firstMatch(name);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  Future<int> _currentDbVersion() async {
    final appDb = ref.read(appDatabaseProvider);
    final db = await appDb.database;
    final rows = await db.rawQuery('PRAGMA user_version');
    final value = rows.isNotEmpty ? rows.first.values.first : null;
    return (value as int?) ?? 0;
  }

  Future<int> _readBackupVersion(Database db) async {
    final rows = await db.rawQuery('PRAGMA user_version');
    final value = rows.isNotEmpty ? rows.first.values.first : null;
    return (value as int?) ?? 0;
  }

  Future<bool> _confirmVersionMismatch({
    required int backupVersion,
    required int currentVersion,
  }) async {
    if (backupVersion == currentVersion) return true;
    if (!mounted) return false;
    return (await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Versao diferente'),
            content: Text(
              'Este backup esta na versao v$backupVersion. '
              'O app usa v$currentVersion. '
              'O app pode ajustar o banco, mas revise os dados apos importar. '
              'Deseja continuar?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Continuar'),
              ),
            ],
          ),
        )) ??
        false;
  }

  Future<bool> _confirmNoChecksum() async {
    if (!mounted) return false;
    return (await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Checksum ausente'),
            content: const Text(
              'Este backup nao possui checksum no nome. '
              'Nao e possivel validar integridade pelo nome do arquivo. '
              'Deseja continuar?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Continuar'),
              ),
            ],
          ),
        )) ??
        false;
  }

  Future<void> _persistBackupInfo({
    required String fileName,
    required DateTime createdAt,
    required int sizeBytes,
  }) async {
    final repo = ref.read(appPreferencesRepositoryProvider);
    await repo.salvarBackupInfo(
      fileName: fileName,
      createdAt: createdAt,
      sizeBytes: sizeBytes,
    );
    final history = await repo.adicionarBackupHistorico(
      BackupInfo(
        fileName: fileName,
        createdAt: createdAt,
        sizeBytes: sizeBytes,
      ),
    );
    if (!mounted) return;
    setState(
      () {
        _backupInfo = BackupInfo(
          fileName: fileName,
          createdAt: createdAt,
          sizeBytes: sizeBytes,
        );
        _backupHistory = history;
      },
    );
  }

  Future<void> _showRestartDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Reiniciar o app'),
        content: const Text(
          'Backup importado com sucesso. Para concluir, feche e abra o app novamente.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              SystemNavigator.pop();
            },
            child: const Text('Fechar app'),
          ),
        ],
      ),
    );
  }

  Future<_BackupExportAction?> _pickExportAction() async {
    return showModalBottomSheet<_BackupExportAction>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.save_alt_outlined),
                title: const Text('Salvar localmente'),
                subtitle: const Text(
                  'Escolher uma pasta para salvar o arquivo',
                ),
                onTap: () =>
                    Navigator.of(ctx).pop(_BackupExportAction.saveLocal),
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Compartilhar'),
                subtitle: const Text('Enviar via WhatsApp, Drive, e-mail...'),
                onTap: () => Navigator.of(ctx).pop(_BackupExportAction.share),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportBackup() async {
    if (_exporting || _importing) return;

    setState(() => _exporting = true);
    try {
      final appDb = ref.read(appDatabaseProvider);
      final db = await appDb.database;
      await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
      final dbVersion = await _currentDbVersion();

      final dbPath = await appDb.dbPath();
      final tempDir = await getTemporaryDirectory();
      final stamp = _timestamp();
      final tempName = 'erp_revenda_backup_$stamp.db';
      final backupPath = p.join(tempDir.path, tempName);

      var backupFile = await File(dbPath).copy(backupPath);
      final exportBytes = await backupFile.readAsBytes();
      final hash = _hashShort(_checksumBytes(exportBytes));
      final fileName = 'erp_revenda_backup_v${dbVersion}_h${hash}_$stamp.db';
      final finalPath = p.join(tempDir.path, fileName);
      if (backupFile.path != finalPath) {
        backupFile = await backupFile.rename(finalPath);
      }
      final stat = await backupFile.stat();
      final now = DateTime.now();

      if (!mounted) return;
      final action = await _pickExportAction();
      if (action == null) return;

      var savedName = fileName;

      if (action == _BackupExportAction.saveLocal) {
        if (Platform.isAndroid || Platform.isIOS) {
          final savedPath = await FilePicker.platform.saveFile(
            dialogTitle: 'Salvar backup',
            fileName: fileName,
            bytes: exportBytes,
          );
          if (savedPath == null) return;
          savedName = p.basename(savedPath);
        } else {
          final targetPath = await FilePicker.platform.saveFile(
            dialogTitle: 'Salvar backup',
            fileName: fileName,
          );
          if (targetPath == null) return;
          final savedFile = await backupFile.copy(targetPath);
          savedName = p.basename(savedFile.path);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup salvo localmente.')),
        );
      } else {
        await Share.shareXFiles([
          XFile(backupFile.path),
        ], text: 'Backup ERP Revenda');

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup pronto para compartilhar.')),
        );
      }

      await _persistBackupInfo(
        fileName: savedName,
        createdAt: now,
        sizeBytes: stat.size,
      );
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(context, 'Erro ao exportar backup:\n$e');
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<bool> _confirmImport() async {
    return (await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Importar backup'),
            content: const Text(
              'Este processo substitui os dados atuais. Deseja continuar?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Continuar'),
              ),
            ],
          ),
        )) ??
        false;
  }

  Future<void> _importBackup() async {
    if (_exporting || _importing) return;

    final confirmed = await _confirmImport();
    if (!confirmed) return;

    FilePickerResult? result;
    try {
      final isMobile = Platform.isAndroid || Platform.isIOS;
      result = await FilePicker.platform.pickFiles(
        type: isMobile ? FileType.any : FileType.custom,
        allowedExtensions: isMobile ? null : ['db'],
        withData: isMobile,
      );
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(context, 'Erro ao abrir o seletor de arquivos:\n$e');
      return;
    }

    final picked = result?.files.single;
    if (picked == null) return;
    if (!_isDbFile(picked)) {
      if (!mounted) return;
      await showErrorDialog(context, 'Selecione um arquivo .db valido.');
      return;
    }
    final pickedPath = picked.path;
    final pickedBytes = picked.bytes;
    if (pickedPath == null && pickedBytes == null) {
      if (!mounted) return;
      await showErrorDialog(
        context,
        'Arquivo invalido. Tente selecionar novamente.',
      );
      return;
    }

    setState(() => _importing = true);
    try {
      final appDb = ref.read(appDatabaseProvider);
      final currentVersion = await _currentDbVersion();

      final bytes = pickedBytes ?? await File(pickedPath!).readAsBytes();
      if (!_isSqliteHeader(bytes)) {
        if (!mounted) return;
        await showErrorDialog(context, 'Arquivo nao e um SQLite valido.');
        return;
      }

      final expectedHash = _extractHashFromName(picked.name);
      final computedHash = _hashShort(_checksumBytes(bytes));
      if (expectedHash != null &&
          expectedHash.toLowerCase() != computedHash.toLowerCase()) {
        if (!mounted) return;
        await showErrorDialog(
          context,
          'Checksum nao confere. Arquivo pode estar corrompido.',
        );
        return;
      }
      if (expectedHash == null) {
        final ok = await _confirmNoChecksum();
        if (!ok) return;
      }

      final tempDir = await getTemporaryDirectory();
      final validationPath = p.join(tempDir.path, 'backup_validate.db');
      final validationFile =
          await File(validationPath).writeAsBytes(bytes, flush: true);
      final validationDb = await openDatabase(
        validationFile.path,
        readOnly: true,
      );
      final integrityRows =
          await validationDb.rawQuery('PRAGMA integrity_check');
      final integrity =
          integrityRows.isNotEmpty ? integrityRows.first.values.first : null;
      if (integrity != 'ok') {
        await validationDb.close();
        if (!mounted) return;
        await showErrorDialog(context, 'Falha na integridade do backup.');
        return;
      }
      final backupVersion = await _readBackupVersion(validationDb);
      await validationDb.close();

      final nameVersion = _extractVersionFromName(picked.name);
      if (nameVersion != null && nameVersion != backupVersion) {
        if (!mounted) return;
        await showErrorDialog(
          context,
          'Versao no nome do arquivo nao confere com o banco.',
        );
        return;
      }

      final proceed = await _confirmVersionMismatch(
        backupVersion: backupVersion,
        currentVersion: currentVersion,
      );
      if (!proceed) return;

      await appDb.close();

      final dbPath = await appDb.dbPath();
      final wal = File('$dbPath-wal');
      final shm = File('$dbPath-shm');

      if (await wal.exists()) await wal.delete();
      if (await shm.exists()) await shm.delete();

      await File(dbPath).writeAsBytes(bytes, flush: true);


      await appDb.database;

      if (!mounted) return;
      await _showRestartDialog();
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(context, 'Erro ao importar backup:\n$e');
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Backup',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (_backupInfo != null) ...[
            Card(
              elevation: 0,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Último backup',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _backupInfo!.fileName,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_fmtDateTime(_backupInfo!.createdAt)} • ${_fmtBytes(_backupInfo!.sizeBytes)}',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_backupHistory.isNotEmpty) ...[
            Card(
              elevation: 0,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Historico de backups',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _backupHistory.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _backupHistory[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            item.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${_fmtDateTime(item.createdAt)} · ${_fmtBytes(item.sizeBytes)}',
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                          trailing: TextButton(
                            onPressed:
                                _exporting || _importing ? null : _exportBackup,
                            child: const Text('Reexportar'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _BackupCard(
            icon: Icons.backup_outlined,
            title: 'Exportar',
            subtitle:
                'Gera um arquivo .db para compartilhar no Drive ou WhatsApp.',
            buttonLabel: _exporting ? 'Exportando...' : 'Exportar backup',
            onPressed: _exporting || _importing ? null : _exportBackup,
          ),
          const SizedBox(height: 12),
          _BackupCard(
            icon: Icons.upload_file_outlined,
            title: 'Importar',
            subtitle: 'Seleciona um arquivo .db e substitui os dados atuais.',
            buttonLabel: _importing ? 'Importando...' : 'Importar backup',
            onPressed: _exporting || _importing ? null : _importBackup,
            isDanger: true,
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: AppColors.surfaceAlt,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Dica: salve o backup em um local seguro. '
                'Para importar, use um arquivo gerado pelo app.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _BackupExportAction { saveLocal, share }

class _BackupCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final bool isDanger;

  const _BackupCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDanger
              ? AppColors.danger.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isDanger
                      ? AppColors.danger.withValues(alpha: 0.1)
                      : AppColors.surfaceAlt,
                  foregroundColor: isDanger
                      ? AppColors.danger
                      : AppColors.primary,
                  child: Icon(icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppGradientButton(
              label: buttonLabel,
              trailingIcon: Icons.arrow_forward,
              onPressed: onPressed,
            ),
          ],
        ),
      ),
    );
  }
}
