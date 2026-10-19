# Open-descriptor watchdog

An editor that leaks descriptors dies at the per-process limit (256 on macOS) with `E903: too many open files` on every BufEnter, hours after the leak began (#399). Once a minute, `fd_watchdog` counts this editor's own descriptors (`/dev/fd`). The first time the count passes `fd_watchdog_threshold` (200; 0 turns it off), it runs `lsof -p <pid>` and `ps -o pid=,ppid=,comm=`, then writes the time, the count, this editor's live children (executable names only: a child's arguments can carry secrets, such as curl's Authorization header) and the full lsof to `<state_dir>/fd-captures/fd-<stamp>-<pid>.txt`. It then warns once, naming that file. Each capture command has a 10 s deadline, and a failed one records its exit and stderr in the capture. It fires once per process: after a capture the timer stops, and rerunning setup does not re-arm it. Each write keeps only the newest five captures.

The capture is the evidence for a leak's root cause: which children were running and which descriptors were open at the onset. The decisions (`crossed`, `children`, `report`, `stale`) are pure; the timer, the two commands and the files are the shell.

Two fake-backed guards in `tests/integration/session_sync_spec.lua` (counting with `fd_watchdog.count`) keep parley's own session-sync path flat: 200 agent writes with reloads and probes, and a rename storm of 50 registered docs.

Code: `lua/parley/fd_watchdog.lua`, wired in `init.lua` setup; config `fd_watchdog_threshold` in `lua/parley/config.lua`.
