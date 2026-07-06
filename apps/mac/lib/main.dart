import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:wakie_core/wakie_core.dart' as core;

import 'dashboard.dart';
import 'engine.dart';
import 'theme.dart';
import 'tray_icon.dart';
import 'updater.dart';

const _window = MethodChannel('wakie/window');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A quit/hot-restart mid-scan can orphan a scrape's CLI in its sandbox
  // config (agy there pesters the user with keychain dialogs) — clean up.
  unawaited(core.killOrphanedSandboxScrapes());

  // Native vibrancy (real desktop blur behind the glass panel).
  await WindowManipulator.initialize(enableWindowDelegate: false);
  WindowManipulator.setMaterial(NSVisualEffectViewMaterial.hudWindow);
  // Keep the frosted blur on even when the window is not focused.
  WindowManipulator.setNSVisualEffectViewState(NSVisualEffectViewState.active);

  runApp(const WakieApp());

  // Check for an update quietly on launch, then on a schedule (Sparkle).
  // Fire-and-forget: no-op in debug/off-macOS, never blocks startup.
  unawaited(initAutoUpdater());
}

class WakieApp extends StatefulWidget {
  const WakieApp({super.key});

  @override
  State<WakieApp> createState() => _WakieAppState();
}

class _WakieAppState extends State<WakieApp> with TrayListener {
  final Engine _engine = Engine.production();
  final TrayIcon _tray = TrayIcon();
  final DashboardController _dash = DashboardController();

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    _initTray();
    // Native tells us each time the panel is brought on screen or tucked away.
    // On show: refresh so opening from the menu bar always shows fresh data.
    // The visible flag also gates cosmetic animations (see DashboardController).
    _window.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'didShow':
          _dash.visible.value = true;
          _dash.refreshAll();
        case 'didHide':
          _dash.visible.value = false;
        case 'didWake':
          _dash.pokeAwake();
      }
      return null;
    });
  }

  Future<void> _initTray() async {
    await _tray.init();
    await trayManager.setToolTip('Wakie');
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'show', label: 'Open Wakie'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Quit'),
    ]));
  }

  @override
  void onTrayIconMouseDown() => _window.invokeMethod('toggle');

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _window.invokeMethod('show');
      case 'quit':
        _window.invokeMethod('quit');
    }
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    _tray.dispose();
    _dash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wakie',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: T.sans,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: DashboardScreen(
        source: _engine.watch,
        onTrayState: _tray.set,
        controller: _dash,
        onUpdateAccount: (a) => _engine.refreshAccount(a.id),
        onRemoveAccount: (a) => _engine.removeAccount(a.id),
        onSetAutoStart: (a, enabled) => _engine.setAutoStart(a.id, enabled),
        onCreateAccount: _engine.addAccount,
        onCheckInstalled: _engine.isProviderInstalled,
        onPollSignins: _engine.pollSignins,
        morningAnchorHour: _engine.morningAnchorHour,
        morningAnchorMinute: _engine.morningAnchorMinute,
        onSetMorningAnchor: (h, m) async {
          final error = await _engine.setMorningAnchor(h, m);
          // When dark wake is on, this shows an admin prompt that steals focus
          // and buries the panel; bring it back so the result is visible.
          await _window.invokeMethod('resurface');
          return error;
        },
        onAwakeTick: _engine.awakeTick,
        launchAtLogin: _engine.launchAtLogin,
        onSetLaunchAtLogin: _engine.setLaunchAtLogin,
        darkWake: _engine.darkWake,
        onSetDarkWake: (on) async {
          final error = await _engine.setDarkWake(on);
          // The admin password dialog (a separate secure process) buries our
          // menubar panel; resurface it so the result is visible without a
          // manual menubar click.
          await _window.invokeMethod('show');
          return error;
        },
      ),
    );
  }
}
