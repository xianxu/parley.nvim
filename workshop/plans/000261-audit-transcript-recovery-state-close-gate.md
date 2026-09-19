---
gate: boundary-review
issue: 261
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-19T00:15:18-07:00"
      agent: sdlc
      findings:
        - id: BR-1
          severity: Minor
          title: W13 claims its query's full output but lists 5 of the 10 Deferred owners
          detail: |-
            The stated query returns document/init.lua:67, diagnostic_refresh.lua:216,
            tool_folds.lua:468 and outline.lua:289 besides the five named; say why they
            are out of scope rather than asserting the list is the query. Same table:
            W16 cites response_topic.lua:142, but the throwing provider.request is at
            :80 (called from :154) with s.started set at :59.
            (carried from plan-quality PQ-1, deferred to the boundary review)
          family: enumeration-claims-completeness
          round: 1
        - id: BR-2
          severity: Minor
          title: Task 3.3's refusal of deadline-less unscoped runs reddens 43 untouched test call sites
          detail: |-
            tests/integration/tasker_run_spec.lua calls tasker.run 43 times with no opts
            table, so every one is unscoped with no deadline_ms. M3's file lists name
            only tasker_supervision_spec and tasker_unit_spec.
            (carried from plan-quality PQ-2, deferred to the boundary review)
          family: seam-change-collateral
          round: 1
        - id: BR-3
          severity: Minor
          title: The legacy answer-recovery directory loses its last mention along with its last reader
          detail: |-
            M1 deletes every reader and removes the README sentence, leaving up to
            256 MiB of answer snapshots on disk that nothing names. One line in
            atlas/chat/transcript_truth.md naming the path and saying it is safe to
            delete satisfies ARCH-FUNERAL without reopening the no-migration decision.
            (carried from plan-quality PQ-3, deferred to the boundary review)
          family: residue-names-no-end
          round: 1
        - id: BR-4
          severity: Minor
          title: Full implementation bodies and per-case test enumerations pre-image code that lands within the hour
          detail: |-
            Tasks 1.4, 2.2, 2.3 and 2.6 embed the implementation verbatim, and most
            tasks enumerate test cases in prose. The function names, the one-line
            strategy per risky function, the counterfactuals and the census specs are
            the durable part. The removal tables are exempt: each carries its
            re-run query and a correct-the-table-first instruction.
            (carried from plan-quality PQ-4, deferred to the boundary review)
          family: plan-restates-the-diff
          round: 1
      boundary: '*'
      no_cap: true
      blocked: false
    - "n": 2
      timestamp: "2026-09-19T00:15:18-07:00"
      agent: claude
      findings:
        - id: BR-5
          severity: Important
          title: custom_prompts.load() prunes the map that set/remove/rename write back, erasing hand-edited prompts
          detail: |-
            load() drops any entry whose system_prompt is not a string; set/remove/rename
            all do load() -> mutate -> save(all), so the dropped entry is written out of
            existence. Probed on the branch: a prompt with an array system_prompt vanishes
            from custom_system_prompts.json on the next set(), with no message naming it.
            Both consumers already guard type(prompt)=='table' and prompt.system_prompt, so
            filter the view, not the table that gets persisted.
          family: read-filter-destroys-source
          round: 2
        - id: BR-6
          severity: Important
          title: The state_dir reader census greps the git index, so an untracked new reader escapes it
          detail: |-
            tests/arch/sidecar_authority_spec.lua:15 uses `git grep -l -e state_dir -- lua/`.
            Adding lua/parley/zz_probe_reader.lua returning config.state_dir leaves the census
            3/3 green; only after `git add -N` does it fail. The guard therefore never fires
            during the loop that introduces a reader. The plan's own counterfactual passed only
            because it edited an already-tracked file. Use `git grep --untracked` or the
            find-based form already used by single_resolver_spec / untrusted_path_spec.
          family: guard-scans-index-not-worktree
          round: 2
        - id: BR-7
          severity: Important
          title: conform emits one logger.warning per dropped field over the unbounded remote-reference cache
          detail: |-
            logger.warning (logger.lua:89-101) opens and writes the log file synchronously and
            schedules a vim.notify on every call. chat_respond.lua:268-271 runs conform once per
            cached chat and once per cached URL, and the audit records that remote_reference_cache.json
            is never pruned. A file whose leaves are all wrongly typed yields N log opens and N
            notifications on the first submission of the session - a hit-enter storm from a sidecar,
            the class M1 exists to remove. Aggregate into one warning per conform call.
          family: per-item-diagnostic-unbounded
          round: 2
        - id: BR-8
          severity: Minor
          title: The degrade spec does not exercise the remote-reference cache on the submission path
          detail: |-
            Task 1.4 Step 3 called for a question carrying a remote reference with oauth.fetch_content
            stubbed. The spec's fixture question has none, and exercise() has already warmed
            parley._remote_reference_cache before submits() runs, so the submit-path arm of the read
            is never taken. resolve_remote_references is called unconditionally at chat_respond.lua:1595,
            so nil-ing the cache immediately before submits() closes it in one line. The deviation is
            not in the issue's Log.
          family: plan-step-not-as-specified
          round: 2
        - id: BR-9
          severity: Minor
          title: The vault sidecar exercise replaces tasker.run wholesale instead of using the fake_process seam
          detail: |-
            tests/helpers/sidecars.lua:34 swaps tasker.run for a callback-invoking stub rather than
            driving tests/helpers/fake_process.lua behind tasker._uv, so the real tasker path is not
            exercised (ARCH-MOCK). vault.add_secret("copilot", ...) also mutates module state that is
            never restored.
          family: stateless-double-at-stateful-seam
          round: 2
        - id: BR-10
          severity: Minor
          title: The finalize adapter's returned cancel handle is discarded by the runner
          detail: |-
            chat_respond.lua:1653 returns {cancel = ...}, but generation_runner.lua:502 does
            `local ok,err=pcall(s.adapters.finalize,ctx,complete)` and reads the second value only
            when ok is false. The cancel path it wires is unreachable; cancellation during finalization
            relies solely on response_completion's own D.subscribe and ctx.cancelled. Pre-existing shape
            carried by the plan's body - M4 should wire it or drop it.
          family: returned-handle-has-no-consumer
          round: 2
        - id: BR-11
          severity: Minor
          title: sidecar_degrade_spec generates its cases by iterating a keyed table with pairs
          detail: |-
            tests/integration/sidecar_degrade_spec.lua:60 iterates `bodies` with pairs, so the order
            of generated tests varies between runs. A list of {label, body} pairs with ipairs is stable.
          family: nondeterministic-test-generation
          round: 2
        - id: BR-12
          severity: Minor
          title: The census asserts vim.v.shell_error in an it body while the command ran in the describe body
          detail: |-
            tests/arch/sidecar_authority_spec.lua:20 checks a global that any intervening shell call
            could have overwritten. Capture the exit code next to the systemlist call.
          family: assertion-detached-from-its-call
          round: 2
        - id: BR-13
          severity: Minor
          title: tool_execution.md left an orphaned short line and two over-joined lines after the carve-out removal
          detail: |-
            atlas/providers/tool_execution.md:12 is a two-word orphan line; :142 and :200 were joined
            into long single lines by the deletions. Reflow those three paragraphs.
          family: docs-reflow-after-deletion
          round: 2
      boundary: M1
      recipe: milestone-review
      blocked: true
