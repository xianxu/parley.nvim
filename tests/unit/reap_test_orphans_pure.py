#!/usr/bin/env python3
"""No-IO tests for the pure #220 census and watchdog predicates."""

import importlib.util
import pathlib
import unittest
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
    def test_parse_ps_and_ancestry_are_pure(self):
        rows = census.parse_ps("100 200 /bin/nvim --headless\n200 1 /bin/sh")
        self.assertEqual(rows[0]["pid"], 100)
        self.assertEqual(census.ancestry(100, rows), {100, 200, 1})

    def test_selector_requires_checkout_and_owned_process_shape(self):
        rows = [
            {"pid": 1, "ppid": 0, "args": "/repo/tests/unit/editor.lua"},
            {"pid": 2, "ppid": 0, "args": "/repo/tests/unit/nvim --headless"},
            {"pid": 3, "ppid": 0, "args": "/repo/tests/fixtures/fake"},
            {"pid": 4, "ppid": 0, "args": "/other/tests/fixtures/fake"},
        ]
        self.assertEqual(
            [row["pid"] for row in census.select_orphans(rows, "/repo")],
            [2, 3],
        )


class WatchdogPureTests(unittest.TestCase):
    def test_init_parent_is_orphaned(self):
        with patch.object(watchdog.os, "getppid", return_value=1):
            self.assertTrue(watchdog.orphaned(1))

    def test_changed_parent_is_orphaned(self):
        with patch.object(watchdog.os, "getppid", return_value=9):
            self.assertTrue(watchdog.orphaned(8))

    def test_same_non_init_parent_is_not_orphaned(self):
        with patch.object(watchdog.os, "getppid", return_value=8):
            self.assertFalse(watchdog.orphaned(8))


if __name__ == "__main__":
    unittest.main()
