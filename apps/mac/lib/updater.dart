import 'dart:io';

import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/foundation.dart';

/// Public appcast feed, served from GitHub Pages. It lists every released
/// version with its EdDSA signature; the actual DMGs live as GitHub Release
/// assets. The CI release workflow appends to this file. See docs/RELEASE.md.
const _feedUrl = 'https://jinleegg.github.io/Wakie/appcast.xml';

/// How often Sparkle re-checks in the background (seconds). Sparkle enforces a
/// 1h floor; daily is plenty for a menu-bar utility.
const _checkInterval = 24 * 60 * 60;

/// Wires up Sparkle-backed auto-update: point it at the feed, check quietly on
/// launch, then let it re-check on a schedule. Sparkle only surfaces UI when an
/// update actually exists, and only installs a build whose EdDSA signature
/// matches the public key baked into Info.plist — so this can't be MITM'd.
///
/// No-op in debug or off macOS: Sparkle needs a signed/notarized release build
/// to verify and swap the bundle, so a `flutter run` would only log errors.
/// Fire-and-forget — a failed feed fetch must never block or crash startup.
Future<void> initAutoUpdater() async {
  if (kDebugMode || !Platform.isMacOS) return;
  try {
    await autoUpdater.setFeedURL(_feedUrl);
    await autoUpdater.setScheduledCheckInterval(_checkInterval);
    await autoUpdater.checkForUpdates(inBackground: true);
  } catch (e) {
    debugPrint('wakie: auto-update init failed: $e');
  }
}
