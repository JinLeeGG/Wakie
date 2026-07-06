#!/usr/bin/env bash
# Build → Developer ID sign → DMG → notarize → staple, for external (non-App
# Store) distribution. MAS is impossible (App Sandbox forbids the engine's core
# ops — PRD §16 D-SANDBOX), so this is the ship path.
#
# One-time prerequisites (owner):
#   • Paid Apple Developer Program membership.
#   • A "Developer ID Application" certificate in the login keychain.
#   • Notary credentials saved as a keychain profile:
#       xcrun notarytool store-credentials "wakieai" \
#         --apple-id <id> --team-id 8GJTN3VYTJ --password <app-specific-pw>
#
# Run from apps/mac:  scripts/package.sh
set -euo pipefail

IDENTITY="Developer ID Application: Gyujin Lee (8GJTN3VYTJ)"
NOTARY_PROFILE="wakieai"

APP="build/macos/Build/Products/Release/wakieai.app"
RUNNER="$APP/Contents/Resources/wakieai_runner"
APP_ENT="macos/Runner/Release.entitlements"
RUNNER_ENT="macos/scripts/runner.entitlements"
DIST="build/dist"
DMG="$DIST/WakieAI.dmg"

say() { printf '\n\033[1;33m▸ %s\033[0m\n' "$*"; }

say "Building release…"
flutter build macos --release

[ -x "$RUNNER" ] || { echo "✗ bundled runner missing at $RUNNER"; exit 1; }

say "Signing nested code (Developer ID + hardened runtime)…"
# Sparkle ships its helpers pre-signed by the Sparkle project (no secure
# timestamp, not our Developer ID) — notarization rejects those. Re-sign the
# nested pieces inside-out BEFORE the framework wrapper, or the framework's
# seal covers stale inner signatures. (Skipped cleanly if Sparkle isn't
# bundled.)
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
if [ -d "$SPARKLE" ]; then
  for nested in \
    "$SPARKLE/Versions/Current/XPCServices/Downloader.xpc" \
    "$SPARKLE/Versions/Current/XPCServices/Installer.xpc" \
    "$SPARKLE/Versions/Current/Autoupdate" \
    "$SPARKLE/Versions/Current/Updater.app"; do
    [ -e "$nested" ] && codesign --force --options runtime --timestamp \
      --sign "$IDENTITY" "$nested"
  done
fi

# Inside-out: frameworks and dylibs first, then the AOT runner (its own
# executable-memory entitlement), then the app itself last.
while IFS= read -r -d '' item; do
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$item"
done < <(find "$APP/Contents/Frameworks" -maxdepth 1 \
           \( -name "*.framework" -o -name "*.dylib" \) -print0 2>/dev/null)

codesign --force --options runtime --timestamp \
  --entitlements "$RUNNER_ENT" --sign "$IDENTITY" "$RUNNER"

say "Signing the app…"
codesign --force --options runtime --timestamp \
  --entitlements "$APP_ENT" --sign "$IDENTITY" "$APP"

say "Verifying signature…"
codesign --verify --deep --strict --verbose=2 "$APP"

say "Building DMG…"
rm -rf "$DIST"; mkdir -p "$DIST"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
# Give the mounted volume the app's own icon (hdiutil has no -volicon): drop it
# as .VolumeIcon.icns, set the custom-icon bit on a read-write image, then
# convert to the final compressed DMG so the flag is preserved.
cp "$APP/Contents/Resources/AppIcon.icns" "$STAGE/.VolumeIcon.icns"
RW="$(mktemp -u).dmg"
hdiutil create -volname "WakieAI" -srcfolder "$STAGE" -ov -format UDRW "$RW" >/dev/null
MOUNT="$(hdiutil attach "$RW" -nobrowse -noverify | grep -o '/Volumes/.*' | head -1)"
SetFile -a C "$MOUNT"
hdiutil detach "$MOUNT" -quiet
hdiutil convert "$RW" -format UDZO -o "$DMG" >/dev/null
rm -f "$RW"; rm -rf "$STAGE"
codesign --force --timestamp --sign "$IDENTITY" "$DMG"

say "Notarizing (this waits on Apple)…"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait

say "Stapling…"
xcrun stapler staple "$DMG"

say "Gatekeeper check…"
spctl -a -t open --context context:primary-signature -vv "$DMG" || true

printf '\n\033[1;32m✓ Shipped: %s\033[0m\n' "$DMG"
