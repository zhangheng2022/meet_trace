"""Classify repository changes for the Flutter CI workflow."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def classify(paths: list[str], *, force_all: bool = False) -> dict[str, bool]:
    result = {"core": False, "android": False, "ios": False}
    if force_all:
        return {key: True for key in result}

    for raw_path in paths:
        path = raw_path.replace("\\", "/").removeprefix("./")
        if not path:
            continue

        if path.startswith((".github/workflows/", ".github/dependabot")):
            return {key: True for key in result}

        if path.startswith(("lib/", "assets/", "tool/")) or path in {
            ".fvmrc",
            "analysis_options.yaml",
            "pubspec.yaml",
            "pubspec.lock",
        }:
            result.update(core=True, android=True, ios=True)
            continue

        if path.startswith("android/"):
            result.update(core=True, android=True)
            continue

        if path.startswith("ios/") or path in {"Gemfile", "Gemfile.lock"}:
            result.update(core=True, ios=True)
            continue

        if path.startswith(("test/", "patrol_test/")):
            result["core"] = True
            continue

        if path.startswith(("docs/", "graphify-out/", ".agents/", ".claude/")):
            continue
        if path.endswith((".md", ".txt")) or path in {"LICENSE", "DESIGN.md"}:
            continue

        # Unknown files are treated conservatively so a new source directory
        # cannot silently bypass platform validation.
        return {key: True for key in result}

    return result


def _paths_from_file(path: Path) -> list[str]:
    return [part.decode("utf-8") for part in path.read_bytes().split(b"\0") if part]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--all", action="store_true", dest="force_all")
    parser.add_argument("--path-file", type=Path)
    parser.add_argument("--path", action="append", default=[])
    parser.add_argument("--github-output", type=Path)
    args = parser.parse_args()

    paths = list(args.path)
    if args.path_file:
        paths.extend(_paths_from_file(args.path_file))
    result = classify(paths, force_all=args.force_all)

    if args.github_output:
        with args.github_output.open("a", encoding="utf-8") as output:
            for key, value in result.items():
                output.write(f"{key}={str(value).lower()}\n")

    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
