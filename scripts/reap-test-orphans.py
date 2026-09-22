#!/usr/bin/env python3
"""Census and reap test processes belonging to one checkout (#220).

The process-table functions are deliberately pure.  ``--ps-from`` exercises
them without reading or mutating the machine process table; the live path is
the small boundary that invokes ``ps`` and sends SIGKILL.
"""

from __future__ import annotations

import argparse
import os
import signal
import subprocess
import sys
import time
from typing import Iterable


def parse_ps(text: str) -> list[dict[str, int | str]]:
    """Parse ``ps -Ao pid=,ppid=,args=`` output."""
    rows: list[dict[str, int | str]] = []
    for line_number, line in enumerate(text.splitlines(), 1):
        if not line.strip():
            continue
        fields = line.strip().split(None, 2)
        if len(fields) != 3:
            continue
        try:
            pid, ppid = int(fields[0]), int(fields[1])
        except ValueError:
            continue
        rows.append({"pid": pid, "ppid": ppid, "args": fields[2]})
    return rows


def ancestry(pid: int, rows: Iterable[dict[str, int | str]]) -> set[int]:
    """Return *pid* and every parent visible in the same process table."""
    parents = {int(row["pid"]): int(row["ppid"]) for row in rows}
    result: set[int] = set()
    current = pid
    while current not in result and current > 0:
        result.add(current)
        parent = parents.get(current)
        if parent is None or parent == current:
            break
        current = parent
    return result


def select_orphans(
    rows: Iterable[dict[str, int | str]],
    root: str,
    excluded_pids: Iterable[int] = (),
) -> list[dict[str, int | str]]:
    """Select headless harnesses and fixture processes under *root*.

    A path under ``root/tests`` identifies this checkout.  ``--headless`` or a
    path under ``tests/fixtures`` identifies a process the census owns.  The
    caller and its ancestors are excluded by the CLI before this function is
    called, so the command that launched the census cannot be killed.
    """
    root_prefix = os.path.abspath(root).rstrip(os.sep) + os.sep
    tests_prefix = root_prefix + "tests" + os.sep
    excluded = {int(pid) for pid in excluded_pids}
    selected: list[dict[str, int | str]] = []
    for row in rows:
        pid = int(row["pid"])
        args = str(row["args"])
        if pid in excluded or tests_prefix not in args:
            continue
        if "--headless" in args or tests_prefix + "fixtures" + os.sep in args:
            selected.append(row)
    return selected


def read_process_table(path: str | None, ps_command: str) -> tuple[str | None, str | None]:
    """Return raw process-table text and why it could not be read."""
    if path:
        with open(path, encoding="utf-8") as stream:
            return stream.read(), None
    try:
        completed = subprocess.run(
            [ps_command, "-Ao", "pid=,ppid=,args="],
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError as exc:
        return None, "unreadable"
    if completed.returncode != 0:
        return None, "unreadable"
    return completed.stdout, None


def describe(row: dict[str, int | str]) -> str:
    return f"pid={row['pid']} ppid={row['ppid']} args={row['args']}"


def persistent_candidates(
    initial: list[dict[str, int | str]],
    root: str,
    excluded: set[int],
    ps_from: str | None,
    grace: float,
) -> list[dict[str, int | str]]:
    """Keep only rows still present after the bounded grace period."""
    if grace <= 0 or ps_from:
        return initial
    survivors = {int(row["pid"]) for row in initial}
    latest = {int(row["pid"]): row for row in initial}
    deadline = time.monotonic() + grace
    while time.monotonic() < deadline and survivors:
        time.sleep(min(1.0, max(0.0, deadline - time.monotonic())))
        text, why_not = read_process_table(None, "ps")
        if why_not or text is None:
            break
        current = select_orphans(parse_ps(text), root, excluded)
        current_by_pid = {int(row["pid"]): row for row in current}
        survivors &= set(current_by_pid)
        latest.update(current_by_pid)
    return [latest[pid] for pid in sorted(survivors)]


def reap(rows: Iterable[dict[str, int | str]], phase: str, live: bool) -> None:
    for row in rows:
        print(f"{phase}: {describe(row)}")
        if live:
            try:
                os.kill(int(row["pid"]), signal.SIGKILL)
            except ProcessLookupError:
                pass
            except PermissionError as exc:
                print(f"BROKEN: cannot kill pid {row['pid']}: {exc}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True)
    parser.add_argument("--phase", choices=("before", "after"), required=True)
    parser.add_argument("--grace", type=float, default=8.0)
    parser.add_argument("--ps-from", help="read a recorded ps table; never signal rows")
    parser.add_argument("--ps-command", default="ps")
    parser.add_argument("--self-pid", type=int, default=os.getpid())
    parser.add_argument("--caller-pid", type=int, help=argparse.SUPPRESS)
    args = parser.parse_args(argv)

    text, why_not = read_process_table(args.ps_from, args.ps_command)
    if why_not == "unreadable":
        print("orphan check skipped: `ps` is unavailable here, so surviving test processes cannot be counted")
        return 0
    if text is None:
        return 0
    rows = parse_ps(text)
    self_pid = args.self_pid
    if not rows or not any(int(row["pid"]) == self_pid for row in rows):
        print(f"orphan check BROKEN: `{args.ps_command}` ran but produced no row this script can read (not even its own pid {self_pid}).")
        print("parse_ps expects `pid ppid args` columns. A census that cannot read ps reports zero leaks forever.")
        return 0 if args.phase == "before" else 1
    excluded = {os.getpid()}
    caller_pid = args.caller_pid if args.caller_pid is not None else self_pid
    excluded.update(ancestry(caller_pid, rows))
    excluded.add(self_pid)
    selected = select_orphans(rows, args.root, excluded)
    selected = persistent_candidates(selected, args.root, excluded, args.ps_from, args.grace)

    if args.phase == "before":
        if selected:
            print(f"reaped {len(selected)} test process(es) left by an earlier run:")
        reap(selected, "reap", args.ps_from is None)
        return 0
    if selected:
        print(f"LEAKED: {len(selected)} test process(es) survived the run, and are being reaped now.")
        reap(selected, "orphan", args.ps_from is None)
        return 1
    print("clean: no surviving test processes")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as exc:
        print(f"BROKEN: {exc}")
        raise SystemExit(2)
