---
gate: plan-quality
issue: 220
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-09-19T19:05:46-07:00"
      agent: claude
      findings:
        - id: PQ-1
          severity: Critical
          title: '`--phase after` runs with zero grace and will fail runs that leaked nothing'
          detail: |-
            Task 3 rule 4 concedes production-spawned detached proxies are covered only
            by the 1s LoopbackHTTPServer poll; cliproxy.stop() (lua/parley/cliproxy.lua:869-874)
            sends SIGTERM only, and cliproxy_update_spec:486 sets PARLEY_FAKE_EXIT_DELAY_MS=4000
            so the fake keeps serving 4s after it. If that spec finishes last under -P 8,
            `$(ORPHANS) --phase after` sees a live match and exits 1 on a clean suite.
            The plan's own ARCH-CONSTRAINTS note budgets ~2s of clearing latency and Step 6
            allows 10s; Step 3 allows none. `after` needs a bounded re-poll window before
            it declares a leak (ARCH-ORDER: liveness at one instant is not proof of a leak).
          family: async-teardown-needs-settle-window
          round: 1
        - id: PQ-2
          severity: Important
          title: '`cliproxy_auth_login_spec:61` does not drive the hangs login; it is a -config spawn'
          detail: |-
            Asserted twice (integration points, Task 2). Line 61 is
            `uv.spawn(FAKE, { args = { "-config", cfg_file } }, ...)` and
            PARLEY_FAKE_LOGIN_MODE appears nowhere in that file. The driver is
            tests/integration/cliproxy_login_spec.lua:58 and :183. That spec starts the
            login through production code, so it is rightly outside Task 3's table, but it
            is also missing from Task 2 Step 6's verification list, which is the list that
            would catch a regression from run_login's new exit_with_parent().
          family: unverified-file-line-claim
          round: 1
        - id: PQ-3
          severity: Important
          title: A ps whose column format drifts makes the census pass silently
          detail: |-
            read_process_table returns None only on a failed or non-zero ps. A successful
            ps with changed columns parses to zero rows and `--phase after` exits 0 —
            the same "remedy that no-ops and reads as success" this issue exists to kill.
            ARCH-MOCK: --ps-from is the seam but the recorded table is the only thing
            parse_ps is checked against, and Steps 5-6 are one-time manual proofs, not a
            cadence. Add a floor in the script (a successful ps must parse >=1 row and
            must contain --self-pid) plus one live case in the house idiom of
            tests/integration/process_group_conformance_spec.lua, pending() where ps is refused.
          family: external-format-drift-fails-open
          round: 1
        - id: PQ-4
          severity: Minor
          title: os.exit(1) skips VimLeavePre, stranding the per-process $PARLEY_QUERY_DIR
          detail: |-
            tests/minimal_init.vim:48-49 creates it and :53-55 deletes it at VimLeavePre
            precisely because #261 M5 found it would otherwise accumulate. The watchdog's
            deliberate os.exit skips that. No regression (the dir leaks today with the
            process), but the plan's ARCH-FUNERAL note "Nothing durable is created" holds
            only for the census; two lines before os.exit would close it.
          family: exit-path-skips-its-own-cleanup
          round: 1
        - id: PQ-5
          severity: Minor
          title: 1803 lines carrying complete spec bodies and the whole census script verbatim
          detail: |-
            The function names plus one strategy line per risky function carry the same
            design at a fraction of the staleness. Task 3's line-numbered uv.spawn table
            is the right instinct done wrong — it already says the arch guard, not the
            table, owns completeness, so the table can go.
          family: plan-restates-the-diff
          round: 1
      blocked: true
---

# Gate ledger — parley.nvim#220 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-19T19:05:46-07:00 (claude) — BLOCKED

### Raised

- **PQ-1** [Critical] `async-teardown-needs-settle-window` `--phase after` runs with zero grace and will fail runs that leaked nothing
  Task 3 rule 4 concedes production-spawned detached proxies are covered only
  by the 1s LoopbackHTTPServer poll; cliproxy.stop() (lua/parley/cliproxy.lua:869-874)
  sends SIGTERM only, and cliproxy_update_spec:486 sets PARLEY_FAKE_EXIT_DELAY_MS=4000
  so the fake keeps serving 4s after it. If that spec finishes last under -P 8,
  `$(ORPHANS) --phase after` sees a live match and exits 1 on a clean suite.
  The plan's own ARCH-CONSTRAINTS note budgets ~2s of clearing latency and Step 6
  allows 10s; Step 3 allows none. `after` needs a bounded re-poll window before
  it declares a leak (ARCH-ORDER: liveness at one instant is not proof of a leak).
- **PQ-2** [Important] `unverified-file-line-claim` `cliproxy_auth_login_spec:61` does not drive the hangs login; it is a -config spawn
  Asserted twice (integration points, Task 2). Line 61 is
  `uv.spawn(FAKE, { args = { "-config", cfg_file } }, ...)` and
  PARLEY_FAKE_LOGIN_MODE appears nowhere in that file. The driver is
  tests/integration/cliproxy_login_spec.lua:58 and :183. That spec starts the
  login through production code, so it is rightly outside Task 3's table, but it
  is also missing from Task 2 Step 6's verification list, which is the list that
  would catch a regression from run_login's new exit_with_parent().
- **PQ-3** [Important] `external-format-drift-fails-open` A ps whose column format drifts makes the census pass silently
  read_process_table returns None only on a failed or non-zero ps. A successful
  ps with changed columns parses to zero rows and `--phase after` exits 0 —
  the same "remedy that no-ops and reads as success" this issue exists to kill.
  ARCH-MOCK: --ps-from is the seam but the recorded table is the only thing
  parse_ps is checked against, and Steps 5-6 are one-time manual proofs, not a
  cadence. Add a floor in the script (a successful ps must parse >=1 row and
  must contain --self-pid) plus one live case in the house idiom of
  tests/integration/process_group_conformance_spec.lua, pending() where ps is refused.
- **PQ-4** [Minor] `exit-path-skips-its-own-cleanup` os.exit(1) skips VimLeavePre, stranding the per-process $PARLEY_QUERY_DIR
  tests/minimal_init.vim:48-49 creates it and :53-55 deletes it at VimLeavePre
  precisely because #261 M5 found it would otherwise accumulate. The watchdog's
  deliberate os.exit skips that. No regression (the dir leaks today with the
  process), but the plan's ARCH-FUNERAL note "Nothing durable is created" holds
  only for the census; two lines before os.exit would close it.
- **PQ-5** [Minor] `plan-restates-the-diff` 1803 lines carrying complete spec bodies and the whole census script verbatim
  The function names plus one strategy line per risky function carry the same
  design at a fraction of the staleness. Task 3's line-numbered uv.spawn table
  is the right instinct done wrong — it already says the arch guard, not the
  table, owns completeness, so the table can go.

## Open findings

- **PQ-1** [Critical] `async-teardown-needs-settle-window` `--phase after` runs with zero grace and will fail runs that leaked nothing
- **PQ-2** [Important] `unverified-file-line-claim` `cliproxy_auth_login_spec:61` does not drive the hangs login; it is a -config spawn
- **PQ-3** [Important] `external-format-drift-fails-open` A ps whose column format drifts makes the census pass silently
- **PQ-4** [Minor] `exit-path-skips-its-own-cleanup` os.exit(1) skips VimLeavePre, stranding the per-process $PARLEY_QUERY_DIR
- **PQ-5** [Minor] `plan-restates-the-diff` 1803 lines carrying complete spec bodies and the whole census script verbatim
