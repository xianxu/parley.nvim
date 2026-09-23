#!/usr/bin/env python3
"""Direct pure predicate tests and injected process-observation sequence tests."""

import importlib.util
import pathlib
import unittest
import contextlib
import io
from unittest.mock import patch


ROOT = pathlib.Path(__file__).parents[2]


def load_module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


census = load_module(ROOT / "scripts/reap-test-orphans.py", "reap_test_orphans")
watchdog = load_module(ROOT / "tests/fixtures/fixture_watchdog.py", "fixture_watchdog")


class CensusPureTests(unittest.TestCase):
    def test_snapshot_validation_requires_all_rows_and_observer(self):
        self.assertEqual(len(census.validated_rows('999 1 census\n3 1 fixture', 999)), 2)
        for text in [None, '', '3 1 fixture', '999 1 census\nbad row']:
            with self.subTest(text=text), self.assertRaises(ValueError):
                census.validated_rows(text, 999)

    def test_parse_ps_and_ancestry_are_pure(self):
        rows = census.parse_ps("100 200 /bin/nvim --headless\n200 1 /bin/sh")
        self.assertEqual(rows[0]["pid"], 100)
        self.assertEqual(census.ancestry(100, rows), {100, 200, 1})

    def test_selector_requires_checkout_and_owned_process_shape(self):
        rows = [
            {"pid": 1, "ppid": 0, "args": "/repo/tests/unit/editor.lua"},
            {"pid": 2, "ppid": 0, "args": "nvim --headless -u /repo/tests/minimal_init.vim"},
            {"pid": 3, "ppid": 0, "args": "/repo/tests/fixtures/fake"},
            {"pid": 4, "ppid": 0, "args": "/other/tests/fixtures/fake"},
        ]
        self.assertEqual(
            [row["pid"] for row in census.select_orphans(rows, "/repo")],
            [2, 3],
        )

    def test_argument_mentions_do_not_establish_process_ownership(self):
        commands = [
            '/usr/bin/nvim /repo/tests/fixtures/fake_cliproxy',
            '/usr/bin/less /repo/tests/fixtures/ps_test_orphans.txt',
            '/bin/echo /repo/tests/fixtures/fake_cliproxy',
            '/bin/sh -c /repo/tests/fixtures/fake_cliproxy',
            'python3 -c print(1) /repo/tests/fixtures/fake_cliproxy',
            'python3 -m viewer /repo/tests/fixtures/fake_cliproxy',
            'nvim /repo/tests/fixtures/fake_cliproxy -c echo --headless',
            'nvim --headless /repo/tests/fixtures/ps_test_orphans.txt',
            'nvim --headless -c echo /repo/tests/fixtures/fake_cliproxy',
        ]
        for command in commands:
            with self.subTest(command=command):
                self.assertEqual(census.select_orphans(
                    [{"pid": 9, "ppid": 1, "args": command}], '/repo'), [])

    def test_fixture_execution_identity_includes_interpreters(self):
        for command in [
            '/repo/tests/fixtures/fake_cliproxy --port 1',
            '/usr/bin/python3 /repo/tests/fixtures/fake_cliproxy --port 1',
            'python3 -B /repo/tests/fixtures/fake_cliproxy --port 1',
            '/bin/sh /repo/tests/fixtures/orphan_me.sh /tmp/pid nvim',
        ]:
            with self.subTest(command=command):
                self.assertEqual(len(census.select_orphans(
                    [{"pid": 9, "ppid": 1, "args": command}], '/repo')), 1)

    def test_unquoted_ps_script_path_with_spaces_is_supported(self):
        row = {"pid": 9, "ppid": 1,
               "args": 'python3 /repo with spaces/tests/fixtures/fake --port 1'}
        self.assertEqual(census.select_orphans([row], '/repo with spaces'), [row])


class CensusSamplingTests(unittest.TestCase):
    def test_invalid_later_observation_never_reports_clean_or_signals_stale_pids(self):
        initial = '999 1 python3 census\n3 1 /repo/tests/fixtures/fake\n'
        for next_sample in [('malformed table', None), (None, 'unreadable'),
                            ('999 1 python3 census\nmalformed row', None)]:
            with self.subTest(next_sample=next_sample):
                output = io.StringIO()
                with patch.object(census, 'read_process_table', side_effect=[(initial, None), next_sample]), \
                     patch.object(census.os, 'kill') as kill, \
                     contextlib.redirect_stdout(output):
                    code = census.main(['--root', '/repo', '--phase', 'after',
                                        '--self-pid', '999', '--grace', '0.01'])
                self.assertNotEqual(code, 0)
                self.assertNotIn('clean:', output.getvalue())
                self.assertIn('BROKEN', output.getvalue())
                kill.assert_not_called()

    def test_grace_resampling_uses_the_configured_process_table_command(self):
        rows = [{"pid": 3, "ppid": 1, "args": "/repo/tests/fixtures/fake"}]
        with patch.object(census, "read_process_table",
                          return_value=("3 1 /repo/tests/fixtures/fake\n999 1 python3 census\n", None)) as read:
            survivors = census.persistent_candidates(rows, "/repo", set(), None, 0.01,
                                                     "custom-ps", 999)
        self.assertEqual([row["pid"] for row in survivors], [3])
        self.assertTrue(read.called)
        self.assertEqual(read.call_args.args, (None, "custom-ps"))


class WatchdogPureTests(unittest.TestCase):
    def test_init_parent_is_orphaned(self):
        self.assertTrue(watchdog.orphaned(1, 1))

    def test_changed_parent_is_orphaned(self):
        self.assertTrue(watchdog.orphaned(8, 9))

    def test_same_non_init_parent_is_not_orphaned(self):
        self.assertFalse(watchdog.orphaned(8, 8))


if __name__ == "__main__":
    unittest.main()
