---
gate: boundary-review
issue: 365
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 80a6e56b-def6-43fa-a6c3-c95034c669fd
            repository: github.com/xianxu/parley.nvim
            issue_id: "000365"
            recipe: milestone-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/334f9af077b2cfb6
            reviewed_head: d897fc1a33dc1e2832b67f6237e9688f12a7e98a
            slot: parley.nvim:4
            requested_at: "2026-10-17T01:09:06.0834Z"
          phase: finished
          pid: 3055
          started_at: "2026-10-17T01:09:06.251985Z"
          finished_at: "2026-10-17T01:12:52.418892Z"
          session_id: 7dc578d1-8f9e-44ab-ad57-9053abefe8ef
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: d897fc1a33dc1e2832b67f6237e9688f12a7e98a
        tracker_head: f5ab523f97d17b6919184e257ef51478683b727b
        branch_point: e4ba9a07c715f6517597a3761647330afdc4c3de
        since: "2026-10-16T17:17:24-07:00"
        until: "2026-10-16T18:08:44-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T17:17:24-07:00"
              end: "2026-10-16T18:08:44-07:00"
              began: "2026-10-16T17:17:24-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 868e7ef2383e7a2325ecf7e40c3a3dfea7a350a2a950d5225f69a6614c2cd9e4
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 25069416
              windows:
                - start: "2026-10-16T17:17:24-07:00"
                  end: "2026-10-16T18:08:44-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 0.042216666666666666
      "n": 1
      timestamp: "2026-10-16T18:12:55-07:00"
      dispatched: "2026-10-16T18:09:06-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: Allowlist drops credentials and display variables that PARLEY_LIVE_* opt-in specs need (CLIPROXYAPI_API_KEY)
          detail: scripts/test-env.sh passes PARLEY_LIVE_CONFORMANCE but not CLIPROXYAPI_API_KEY, which tests/integration/cliproxy_tool_conformance_spec.lua:53 reads. Its skip message at :120 ("set CLIPROXYAPI_API_KEY then re-run") does nothing under the harness. Let each live opt-in carry its named credentials, or document PARLEY_TEST_ENV_PASS for it, and sweep the other PARLEY_LIVE_* specs (for example DISPLAY for the live clipboard check). ARCH-MOCK / ARCH-PURPOSE.
          family: allowlist-strands-live-optins
          round: 1
        - kind: defect
          id: BR-2
          severity: Important
          title: test-env.sh puts PARLEY_TEST_ENV_PASS credentials into the env -i argument list
          detail: scripts/test-env.sh:60 runs exec /usr/bin/env -i NAME=value ..., so make fixtures exposes the API keys as process arguments (briefly visible in ps). Instead, unset non-allowlisted names in the shell and exec "$@", so values never reach an argument list. ARCH-SECURE.
          family: credential-in-argv
          round: 1
        - kind: defect
          id: BR-3
          severity: Important
          title: Couch --actors live conformance case in couch_spec can no longer run anywhere
          detail: tests/unit/couch_spec.lua:33-45 gates on an ambient Couch thread, which the launcher now always strips, and a bare couch now resolves to the sentinel. No opt-in replaces it, and check-couch-registry-conformance.py does not cover --actors. Add a PARLEY_LIVE_COUCH opt-in that passes the thread names and uses the real binary explicitly, or move the check into the conformance script. ARCH-MOCK.
          family: live-conformance-disabled
          round: 1
        - kind: defect
          id: BR-4
          severity: Minor
          title: No test pins that every target runs SENTINEL_CHECK after its specs
          detail: The launch scan in tests/unit/test_isolation_spec.lua checks only the launcher prefix. A target that drops SENTINEL_CHECK would go unnoticed. I verified the gate manually with a wrapper makefile.
          family: gate-wiring-untested
          round: 1
        - kind: defect
          id: BR-5
          severity: Minor
          title: Concurrent make targets share and truncate a single sentinel.log
          detail: PREP_TEST_ENV empties TEST_ENV_ROOT/sentinel.log for each target, so make -j test-unit test-integration can wipe the other target's evidence. Serial make test is unaffected. ARCH-ORDER.
          family: shared-run-artifact-race
          round: 1
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 2b270b6f-63b8-4810-b65e-27ac49bc36a9
            repository: github.com/xianxu/parley.nvim
            issue_id: "000365"
            recipe: milestone-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/1c805fc94468a4a7
            reviewed_head: 1ce4859ca04e15040e23ecd8d8dc3310993ef5f2
            slot: parley.nvim:4
            requested_at: "2026-10-17T01:16:55.546313Z"
          phase: finished
          pid: 95954
          started_at: "2026-10-17T01:16:55.765734Z"
          finished_at: "2026-10-17T01:21:00.674676Z"
          session_id: 489ed8d2-f399-44ca-924f-c0f1f63d6390
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 1ce4859ca04e15040e23ecd8d8dc3310993ef5f2
        tracker_head: f5ab523f97d17b6919184e257ef51478683b727b
        branch_point: e4ba9a07c715f6517597a3761647330afdc4c3de
        since: "2026-10-16T17:17:24-07:00"
        until: "2026-10-16T18:16:29-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T17:17:24-07:00"
              end: "2026-10-16T18:16:29-07:00"
              began: "2026-10-16T17:17:24-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 08d812ba53702a51006564cbec93936e948686af94080a2219bfeb86bdb3d545
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 25396582
              windows:
                - start: "2026-10-16T17:17:24-07:00"
                  end: "2026-10-16T18:16:29-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 0.042216666666666666
        cuts:
            - dispatched: "2026-10-16T18:09:06-07:00"
              finalized: "2026-10-16T18:12:55-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-16T18:21:01-07:00"
      dispatched: "2026-10-16T18:16:55-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: test-env.sh:29-33 maps each PARLEY_LIVE_* flag to its names; test_isolation_spec.lua:453 goes red without it; swept GITHUB/SHRINK (no extra names needed).
          round: 2
        - id: BR-2
          disposition: addressed
          note: Launcher now builds env -u NAME only; tests/unit/test_isolation_spec.lua:576 forbids NAME=$value argv and the old eval pattern.
          round: 2
        - id: BR-3
          disposition: addressed
          note: make check-couch-actors-live sets PARLEY_LIVE_COUCH; ran it, real_couch() resolved past the sentinel and reached the --actors call (pended only on sandbox socket).
          round: 2
        - id: BR-4
          disposition: addressed
          note: tests/unit/test_isolation_spec.lua:567 requires SENTINEL_CHECK count == orphan-gate count; dropping one goes red.
          round: 2
        - id: BR-5
          disposition: not-addressed
          note: Per-target SENTINEL_LOG (sentinel-$@.log) is in place and plausible, but no test pins it; add a scan asserting SENTINEL_LOG contains $@.
          round: 2
      findings:
        - kind: defect
          id: BR-6
          severity: Minor
          title: PARLEY_LIVE_COUCH is stripped only by RUN_SPEC; test-spec/test-changed/perf/goldens/fixtures pass the real thread to every spec
          detail: 'Makefile.parley:101 strips the flag only for test-unit/test-integration. An ambient PARLEY_LIVE_COUCH=1 with make test-spec makes test-env.sh:33 keep COUCH_THREAD_*/STORE_DIR/ISOLATED_ROOT for every spec, which contradicts atlas "only for make check-couch-actors-live". It fails loudly (sentinel, ambient()). Enforce in the launcher: honour thread-carrying flags only when the target itself sets them.'
          family: live-optin-leaks-into-suite
          round: 2
        - kind: defect
          id: BR-7
          severity: Minor
          title: atlas/infra/test_harness.md:195 still says the launcher runs env -i; the fixtures bullet absorbs the sentinel paragraph
          detail: The launcher now unsets names with env -u (scripts/test-env.sh:41-54). Fix the sentence, and add a blank line after the make fixtures bullet at :206.
          family: atlas-claim-drift
          round: 2
      recipe: milestone-review
      isolation: fenced
      reviewed: 1ce4859ca04e15040e23ecd8d8dc3310993ef5f2
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 52619cbc-f10c-499e-9cbc-d1c616676e11
            repository: github.com/xianxu/parley.nvim
            issue_id: "000365"
            recipe: fix-review
            round: 3
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/346bae5e7aec2329
            reviewed_head: 2999bfba8d35a68d1436e301cc63b61e76ed2f65
            slot: parley.nvim:4
            requested_at: "2026-10-17T01:22:20.07942Z"
          phase: finished
          pid: 20069
          started_at: "2026-10-17T01:22:20.205953Z"
          finished_at: "2026-10-17T01:26:57.563006Z"
          session_id: c4b4b516-7748-4bdf-b6bd-cfec65f1f8cc
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 2999bfba8d35a68d1436e301cc63b61e76ed2f65
        tracker_head: f5ab523f97d17b6919184e257ef51478683b727b
        branch_point: e4ba9a07c715f6517597a3761647330afdc4c3de
        since: "2026-10-16T17:17:24-07:00"
        until: "2026-10-16T18:21:58-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T17:17:24-07:00"
              end: "2026-10-16T18:21:58-07:00"
              began: "2026-10-16T17:17:24-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 340feacd6423f8694ea176461d2c8304bf45b549a679d3435e62f2929da55470
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 25516521
              windows:
                - start: "2026-10-16T17:17:24-07:00"
                  end: "2026-10-16T18:21:58-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 0.042216666666666666
        cuts:
            - dispatched: "2026-10-16T18:09:06-07:00"
              finalized: "2026-10-16T18:12:55-07:00"
              finalizing: false
            - dispatched: "2026-10-16T18:16:55-07:00"
              finalized: "2026-10-16T18:21:01-07:00"
              finalizing: true
      "n": 3
      timestamp: "2026-10-16T18:26:59-07:00"
      dispatched: "2026-10-16T18:22:20-07:00"
      agent: claude
      dispose:
        - id: BR-5
          disposition: addressed
          note: SENTINEL_LOG = $(TEST_ENV_ROOT)/sentinel-$@.log (Makefile.parley:66); PREP_TEST_ENV truncates only the target's own log; new spec asserts $@ in SENTINEL_LOG.
          round: 3
        - id: BR-6
          disposition: addressed
          note: TEST_RUN (Makefile.parley:64), RUN_SPEC and perf all run env -u PARLEY_LIVE_COUCH; only check-couch-actors-live sets it. Scan test pins this; removing the strip from TEST_RUN makes it fail at test_isolation_spec.lua:120.
          round: 3
        - id: BR-7
          disposition: addressed
          note: atlas/infra/test_harness.md:86-88 now says the launcher keeps a fixed list and removes the rest with env -u; blank line added after the make fixtures bullet.
          round: 3
      findings:
        - kind: defect
          id: BR-8
          severity: Minor
          title: scripts/test-env.sh comments still say RUN_SPEC strips PARLEY_LIVE_COUCH and name a single sentinel.log
          detail: 'This is the 2nd finding in family atlas-claim-drift. test-env.sh:31-32 says RUN_SPEC strips the flag, but the BR-6 fix moved the strip into TEST_RUN for every target. The header at :14 still names $PARLEY_TEST_ENV_ROOT/sentinel.log, but each target now writes its own sentinel-<target>.log. Rule: when a fix moves where an invariant is enforced, update every prose restatement of that invariant. Grep for the old enforcer''s name (RUN_SPEC, sentinel.log) across scripts/, Makefile.parley and atlas/ in the same change.'
          family: atlas-claim-drift
          round: 3
      recipe: fix-review
      isolation: fenced
      reviewed: 2999bfba8d35a68d1436e301cc63b61e76ed2f65
      blocked: false
