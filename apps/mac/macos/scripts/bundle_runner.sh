#!/usr/bin/env bash
# Xcode build phase: compiles the headless dark-wake runner
# (packages/core/bin/wakieai_runner.dart) and bundles it at
# Contents/Resources/wakieai_runner — the first place the app's
# _resolveRunnerPath() looks — so the dark-wake toggle works out of the box
# without scripts/install_dark_wake.sh (that script stays for core-only dev).
#
# The compiled binary is cached in DERIVED_FILE_DIR and only rebuilt when a
# core source file changed, so incremental app builds stay fast.
set -euo pipefail

CORE_DIR="$PROJECT_DIR/../../../packages/core"
DART="$FLUTTER_ROOT/bin/dart"
CACHE_BIN="$DERIVED_FILE_DIR/wakieai_runner"
DEST="$BUILT_PRODUCTS_DIR/$CONTENTS_FOLDER_PATH/Resources/wakieai_runner"

mkdir -p "$DERIVED_FILE_DIR"
if [ ! -x "$CACHE_BIN" ] || [ -n "$(find "$CORE_DIR/bin" "$CORE_DIR/lib" \
    "$CORE_DIR/pubspec.yaml" -newer "$CACHE_BIN" -print -quit 2>/dev/null)" ]; then
  (cd "$CORE_DIR" && "$DART" pub get)
  "$DART" compile exe "$CORE_DIR/bin/wakieai_runner.dart" -o "$CACHE_BIN"
fi

mkdir -p "$(dirname "$DEST")"
cp -f "$CACHE_BIN" "$DEST"

# Xcode's codesign pass doesn't descend into Resources; sign the runner with
# the app's identity so a signed/notarized build stays valid.
if [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
  codesign --force --options runtime \
    --sign "$EXPANDED_CODE_SIGN_IDENTITY" "$DEST"
fi
