#!/usr/bin/env bash
# curl-install: fetch the latest notarized WakieAI DMG from GitHub Releases and
# drop the app into /Applications. Because the DMG is signed + notarized +
# stapled, Gatekeeper passes with no right-click dance.
#
#   curl -fsSL https://raw.githubusercontent.com/JinLeeGG/WakeyAI/main/deploy/install.sh | bash
#
# After install, the app self-updates via Sparkle — this script is only for the
# very first install.
set -euo pipefail

REPO="JinLeeGG/WakeyAI"
APP="WakieAI.app"
DMG_NAME="WakieAI.dmg"

say() { printf '\033[1;33m▸ %s\033[0m\n' "$*"; }

url="https://github.com/${REPO}/releases/latest/download/${DMG_NAME}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"; [ -n "${mnt:-}" ] && hdiutil detach "$mnt" -quiet 2>/dev/null || true' EXIT

say "Downloading ${DMG_NAME}…"
curl -fL# -o "$tmp/$DMG_NAME" "$url"

say "Mounting…"
mnt="$(hdiutil attach "$tmp/$DMG_NAME" -nobrowse -readonly | grep -o '/Volumes/.*' | head -1)"

say "Installing to /Applications…"
rm -rf "/Applications/$APP"
cp -R "$mnt/$APP" /Applications/

say "Done. Launch WakieAI from /Applications (it lives in the menu bar)."