---

# Gate ledger — parley.nvim#365 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T18:12:55-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `allowlist-strands-live-optins` (kind: defect) Allowlist drops credentials and display variables that PARLEY_LIVE_* opt-in specs need (CLIPROXYAPI_API_KEY)
  scripts/test-env.sh passes PARLEY_LIVE_CONFORMANCE but not CLIPROXYAPI_API_KEY, which tests/integration/cliproxy_tool_conformance_spec.lua:53 reads. Its skip message at :120 ("set CLIPROXYAPI_API_KEY then re-run") does nothing under the harness. Let each live opt-in carry its named credentials, or document PARLEY_TEST_ENV_PASS for it, and sweep the other PARLEY_LIVE_* specs (for example DISPLAY for the live clipboard check). ARCH-MOCK / ARCH-PURPOSE.
- **BR-2** [Important] `credential-in-argv` (kind: defect) test-env.sh puts PARLEY_TEST_ENV_PASS credentials into the env -i argument list
  scripts/test-env.sh:60 runs exec /usr/bin/env -i NAME=value ..., so make fixtures exposes the API keys as process arguments (briefly visible in ps). Instead, unset non-allowlisted names in the shell and exec "$@", so values never reach an argument list. ARCH-SECURE.
- **BR-3** [Important] `live-conformance-disabled` (kind: defect) Couch --actors live conformance case in couch_spec can no longer run anywhere
  tests/unit/couch_spec.lua:33-45 gates on an ambient Couch thread, which the launcher now always strips, and a bare couch now resolves to the sentinel. No opt-in replaces it, and check-couch-registry-conformance.py does not cover --actors. Add a PARLEY_LIVE_COUCH opt-in that passes the thread names and uses the real binary explicitly, or move the check into the conformance script. ARCH-MOCK.
