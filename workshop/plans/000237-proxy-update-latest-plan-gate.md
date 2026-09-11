---
gate: plan-quality
issue: 237
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-09-11T13:24:32-07:00"
      agent: claude
      findings:
        - id: PQ-1
          severity: Important
          title: New specs kill spawned fake_cliproxy handles after the assertion, so a failing case orphans the process
          detail: |-
            Task 5's version_probe describe (plan:1314) has no after_each and each case
            calls handle:kill("sigterm") as the last statement of the it body, after the
            assertion (plan:1321, plan:1329); Task 7's foreign-proxy case repeats the
            shape (plan:1887). A failing assertion aborts before the kill and orphans a
            fake_cliproxy on a random port that cliproxy.stop() cannot reach - the exact
            class issue 000220 measured on this machine (430 orphans, load average 584,
            invisible to pgrep -f). Collect handles and reap them in after_each, and
            assert the handle (fixture_process.spawn returns handle, exited, err).
          family: fixture-process-leak
          round: 1
        - id: PQ-2
          severity: Minor
          title: status reaches github.com even when cliproxy.manage is off or no endpoint is set
          detail: |-
            M.status calls M.latest_release unconditionally (plan:2529), so an operator
            who set manage = false still gets outbound egress from :ParleyProxy status.
            Gate the latest read on info.managed.
          family: opt-out-respected
          round: 1
        - id: PQ-3
          severity: Minor
          title: _update_in_flight has no reset path or test seam if the async restart leg never answers
          detail: |-
            The guard (plan:1962) is cleared only inside finish, which on the restart
            path is reached only via restart_managed's callbacks. An unhandled raise in
            that async leg wedges every later :ParleyProxy update on "an update is
            already running" until nvim restarts, contradicting the ARCH-ORDER row that
            claims it is cleared on every terminal path.
          family: terminal-path-clears-guard
          round: 1
        - id: PQ-4
          severity: Minor
          title: ARCH-ORDER row promises a message plan_update never produces for "nothing listening"
          detail: |-
            plan:172 says the installed-with-no-listener state tells the user the next
            dispatch spawns the new binary, but plan_update and its tests emit only
            "updated X to Y" when running is nil. Reconcile the table with the code.
          family: ordering-table-matches-code
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-09-11T13:40:01-07:00"
      agent: claude
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Process ownership table + stated rule + fixture_watchdog.py; every new spawn is asserted and reaped in after_each.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: M.status gates the latest read on info.managed, with a request-log assertion on the release fake.
          round: 2
        - id: PQ-3
          disposition: addressed
          note: 20s deadline above restart_managed's ~13s worst case, test seam, and a released-guard test.
          round: 2
        - id: PQ-4
          disposition: addressed
          note: The ARCH-ORDER table now splits "listener not ours" from "nothing listening" and matches plan_update.
          round: 2
      findings:
        - id: PQ-5
          severity: Minor
          title: Ownership is enumerated by who starts a process, not by when — an async leg can spawn after after_each
          detail: |-
            Task 7's restart-deadline case restores the real restart_managed before its
            second update() while the 300ms deadline seam is still armed, so the it body
            returns with a real restart in flight; its spawn can land after reap() /
            stop() / _reset_spawned(), into the next test's rendered endpoint. Second
            finding in this family: state the temporal rule in Process ownership — an it
            body must not return while an async leg it started can still spawn (await the
            callback, or keep the spawner stubbed for the whole body) — and let that rule,
            not this one line, drive the sweep.
          family: fixture-process-leak
          round: 2
      blocked: false
    - "n": 3
      timestamp: "2026-09-11T13:44:35-07:00"
      agent: claude
      dispose:
        - id: PQ-5
          disposition: addressed
          note: Process ownership now states the timing rule and covers every case with an async spawning step; the deadline case keeps restart_managed stubbed through both calls; the 13 s restart, 20 s deadline and 25 s await margins hold against cliproxy.lua:378-430.
          round: 3
      blocked: false
content_hash: c6359580980b200663edbcf497569ecce12dab256934c01df410a5eeffabe77f
---

# Gate ledger — parley.nvim#237 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-11T13:24:32-07:00 (claude) — BLOCKED

### Raised

- **PQ-1** [Important] `fixture-process-leak` New specs kill spawned fake_cliproxy handles after the assertion, so a failing case orphans the process
  Task 5's version_probe describe (plan:1314) has no after_each and each case
  calls handle:kill("sigterm") as the last statement of the it body, after the
  assertion (plan:1321, plan:1329); Task 7's foreign-proxy case repeats the
  shape (plan:1887). A failing assertion aborts before the kill and orphans a
  fake_cliproxy on a random port that cliproxy.stop() cannot reach - the exact
  class issue 000220 measured on this machine (430 orphans, load average 584,
  invisible to pgrep -f). Collect handles and reap them in after_each, and
  assert the handle (fixture_process.spawn returns handle, exited, err).
- **PQ-2** [Minor] `opt-out-respected` status reaches github.com even when cliproxy.manage is off or no endpoint is set
  M.status calls M.latest_release unconditionally (plan:2529), so an operator
  who set manage = false still gets outbound egress from :ParleyProxy status.
  Gate the latest read on info.managed.
- **PQ-3** [Minor] `terminal-path-clears-guard` _update_in_flight has no reset path or test seam if the async restart leg never answers
  The guard (plan:1962) is cleared only inside finish, which on the restart
  path is reached only via restart_managed's callbacks. An unhandled raise in
  that async leg wedges every later :ParleyProxy update on "an update is
  already running" until nvim restarts, contradicting the ARCH-ORDER row that
  claims it is cleared on every terminal path.
- **PQ-4** [Minor] `ordering-table-matches-code` ARCH-ORDER row promises a message plan_update never produces for "nothing listening"
  plan:172 says the installed-with-no-listener state tells the user the next
  dispatch spawns the new binary, but plan_update and its tests emit only
  "updated X to Y" when running is nil. Reconcile the table with the code.

## Round 2 — 2026-09-11T13:40:01-07:00 (claude) — passed

### Disposed

- PQ-1 — addressed — Process ownership table + stated rule + fixture_watchdog.py; every new spawn is asserted and reaped in after_each.
- PQ-2 — addressed — M.status gates the latest read on info.managed, with a request-log assertion on the release fake.
- PQ-3 — addressed — 20s deadline above restart_managed's ~13s worst case, test seam, and a released-guard test.
- PQ-4 — addressed — The ARCH-ORDER table now splits "listener not ours" from "nothing listening" and matches plan_update.

### Raised

- **PQ-5** [Minor] `fixture-process-leak` Ownership is enumerated by who starts a process, not by when — an async leg can spawn after after_each
  Task 7's restart-deadline case restores the real restart_managed before its
  second update() while the 300ms deadline seam is still armed, so the it body
  returns with a real restart in flight; its spawn can land after reap() /
  stop() / _reset_spawned(), into the next test's rendered endpoint. Second
  finding in this family: state the temporal rule in Process ownership — an it
  body must not return while an async leg it started can still spawn (await the
  callback, or keep the spawner stubbed for the whole body) — and let that rule,
  not this one line, drive the sweep.

## Round 3 — 2026-09-11T13:44:35-07:00 (claude) — passed

### Disposed

- PQ-5 — addressed — Process ownership now states the timing rule and covers every case with an async spawning step; the deadline case keeps restart_managed stubbed through both calls; the 13 s restart, 20 s deadline and 25 s await margins hold against cliproxy.lua:378-430.

## Open findings

(none — every finding has been disposed)