---

# Gate ledger — parley.nvim#261 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-19T00:15:18-07:00 (sdlc) — passed

### Raised

- **BR-1** [Minor] `enumeration-claims-completeness` W13 claims its query's full output but lists 5 of the 10 Deferred owners
  The stated query returns document/init.lua:67, diagnostic_refresh.lua:216,
  tool_folds.lua:468 and outline.lua:289 besides the five named; say why they
  are out of scope rather than asserting the list is the query. Same table:
  W16 cites response_topic.lua:142, but the throwing provider.request is at
  :80 (called from :154) with s.started set at :59.
  (carried from plan-quality PQ-1, deferred to the boundary review)
- **BR-2** [Minor] `seam-change-collateral` Task 3.3's refusal of deadline-less unscoped runs reddens 43 untouched test call sites
  tests/integration/tasker_run_spec.lua calls tasker.run 43 times with no opts
  table, so every one is unscoped with no deadline_ms. M3's file lists name
  only tasker_supervision_spec and tasker_unit_spec.
  (carried from plan-quality PQ-2, deferred to the boundary review)
- **BR-3** [Minor] `residue-names-no-end` The legacy answer-recovery directory loses its last mention along with its last reader
  M1 deletes every reader and removes the README sentence, leaving up to
  256 MiB of answer snapshots on disk that nothing names. One line in
  atlas/chat/transcript_truth.md naming the path and saying it is safe to
  delete satisfies ARCH-FUNERAL without reopening the no-migration decision.
  (carried from plan-quality PQ-3, deferred to the boundary review)
