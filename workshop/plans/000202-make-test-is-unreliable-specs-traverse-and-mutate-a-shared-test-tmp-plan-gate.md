---
gate: plan-quality
issue: 202
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-08-21T22:54:56-07:00"
      agent: claude
      findings:
        - id: PQ-1
          severity: Critical
          title: Plan fixes only tools_builtin_find_spec, but grep/ack specs share the same repo-root traversal shape
          detail: |-
            tests/unit/tools_builtin_grep_spec.lua:54 and tests/unit/tools_builtin_ack_spec.lua:28 both call
            the handler with path = "." and assert is_error == false; grep_spec.lua:41 traverses cwd with no
            path argument at all. The proposed arch rule forbidding repo-root traversal in specs would fail on
            all three. Decide in the plan whether they are fixed or allow-listed, and say why.
          family: fix-scope-misses-siblings
          round: 1
        - id: PQ-2
          severity: Important
          title: Arch fitness function names no pattern, scope, or allow list, and does not reuse arch_helper
          detail: |-
            tests/arch/arch_helper.lua:41 already offers assert_pattern_scoping with allow_only_in = {} meaning
            "forbidden everywhere in scope" (ARCH-DRY). Name it, and state the literal/pattern, the scope glob
            over tests/, and the allow list. Note that it is a line-wise text grep and therefore cannot detect
            grep_spec.lua:41, which omits the path key entirely.
          family: fitness-rule-underspecified
          round: 1
        - id: PQ-3
          severity: Important
          title: Done-when item 2 still asks for a bind retry that the Log refuted
          detail: |-
            Log entry 2 establishes the bind succeeds before readiness is published and concludes retrying the
            bind "would have changed nothing", but Done-when still reads "either retries its bind or is given a
            port it does not have to race for". Restate it as the atomic readiness publish the plan actually builds.
          family: stale-acceptance-criteria
          round: 1
        - id: PQ-4
          severity: Important
          title: Mechanism 2 is verified only by ten suite runs; no test exercises the new readiness guard
          detail: |-
            Name start_server (tests/integration/chat_progress_process_spec.lua:28) as the unit under test and
            give one strategy line: drive its readiness wait against a writer that publishes a zero-byte file
            before the port digits, and assert it waits or fails by name rather than nil-concatenating. Repetition
            is weak evidence for a roughly 1-in-5 race.
          family: race-fix-without-deterministic-test
          round: 1
        - id: PQ-5
          severity: Important
          title: Permanent ban on repo-root traversal adopted without stating why scratch stays inside the repo
          detail: |-
            TEST_TMP is $(CURDIR)/.test-tmp (Makefile.parley:27) and tests/minimal_init.vim:21 puts nvim swap
            files there, so eight parallel jobs churn the repo tree. That placement is also the direct cause of
            Log entry 4's sandbox git-init failure. Moving TEST_TMP outside $(CURDIR) would close mechanism 1
            generally and make the fitness function unnecessary; state why it was rejected, and add the plan's
            other non-goals explicitly.
          family: unstated-design-alternative
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-08-21T22:59:51-07:00"
      agent: claude
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Fix relocated from the traversers to the churner; Non-goals names grep/ack/find and why they are untouched.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: Fitness function withdrawn in Non-goals with the false-positive and line-wise-grep blindness both stated.
          round: 2
        - id: PQ-3
          disposition: addressed
          note: Done-when restated as atomic readiness publish plus parseable-port wait, matching Log entry 2.
          round: 2
        - id: PQ-4
          disposition: addressed
          note: wait_for_port named as the unit under test with absent/incomplete/garbage input class and a named-failure guard.
          round: 2
        - id: PQ-5
          disposition: addressed
          note: Scratch root moves outside $(CURDIR); Non-goals now records parallelism, tool-spec rewrites, and sandbox git init.
          round: 2
      blocked: false
content_hash: 23132b8a882cb80f927bb6bb93962b7b0633aca7519e3169da5ba120e30aba6f
---

# Gate ledger — parley.nvim#202 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-08-21T22:54:56-07:00 (claude) — BLOCKED

### Raised

- **PQ-1** [Critical] `fix-scope-misses-siblings` Plan fixes only tools_builtin_find_spec, but grep/ack specs share the same repo-root traversal shape
  tests/unit/tools_builtin_grep_spec.lua:54 and tests/unit/tools_builtin_ack_spec.lua:28 both call
  the handler with path = "." and assert is_error == false; grep_spec.lua:41 traverses cwd with no
  path argument at all. The proposed arch rule forbidding repo-root traversal in specs would fail on
  all three. Decide in the plan whether they are fixed or allow-listed, and say why.
- **PQ-2** [Important] `fitness-rule-underspecified` Arch fitness function names no pattern, scope, or allow list, and does not reuse arch_helper
  tests/arch/arch_helper.lua:41 already offers assert_pattern_scoping with allow_only_in = {} meaning
  "forbidden everywhere in scope" (ARCH-DRY). Name it, and state the literal/pattern, the scope glob
  over tests/, and the allow list. Note that it is a line-wise text grep and therefore cannot detect
  grep_spec.lua:41, which omits the path key entirely.
- **PQ-3** [Important] `stale-acceptance-criteria` Done-when item 2 still asks for a bind retry that the Log refuted
  Log entry 2 establishes the bind succeeds before readiness is published and concludes retrying the
  bind "would have changed nothing", but Done-when still reads "either retries its bind or is given a
  port it does not have to race for". Restate it as the atomic readiness publish the plan actually builds.
- **PQ-4** [Important] `race-fix-without-deterministic-test` Mechanism 2 is verified only by ten suite runs; no test exercises the new readiness guard
  Name start_server (tests/integration/chat_progress_process_spec.lua:28) as the unit under test and
  give one strategy line: drive its readiness wait against a writer that publishes a zero-byte file
  before the port digits, and assert it waits or fails by name rather than nil-concatenating. Repetition
  is weak evidence for a roughly 1-in-5 race.
- **PQ-5** [Important] `unstated-design-alternative` Permanent ban on repo-root traversal adopted without stating why scratch stays inside the repo
  TEST_TMP is $(CURDIR)/.test-tmp (Makefile.parley:27) and tests/minimal_init.vim:21 puts nvim swap
  files there, so eight parallel jobs churn the repo tree. That placement is also the direct cause of
  Log entry 4's sandbox git-init failure. Moving TEST_TMP outside $(CURDIR) would close mechanism 1
  generally and make the fitness function unnecessary; state why it was rejected, and add the plan's
  other non-goals explicitly.

## Round 2 — 2026-08-21T22:59:51-07:00 (claude) — passed

### Disposed

- PQ-1 — addressed — Fix relocated from the traversers to the churner; Non-goals names grep/ack/find and why they are untouched.
- PQ-2 — addressed — Fitness function withdrawn in Non-goals with the false-positive and line-wise-grep blindness both stated.
- PQ-3 — addressed — Done-when restated as atomic readiness publish plus parseable-port wait, matching Log entry 2.
- PQ-4 — addressed — wait_for_port named as the unit under test with absent/incomplete/garbage input class and a named-failure guard.
- PQ-5 — addressed — Scratch root moves outside $(CURDIR); Non-goals now records parallelism, tool-spec rewrites, and sandbox git init.

## Open findings

(none — every finding has been disposed)
