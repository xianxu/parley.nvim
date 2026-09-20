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
    - "n": 2
      timestamp: "2026-09-19T19:12:24-07:00"
      agent: claude
      dispose:
        - id: PQ-1
          disposition: addressed
          note: '`after` re-polls for --grace (default 8 s) and reports only pids in every sample; cliproxy_update_spec:486''s 4000 ms delay verified.'
          round: 2
        - id: PQ-2
          disposition: addressed
          note: Corrected to cliproxy_login_spec.lua:58 and :183 (production run_login), verified; that spec is now in Task 2 Step 6.
          round: 2
        - id: PQ-3
          disposition: addressed
          note: sample() separates unreadable from unparsable; a successful ps must parse >=1 row and contain --self-pid, else BROKEN/exit 1, plus a live pending()-guarded conformance case.
          round: 2
        - id: PQ-4
          disposition: addressed
          note: install(poll_ms, before_exit) runs the hoisted drop_query_dir before os.exit; minimal_init gives it to both triggers.
          round: 2
        - id: PQ-5
          disposition: not-addressed
          note: Task 3's table went, but the plan grew 1803 to 1958 lines; spec bodies and the census script remain verbatim. Minor, carried to close.
          round: 2
      findings:
        - id: PQ-6
          severity: Important
          title: Task 2 Step 6 names image_shrink_live_spec as the fake_sips slow driver; it never touches fake_sips and pending()s by default
          detail: |-
            2nd finding in this family. tests/integration/image_shrink_live_spec.lua has zero
            occurrences of fake_sips, iterates shrink.RECIPES (lua/parley/image_shrink.lua:22-40 =
            sips/magick/convert), and pending()s unless PARLEY_LIVE_SHRINK=1, so it passes without
            exercising anything. The real driver is tests/unit/image_shrink_spec.lua:298, which asserts
            exit 124 and elapsed in [4.5, 8) and is precisely what a new exit_with_parent() in fake_sips
            could perturb. Do not just swap the filename. The rule, which the round that fixed PQ-2
            applied to Task 3 and not to Task 2, is that every spec list in this plan is derived by a
            command the plan states rather than typed. State Step 6's list as a grep over what selects
            each mode (PARLEY_FAKE_LOGIN_MODE, PARLEY_FAKE_SIPS, plus the LoopbackHTTPServer consumers)
            so membership is computed, not remembered (ARCH-PURPOSE).
          family: unverified-file-line-claim
          round: 2
      blocked: true
    - "n": 3
      timestamp: "2026-09-19T19:14:08-07:00"
      agent: claude
      dispose:
        - id: PQ-6
          disposition: addressed
          note: Step 6's list is now computed by two stated greps, verified to return the three mode drivers; image_shrink_spec.lua:295-301 and fake_sips:16 confirmed.
          round: 3
        - id: PQ-5
          disposition: not-addressed
          note: 1975 lines now (was 1958); spec bodies and the census script remain verbatim. Minor, carried to the close review.
          round: 3
      blocked: false
content_hash: 07043cab6a355d9575145ab25503bab064ed09dbedfbf2f903d9c700a9d5d9c6
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

## Round 2 — 2026-09-19T19:12:24-07:00 (claude) — BLOCKED

### Disposed

- PQ-1 — addressed — `after` re-polls for --grace (default 8 s) and reports only pids in every sample; cliproxy_update_spec:486's 4000 ms delay verified.
- PQ-2 — addressed — Corrected to cliproxy_login_spec.lua:58 and :183 (production run_login), verified; that spec is now in Task 2 Step 6.
- PQ-3 — addressed — sample() separates unreadable from unparsable; a successful ps must parse >=1 row and contain --self-pid, else BROKEN/exit 1, plus a live pending()-guarded conformance case.
- PQ-4 — addressed — install(poll_ms, before_exit) runs the hoisted drop_query_dir before os.exit; minimal_init gives it to both triggers.
- PQ-5 — not-addressed — Task 3's table went, but the plan grew 1803 to 1958 lines; spec bodies and the census script remain verbatim. Minor, carried to close.

### Raised

- **PQ-6** [Important] `unverified-file-line-claim` Task 2 Step 6 names image_shrink_live_spec as the fake_sips slow driver; it never touches fake_sips and pending()s by default
  2nd finding in this family. tests/integration/image_shrink_live_spec.lua has zero
  occurrences of fake_sips, iterates shrink.RECIPES (lua/parley/image_shrink.lua:22-40 =
  sips/magick/convert), and pending()s unless PARLEY_LIVE_SHRINK=1, so it passes without
  exercising anything. The real driver is tests/unit/image_shrink_spec.lua:298, which asserts
  exit 124 and elapsed in [4.5, 8) and is precisely what a new exit_with_parent() in fake_sips
  could perturb. Do not just swap the filename. The rule, which the round that fixed PQ-2
  applied to Task 3 and not to Task 2, is that every spec list in this plan is derived by a
  command the plan states rather than typed. State Step 6's list as a grep over what selects
  each mode (PARLEY_FAKE_LOGIN_MODE, PARLEY_FAKE_SIPS, plus the LoopbackHTTPServer consumers)
  so membership is computed, not remembered (ARCH-PURPOSE).

## Round 3 — 2026-09-19T19:14:08-07:00 (claude) — passed

### Disposed

- PQ-6 — addressed — Step 6's list is now computed by two stated greps, verified to return the three mode drivers; image_shrink_spec.lua:295-301 and fake_sips:16 confirmed.
- PQ-5 — not-addressed — 1975 lines now (was 1958); spec bodies and the census script remain verbatim. Minor, carried to the close review.

## Open findings

- **PQ-5** [Minor] `plan-restates-the-diff` 1803 lines carrying complete spec bodies and the whole census script verbatim
