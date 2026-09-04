#!/usr/bin/env bash
set -euo pipefail

apk="build/android/distribution/meettrace-${RELEASE_ID}-android-x86_64.apk"
output="build/android/distribution/emulator-output.txt"
[[ -s "$apk" ]] || { echo "Missing $apk" >&2; exit 1; }

adb install --no-streaming "$apk"
adb logcat -c
adb shell am start -W -n com.meettrace.app/.MainActivity
sleep 10
app_pid="$(adb shell pidof com.meettrace.app | tr -d '\r')"
[[ -n "$app_pid" ]]
{
  adb logcat -d --pid="$app_pid" '*:E'
  adb logcat -d '*:E' | grep -E 'ANR in com\.meettrace\.app' || true
} > "$output"
cat "$output"
if grep -Eq 'FATAL EXCEPTION|Fatal signal|ANR in com\.meettrace\.app|sherpa/ONNX 原生运行时加载失败' "$output"; then
  echo 'x86_64 emulator reported an app or native-runtime crash' >&2
  exit 1
fi
