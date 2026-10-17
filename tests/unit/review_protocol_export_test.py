"""Contract tests for the build-time universal review snapshot (stdlib only)."""
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import random
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'scripts/sync-review-protocol.py'
NAMES = ('developmental', 'line-editing', 'copy-editing', 'proofreading', 'fact-check', 'free-form')


def fixture():
    members = [dict(role='round', path='round.md'), dict(role='grammar', path='review-convention.md',
        source='construct/local/fix/review-convention.md'), dict(role='adapter', name='file-edit', path='adapters/file-edit.md')]
    members += [dict(role='mode', name=name, path=f'modes/{name}.md', order=i + 1,
        scope='whole-doc', deletions='propose-strike', frontier='off') for i, name in enumerate(NAMES)]
    content = {m['path']: ('# ' + m['path'] + '\n').encode() for m in members}
    for m in members:
        if m['role'] == 'mode':
            content[m['path']] = ('---\n' + ''.join(f'{key}: {m[key]}\n' for key in
                ('name', 'order', 'scope', 'deletions', 'frontier')) + '---\n# ' + m['path'] + '\n').encode()
    for m in members:
        m.update(bytes=len(content[m['path']]), sha256=hashlib.sha256(content[m['path']]).hexdigest())
    return dict(schema='ariadne/universal-review-export', version=1, members=members), content


class ExportTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.api = None
        if SCRIPT.exists():
            spec = importlib.util.spec_from_file_location('review_export', SCRIPT)
            cls.api = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(cls.api)

    def setUp(self):
        self.assertIsNotNone(self.api, 'build-time review export generator must exist')
        self.manifest, self.content = fixture()

    def add_collaboration_modes(self):
        path, data = 'collaboration-modes.md', b'# Collaboration modes\nCanonical routing.\n'
        self.manifest['members'].append(dict(role='collaboration-modes', path=path,
            bytes=len(data), sha256=hashlib.sha256(data).hexdigest()))
        self.content[path] = data
        return path

    def add_move_fixtures(self):
        self.manifest['version'] = 2
        for suffix in ('case.md', 'before/nested/old.md', 'after/nested/new.md'):
            path = 'examples/move-test/' + suffix
            data = ('FIXTURE ONLY: ' + suffix + '\n').encode()
            self.manifest['members'].append(dict(role='fixture', name='move-test', path=path,
                bytes=len(data), sha256=hashlib.sha256(data).hexdigest()))
            self.content[path] = data

    def test_v2_fixture_snapshot_and_provenance_exclude_fixture_prose_from_prompt(self):
        self.add_move_fixtures()
        snapshot = self.api.render_snapshot(self.manifest, self.content)
        self.assertIn(b'version 2;', snapshot['SKILL.md'])
        for member in self.manifest['members']:
            if member['role'] == 'fixture':
                self.assertEqual(self.content[member['path']], snapshot[member['path']])
                self.assertNotIn(self.content[member['path']].strip(), snapshot['SKILL.md'])
        self.assertEqual(set('modes/' + name + '.md' for name in NAMES),
                         {path for path in snapshot if path.startswith('modes/')})

    def test_fixture_version_names_and_exact_path_shapes(self):
        self.add_move_fixtures()
        self.api.validate_manifest(self.manifest)
        mutations = [{'version': 1}, {'name': 'Other'}, {'name': '../bad'}, {'name': 'wrong'},
            {'path': 'examples/move-test/other.md'}, {'path': 'examples/move-test/before'},
            {'path': 'examples/move-test/after/'}, {'path': 'examples/move-test/case.md/extra'},
            {'path': 'examples/move-test/before/../escape'}, {'path': 'examples/move-test//case.md'},
            {'path': 'examples/move-test/before/./x'}, {'name': True},
            *({'path': 'examples/move-test/before/a' + chr(code) + '.md'}
              for code in (1, 9, 10, 13, 31, 127))]
        for changes in mutations:
            mutant = copy.deepcopy(self.manifest)
            if 'version' in changes:
                mutant.update(changes)
            else:
                mutant['members'][-1].update(changes)
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                self.api.validate_manifest(mutant)
        mutant = copy.deepcopy(self.manifest)
        mutant['members'].append(copy.deepcopy(mutant['members'][-1]))
        with self.assertRaises(ValueError):
            self.api.validate_manifest(mutant)

    def test_fixture_corruption_refuses_before_any_output(self):
        self.add_move_fixtures()
        with tempfile.TemporaryDirectory(prefix='review-export-', dir='/tmp') as tmp:
            base = Path(tmp).resolve()
            source = self.make_source(base)
            output = base / 'bundle'
            for member in self.manifest['members']:
                if member['role'] != 'fixture':
                    continue
                path = source / member['path']
                original = path.read_bytes()
                for data in (original[:-1], bytes([original[0] ^ 1]) + original[1:]):
                    path.write_bytes(data)
                    result = self.cli(source, output)
                    self.assertNotEqual(0, result.returncode)
                    self.assertIn('mismatch: ' + member['path'], result.stderr)
                    self.assertFalse(output.exists())
                path.write_bytes(original)

    def test_recursive_fixture_output_preflight_and_stale_refusal(self):
        self.add_move_fixtures()
        with tempfile.TemporaryDirectory(prefix='review-export-', dir='/tmp') as tmp:
            base = Path(tmp).resolve()
            source = self.make_source(base)
            output = base / 'bundle'
            result = self.cli(source, output)
            self.assertEqual(0, result.returncode, result.stderr)
            self.assertEqual(0, self.cli(source, output, True).returncode)
            stale = output / 'examples/move-test/before/nested/stale.md'
            stale.write_text('stale')
            before = self.tree(output)
            for check in (True, False):
                result = self.cli(source, output, check)
                self.assertNotEqual(0, result.returncode)
                self.assertIn('extra: examples/move-test/before/nested/stale.md', result.stderr)
                self.assertEqual(before, self.tree(output))
            stale.unlink()
            (output / 'round.md').write_text('would change')
            victim = base / 'victim'
            victim.mkdir()
            for unsafe in ('examples/linked', 'examples/move-test/before/nested/linked', 'modes/linked'):
                path = output / unsafe
                path.symlink_to(victim, target_is_directory=True)
                result = self.cli(source, output)
                self.assertIn('unsafe output symlink', result.stderr)
                self.assertEqual('would change', (output / 'round.md').read_text())
                path.unlink()
            fifo = output / 'examples/move-test/before/pipe'
            os.mkfifo(fifo)
            result = self.cli(source, output)
            self.assertNotEqual(0, result.returncode)
            self.assertIn('special file', result.stderr)
            self.assertEqual('would change', (output / 'round.md').read_text())

    def test_every_expected_output_leaf_refuses_a_directory_before_mutation(self):
        self.add_collaboration_modes()
        self.add_move_fixtures()
        expected = self.api.render_snapshot(self.manifest, self.content)
        with tempfile.TemporaryDirectory(prefix='review-export-', dir='/tmp') as tmp:
            base = Path(tmp).resolve()
            source = self.make_source(base)
            for index, name in enumerate(sorted(expected)):
                with self.subTest(path=name):
                    output = base / ('bundle-' + str(index))
                    blocked = output / name
                    blocked.mkdir(parents=True)
                    sentinel = 'round.md' if name == 'SKILL.md' else 'SKILL.md'
                    (output / sentinel).write_bytes(b'stale generated bytes must survive')
                    (output / 'local-adapter.md').write_bytes(b'local bytes must survive')
                    before = self.tree(output)
                    directories = sorted(str(p.relative_to(output)) for p in output.rglob('*') if p.is_dir())
                    for check in (False, True):
                        result = self.cli(source, output, check)
                        self.assertNotEqual(0, result.returncode)
                        self.assertEqual(before, self.tree(output))
                        self.assertEqual(directories,
                            sorted(str(p.relative_to(output)) for p in output.rglob('*') if p.is_dir()))
                        self.assertIn('expected output file', result.stderr)
                        self.assertIn(name, result.stderr)

    def test_every_expected_output_ancestor_refuses_a_file_before_mutation(self):
        self.add_collaboration_modes()
        self.add_move_fixtures()
        expected = self.api.render_snapshot(self.manifest, self.content)
        ancestors = sorted({str(parent) for name in expected for parent in Path(name).parents
                            if str(parent) != '.'})
        with tempfile.TemporaryDirectory(prefix='review-export-', dir='/tmp') as tmp:
            base = Path(tmp).resolve()
            source = self.make_source(base)
            for index, name in enumerate(ancestors):
                with self.subTest(path=name):
                    output = base / ('bundle-' + str(index))
                    blocked = output / name
                    blocked.parent.mkdir(parents=True)
                    blocked.write_bytes(b'file occupying a required directory')
                    (output / 'SKILL.md').write_bytes(b'stale generated bytes must survive')
                    before = self.tree(output)
                    for check in (False, True):
                        result = self.cli(source, output, check)
                        self.assertNotEqual(0, result.returncode)
                        self.assertEqual(before, self.tree(output))
                        self.assertIn('output ancestor must be a directory', result.stderr)
                        self.assertIn(name, result.stderr)

    def test_output_ancestor_symlink_refuses_missing_and_existing_destinations(self):
        with tempfile.TemporaryDirectory(prefix='review-export-', dir='/tmp') as tmp:
            base = Path(tmp).resolve()
            source = self.make_source(base)
            real = base / 'real'
            real.mkdir()
            alias = base / 'alias'
            alias.symlink_to(real, target_is_directory=True)
            for check in (False, True):
                result = self.cli(source, alias / 'new/bundle', check)
                self.assertNotEqual(0, result.returncode)
                self.assertIn('unsafe output symlink', result.stderr)
                self.assertEqual([], list(real.iterdir()))
            (real / 'bundle').mkdir()
            result = self.cli(source, alias / 'bundle')
            self.assertNotEqual(0, result.returncode)
            self.assertIn('unsafe output symlink', result.stderr)
            self.assertEqual([], list((real / 'bundle').iterdir()))

    def test_collaboration_modes_snapshot_follows_grammar_regardless_of_manifest_order(self):
        path = self.add_collaboration_modes()
        self.manifest['members'].reverse()
        snapshot = self.api.render_snapshot(self.manifest, self.content)
        self.assertEqual(self.content[path], snapshot[path])
        skill = snapshot['SKILL.md']
        positions = [skill.index(self.content[p].strip()) for p in ('round.md', 'review-convention.md', path)]
        self.assertEqual(sorted(positions), positions)
        self.assertEqual(1, skill.count(self.content[path].strip()))

    def test_collaboration_modes_refuses_duplicate_wrong_path_and_unknown_role(self):
        self.add_collaboration_modes()
        for replacement in ({}, {'path': 'other.md'}, {'role': 'future-role'}):
            mutant = copy.deepcopy(self.manifest)
            if replacement:
                mutant['members'][-1].update(replacement)
            else:
                mutant['members'].append(copy.deepcopy(mutant['members'][-1]))
            with self.subTest(replacement=replacement), self.assertRaises(ValueError):
                self.api.validate_manifest(mutant)

    def test_collaboration_modes_cli_sync_and_check_track_owned_output(self):
        path = self.add_collaboration_modes()
        with tempfile.TemporaryDirectory(prefix='review-export-', dir='/tmp') as tmp:
            base = Path(tmp).resolve()
            source = self.make_source(base)
            (source / 'examples').mkdir()
            (source / 'examples/private.md').write_text('not exported')
            output = base / 'bundle'
            result = self.cli(source, output)
            self.assertEqual(0, result.returncode, result.stderr)
            self.assertEqual(self.content[path], (output / path).read_bytes())
            self.assertFalse((output / 'examples').exists())
            self.assertEqual(0, self.cli(source, output, True).returncode)
            (output / 'local-adapter.md').write_text('local adapter')
            (output / path).write_text('changed')
            before = self.tree(output)
            result = self.cli(source, output, True)
            self.assertNotEqual(0, result.returncode)
            self.assertIn('changed: ' + path, result.stderr)
            self.assertEqual(before, self.tree(output))
            self.assertEqual(0, self.cli(source, output).returncode)
            self.assertEqual(self.content[path], (output / path).read_bytes())
            self.assertEqual('local adapter', (output / 'local-adapter.md').read_text())
            # Older v1 source cannot silently leave a stale owned member behind.
            self.manifest['members'].pop()
            (source / 'export.json').write_text(json.dumps(self.manifest))
            before = self.tree(output)
            result = self.cli(source, output)
            self.assertNotEqual(0, result.returncode)
            self.assertIn('extra: ' + path, result.stderr)
            self.assertEqual(before, self.tree(output))

    def test_collaboration_modes_corruption_and_output_symlinks_refuse_before_writes(self):
        path = self.add_collaboration_modes()
        with tempfile.TemporaryDirectory(prefix='review-export-', dir='/tmp') as tmp:
            base = Path(tmp).resolve()
            source = self.make_source(base)
            output = base / 'bundle'
            for data in (b'truncated', bytes([self.content[path][0] ^ 1]) + self.content[path][1:]):
                (source / path).write_bytes(data)
                result = self.cli(source, output)
                self.assertNotEqual(0, result.returncode)
                self.assertIn('mismatch: ' + path, result.stderr)
                self.assertFalse(output.exists())
            (source / path).write_bytes(self.content[path])
            output.mkdir()
            victim = base / 'victim'
            victim.write_text('untouched')
            (output / path).symlink_to(victim)
            for check in (True, False):
                result = self.cli(source, output, check)
                self.assertNotEqual(0, result.returncode)
                self.assertIn('unsafe output symlink', result.stderr)
                self.assertEqual('untouched', victim.read_text())
                self.assertFalse((output / 'round.md').exists())

    def test_manifest_rejects_seeded_type_and_contract_mutations(self):
        self.api.validate_manifest(self.manifest)
        mutations = []
        for key, bad in [('schema', 'other'), ('version', True), ('version', 3), ('members', {})]:
            mutant = copy.deepcopy(self.manifest)
            mutant[key] = bad
            mutations.append(mutant)
        for index in range(9):
            for key, bad in [('path', '../escape.md'), ('bytes', True), ('bytes', -1), ('sha256', 'x' * 64), ('role', 'other')]:
                mutant = copy.deepcopy(self.manifest)
                mutant['members'][index][key] = bad
                mutations.append(mutant)
        for path in ('/tmp/escape', './round.md', 'modes//x.md', 'modes/../round.md', 'modes\\x.md', '', 'round.md\x00'):
            mutant = copy.deepcopy(self.manifest)
            mutant['members'][0]['path'] = path
            mutations.append(mutant)
        for key, bad in [('name', 1), ('order', True), ('order', 0), ('scope', 'all'), ('deletions', 'delete'), ('frontier', True)]:
            mutant = copy.deepcopy(self.manifest)
            mutant['members'][3][key] = bad
            mutations.append(mutant)
        for member in (dict(role='grammar', source='elsewhere'), dict(role='adapter', name='../unsafe')):
            mutant = copy.deepcopy(self.manifest)
            mutant['members'][1 if member['role'] == 'grammar' else 2].update(member)
            mutations.append(mutant)
        for index in (0, 1):
            mutant = copy.deepcopy(self.manifest)
            mutant['members'].pop(index)
            mutations.append(mutant)
        mutant = copy.deepcopy(self.manifest)
        mutant['members'][4] = copy.deepcopy(mutant['members'][3])
        mutations.append(mutant)
        random.Random(319).shuffle(mutations)
        for mutant in mutations:
            with self.subTest(manifest=mutant), self.assertRaises(ValueError):
                self.api.validate_manifest(mutant)
        self.assertEqual(fixture()[0], self.manifest)

    def test_new_well_formed_modes_and_adapters_are_authoritative(self):
        mode = dict(self.manifest['members'][3], name='new-mode', path='modes/new-mode.md', order=7)
        data = b'---\nname: new-mode\norder: 7\nscope: whole-doc\ndeletions: propose-strike\nfrontier: off\n---\nnew body\n'
        mode.update(bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
        adapter = dict(role='adapter', name='other', path='adapters/other.md', bytes=0,
                       sha256=hashlib.sha256(b'').hexdigest())
        self.manifest['members'] += [mode, adapter]
        self.content['modes/new-mode.md'] = data
        self.content['adapters/other.md'] = b''
        snapshot = self.api.render_snapshot(self.manifest, self.content)
        self.assertEqual(data, snapshot['modes/new-mode.md'])
        self.assertNotIn('adapters/other.md', snapshot)

    def test_optional_order_defaults_and_tied_orders_match_producer(self):
        self.manifest['members'][4]['order'] = self.manifest['members'][3]['order']
        self.manifest['members'][5].pop('order')
        self.manifest['members'][5].update(scope='markers-only', deletions='propose-strike', frontier='on')
        path = self.manifest['members'][5]['path']
        data = b'---\nname: copy-editing\n---\nBrief with default flags.\n'
        self.content[path] = data
        self.manifest['members'][5].update(bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
        self.assertEqual(data, self.api.render_snapshot(self.manifest, self.content)[path])

    def test_render_validates_all_resolved_contents_before_rendering(self):
        for path in random.Random(319).sample(list(self.content), 9):
            bad = dict(self.content)
            data = bytearray(bad[path])
            data[random.Random(path).randrange(len(data))] ^= 1
            bad[path] = bytes(data)
            with self.subTest(path=path), self.assertRaises(ValueError):
                self.api.render_snapshot(self.manifest, bad)
        with self.assertRaises(ValueError):
            self.api.render_snapshot(self.manifest, {})
        bad = copy.deepcopy(self.manifest)
        bad['members'][0]['sha256'] = '0' * 64
        with self.assertRaises(ValueError):
            self.api.render_snapshot(bad, self.content)

    def test_snapshot_is_deterministic_and_excludes_adapter(self):
        snapshot = self.api.render_snapshot(self.manifest, self.content)
        self.assertEqual(snapshot, self.api.render_snapshot(copy.deepcopy(self.manifest), dict(reversed(list(self.content.items())))))
        self.assertEqual(10, len(snapshot))
        self.assertNotIn('adapters/file-edit.md', snapshot)
        self.assertEqual(self.manifest, json.loads(snapshot['export.json']))
        skill = snapshot['SKILL.md'].decode()
        self.assertIn('Generated', skill)
        self.assertIn('sha256', skill)
        self.assertIn(self.content['round.md'].decode().strip(), skill)
        self.assertIn(self.content['review-convention.md'].decode().strip(), skill)
        self.assertNotIn(self.content['adapters/file-edit.md'].decode().strip(), skill)
        self.assertLess(skill.index('# round.md'), skill.index('# review-convention.md'))

    def test_snapshot_diff_classifies_missing_changed_and_extra(self):
        expected = self.api.render_snapshot(self.manifest, self.content)
        actual = dict(expected)
        actual.pop('round.md')
        actual['SKILL.md'] += b'x'
        actual['modes/stale.md'] = b'stale'
        self.assertEqual({'missing': ['round.md'], 'changed': ['SKILL.md'], 'extra': ['modes/stale.md']},
            self.api.compare_snapshot(expected, actual))

    def test_seeded_snapshot_diff_reports_every_mutation(self):
        expected = self.api.render_snapshot(self.manifest, self.content)
        rng = random.Random(319)
        for _ in range(30):
            paths = rng.sample(sorted(expected), 4)
            actual = dict(expected)
            for path in paths[:2]:
                actual.pop(path)
            for path in paths[2:]:
                actual[path] += b'changed'
            extra = f'modes/stale-{rng.randrange(1000)}.md'
            actual[extra] = b'extra'
            self.assertEqual({'missing': sorted(paths[:2]), 'changed': sorted(paths[2:]), 'extra': [extra]},
                             self.api.compare_snapshot(expected, actual))

    def make_source(self, base):
        source = base / 'source/construct/local/universal-review'
        source.mkdir(parents=True)
        for path, data in self.content.items():
            destination = source / path
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(data)
        grammar = source.parent / 'fix/review-convention.md'
        grammar.parent.mkdir()
        grammar.write_bytes(self.content['review-convention.md'])
        (source / 'review-convention.md').unlink()
        (source / 'review-convention.md').symlink_to('../fix/review-convention.md')
        (source / 'export.json').write_text(json.dumps(self.manifest, indent=2) + '\n')
        return source

    def cli(self, source, output, check=False):
        return subprocess.run([sys.executable, str(SCRIPT), '--source', str(source), '--output', str(output)]
            + (['--check'] if check else []), capture_output=True, text=True)

    def tree(self, root):
        return {str(p.relative_to(root)): (p.read_bytes(), p.stat().st_mtime_ns)
                for p in root.rglob('*') if p.is_file()}

    def test_real_cli_check_never_writes_and_sync_preserves_local_files(self):
        with tempfile.TemporaryDirectory(prefix='review-export-', dir='/tmp') as tmp:
            base = Path(tmp).resolve()
            source = self.make_source(base)
            output = base / 'bundle'
            self.assertNotEqual(0, self.cli(source, output, True).returncode)
            self.assertFalse(output.exists())
            self.assertEqual(0, self.cli(source, output).returncode)
            (output / 'local-adapter.md').write_text('local')
            (output / 'instruction.lua').write_text('local')
            before = self.tree(output)
            self.assertEqual(0, self.cli(source, output, True).returncode)
            self.assertEqual(before, self.tree(output))
            (output / 'modes/stale.md').write_text('old')
            before = self.tree(output)
            for check in (True, False):
                result = self.cli(source, output, check)
                self.assertNotEqual(0, result.returncode)
                self.assertIn('stale.md', result.stderr)
                self.assertEqual(before, self.tree(output))
            (output / 'modes/stale.md').unlink()
            (output / 'round.md').write_text('changed')
            before = self.tree(output)
            self.assertNotEqual(0, self.cli(source, output, True).returncode)
            self.assertEqual(before, self.tree(output))
            self.assertEqual(0, self.cli(source, output).returncode)
            self.assertEqual('local', (output / 'local-adapter.md').read_text())

    def test_old_v1_cli_reports_absent_collaboration_modes(self):
        with tempfile.TemporaryDirectory(prefix='review-export-', dir='/tmp') as tmp:
            base = Path(tmp).resolve()
            source = self.make_source(base)
            output = base / 'bundle'
            for check in (False, True):
                result = self.cli(source, output, check)
                self.assertEqual(0, result.returncode, result.stderr)
                self.assertIn('export has no move fixtures', result.stderr)
                self.assertIn('export has no collaboration-modes member; '
                              'the synced prompt has no collaboration modes', result.stderr)

    def test_cli_refuses_corrupt_source_and_unsafe_output_without_writes(self):
        with tempfile.TemporaryDirectory(prefix='review-export-', dir='/tmp') as tmp:
            base = Path(tmp).resolve()
            source = self.make_source(base)
            output = base / 'bundle'
            (source / 'adapters/file-edit.md').write_text('corrupt excluded adapter')
            self.assertNotEqual(0, self.cli(source, output).returncode)
            self.assertFalse(output.exists())
            (source / 'adapters/file-edit.md').write_bytes(self.content['adapters/file-edit.md'])
            output.mkdir()
            victim = base / 'victim'
            victim.write_text('untouched')
            (output / 'round.md').symlink_to(victim)
            self.assertNotEqual(0, self.cli(source, output).returncode)
            self.assertEqual('untouched', victim.read_text())
            (output / 'round.md').unlink()
            (output / 'modes').symlink_to(base, target_is_directory=True)
            self.assertNotEqual(0, self.cli(source, output).returncode)
            self.assertFalse((output / 'SKILL.md').exists())

    def test_cli_requires_canonical_resolved_grammar_and_preserves_existing_output(self):
        with tempfile.TemporaryDirectory(prefix='review-export-', dir='/tmp') as tmp:
            base = Path(tmp).resolve()
            source = self.make_source(base)
            output = base / 'bundle'
            self.assertEqual(0, self.cli(source, output).returncode)
            before = self.tree(output)
            grammar = source / 'review-convention.md'
            grammar.unlink()
            grammar.write_bytes(self.content['review-convention.md'])
            for check in (False, True):
                result = self.cli(source, output, check)
                self.assertNotEqual(0, result.returncode)
                self.assertIn('grammar must resolve', result.stderr)
                self.assertEqual(before, self.tree(output))
            grammar.unlink()
            grammar.symlink_to('../fix/review-convention.md')
            (source / 'round.md').write_bytes(b'corrupt')
            self.assertNotEqual(0, self.cli(source, output).returncode)
            self.assertEqual(before, self.tree(output))

    def test_packaged_snapshot_needs_no_source_checkout(self):
        output = ROOT / 'lua/parley/skills/review'
        manifest = json.loads((output / 'export.json').read_bytes())
        self.api.validate_manifest(manifest)
        self.assertEqual(['collaboration-modes.md'],
                         [m['path'] for m in manifest['members'] if m['role'] == 'collaboration-modes'])
        self.assertEqual(2, manifest['version'])
        cases = {m['name'] for m in manifest['members'] if m['role'] == 'fixture'}
        self.assertEqual({'move-rename', 'move-orphan'}, cases)
        for case in cases:
            paths = {m['path'] for m in manifest['members'] if m['role'] == 'fixture' and m['name'] == case}
            self.assertIn(f'examples/{case}/case.md', paths)
            for stage in ('before', 'after'):
                self.assertTrue(any(p.startswith(f'examples/{case}/{stage}/') for p in paths))
        for member in manifest['members']:
            if member['role'] != 'adapter':
                data = (output / member['path']).read_bytes()
                self.assertEqual(member['bytes'], len(data))
                self.assertEqual(member['sha256'], hashlib.sha256(data).hexdigest())
        skill = (output / 'SKILL.md').read_text()
        self.assertIn((output / 'round.md').read_text().strip(), skill)
        self.assertIn((output / 'review-convention.md').read_text().strip(), skill)
        collaboration = (output / 'collaboration-modes.md').read_text().strip()
        self.assertEqual(1, skill.count(collaboration))
        self.assertLess(skill.index((output / 'review-convention.md').read_text().strip()),
                        skill.index(collaboration))
        self.assertNotIn('adapters/file-edit.md\n', skill)


if __name__ == '__main__':
    unittest.main()