- **BR-4** [Minor] `gate-wiring-untested` (kind: defect) No test pins that every target runs SENTINEL_CHECK after its specs
  The launch scan in tests/unit/test_isolation_spec.lua checks only the launcher prefix. A target that drops SENTINEL_CHECK would go unnoticed. I verified the gate manually with a wrapper makefile.
- **BR-5** [Minor] `shared-run-artifact-race` (kind: defect) Concurrent make targets share and truncate a single sentinel.log
  PREP_TEST_ENV empties TEST_ENV_ROOT/sentinel.log for each target, so make -j test-unit test-integration can wipe the other target's evidence. Serial make test is unaffected. ARCH-ORDER.

## Round 2 — 2026-10-16T18:21:01-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — test-env.sh:29-33 maps each PARLEY_LIVE_* flag to its names; test_isolation_spec.lua:453 goes red without it; swept GITHUB/SHRINK (no extra names needed).
- BR-2 — addressed — Launcher now builds env -u NAME only; tests/unit/test_isolation_spec.lua:576 forbids NAME=$value argv and the old eval pattern.
- BR-3 — addressed — make check-couch-actors-live sets PARLEY_LIVE_COUCH; ran it, real_couch() resolved past the sentinel and reached the --actors call (pended only on sandbox socket).
- BR-4 — addressed — tests/unit/test_isolation_spec.lua:567 requires SENTINEL_CHECK count == orphan-gate count; dropping one goes red.
- BR-5 — not-addressed — Per-target SENTINEL_LOG (sentinel-$@.log) is in place and plausible, but no test pins it; add a scan asserting SENTINEL_LOG contains $@.

