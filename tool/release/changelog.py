"""Validate and extract one immutable MeetTrace changelog entry."""

from __future__ import annotations

import argparse
import re
import sys
from datetime import date
from pathlib import Path


RELEASE_ID = re.compile(r"^v(\d+\.\d+\.\d+-alpha\.[1-9]\d*)$")
RELEASE_HEADING = re.compile(
    r"^## \[(\d+\.\d+\.\d+-alpha\.[1-9]\d*)\] - (\d{4}-\d{2}-\d{2})$",
)
SECTION_HEADING = re.compile(r"^## .+$", re.MULTILINE)
ENTRY = re.compile(r"^- (新增|变更|修复|安全|兼容性|已知问题)：\S", re.MULTILINE)
NOTES_START = "<!-- meettrace-public-notes:start -->"
NOTES_END = "<!-- meettrace-public-notes:end -->"


def release_entries(changelog: str) -> dict[str, str]:
    text = changelog.replace("\r\n", "\n").replace("\r", "\n")
    if NOTES_START in text or NOTES_END in text:
        raise ValueError("CHANGELOG.md 包含保留的发布说明标记")
    headings = list(SECTION_HEADING.finditer(text))
    if [match.group() for match in headings].count("## [Unreleased]") != 1:
        raise ValueError("CHANGELOG.md 必须包含一个 ## [Unreleased] 区段")
    if headings[0].group() != "## [Unreleased]":
        raise ValueError("## [Unreleased] 必须是第一个二级标题")

    entries: dict[str, str] = {}
    for index, heading in enumerate(headings[1:], start=1):
        match = RELEASE_HEADING.fullmatch(heading.group())
        if match is None:
            raise ValueError(f"版本标题无效：{heading.group()}")
        version, raw_date = match.groups()
        try:
            date.fromisoformat(raw_date)
        except ValueError as error:
            raise ValueError(f"版本 {version} 的日期无效") from error
        if version in entries:
            raise ValueError(f"版本 {version} 重复")
        end = headings[index + 1].start() if index + 1 < len(headings) else len(text)
        body = text[heading.end() : end].strip()
        if not ENTRY.search(body):
            raise ValueError(f"版本 {version} 没有有效的用户可见条目")
        entries[version] = body
    return entries


def entry_for_release(changelog: str, release_id: str) -> str:
    match = RELEASE_ID.fullmatch(release_id)
    if match is None:
        raise ValueError("release ID 必须形如 v1.0.0-alpha.13")
    version = match.group(1)
    try:
        return release_entries(changelog)[version]
    except KeyError as error:
        raise ValueError(f"CHANGELOG.md 缺少版本 {version}") from error


def public_notes_from_draft(draft: str, changelog_entry: str) -> str:
    draft = draft.replace("\r\n", "\n").replace("\r", "\n")
    if draft.count(NOTES_START) != 1 or draft.count(NOTES_END) != 1:
        raise ValueError("Draft release notes markers are missing or duplicated")
    start = draft.index(NOTES_START)
    end = draft.index(NOTES_END)
    if start >= end:
        raise ValueError("Draft release notes markers are out of order")
    block = draft[start + len(NOTES_START) : end].strip()
    expected = f"## 本版变化\n\n{changelog_entry}"
    if block == expected:
        return block
    supplement = f"{expected}\n\n## 补充说明\n\n"
    if not block.startswith(supplement) or not block.removeprefix(supplement).strip():
        raise ValueError("Draft release notes differ from the immutable candidate changelog")
    return block


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--changelog", type=Path, default=Path("CHANGELOG.md"))
    parser.add_argument("--release-id")
    parser.add_argument("--draft-body", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    try:
        changelog = args.changelog.read_text(encoding="utf-8")
        if args.release_id:
            output = entry_for_release(changelog, args.release_id)
            if args.draft_body:
                output = public_notes_from_draft(
                    args.draft_body.read_text(encoding="utf-8"), output
                )
            if args.output:
                args.output.write_bytes(f"{output}\n".encode())
            else:
                print(output)
        elif args.draft_body:
            raise ValueError("--draft-body 必须与 --release-id 一起使用")
        elif args.output:
            raise ValueError("--output 必须与 --release-id 一起使用")
        else:
            release_entries(changelog)
    except (OSError, ValueError) as error:
        print(f"更新日志校验失败：{error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
