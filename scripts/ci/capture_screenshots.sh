#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="artifacts/screenshots"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 16}"
APP_BUNDLE_PATH="${APP_BUNDLE_PATH:-}"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-}"

mkdir -p "$OUT_DIR"

cleanup() {
  echo "Shutting down simulator: $SIMULATOR_NAME"
  xcrun simctl shutdown "$SIMULATOR_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Booting simulator: $SIMULATOR_NAME"
boot_stderr="$(mktemp)"
if ! xcrun simctl boot "$SIMULATOR_NAME" 2>"$boot_stderr"; then
  if xcrun simctl list devices "$SIMULATOR_NAME" | grep -q "(Booted)"; then
    echo "simctl boot returned a non-zero exit code, but the simulator is already booted; continuing."
  else
    echo "Failed to boot simulator: $SIMULATOR_NAME" >&2
    cat "$boot_stderr" >&2
    rm -f "$boot_stderr"
    exit 1
  fi
fi
rm -f "$boot_stderr"
xcrun simctl bootstatus "$SIMULATOR_NAME" -b

fallback_path="$OUT_DIR/launch.png"

if [[ -n "$APP_BUNDLE_PATH" && -d "$APP_BUNDLE_PATH" && -n "$APP_BUNDLE_ID" ]]; then
  echo "Installing app for screenshot capture: $APP_BUNDLE_ID"
  xcrun simctl install booted "$APP_BUNDLE_PATH"
  xcrun simctl terminate booted "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl launch booted "$APP_BUNDLE_ID"
  sleep 3
else
  echo "Missing APP_BUNDLE_PATH or APP_BUNDLE_ID for screenshot capture." >&2
  exit 1
fi

xcrun simctl io booted screenshot "$fallback_path"

echo "Exported screenshot artifacts to:"
echo "$fallback_path"
