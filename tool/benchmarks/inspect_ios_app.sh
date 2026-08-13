#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
app_input="${1:-$repo_root/build/ios/iphoneos/Runner.app}"
report_input="${2:-$repo_root/.spike/results/ios-app-inspection.json}"

if [[ ! -d "$app_input" ]]; then
  echo "iOS app bundle not found: $app_input" >&2
  exit 1
fi

app_path="$(cd "$(dirname "$app_input")" && pwd -P)/$(basename "$app_input")"
case "$report_input" in
  /*) report_path="$report_input" ;;
  *) report_path="$repo_root/$report_input" ;;
esac
mkdir -p "$(dirname "$report_path")"

python3 - "$app_path" "$report_path" <<'PY'
import datetime
import json
import os
import plistlib
import re
import subprocess
import sys
from pathlib import Path

app_path = Path(sys.argv[1])
report_path = Path(sys.argv[2])
info_path = app_path / "Info.plist"

if not info_path.is_file():
    raise SystemExit(f"Info.plist not found: {info_path}")

with info_path.open("rb") as stream:
    info = plistlib.load(stream)

files = sorted(
    path.relative_to(app_path).as_posix()
    for path in app_path.rglob("*")
    if path.is_file()
)

required_assets = [
    "assets/models/manifest.json",
    "assets/models/silero-vad-manifest.json",
    "assets/models/speaker-diarization-manifest.json",
    "assets/licenses/sense-voice-NOTICE.txt",
    "assets/licenses/sense-voice-LICENSE.txt",
    "assets/licenses/silero-vad-NOTICE.txt",
    "assets/licenses/silero-vad-LICENSE.txt",
    "assets/licenses/pyannote-segmentation-NOTICE.txt",
    "assets/licenses/pyannote-segmentation-LICENSE.txt",
    "assets/licenses/3d-speaker-NOTICE.txt",
    "assets/licenses/3d-speaker-LICENSE.txt",
]


def contains_flutter_asset(relative_path: str) -> bool:
    suffix = f"flutter_assets/{relative_path}"
    return any(path.endswith(suffix) for path in files)


missing_assets = [path for path in required_assets if not contains_flutter_asset(path)]
has_flutter_notices = any(path.endswith("flutter_assets/NOTICES.Z") for path in files)

weight_pattern = re.compile(
    r"(?i)(\.onnx$|\.tflite$|\.tar\.bz2$|/tokens\.txt$|/model\.int8(?:\.bin)?$|"
    r"paraformer|qwen3-asr|sense-voice-.*/model|silero_vad.*\.onnx)"
)
user_data_pattern = re.compile(
    r"(?i)\.(wav|pcm|m4a|aac|mp3|ogg|flac|sqlite|sqlite3|db)$"
)
secret_pattern = re.compile(
    r"(?i)(?:^|/)(?:\.env(?:\..*)?|[^/]+\.(?:p12|pfx|pem|key|mobileprovision))$"
)

forbidden_weights = [path for path in files if weight_pattern.search(path)]
forbidden_user_data = [path for path in files if user_data_pattern.search(path)]
forbidden_secrets = [path for path in files if secret_pattern.search(path)]

bundle_id = str(info.get("CFBundleIdentifier", ""))
minimum_os_version = str(info.get("MinimumOSVersion", ""))
microphone_usage = str(info.get("NSMicrophoneUsageDescription", "")).strip()
background_modes = info.get("UIBackgroundModes", [])
if not isinstance(background_modes, list):
    background_modes = []

executable_name = str(info.get("CFBundleExecutable", "Runner"))
executable_path = app_path / executable_name
architectures: list[str] = []
lipo_error = ""
if executable_path.is_file():
    try:
        lipo_output = subprocess.check_output(
            ["lipo", "-archs", str(executable_path)],
            text=True,
            stderr=subprocess.STDOUT,
        ).strip()
        architectures = sorted(set(lipo_output.split()))
    except (OSError, subprocess.CalledProcessError) as error:
        lipo_error = str(error)
else:
    lipo_error = f"Executable not found: {executable_path}"


def normalized_version(value: str) -> tuple[int, ...] | None:
    if not re.fullmatch(r"\d+(?:\.\d+)*", value):
        return None
    parts = tuple(int(part) for part in value.split("."))
    return parts + (0,) * max(0, 2 - len(parts))


normalized_minimum_version = normalized_version(minimum_os_version)
minimum_version_matches = (
    normalized_minimum_version is not None
    and normalized_minimum_version[:2] == (15, 0)
    and all(part == 0 for part in normalized_minimum_version[2:])
)
frameworks = [
    path
    for path in files
    if path.startswith("Frameworks/")
    and (".framework/" in path or path.endswith(".dylib"))
]
privacy_manifests = [path for path in files if path.endswith("PrivacyInfo.xcprivacy")]
top_files = sorted(
    (
        {"path": path, "bytes": (app_path / path).stat().st_size}
        for path in files
    ),
    key=lambda item: item["bytes"],
    reverse=True,
)[:20]

checks = {
    "bundleId": bundle_id == "com.meettrace.app",
    "minimumIosVersion": minimum_version_matches,
    "microphoneUsageDescription": bool(microphone_usage),
    "backgroundAudio": "audio" in background_modes,
    "arm64Executable": "arm64" in architectures,
    "appFramework": any(path.startswith("Frameworks/App.framework/") for path in files),
    "flutterFramework": any(
        path.startswith("Frameworks/Flutter.framework/") for path in files
    ),
    "flutterNotices": has_flutter_notices,
    "privacyManifests": bool(privacy_manifests),
    "requiredAssets": not missing_assets,
    "noModelWeights": not forbidden_weights,
    "noUserData": not forbidden_user_data,
    "noSigningSecrets": not forbidden_secrets,
    "noProvisioningProfile": not (app_path / "embedded.mobileprovision").exists(),
}
failures = [name for name, passed in checks.items() if not passed]

report = {
    "capturedAtUtc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "appPath": str(app_path),
    "appBytes": sum((app_path / path).stat().st_size for path in files),
    "fileCount": len(files),
    "bundleId": bundle_id,
    "minimumIosVersion": minimum_os_version,
    "microphoneUsageDescription": microphone_usage,
    "backgroundModes": background_modes,
    "architectures": architectures,
    "lipoError": lipo_error,
    "hasFlutterNotices": has_flutter_notices,
    "requiredAssets": required_assets,
    "missingAssets": missing_assets,
    "forbiddenWeights": forbidden_weights,
    "forbiddenUserData": forbidden_user_data,
    "forbiddenSecrets": forbidden_secrets,
    "privacyManifests": privacy_manifests,
    "nativeFrameworkFiles": frameworks,
    "topFiles": top_files,
    "checks": checks,
    "failures": failures,
    "passed": not failures,
}
report_path.write_text(
    json.dumps(report, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)

print(f"iOS app inspection report: {report_path}")
print(f"Bundle ID: {bundle_id}")
print(f"Architectures: {', '.join(architectures) or 'unknown'}")
print(f"App size: {report['appBytes']} bytes across {len(files)} files")

if failures:
    print(f"Inspection failed: {', '.join(failures)}", file=sys.stderr)
    raise SystemExit(1)

print("Inspection passed")
PY