### Raised

- **BR-6** [Minor] `live-optin-leaks-into-suite` (kind: defect) PARLEY_LIVE_COUCH is stripped only by RUN_SPEC; test-spec/test-changed/perf/goldens/fixtures pass the real thread to every spec
  Makefile.parley:101 strips the flag only for test-unit/test-integration. An ambient PARLEY_LIVE_COUCH=1 with make test-spec makes test-env.sh:33 keep COUCH_THREAD_*/STORE_DIR/ISOLATED_ROOT for every spec, which contradicts atlas "only for make check-couch-actors-live". It fails loudly (sentinel, ambient()). Enforce in the launcher: honour thread-carrying flags only when the target itself sets them.
- **BR-7** [Minor] `atlas-claim-drift` (kind: defect) atlas/infra/test_harness.md:195 still says the launcher runs env -i; the fixtures bullet absorbs the sentinel paragraph
  The launcher now unsets names with env -u (scripts/test-env.sh:41-54). Fix the sentence, and add a blank line after the make fixtures bullet at :206.

## Round 3 — 2026-10-16T18:26:59-07:00 (claude) — passed

### Disposed

- BR-5 — addressed — SENTINEL_LOG = $(TEST_ENV_ROOT)/sentinel-$@.log (Makefile.parley:66); PREP_TEST_ENV truncates only the target's own log; new spec asserts $@ in SENTINEL_LOG.
- BR-6 — addressed — TEST_RUN (Makefile.parley:64), RUN_SPEC and perf all run env -u PARLEY_LIVE_COUCH; only check-couch-actors-live sets it. Scan test pins this; removing the strip from TEST_RUN makes it fail at test_isolation_spec.lua:120.
- BR-7 — addressed — atlas/infra/test_harness.md:86-88 now says the launcher keeps a fixed list and removes the rest with env -u; blank line added after the make fixtures bullet.

### Raised

- **BR-8** [Minor] `atlas-claim-drift` (kind: defect) scripts/test-env.sh comments still say RUN_SPEC strips PARLEY_LIVE_COUCH and name a single sentinel.log
  This is the 2nd finding in family atlas-claim-drift. test-env.sh:31-32 says RUN_SPEC strips the flag, but the BR-6 fix moved the strip into TEST_RUN for every target. The header at :14 still names $PARLEY_TEST_ENV_ROOT/sentinel.log, but each target now writes its own sentinel-<target>.log. Rule: when a fix moves where an invariant is enforced, update every prose restatement of that invariant. Grep for the old enforcer's name (RUN_SPEC, sentinel.log) across scripts/, Makefile.parley and atlas/ in the same change.

## Open findings

- **BR-8** [Minor] `atlas-claim-drift` (kind: defect) scripts/test-env.sh comments still say RUN_SPEC strips PARLEY_LIVE_COUCH and name a single sentinel.log
