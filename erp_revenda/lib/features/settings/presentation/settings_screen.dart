import 'package:flutter/material.dart';
import '../../../shared/widgets/app_page.dart';
import '../../../app/ui/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Configurações',
      showBack: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: const [
          _SettingTile(
            icon: Icons.person_outline,
            title: 'Perfil',
            subtitle: 'Dados do usuário e PIN',
          ),
          SizedBox(height: 10),
          _SettingTile(
            icon: Icons.backup_outlined,
            title: 'Backup',
            subtitle: 'Exportar / importar dados por e-mail',
          ),
          SizedBox(height: 10),
          _SettingTile(
            icon: Icons.palette_outlined,
            title: 'Aparência',
            subtitle: 'Tema e preferências',
          ),
          SizedBox(height: 10),
          _SettingTile(
            icon: Icons.info_outline,
            title: 'Sobre',
            subtitle: 'Versão do app e suporte',
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.chevron_right, color: AppColors.textMuted),
      ),
    );
  }
}
