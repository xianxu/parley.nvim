"""Exit a test fixture when the process that started it is gone (#237, #220).

A fixture reparented to init outlives its spec forever: #220 measured 897
orphaned fake_cliproxy processes holding ~10 GB. after_each teardown covers a
failing assertion, but not a crashed or killed nvim, which #220 found to be the
dominant case. This covers that one: the fixture polls its parent pid and exits
the moment it changes (reparenting to init, or to a subreaper).
"""
import os
import threading
import time


def exit_with_parent(poll_seconds=1.0):
    parent = os.getppid()

    def watch():
        while True:
            time.sleep(poll_seconds)
            if os.getppid() != parent:
                os._exit(0)

    threading.Thread(target=watch, daemon=True).start()
