import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'features/settings/controller/app_preferences_controller.dart';
import 'app/ui/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ErpRevendaApp()));
}

class ErpRevendaApp extends ConsumerWidget {
  const ErpRevendaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final prefsAsync = ref.watch(appPreferencesProvider);
    final paletteId = prefsAsync.value?.paletteId ?? AppColors.defaultPaletteId;
    final palette = AppColors.paletteById(paletteId);

    return MaterialApp.router(
      title: 'ERP Revenda',
      theme: appTheme(palette),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('pt'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
    );
  }
}
