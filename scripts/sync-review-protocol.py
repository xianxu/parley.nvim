#!/usr/bin/env python3
"""Validate and snapshot ariadne's universal-review export at build time.

Usage: sync-review-protocol.py --source DIR --output DIR [--check]
The source is construct/local/universal-review, including its canonical grammar
symlink. No source checkout or generator is needed by the packaged plugin.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import stat
import sys

SCHEMA = 'ariadne/universal-review-export'
GRAMMAR_SOURCE = 'construct/local/fix/review-convention.md'
SAFE_NAME = re.compile(r'[a-z0-9]+(?:-[a-z0-9]+)*')
FIXED_OUTPUTS = ('round.md', 'review-convention.md', 'collaboration-modes.md', 'export.json', 'SKILL.md')


def require(condition, message):
    if not condition:
        raise ValueError(message)


def validate_manifest(manifest):
    """Validate the complete versioned contract without IO or mutations."""
    require(type(manifest) is dict, 'manifest must be an object')
    require(manifest.get('schema') == SCHEMA, 'unsupported export schema')
    require(type(manifest.get('version')) is int and manifest['version'] in (1, 2, 3), 'unsupported export version')
    members = manifest.get('members')
    require(type(members) is list and bool(members), 'export members must be a nonempty list')
    allowed_roles = {'round', 'grammar', 'collaboration-modes', 'adapter', 'mode'}
    if manifest['version'] >= 2:
        allowed_roles.add('fixture')
    paths, roles, names, adapters = set(), [], set(), set()
    for member in members:
        require(type(member) is dict, 'member must be an object')
        role, path = member.get('role'), member.get('path')
        require(type(role) is str and role in allowed_roles, 'invalid member role')
        require(type(path) is str and path and '\\' not in path and not re.search(r'[\x00-\x1f\x7f]', path),
                'invalid member path')
        parsed = PurePosixPath(path)
        require(not parsed.is_absolute() and '..' not in parsed.parts and str(parsed) == path,
                'member path must be safe and normalized: ' + path)
        require(path not in paths, 'duplicate member path: ' + path)
        paths.add(path)
        roles.append(role)
        require(type(member.get('bytes')) is int and member['bytes'] >= 0, 'invalid member byte count: ' + path)
        require(type(member.get('sha256')) is str and re.fullmatch('[0-9a-f]{64}', member['sha256']),
                'invalid member sha256: ' + path)
        if role == 'round':
            require(path == 'round.md', 'round path must be round.md')
        elif role == 'grammar':
            require(path == 'review-convention.md' and member.get('source') == GRAMMAR_SOURCE,
                    'grammar must name the canonical source')
        elif role == 'collaboration-modes':
            require(path == 'collaboration-modes.md', 'collaboration-modes path must be collaboration-modes.md')
        elif role == 'fixture':
            name = member.get('name')
            require(type(name) is str and SAFE_NAME.fullmatch(name), 'invalid fixture name')
            parts = parsed.parts
            require(len(parts) >= 3 and parts[:2] == ('examples', name)
                    and ((len(parts) == 3 and parts[2] == 'case.md')
                         or (len(parts) >= 4 and parts[2] in {'before', 'after'})),
                    'fixture path must match its case and tree: ' + path)
        elif role == 'adapter':
            name = member.get('name')
            require(type(name) is str and SAFE_NAME.fullmatch(name) and name not in adapters,
                    'invalid or duplicate adapter name')
            require(path == 'adapters/' + name + '.md', 'adapter path must match its name')
            adapters.add(name)
        else:
            name, order = member.get('name'), member.get('order')
            require(type(name) is str and SAFE_NAME.fullmatch(name) and name not in names, 'invalid or duplicate mode name')
            require(path == 'modes/' + name + '.md', 'mode path must match its name')
            require('order' not in member or (type(order) is int and order > 0), 'invalid mode order')
            flags = [('scope', {'whole-doc', 'markers-only'}), ('frontier', {'on', 'off'})]
            # v3 (ariadne#437) retires the deletions flag: the document's own
            # `presentation:` is the one proposal knob. A v3 record still carrying
            # it is a half-migrated export, refused rather than half-applied.
            if manifest['version'] >= 3:
                require('deletions' not in member, 'a version 3 mode carries no deletions')
            else:
                flags.append(('deletions', {'apply-with-gutter-why', 'apply', 'propose-strike'}))
            for key, allowed in flags:
                require(type(member.get(key)) is str and member[key] in allowed, 'invalid mode ' + key)
            names.add(name)
    require(roles.count('round') == 1 and roles.count('grammar') == 1 and roles.count('adapter') >= 1
            and roles.count('mode') >= 1, 'incomplete export roles')
    require(roles.count('collaboration-modes') <= 1, 'duplicate collaboration-modes role')


def render_snapshot(manifest, member_bytes):
    """Verify every resolved member (including adapter); return generated bytes."""
    validate_manifest(manifest)
    for member in manifest['members']:
        path = member['path']
        data = member_bytes.get(path)
        require(type(data) is bytes, 'missing member bytes: ' + path)
        require(len(data) == member['bytes'], 'byte count mismatch: ' + path)
        require(hashlib.sha256(data).hexdigest() == member['sha256'], 'sha256 mismatch: ' + path)
        try:
            data.decode('utf-8')
        except UnicodeDecodeError as error:
            raise ValueError('member must be UTF-8: ' + path) from error
    snapshot = {m['path']: member_bytes[m['path']] for m in manifest['members'] if m['role'] != 'adapter'}
    exported = (json.dumps(manifest, indent=2, ensure_ascii=False) + '\n').encode('utf-8')
    snapshot['export.json'] = exported
    provenance = ('<!-- Generated by scripts/sync-review-protocol.py from ariadne\n'
                  '     ' + SCHEMA + ' version ' + str(manifest['version']) + '; export.json sha256: '
                  + hashlib.sha256(exported).hexdigest() + '\n'
                  '     Source members retain the digests in export.json. Do not edit. -->\n\n')
    prompt_paths = ['round.md', 'review-convention.md']
    if 'collaboration-modes.md' in snapshot:
        prompt_paths.append('collaboration-modes.md')
    snapshot['SKILL.md'] = (provenance.encode('utf-8')
                            + b'\n\n'.join(member_bytes[path].rstrip() for path in prompt_paths) + b'\n')
    return snapshot


def compare_snapshot(expected, actual):
    """Return deterministic path lists describing byte-level snapshot drift."""
    return {'missing': sorted(expected.keys() - actual.keys()),
            'changed': sorted(path for path in expected.keys() & actual.keys() if expected[path] != actual[path]),
            'extra': sorted(actual.keys() - expected.keys())}


def read_source(source):
    manifest = json.loads((source / 'export.json').read_bytes())
    validate_manifest(manifest)
    source = source.resolve(strict=True)
    contents = {}
    for member in manifest['members']:
        path = member['path']
        resolved = (source / path).resolve(strict=True)
        if member['role'] == 'grammar':
            canonical = (source.parent / 'fix/review-convention.md').resolve(strict=True)
            require(resolved == canonical, 'grammar must resolve to ' + GRAMMAR_SOURCE)
        else:
            require(resolved.is_relative_to(source), 'source member escapes export directory: ' + path)
        contents[path] = resolved.read_bytes()
    return render_snapshot(manifest, contents)


def read_output(output, expected):
    """Preflight owned paths only; local adapters and Lua files remain unowned."""
    # Inspect lexical ancestors before resolving: resolution would hide a symlink
    # and permit writes into a different tree, even when output does not exist.
    for ancestor in reversed((output.absolute(), *output.absolute().parents)):
        require(not ancestor.is_symlink(), 'unsafe output symlink: ' + str(ancestor))
        require(not ancestor.exists() or ancestor.is_dir(), 'output ancestor must be a directory: ' + str(ancestor))
    # A recursive scan alone cannot distinguish an empty directory from a
    # missing expected file. Validate the shape of the entire snapshot first,
    # including missing leaves whose existing parent might instead be a file.
    for name in sorted(expected):
        relative = Path(name)
        for ancestor in reversed(relative.parents):
            if ancestor == Path('.'):
                continue
            path = output / ancestor
            try:
                mode = path.lstat().st_mode
            except FileNotFoundError:
                continue
            require(not stat.S_ISLNK(mode), 'unsafe output symlink: ' + str(path))
            require(stat.S_ISDIR(mode), 'output ancestor must be a directory: ' + str(path))
        path = output / relative
        try:
            mode = path.lstat().st_mode
        except FileNotFoundError:
            continue
        require(not stat.S_ISLNK(mode), 'unsafe output symlink: ' + str(path))
        require(stat.S_ISREG(mode), 'expected output file must be a regular file: ' + str(path))
    actual = {}

    def inspect(path, directory_allowed=False):
        try:
            mode = path.lstat().st_mode
        except FileNotFoundError:
            return
        require(not stat.S_ISLNK(mode), 'unsafe output symlink: ' + str(path))
        if stat.S_ISDIR(mode) and directory_allowed:
            for child in sorted(path.iterdir()):
                inspect(child, directory_allowed=True)
        else:
            require(stat.S_ISREG(mode), 'unexpected output directory or special file: ' + str(path))
            actual[path.relative_to(output).as_posix()] = path.read_bytes()

    for name in FIXED_OUTPUTS:
        inspect(output / name)
    for name in ('modes', 'examples'):
        path = output / name
        require(not path.exists() or path.is_dir(), name + ' output must be a directory')
        inspect(path, directory_allowed=True)
    return actual


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--check', action='store_true', help='report drift without writing anything')
    args = parser.parse_args()
    try:
        expected = read_source(args.source)
        if 'collaboration-modes.md' not in expected:
            print('review protocol export: export has no collaboration-modes member; '
                  'the synced prompt has no collaboration modes', file=sys.stderr)
        manifest = json.loads(expected['export.json'])
        if not any(member['role'] == 'fixture' for member in manifest['members']):
            print('review protocol export: export has no move fixtures', file=sys.stderr)
        actual = read_output(args.output, expected)
        differences = compare_snapshot(expected, actual)
        if args.check or differences['extra']:
            for kind, paths in differences.items():
                for path in paths:
                    print(kind + ': ' + path, file=sys.stderr)
            if differences['extra'] and not args.check:
                print('Remove stale generated files explicitly before syncing.', file=sys.stderr)
            return int(any(differences.values()))
        # All source digests and all existing output paths passed preflight.
        for name, data in sorted(expected.items()):
            destination = args.output / name
            if actual.get(name) != data:
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(data)
        return 0
    except (ValueError, OSError, RuntimeError) as error:
        print('review protocol export: ' + str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
