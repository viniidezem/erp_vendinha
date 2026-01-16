import 'dart:async';

import 'package:bottom_bar/bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cadastros/presentation/cadastros_hub_screen.dart';
import '../../settings/controller/pin_settings_controller.dart';
import '../../settings/presentation/pin_lock_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../vendas/presentation/vendas_screen.dart';
import 'dashboard_screen.dart';

class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen>
    with WidgetsBindingObserver {
  int _index = 0;
  Timer? _inactivityTimer;
  DateTime _lastInteraction = DateTime.now();

  void _setIndex(int i) {
    if (i == _index) return;
    setState(() => _index = i);
  }

  void _touch() {
    _lastInteraction = DateTime.now();
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkInactivity(),
    );
  }

  void _checkInactivity() {
    final settings = ref.read(pinSettingsProvider).value;
    if (settings == null) return;
    if (!settings.enabled) return;
    if (settings.lockTimeoutMinutes <= 0) return;
    final unlocked = ref.read(pinSessionUnlockedProvider);
    if (!unlocked) return;
    final diff = DateTime.now().difference(_lastInteraction);
    if (diff >= Duration(minutes: settings.lockTimeoutMinutes)) {
      ref.read(pinSessionUnlockedProvider.notifier).state = false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _touch();
    _startInactivityTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final settings = ref.read(pinSettingsProvider).value;
    if (settings == null) return;
    if (!settings.enabled || !settings.lockOnBackground) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ref.read(pinSessionUnlockedProvider.notifier).state = false;
    } else if (state == AppLifecycleState.resumed) {
      _touch();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(pinSessionUnlockedProvider, (previous, next) {
      if (next) {
        _touch();
      }
    });

    final activeColor = Theme.of(context).colorScheme.primary;
    final pages = <Widget>[
      const DashboardScreen(),
      const CadastrosHubScreen(),
      const VendasScreen(showBack: false),
      const SettingsScreen(),
    ];

    final pinAsync = ref.watch(pinSettingsProvider);
    return pinAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Erro ao carregar PIN: $e')),
      ),
      data: (settings) {
        final unlocked = ref.watch(pinSessionUnlockedProvider);
        final locked = settings.enabled && !unlocked;

        return Scaffold(
          body: Stack(
            children: [
              Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) => _touch(),
                onPointerMove: (_) => _touch(),
                child: IndexedStack(index: _index, children: pages),
              ),
              if (settings.enabled)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !locked,
                    child: AnimatedOpacity(
                      opacity: locked ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const PinLockScreen(),
                    ),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: locked
              ? null
              : SafeArea(
                  top: false,
                  child: BottomBar(
                    selectedIndex: _index,
                    onTap: _setIndex,
                    showActiveBackgroundColor: true,
                    itemPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    items: <BottomBarItem>[
                      BottomBarItem(
                        icon: const Icon(Icons.home_outlined),
                        title: const Text('Home'),
                        activeColor: activeColor,
                      ),
                      BottomBarItem(
                        icon: const Icon(Icons.dashboard_customize_outlined),
                        title: const Text('Cadastros'),
                        activeColor: activeColor,
                      ),
                      BottomBarItem(
                        icon: const Icon(Icons.receipt_long_outlined),
                        title: const Text('Pedidos'),
                        activeColor: activeColor,
                      ),
                      BottomBarItem(
                        icon: const Icon(Icons.settings_outlined),
                        title: const Text('Config'),
                        activeColor: activeColor,
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
