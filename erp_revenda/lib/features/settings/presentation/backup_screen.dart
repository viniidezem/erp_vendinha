import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/ui/app_colors.dart';
import '../../../shared/widgets/app_error_dialog.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_page.dart';
import '../../clientes/controller/clientes_controller.dart'
    show appDatabaseProvider;

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _exporting = false;
  bool _importing = false;

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

  Future<void> _exportBackup() async {
    if (_exporting || _importing) return;

    setState(() => _exporting = true);
    try {
      final appDb = ref.read(appDatabaseProvider);
      final db = await appDb.database;
      await db.rawQuery('PRAGMA wal_checkpoint(FULL)');

      final dbPath = await appDb.dbPath();
      final tempDir = await getTemporaryDirectory();
      final fileName = 'erp_revenda_backup_${_timestamp()}.db';
      final backupPath = p.join(tempDir.path, fileName);

      await File(dbPath).copy(backupPath);

      await Share.shareXFiles(
        [XFile(backupPath)],
        text: 'Backup ERP Revenda',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup pronto para compartilhar.')),
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

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db'],
    );

    final pickedPath = result?.files.single.path;
    if (pickedPath == null) return;

    setState(() => _importing = true);
    try {
      final source = File(pickedPath);
      if (!await source.exists()) {
        throw StateError('Arquivo de backup nao encontrado.');
      }

      final appDb = ref.read(appDatabaseProvider);
      await appDb.close();

      final dbPath = await appDb.dbPath();
      final wal = File('$dbPath-wal');
      final shm = File('$dbPath-shm');

      if (await wal.exists()) await wal.delete();
      if (await shm.exists()) await shm.delete();

      await source.copy(dbPath);

      await appDb.database;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup importado com sucesso.')),
      );
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
          _BackupCard(
            icon: Icons.backup_outlined,
            title: 'Exportar',
            subtitle: 'Gera um arquivo .db para compartilhar no Drive ou WhatsApp.',
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
          color: isDanger ? AppColors.danger.withValues(alpha: 0.3) : AppColors.border,
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
                  backgroundColor:
                      isDanger
                          ? AppColors.danger.withValues(alpha: 0.1)
                          : AppColors.surfaceAlt,
                  foregroundColor:
                      isDanger ? AppColors.danger : AppColors.primary,
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
