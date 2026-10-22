#!/usr/bin/env python3
"""#409: real make/flock/census ordering in disposable contributor checkouts."""
import os
import fcntl
import pathlib
import re
import shutil
import shlex
import signal
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
WRAPPER = ROOT / 'scripts/test-run-lease.py'


class RunLeaseTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix='parley-run-lease-')
        self.addCleanup(self.scratch.cleanup)
        self.base = pathlib.Path(self.scratch.name)
        self.processes = []
        self.addCleanup(self.stop_processes)

    def stop_processes(self):
        # These sessions were created by this case, never discovered in ps.
        for process in self.processes:
            if process.poll() is not None:
                continue
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait(timeout=5)

    def start(self, argv, name, cwd=None, env=None, pass_fds=()):
        out = self.base / (name + '.out')
        err = self.base / (name + '.err')
        with out.open('wb') as stdout, err.open('wb') as stderr:
            process = subprocess.Popen(argv, cwd=cwd, env=env, stdout=stdout,
                                       stderr=stderr, start_new_session=True,
                                       pass_fds=pass_fds)
        self.processes.append(process)
        return process, out, err

    def until(self, predicate, detail):
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            if predicate():
                return
            time.sleep(0.01)
        self.fail(detail)

    def checkout(self, name):
        root = self.base / name
        (root / 'scripts').mkdir(parents=True)
        (root / 'tests').mkdir()
        (root / 'plenary/plugin').mkdir(parents=True)
        (root / 'plenary/plugin/plenary.vim').touch()
        shutil.copyfile(ROOT / 'Makefile.parley', root / 'Makefile')
        if WRAPPER.exists():
            shutil.copyfile(WRAPPER, root / 'scripts/test-run-lease.py')
        shutil.copyfile(ROOT / 'scripts/reap-test-orphans.py', root / 'scripts/reap-test-orphans.py')
        mapping = root / 'scripts/spec_test_map.sh'
        mapping.write_text('#!/bin/sh\necho tests/unit/gated_spec.lua\n')
        mapping.chmod(0o755)
        # Real recognizable headless nvim; no plugin, watchdog or assertion race.
        (root / 'tests/minimal_init.vim').write_text('''lua << LUA
vim.fn.writefile({tostring(vim.fn.getpid())}, vim.env.GATE .. '.ready')
vim.wait(30000, function() return vim.fn.filereadable(vim.env.GATE .. '.release') == 1 end, 10)
vim.fn.writefile({}, vim.env.GATE .. '.done')
LUA
qa!
''')
        return root

    def make(self, root, name, extra=(), goals=('test-spec',)):
        gate = self.base / name
        env = dict(os.environ, GATE=str(gate))
        # A spec's ambient inherited lease must not bless a new disposable root.
        argv = ['make', '--no-print-directory', *goals, 'SPEC=infra/test_harness',
                'PLENARY=' + str(root / 'plenary'), 'TEST_NVIM_DIR=', 'TEST_RUN=env',
                'TEST_ENV_ROOT=' + str(self.base / (name + '-env')),
                'ORPHANS=python3 scripts/reap-test-orphans.py --root "' + str(root) + '" --grace 0']
        return self.start(argv + list(extra), name, cwd=root, env=env)

    def test_two_targeted_runs_wait_before_census_and_scratch(self):
        root = self.checkout('checkout with spaces')
        self.assert_two_runs_serialize(root)

    def assert_two_runs_serialize(self, root, goals=('test-spec',)):
        first, _, first_err = self.make(root, 'first', goals=goals)
        ready = self.base / 'first.ready'
        self.until(ready.exists, 'first targeted harness did not start: ' + first_err.read_text())
        harness_pid = int(ready.read_text())
        second, _, err = self.make(root, 'second')
        second_ready = self.base / 'second.ready'
        self.until(lambda: 'waiting' in err.read_text() or second_ready.exists() or first.poll() is not None,
                   'second command neither waited nor ran')
        self.assertIsNone(first.poll(), 'healthy first harness was reaped by the second run')
        self.assertIn('waiting', err.read_text(), 'second run entered instead of waiting for the active owner')
        self.assertIn('pid=', err.read_text(), 'wait diagnostic must name the lease holder')
        self.assertFalse(second_ready.exists())
        self.assertFalse((self.base / 'second-env').exists(), 'waiter touched scratch before admission')
        os.kill(harness_pid, 0)
        # A manual census must obey the same lease, including --phase after.
        manual, _, manual_err = self.start(
            [sys.executable, str(root / 'scripts/reap-test-orphans.py'), '--root', str(root),
             '--phase', 'after', '--grace', '0'], 'manual')
        self.until(lambda: 'waiting' in manual_err.read_text() or manual.poll() is not None,
                   'standalone census neither waited nor finished')
        self.assertIsNone(manual.poll(), manual_err.read_text())
        os.kill(harness_pid, 0)
        (self.base / 'first.release').touch()
        self.assertEqual(first.wait(timeout=15), 0, first_err.read_text())
        self.until(second_ready.exists, 'second targeted run did not acquire released lease: ' + err.read_text())
        (self.base / 'second.release').touch()
        self.assertEqual(second.wait(timeout=15), 0, err.read_text())
        self.assertEqual(manual.wait(timeout=15), 0, manual_err.read_text())

    def test_prerequisite_chain_enters_the_same_lifetime_lease(self):
        root = self.checkout('alias chain')
        with (root / 'Makefile').open('a') as makefile:
            makefile.write('\nfirst-alias: test-spec\nouter-alias: first-alias\n')
        self.assert_two_runs_serialize(root, goals=('outer-alias',))

    def test_default_goal_enters_the_same_lifetime_lease(self):
        root = self.checkout('default goal')
        with (root / 'Makefile').open('a') as makefile:
            makefile.write('\n.DEFAULT_GOAL := outer-alias\nouter-alias: test-spec\n')
        self.assert_two_runs_serialize(root, goals=())

    def test_internal_body_refuses_unowned_execution_before_scratch(self):
        root = self.checkout('unowned body')
        process, _, err = self.make(root, 'unowned', goals=('parley-test-body-test-spec',))
        self.assertNotEqual(process.wait(timeout=10), 0)
        self.assertIn('test lease required', err.read_text())
        self.assertFalse((self.base / 'unowned-env').exists())
        self.assertFalse((self.base / 'unowned.ready').exists())

    def wrapped(self, root, command, name, env=None, pass_fds=()):
        return self.start([sys.executable, str(WRAPPER), '--root', str(root), '--'] + command,
                          name, env=env, pass_fds=pass_fds)

    def gate_command(self, name):
        return [sys.executable, '-c',
                'import pathlib,sys,time\np=pathlib.Path(sys.argv[1])\n'
                'p.with_suffix(".ready").touch()\n'
                'while not p.with_suffix(".release").exists(): time.sleep(0.01)\n',
                str(self.base / name)]

    def test_different_checkouts_run_concurrently(self):
        first_root, second_root = self.checkout('one'), self.checkout('two')
        first, _, _ = self.make(first_root, 'one')
        self.until((self.base / 'one.ready').exists, 'first checkout did not start')
        second, _, _ = self.make(second_root, 'two')
        self.until((self.base / 'two.ready').exists, 'independent checkout was serialized')
        for name, process in [('one', first), ('two', second)]:
            (self.base / (name + '.release')).touch()
            self.assertEqual(process.wait(timeout=15), 0)

    def test_nested_wrapper_reuses_lock_and_preserves_status(self):
        root = self.checkout('nested')
        nested = [sys.executable, str(WRAPPER), '--root', str(root), '--',
                  sys.executable, '-c', 'raise SystemExit(23)']
        process, _, err = self.wrapped(root, nested, 'nested')
        self.assertEqual(process.wait(timeout=10), 23, err.read_text())
        self.assertNotIn('waiting', err.read_text())

    def test_kernel_releases_lease_when_last_owner_dies(self):
        root = self.checkout('death')
        first, _, _ = self.wrapped(root, self.gate_command('first'), 'first')
        self.until((self.base / 'first.ready').exists, 'owner never entered')
        second, _, err = self.wrapped(root, self.gate_command('second'), 'second')
        self.until(lambda: 'waiting' in err.read_text(), 'second command did not wait')
        first.kill()
        first.wait(timeout=5)
        self.until((self.base / 'second.ready').exists, 'kernel did not release dead owner lease')
        (self.base / 'second.release').touch()
        self.assertEqual(second.wait(timeout=5), 0)

    def test_invalid_inherited_descriptor_refuses_before_command(self):
        root = self.checkout('invalid')
        env = dict(os.environ, PARLEY_TEST_LEASE_FD='999999')
        process, _, err = self.wrapped(root, self.gate_command('invalid'), 'invalid', env=env)
        self.assertNotEqual(process.wait(timeout=5), 0)
        self.assertIn('lease', err.read_text())
        self.assertFalse((self.base / 'invalid.ready').exists())

    def test_cancelled_waiter_never_runs_its_command(self):
        root = self.checkout('cancel')
        first, _, _ = self.wrapped(root, self.gate_command('first'), 'first')
        self.until((self.base / 'first.ready').exists, 'owner never entered')
        second, _, err = self.wrapped(root, self.gate_command('second'), 'second')
        self.until(lambda: 'waiting' in err.read_text(), 'second command did not wait')
        second.terminate()
        self.assertEqual(second.wait(timeout=5), -signal.SIGTERM)
        (self.base / 'first.release').touch()
        self.assertEqual(first.wait(timeout=5), 0)
        self.assertFalse((self.base / 'second.ready').exists())

    def test_live_census_still_reaps_leftovers_and_fails_own_leaks(self):
        for phase, expected in [('before', 0), ('after', 1)]:
            with self.subTest(phase=phase):
                root = self.checkout(phase)
                fixtures = root / 'tests/fixtures'
                fixtures.mkdir()
                fixture = fixtures / 'gated_fixture.py'
                command = self.gate_command(phase)
                fixture.write_text(command[2])
                child, _, _ = self.start([sys.executable, str(fixture), command[3]], phase + '-child')
                self.until((self.base / (phase + '.ready')).exists, 'fixture never started')
                census, out, err = self.start(
                    [sys.executable, str(ROOT / 'scripts/reap-test-orphans.py'), '--root', str(root),
                     '--phase', phase, '--grace', '0'], phase + '-census')
                self.assertEqual(census.wait(timeout=10), expected, err.read_text())
                self.assertIn('pid=' + str(child.pid), out.read_text())
                self.assertEqual(child.wait(timeout=5), -signal.SIGKILL)

    @staticmethod
    def unwrapped_recipes(text):
        lines = text.splitlines()
        targets = next(line.split(':=', 1)[1].split() for line in lines
                       if line.startswith('PARLEY_TEST_TARGETS :='))
        current, found = None, set()
        for line in lines:
            target = re.match(r'^([A-Za-z][\w-]*):', line)
            if target:
                current = target.group(1)
            if not current or not line.startswith('\t'):
                continue
            public = current.removeprefix('parley-test-body-')
            harness = any(token in line for token in ('$(PREP_TEST_ENV)', '$(ORPHANS)',
                          '$(TEST_RUN)', '$(TEST_ENV)', 'tests/minimal_init.vim'))
            if current.startswith('test') or public in targets or harness:
                if current == public or public not in targets:
                    found.add(current)
        return found

    def test_make_entries_cover_every_census_and_scratch_recipe(self):
        text = '\n'.join((ROOT / name).read_text() for name in
                         ['Makefile.parley', 'Makefile', 'Makefile.local'])
        self.assertEqual(self.unwrapped_recipes(text), set())

    def test_entry_guard_rejects_a_new_unwrapped_public_test_target(self):
        text = (ROOT / 'Makefile.parley').read_text()
        self.assertEqual(self.unwrapped_recipes(text + '\ntest-new:\n\t@true\n'), {'test-new'})
        self.assertEqual(self.unwrapped_recipes(text + '\nnew-check:\n\t@$(PREP_TEST_ENV)\n'), {'new-check'})

    def test_alias_and_default_dry_runs_never_wait_for_lease(self):
        root = self.checkout('dry aliases')
        with (root / 'Makefile').open('a') as makefile:
            makefile.write('\n.DEFAULT_GOAL := outer-alias\nouter-alias: test-spec\n')
        first, _, _ = self.wrapped(root, self.gate_command('first'), 'first')
        self.until((self.base / 'first.ready').exists, 'owner never entered')
        for index, goals in enumerate([['outer-alias'], []]):
            dry, out, err = self.make(root, 'dry' + str(index), goals=goals, extra=['-n'])
            self.assertEqual(dry.wait(timeout=10), 0, err.read_text())
            self.assertIn('nvim', out.read_text())
            self.assertNotIn('waiting', err.read_text())
            self.assertFalse((self.base / ('dry' + str(index) + '-env')).exists())
        (self.base / 'first.release').touch()
        self.assertEqual(first.wait(timeout=5), 0)

    def test_recursive_dry_run_does_not_wait_or_touch_scratch(self):
        root = self.checkout('dry run')
        first, _, _ = self.wrapped(root, self.gate_command('first'), 'first')
        self.until((self.base / 'first.ready').exists, 'owner never entered')
        dry, out, err = self.start(['make', '-n', '--no-print-directory', 'test',
                                    'TEST_NVIM_DIR=', 'TEST_ENV_ROOT=' + str(self.base / 'dry-env')],
                                   'dry', cwd=root)
        self.assertEqual(dry.wait(timeout=10), 0, err.read_text())
        self.assertIn('rm -rf', out.read_text())
        self.assertIn('nvim', out.read_text())
        self.assertNotIn('waiting', err.read_text())
        self.assertFalse((self.base / 'dry-env').exists())
        (self.base / 'first.release').touch()
        self.assertEqual(first.wait(timeout=5), 0)

    def test_symlinked_checkout_reuses_the_same_descriptor(self):
        root = self.checkout('physical')
        alias = self.base / 'alias'
        alias.symlink_to(root, target_is_directory=True)
        nested = [sys.executable, str(WRAPPER), '--root', str(alias), '--',
                  sys.executable, '-c', 'raise SystemExit(19)']
        process, _, err = self.wrapped(root, nested, 'alias')
        self.assertEqual(process.wait(timeout=10), 19, err.read_text())
        self.assertNotIn('waiting', err.read_text())

    def test_descendant_keeps_lease_after_originating_owner_dies(self):
        root = self.checkout('descendant')
        spawn = [sys.executable, '-c',
                 'import os,subprocess,sys; '
                 'p=subprocess.Popen(sys.argv[1:], pass_fds=(int(os.environ["PARLEY_TEST_LEASE_FD"]),)); '
                 'p.wait()'] + self.gate_command('child')
        first, _, _ = self.wrapped(root, spawn, 'parent')
        try:
            self.until((self.base / 'child.ready').exists, 'descendant never entered')
            first.kill()
            first.wait(timeout=5)
            # An independent descriptor cannot acquire while the descendant lives.
            with (root / '.test-run.lock').open('r') as probe:
                with self.assertRaises(BlockingIOError):
                    fcntl.flock(probe, fcntl.LOCK_EX | fcntl.LOCK_NB)
            second, _, err = self.wrapped(root, self.gate_command('second'), 'second')
            self.until(lambda: 'waiting' in err.read_text(), 'descendant lease was ignored')
            (self.base / 'child.release').touch()
            self.until((self.base / 'second.ready').exists, 'last descendant did not release lease')
            (self.base / 'second.release').touch()
            self.assertEqual(second.wait(timeout=5), 0)
        finally:
            (self.base / 'child.release').touch()
            (self.base / 'second.release').touch()

    def test_same_inode_on_a_different_open_description_is_not_reentry(self):
        root = self.checkout('not reentry')
        first, _, _ = self.wrapped(root, self.gate_command('first'), 'first')
        self.until((self.base / 'first.ready').exists, 'owner never entered')
        with (root / '.test-run.lock').open('r') as probe:
            fd = probe.fileno()
            env = dict(os.environ, PARLEY_TEST_LEASE_FD=str(fd))
            second, _, err = self.wrapped(root, self.gate_command('second'), 'second',
                                           env=env, pass_fds=(fd,))
            self.assertNotEqual(second.wait(timeout=5), 0, err.read_text())
        self.assertFalse((self.base / 'second.ready').exists())
        (self.base / 'first.release').touch()
        self.assertEqual(first.wait(timeout=5), 0)

    def test_parallel_make_goals_do_not_overlap_inside_one_lease(self):
        root = self.checkout('multiple goals')
        with (root / 'Makefile').open('a') as makefile:
            makefile.write('\nsecond:\n\t@test -f ' + shlex.quote(str(self.base / 'first.done')) + '\n')
        first, _, err = self.make(root, 'first', extra=['-j2', 'second'])
        self.until((self.base / 'first.ready').exists, 'targeted harness never entered')
        (self.base / 'first.release').touch()
        self.assertEqual(first.wait(timeout=15), 0, err.read_text())

    def test_mixed_help_goal_keeps_product_help_prerequisite(self):
        root = self.checkout('mixed help')
        with (root / 'Makefile').open('a') as makefile:
            makefile.write('\nhelp: help-parley\n')
        (self.base / 'first.release').touch()
        first, out, err = self.make(root, 'first', extra=['help'])
        self.assertEqual(first.wait(timeout=15), 0, err.read_text())
        self.assertIn('same checkout serialize', out.read_text())


if __name__ == '__main__':
    unittest.main()
