#!/usr/bin/env python3
"""Check every vendored skill, source record and file digest without networking."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def digest_tree(directory):
    return {
        str(path.relative_to(directory)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted(directory.rglob('*'))
        if path.is_file()
    }


def main():
    manifest = json.loads((ROOT / 'tool/skills/sources.json').read_text())
    lock = json.loads((ROOT / 'skills-lock.json').read_text())['skills']
    records = manifest['skills']
    errors = []
    if set(lock) != set(records) - {'graphify'}:
        errors.append('skills-lock.json inventory differs from sources.json')
    for location in ('.agents/skills', '.claude/skills'):
        actual = {p.name for p in (ROOT / location).iterdir() if p.is_dir()}
        if actual != set(records):
            errors.append(f'{location}: missing or untracked skill directory')
        for name, record in records.items():
            directory = ROOT / location / name
            if directory.is_symlink() or any(p.is_symlink() for p in directory.rglob('*')):
                errors.append(f'{location}/{name}: symlinks are not permitted in vendored skills')
            if not (directory / 'SKILL.md').is_file():
                errors.append(f'{directory}: missing SKILL.md')
            if digest_tree(directory) != record['files'][location]:
                errors.append(f'{location}/{name}: content differs from source manifest')
            if name in lock and lock[name] != record['skillsLock']:
                errors.append(f'{name}: skills-lock.json source/hash drift')
    if errors:
        raise SystemExit('\n'.join(sorted(set(errors))))
    print(f'Validated {len(records)} skills in both agent directories; source locks and all file hashes match.')


if __name__ == '__main__':
    main()
