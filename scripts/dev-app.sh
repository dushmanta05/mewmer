#!/usr/bin/env bash
set -euo pipefail

DEVICE_ID=$(flutter devices --machine | python3 -c '
import json, sys
devices = json.load(sys.stdin)
android = [d for d in devices if str(d.get("targetPlatform", "")).startswith("android")]
if not android:
    sys.exit(0)
physical = [d for d in android if not d.get("emulator", False)]
chosen = physical[0] if physical else android[0]
print(chosen["id"])
')

if [ -z "$DEVICE_ID" ]; then
  echo "No Android device found. Connected devices:"
  flutter devices
  exit 1
fi

adb -s "$DEVICE_ID" reverse tcp:3030 tcp:3030 >/dev/null 2>&1 || true

cd app
exec flutter run -d "$DEVICE_ID" "$@"