- **BR-4** [Minor] `plan-restates-the-diff` Full implementation bodies and per-case test enumerations pre-image code that lands within the hour
  Tasks 1.4, 2.2, 2.3 and 2.6 embed the implementation verbatim, and most
  tasks enumerate test cases in prose. The function names, the one-line
  strategy per risky function, the counterfactuals and the census specs are
  the durable part. The removal tables are exempt: each carries its
  re-run query and a correct-the-table-first instruction.
  (carried from plan-quality PQ-4, deferred to the boundary review)

## Round 2 — 2026-09-19T00:15:18-07:00 (claude) — BLOCKED

### Raised

- **BR-5** [Important] `read-filter-destroys-source` custom_prompts.load() prunes the map that set/remove/rename write back, erasing hand-edited prompts
  load() drops any entry whose system_prompt is not a string; set/remove/rename
  all do load() -> mutate -> save(all), so the dropped entry is written out of
  existence. Probed on the branch: a prompt with an array system_prompt vanishes
  from custom_system_prompts.json on the next set(), with no message naming it.
  Both consumers already guard type(prompt)=='table' and prompt.system_prompt, so
  filter the view, not the table that gets persisted.
- **BR-6** [Important] `guard-scans-index-not-worktree` The state_dir reader census greps the git index, so an untracked new reader escapes it
  tests/arch/sidecar_authority_spec.lua:15 uses `git grep -l -e state_dir -- lua/`.
  Adding lua/parley/zz_probe_reader.lua returning config.state_dir leaves the census
  3/3 green; only after `git add -N` does it fail. The guard therefore never fires
  during the loop that introduces a reader. The plan's own counterfactual passed only
  because it edited an already-tracked file. Use `git grep --untracked` or the
  find-based form already used by single_resolver_spec / untrusted_path_spec.
- **BR-7** [Important] `per-item-diagnostic-unbounded` conform emits one logger.warning per dropped field over the unbounded remote-reference cache
  logger.warning (logger.lua:89-101) opens and writes the log file synchronously and
  schedules a vim.notify on every call. chat_respond.lua:268-271 runs conform once per
  cached chat and once per cached URL, and the audit records that remote_reference_cache.json
  is never pruned. A file whose leaves are all wrongly typed yields N log opens and N
  notifications on the first submission of the session - a hit-enter storm from a sidecar,
  the class M1 exists to remove. Aggregate into one warning per conform call.
- **BR-8** [Minor] `plan-step-not-as-specified` The degrade spec does not exercise the remote-reference cache on the submission path
  Task 1.4 Step 3 called for a question carrying a remote reference with oauth.fetch_content
  stubbed. The spec's fixture question has none, and exercise() has already warmed
  parley._remote_reference_cache before submits() runs, so the submit-path arm of the read
  is never taken. resolve_remote_references is called unconditionally at chat_respond.lua:1595,
  so nil-ing the cache immediately before submits() closes it in one line. The deviation is
  not in the issue's Log.
