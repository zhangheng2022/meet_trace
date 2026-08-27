"""Select the only Alpha Draft that is newer than the latest public Alpha."""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ALPHA_TAG = re.compile(r"^v\d+\.\d+\.\d+-alpha\.[1-9]\d*$")


def _timestamp(value: Any) -> datetime:
    if not isinstance(value, str) or not value:
        raise ValueError("Alpha release timestamp is missing")
    timestamp = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if timestamp.tzinfo is None:
        raise ValueError("Alpha release timestamp must include a timezone")
    return timestamp


def _releases(payload: Any) -> list[dict[str, Any]]:
    if not isinstance(payload, list):
        raise ValueError("GitHub releases response must be an array")
    flattened = [release for page in payload for release in page] if payload and all(
        isinstance(page, list) for page in payload
    ) else payload
    if not all(isinstance(release, dict) for release in flattened):
        raise ValueError("GitHub releases response contains an invalid release")
    return flattened


def active_alpha_drafts(payload: Any) -> list[dict[str, Any]]:
    releases = _releases(payload)
    latest_publication = max(
        (
            _timestamp(release.get("published_at"))
            for release in releases
            if not release.get("draft")
            and ALPHA_TAG.fullmatch(str(release.get("tag_name", "")))
        ),
        default=datetime.min.replace(tzinfo=timezone.utc),
    )
    return sorted(
        (
            release
            for release in releases
            if release.get("draft") is True
            and release.get("prerelease") is True
            and ALPHA_TAG.fullmatch(str(release.get("tag_name", "")))
            and _timestamp(release.get("created_at")) > latest_publication
        ),
        key=lambda release: (
            _timestamp(release.get("created_at")),
            int(release.get("id", 0)),
        ),
    )


def selected_tag(payload: Any) -> str:
    drafts = active_alpha_drafts(payload)
    return str(drafts[-1]["tag_name"]) if drafts else ""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--releases", required=True, type=Path)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--select", action="store_true")
    mode.add_argument("--ensure-empty", action="store_true")
    mode.add_argument("--require-selected")
    args = parser.parse_args()

    try:
        payload = json.loads(args.releases.read_text(encoding="utf-8"))
        selected = selected_tag(payload)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"Unable to classify Alpha releases: {error}", file=sys.stderr)
        return 1

    if args.select:
        print(selected)
        return 0
    if args.ensure_empty:
        if selected:
            print(
                f"Alpha candidate {selected} is still active; resume it before creating another candidate.",
                file=sys.stderr,
            )
            return 1
        return 0
    if selected != args.require_selected:
        print(
            f"Alpha candidate {args.require_selected} is not the active candidate ({selected or 'none'}).",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
