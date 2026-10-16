"""Contract tests for the build-time universal review snapshot (stdlib only)."""
import copy
import hashlib
import importlib.util
import json
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

    def test_manifest_rejects_seeded_type_and_contract_mutations(self):
        self.api.validate_manifest(self.manifest)
        mutations = []
        for key, bad in [('schema', 'other'), ('version', True), ('version', 2), ('members', {})]:
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
            destination.parent.mkdir(exist_ok=True)
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
            base = Path(tmp)
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

    def test_cli_refuses_corrupt_source_and_unsafe_output_without_writes(self):
        with tempfile.TemporaryDirectory(prefix='review-export-', dir='/tmp') as tmp:
            base = Path(tmp)
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
            base = Path(tmp)
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
        for member in manifest['members']:
            if member['role'] != 'adapter':
                data = (output / member['path']).read_bytes()
                self.assertEqual(member['bytes'], len(data))
                self.assertEqual(member['sha256'], hashlib.sha256(data).hexdigest())
        skill = (output / 'SKILL.md').read_text()
        self.assertIn((output / 'round.md').read_text().strip(), skill)
        self.assertIn((output / 'review-convention.md').read_text().strip(), skill)
        self.assertNotIn('adapters/file-edit.md\n', skill)


if __name__ == '__main__':
    unittest.main()
