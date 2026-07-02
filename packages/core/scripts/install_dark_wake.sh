#!/usr/bin/env bash
# Installs the WakieAI headless runner as a daily dark-wake LaunchAgent
# (PRD §9.2, §15 Phase 1). Safe, non-privileged steps only — compiling the
# runner, writing the plist, and `launchctl` registration all run under your
# normal user account. The one privileged step (programming the actual
# hardware wake) needs admin and is never run for you: this script prints
# the exact `sudo pmset` command at the end for you to run yourself.
#
# Re-run any time you change the morning anchor time in WakieAI's settings —
# it recompiles/reinstalls the plist with the new time.
set -euo pipefail

CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="$HOME/Library/Application Support/WakieAI"
RUNNER_BIN="$INSTALL_DIR/wakieai_runner"
LOG_DIR="$INSTALL_DIR/logs"
PLIST_PATH="$HOME/Library/LaunchAgents/ai.wakie.runner.plist"

mkdir -p "$INSTALL_DIR" "$LOG_DIR"

echo "==> Fetching packages..."
(cd "$CORE_DIR" && dart pub get)

echo "==> Compiling the headless runner to $RUNNER_BIN ..."
(cd "$CORE_DIR" && dart compile exe bin/wakieai_runner.dart -o "$RUNNER_BIN")

echo "==> Writing $PLIST_PATH ..."
(cd "$CORE_DIR" && dart run bin/print_launch_agent_plist.dart \
  "$RUNNER_BIN" "$LOG_DIR/out.log" "$LOG_DIR/err.log" > "$PLIST_PATH")

echo "==> Registering with launchd..."
launchctl unload "$PLIST_PATH" >/dev/null 2>&1 || true
launchctl load "$PLIST_PATH"

PMSET_CMD="$(cd "$CORE_DIR" && dart run bin/print_pmset_command.dart)"

cat <<EOF

Installed. launchd will run the runner once a day at your morning anchor
time (see WakieAI settings; default 8:00am) whenever the Mac is awake.

For it to also WAKE the Mac from sleep at that time, run this yourself
(admin password required — WakieAI never runs this for you):

  $PMSET_CMD

To remove everything later:
  launchctl unload "$PLIST_PATH"
  rm "$PLIST_PATH" "$RUNNER_BIN"
  sudo pmset repeat cancel
EOF
