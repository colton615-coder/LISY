#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="artifacts/screenshots"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 16}"
XCRESULT_PATH="${XCRESULT_PATH:-}"

mkdir -p "$OUT_DIR"

cleanup() {
  echo "Shutting down simulator: $SIMULATOR_NAME"
  xcrun simctl shutdown "$SIMULATOR_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Booting simulator: $SIMULATOR_NAME"
if ! xcrun simctl boot "$SIMULATOR_NAME" >/dev/null 2>&1; then
  echo "simctl boot returned a non-zero exit code (may already be booted); continuing."
fi
xcrun simctl bootstatus "$SIMULATOR_NAME" -b

resolve_xcresult_path() {
  if [[ -n "$XCRESULT_PATH" && -d "$XCRESULT_PATH" ]]; then
    printf '%s\n' "$XCRESULT_PATH"
    return 0
  fi

  shopt -s nullglob globstar
  local candidates=("$HOME"/Library/Developer/Xcode/DerivedData/**/Logs/Test/*.xcresult)
  shopt -u globstar

  if (( ${#candidates[@]} == 0 )); then
    return 1
  fi

  local latest
  latest=$(ls -td "${candidates[@]}" | head -n 1)
  printf '%s\n' "$latest"
}

export_from_xcresult() {
  local xcresult_path="$1"
  local json_path
  json_path="$(mktemp)"

  echo "Attempting Option A: export screenshots from xcresult"
  xcrun xcresulttool get --path "$xcresult_path" --format json > "$json_path"

  python3 - <<'PY' "$json_path" "$OUT_DIR"
import json
import os
import subprocess
import sys

json_path, out_dir = sys.argv[1], sys.argv[2]
with open(json_path, "r", encoding="utf-8") as f:
    data = json.load(f)

seen = set()
exports = []


def unwrap(value):
    if isinstance(value, dict):
        if "_value" in value and len(value) == 1:
            return value["_value"]
    return value


def walk(node):
    if isinstance(node, dict):
        filename = unwrap(node.get("filename", ""))
        uti = unwrap(node.get("uniformTypeIdentifier", ""))
        name = unwrap(node.get("name", ""))
        payload = node.get("payloadRef")

        payload_id = None
        if isinstance(payload, dict):
            payload_id_obj = payload.get("id")
            if isinstance(payload_id_obj, dict):
                payload_id = unwrap(payload_id_obj)

        looks_like_png = (
            isinstance(filename, str)
            and filename.lower().endswith(".png")
        ) or (isinstance(uti, str) and "png" in uti.lower())

        likely_launch = isinstance(name, str) and "launch" in name.lower()

        if payload_id and looks_like_png:
            safe_name = filename if isinstance(filename, str) and filename else f"attachment_{len(exports)+1}.png"
            exports.append((payload_id, safe_name, likely_launch))

        for v in node.values():
            walk(v)

    elif isinstance(node, list):
        for item in node:
            walk(item)


walk(data)

# Prefer launch-like attachments first, then other PNG attachments.
exports.sort(key=lambda item: (not item[2], item[1]))

selected = []
for payload_id, filename, _ in exports:
    if payload_id in seen:
        continue
    seen.add(payload_id)

    base = os.path.basename(filename)
    if not base.lower().endswith(".png"):
        base = f"{base}.png"

    output_path = os.path.join(out_dir, base)
    counter = 1
    while os.path.exists(output_path):
        stem, ext = os.path.splitext(base)
        output_path = os.path.join(out_dir, f"{stem}_{counter}{ext}")
        counter += 1

    selected.append((payload_id, output_path))

if not selected:
    print("No PNG attachments found in xcresult.")
    sys.exit(3)

xcresult_path = os.environ.get("XCRESULT_PATH_RESOLVED")
if not xcresult_path:
    print("Missing XCRESULT_PATH_RESOLVED environment variable.")
    sys.exit(4)

for payload_id, output_path in selected:
    subprocess.run(
        [
            "xcrun",
            "xcresulttool",
            "export",
            "--path",
            xcresult_path,
            "--id",
            payload_id,
            "--type",
            "file",
            "--output-path",
            output_path,
        ],
        check=True,
    )
    print(output_path)
PY
}

if resolved_xcresult="$(resolve_xcresult_path)"; then
  echo "Using xcresult at: $resolved_xcresult"
  if XCRESULT_PATH_RESOLVED="$resolved_xcresult" export_from_xcresult "$resolved_xcresult"; then
    echo "Exported screenshot artifacts to:"
    find "$OUT_DIR" -maxdepth 1 -type f -name '*.png' -print | sort
    exit 0
  fi
  echo "Option A failed; falling back to Option B."
else
  echo "No xcresult bundle found; falling back to Option B."
fi

echo "Running Option B: direct simulator screenshot"
fallback_path="$OUT_DIR/launch.png"
xcrun simctl io booted screenshot "$fallback_path"

echo "Exported screenshot artifacts to:"
echo "$fallback_path"
