#!/usr/bin/env bash
# Finish a notarization that package.sh couldn't wait out (Apple can take
# hours). Checks the submission, and once it's Accepted, staples the ticket to
# the already-built DMG — no rebuild or re-notarize needed.
#
# Run from apps/mac:
#   scripts/staple.sh                 # uses the most recent submission
#   scripts/staple.sh <submission-id> # a specific one
set -euo pipefail

NOTARY_PROFILE="wakieai"
DMG="build/dist/WakieAI.dmg"

[ -f "$DMG" ] || { echo "✗ no DMG at $DMG — run scripts/package.sh first"; exit 1; }

ID="${1:-}"
if [ -z "$ID" ]; then
  ID="$(xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" \
        | sed -n 's/^ *id: //p' | head -1)"
  [ -n "$ID" ] || { echo "✗ no submissions found for profile '$NOTARY_PROFILE'"; exit 1; }
  echo "▸ latest submission: $ID"
fi

STATUS="$(xcrun notarytool info "$ID" --keychain-profile "$NOTARY_PROFILE" \
          | sed -n 's/^ *status: //p')"
echo "▸ status: $STATUS"

case "$STATUS" in
  Accepted)
    xcrun stapler staple "$DMG"
    spctl -a -t open --context context:primary-signature -vv "$DMG" || true
    printf '\n\033[1;32m✓ Stapled: %s\033[0m\n' "$DMG" ;;
  "In Progress")
    echo "… still notarizing — re-run later." ; exit 2 ;;
  *)
    echo "✗ not Accepted ($STATUS). Fetch the log with:"
    echo "    xcrun notarytool log $ID --keychain-profile $NOTARY_PROFILE"
    exit 1 ;;
esac
