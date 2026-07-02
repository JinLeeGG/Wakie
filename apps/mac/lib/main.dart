import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:tray_manager/tray_manager.dart';

import 'dashboard.dart';
import 'engine.dart';
import 'theme.dart';

const _window = MethodChannel('wakieai/window');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Native vibrancy (real desktop blur behind the glass panel).
  await WindowManipulator.initialize(enableWindowDelegate: false);
  WindowManipulator.setMaterial(NSVisualEffectViewMaterial.hudWindow);
  // Keep the frosted blur on even when the window is not focused.
  WindowManipulator.setNSVisualEffectViewState(NSVisualEffectViewState.active);

  runApp(const WakieApp());
}

class WakieApp extends StatefulWidget {
  const WakieApp({super.key});

  @override
  State<WakieApp> createState() => _WakieAppState();
}

class _WakieAppState extends State<WakieApp> with TrayListener {
  final Engine _engine = Engine.production();

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    _initTray();
  }

  Future<void> _initTray() async {
    await trayManager.setIcon('assets/tray/tray_icon.png', isTemplate: true);
    await trayManager.setToolTip('WakieAI');
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'show', label: 'Open WakieAI'),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WakieAI',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: T.sans,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: DashboardScreen(
        source: _engine.watch,
        onUpdateAccount: (a) => _engine.refreshAccount(a.id),
        onRemoveAccount: (a) => _engine.removeAccount(a.id),
        onSetAutoStart: (a, enabled) => _engine.setAutoStart(a.id, enabled),
        onCreateAccount: _engine.addAccount,
        onPollSignins: _engine.pollSignins,
        morningAnchorHour: _engine.morningAnchorHour,
        morningAnchorMinute: _engine.morningAnchorMinute,
        onSetMorningAnchor: _engine.setMorningAnchor,
        onAwakeTick: _engine.awakeTick,
        launchAtLogin: _engine.launchAtLogin,
        onSetLaunchAtLogin: _engine.setLaunchAtLogin,
      ),
    );
  }
}
