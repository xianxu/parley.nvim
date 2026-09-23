"""Exit a test fixture when the process that started it is gone (#237, #220).

A fixture reparented to init outlives its spec forever: #220 measured 897
orphaned fake_cliproxy processes holding ~10 GB. after_each teardown covers a
failing assertion, but not a crashed or killed nvim, which #220 found to be the
dominant case. This covers that one: the fixture polls its parent pid and exits
the moment it is orphaned.
"""
import os
import threading
import time


def orphaned(parent, ppid):
    """A fixture is orphaned when its parent is init, OR when its parent changed.

    The `== 1` half is load-bearing and not redundant: a fixture orphaned while it
    is still starting samples 1 as its own parent, so a rule that only watches for
    a CHANGE never fires for exactly the case that produces these (#220). Measured
    with PARLEY_FAKE_EXIT_WITH_PARENT=1 and a parent that exits at once: alive at
    t=4s under the old rule, gone by t=3s under this one. Stated identically in
    tests/helpers/exit_with_parent.lua.
    """
    return ppid == 1 or ppid != parent


def exit_with_parent(poll_seconds=1.0):
    parent = os.getppid()

    def watch():
        while True:
            time.sleep(poll_seconds)
            if orphaned(parent, os.getppid()):
                os._exit(0)

    threading.Thread(target=watch, daemon=True).start()