- **BR-9** [Minor] `stateless-double-at-stateful-seam` The vault sidecar exercise replaces tasker.run wholesale instead of using the fake_process seam
  tests/helpers/sidecars.lua:34 swaps tasker.run for a callback-invoking stub rather than
  driving tests/helpers/fake_process.lua behind tasker._uv, so the real tasker path is not
  exercised (ARCH-MOCK). vault.add_secret("copilot", ...) also mutates module state that is
  never restored.
- **BR-10** [Minor] `returned-handle-has-no-consumer` The finalize adapter's returned cancel handle is discarded by the runner
  chat_respond.lua:1653 returns {cancel = ...}, but generation_runner.lua:502 does
  `local ok,err=pcall(s.adapters.finalize,ctx,complete)` and reads the second value only
  when ok is false. The cancel path it wires is unreachable; cancellation during finalization
  relies solely on response_completion's own D.subscribe and ctx.cancelled. Pre-existing shape
  carried by the plan's body - M4 should wire it or drop it.
- **BR-11** [Minor] `nondeterministic-test-generation` sidecar_degrade_spec generates its cases by iterating a keyed table with pairs
  tests/integration/sidecar_degrade_spec.lua:60 iterates `bodies` with pairs, so the order
  of generated tests varies between runs. A list of {label, body} pairs with ipairs is stable.
- **BR-12** [Minor] `assertion-detached-from-its-call` The census asserts vim.v.shell_error in an it body while the command ran in the describe body
  tests/arch/sidecar_authority_spec.lua:20 checks a global that any intervening shell call
  could have overwritten. Capture the exit code next to the systemlist call.
- **BR-13** [Minor] `docs-reflow-after-deletion` tool_execution.md left an orphaned short line and two over-joined lines after the carve-out removal
  atlas/providers/tool_execution.md:12 is a two-word orphan line; :142 and :200 were joined
  into long single lines by the deletions. Reflow those three paragraphs.

## Open findings

- **BR-1** [Minor] `enumeration-claims-completeness` W13 claims its query's full output but lists 5 of the 10 Deferred owners
- **BR-2** [Minor] `seam-change-collateral` Task 3.3's refusal of deadline-less unscoped runs reddens 43 untouched test call sites
- **BR-3** [Minor] `residue-names-no-end` The legacy answer-recovery directory loses its last mention along with its last reader
- **BR-4** [Minor] `plan-restates-the-diff` Full implementation bodies and per-case test enumerations pre-image code that lands within the hour
- **BR-5** [Important] `read-filter-destroys-source` custom_prompts.load() prunes the map that set/remove/rename write back, erasing hand-edited prompts
- **BR-6** [Important] `guard-scans-index-not-worktree` The state_dir reader census greps the git index, so an untracked new reader escapes it
- **BR-7** [Important] `per-item-diagnostic-unbounded` conform emits one logger.warning per dropped field over the unbounded remote-reference cache
- **BR-8** [Minor] `plan-step-not-as-specified` The degrade spec does not exercise the remote-reference cache on the submission path
- **BR-9** [Minor] `stateless-double-at-stateful-seam` The vault sidecar exercise replaces tasker.run wholesale instead of using the fake_process seam
- **BR-10** [Minor] `returned-handle-has-no-consumer` The finalize adapter's returned cancel handle is discarded by the runner
- **BR-11** [Minor] `nondeterministic-test-generation` sidecar_degrade_spec generates its cases by iterating a keyed table with pairs
- **BR-12** [Minor] `assertion-detached-from-its-call` The census asserts vim.v.shell_error in an it body while the command ran in the describe body
- **BR-13** [Minor] `docs-reflow-after-deletion` tool_execution.md left an orphaned short line and two over-joined lines after the carve-out removal
