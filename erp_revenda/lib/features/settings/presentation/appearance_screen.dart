import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/ui/app_colors.dart';
import '../../../shared/widgets/app_error_dialog.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_page.dart';
import '../controller/app_preferences_controller.dart';

class AppearanceScreen extends ConsumerStatefulWidget {
  const AppearanceScreen({super.key});

  @override
  ConsumerState<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends ConsumerState<AppearanceScreen> {
  final _storeCtrl = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _storeCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvarNome() async {
    try {
      await ref
          .read(appPreferencesProvider.notifier)
          .atualizar(storeName: _storeCtrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome da loja atualizado.')),
      );
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(context, 'Erro ao salvar nome da loja:\n$e');
    }
  }

  Future<void> _selecionarPaleta(AppPalette palette) async {
    try {
      await ref
          .read(appPreferencesProvider.notifier)
          .atualizar(paletteId: palette.id);
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(context, 'Erro ao salvar paleta:\n$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncPrefs = ref.watch(appPreferencesProvider);

    return AppPage(
      title: 'Aparencia',
      child: asyncPrefs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar preferencias: $e')),
        data: (prefs) {
          if (!_initialized) {
            _storeCtrl.text = prefs.storeName ?? '';
            _initialized = true;
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const Text(
                'Nome da loja',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _storeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ex: Loja da Fulana',
                ),
              ),
              const SizedBox(height: 12),
              AppGradientButton(
                label: 'Salvar nome',
                trailingIcon: Icons.check,
                onPressed: _salvarNome,
              ),
              const SizedBox(height: 20),
              const Text(
                'Paletas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              ...AppColors.palettes.map(
                (p) => _PaletteTile(
                  palette: p,
                  selected: prefs.paletteId == p.id,
                  onTap: () => _selecionarPaleta(p),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PaletteTile extends StatelessWidget {
  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  const _PaletteTile({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? palette.primary : AppColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(palette.label),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ColorDot(color: palette.primary),
            const SizedBox(width: 6),
            _ColorDot(color: palette.primarySoft),
            const SizedBox(width: 6),
            _ColorDot(color: palette.gradientStart),
            const SizedBox(width: 6),
            _ColorDot(color: palette.gradientEnd),
          ],
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;

  const _ColorDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
