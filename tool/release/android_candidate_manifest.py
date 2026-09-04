"""Create and verify the immutable four-APK Android candidate manifest."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import zipfile
from pathlib import Path
from typing import Any


VARIANTS = {
    "armeabi-v7a": ("armeabi-v7a",),
    "arm64-v8a": ("arm64-v8a",),
    "x86_64": ("x86_64",),
    "universal": ("armeabi-v7a", "arm64-v8a", "x86_64"),
}
SUFFIXES = {
    "armeabi-v7a": "armeabi-v7a",
    "arm64-v8a": "arm64",
    "x86_64": "x86_64",
    "universal": "universal",
}


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _abis(path: Path) -> tuple[str, ...]:
    with zipfile.ZipFile(path) as archive:
        return tuple(sorted({
            name.split("/")[1]
            for name in archive.namelist()
            if re.fullmatch(r"lib/[^/]+/.+\.so", name)
        }))


def build_manifest(
    *,
    release_id: str,
    marketing_version: str,
    build_number: int,
    commit_sha: str,
    run_id: int,
    run_attempt: int,
    repository: str,
    signing_identity_sha256: str,
    artifacts: dict[str, Path],
) -> dict[str, Any]:
    if set(artifacts) != set(VARIANTS):
        raise ValueError("Android candidate must contain exactly four variants")
    entries: dict[str, Any] = {}
    for variant, expected_abis in VARIANTS.items():
        path = artifacts[variant]
        expected_name = f"meettrace-{release_id}-android-{SUFFIXES[variant]}.apk"
        actual_abis = _abis(path)
        if path.name != expected_name or actual_abis != tuple(sorted(expected_abis)):
            raise ValueError(f"Invalid Android {variant} APK name or ABI set")
        entries[variant] = {
            "name": path.name,
            "abis": list(actual_abis),
            "bytes": path.stat().st_size,
            "sha256": _sha256(path),
            "versionCode": build_number,
        }
    return {
        "schemaVersion": 3,
        "platform": "android",
        "releaseId": release_id,
        "marketingVersion": marketing_version,
        "buildNumber": build_number,
        "commitSha": commit_sha,
        "workflowFile": ".github/workflows/alpha-release.yml",
        "job": "android",
        "runId": run_id,
        "runAttempt": run_attempt,
        "packageIdentity": "com.meettrace.app",
        "signingIdentitySha256": signing_identity_sha256.lower(),
        "artifacts": entries,
        "distribution": {
            "repository": repository,
            "visibility": "public-after-finalize",
            "releaseState": "draft",
            "publiclyInstallable": False,
        },
    }


def verify_manifest(
    manifest: dict[str, Any],
    *,
    release_id: str,
    build_number: int,
    commit_sha: str,
    artifact_directory: Path,
) -> None:
    expected = {
        "schemaVersion": 3,
        "platform": "android",
        "releaseId": release_id,
        "buildNumber": build_number,
        "commitSha": commit_sha,
        "packageIdentity": "com.meettrace.app",
    }
    if any(manifest.get(key) != value for key, value in expected.items()):
        raise ValueError("Android candidate identity mismatch")
    signing = manifest.get("signingIdentitySha256")
    if not isinstance(signing, str) or not re.fullmatch(r"[0-9a-f]{64}", signing):
        raise ValueError("Invalid Android signing identity")
    entries = manifest.get("artifacts")
    if not isinstance(entries, dict) or set(entries) != set(VARIANTS):
        raise ValueError("Android candidate artifact set is incomplete")
    for variant, expected_abis in VARIANTS.items():
        entry = entries[variant]
        if not isinstance(entry, dict):
            raise ValueError(f"Invalid Android {variant} entry")
        name = f"meettrace-{release_id}-android-{SUFFIXES[variant]}.apk"
        path = artifact_directory / name
        if not path.is_file():
            raise ValueError(f"Missing Android {variant} artifact")
        if (
            entry.get("name") != name
            or entry.get("abis") != sorted(expected_abis)
            or entry.get("versionCode") != build_number
            or entry.get("bytes") != path.stat().st_size
            or entry.get("sha256") != _sha256(path)
            or _abis(path) != tuple(sorted(expected_abis))
        ):
            raise ValueError(f"Android {variant} artifact mismatch")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--release-id", required=True)
    parser.add_argument("--build-number", required=True, type=int)
    parser.add_argument("--commit-sha", required=True)
    parser.add_argument("--artifact-directory", required=True, type=Path)
    parser.add_argument("--create", action="store_true")
    parser.add_argument("--marketing-version")
    parser.add_argument("--run-id", type=int)
    parser.add_argument("--run-attempt", type=int)
    parser.add_argument("--repository")
    parser.add_argument("--signing-identity-sha256")
    args = parser.parse_args()

    if args.create:
        required = (
            args.marketing_version,
            args.run_id,
            args.run_attempt,
            args.repository,
            args.signing_identity_sha256,
        )
        if any(value in (None, "") for value in required):
            parser.error("create requires release metadata and signing identity")
        artifacts = {
            variant: args.artifact_directory
            / f"meettrace-{args.release_id}-android-{SUFFIXES[variant]}.apk"
            for variant in VARIANTS
        }
        manifest = build_manifest(
            release_id=args.release_id,
            marketing_version=args.marketing_version,
            build_number=args.build_number,
            commit_sha=args.commit_sha,
            run_id=args.run_id,
            run_attempt=args.run_attempt,
            repository=args.repository,
            signing_identity_sha256=args.signing_identity_sha256,
            artifacts=artifacts,
        )
        args.manifest.write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    else:
        manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
        verify_manifest(
            manifest,
            release_id=args.release_id,
            build_number=args.build_number,
            commit_sha=args.commit_sha,
            artifact_directory=args.artifact_directory,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
