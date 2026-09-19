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
    - "n": 3
      timestamp: "2026-09-19T00:36:19-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: 'W13 now names all ten Deferred owners with a scope reason each (verified: nine live owners plus the deleted chat_recovery:258); W16 corrected to response_topic.lua:80 from :154 with s.started at :59 — all three line references check out.'
          round: 3
        - id: BR-2
          disposition: addressed
          note: Task 3.3 now names tasker_run_spec.lua, its 43 option-less calls (grep -c confirms 43) and a re-grep that would also surface chat_async_tools_spec.
          round: 3
        - id: BR-3
          disposition: addressed
          note: Task 5.4's inventory now names the legacy directory as safe to delete; the page it belongs to does not exist until M5, so deferring it there is the right home.
          round: 3
        - id: BR-4
          disposition: withdrawn
          note: Operator decision recorded in the plan's Revisions with an explicit authority rule; the divergence it predicted has already appeared (Task 1.4's body lacks the schema arg) and that rule governs it — see the plan-revision recommendation rather than re-raising.
          round: 3
        - id: BR-5
          disposition: addressed
          note: read_authored/load split plus A2b/A2c pin the file-preservation half; the writes/preserve declaration is enforced by the census. The refusal half it introduced is now C1.
          round: 3
        - id: BR-6
          disposition: addressed
          note: 'Verified by counterfactual: an untracked lua/parley/zz_probe_reader.lua returning config.state_dir turns the census red, and arch_helper_spec fails any arch spec that lists through the index.'
          round: 3
        - id: BR-7
          disposition: addressed
          note: conform emits one warning per call with a count and a five-path sample; 300 bad leaves produce exactly one (helper_io_spec). The per-call-per-item level above it is I1.
          round: 3
        - id: BR-8
          disposition: addressed
          note: submits() nils parley._remote_reference_cache immediately before the command, so resolve_remote_references reads the corrupt file on the submission path (get_chat_remote_reference_cache is unconditional at chat_respond.lua:1200).
          round: 3
        - id: BR-9
          disposition: addressed
          note: The vault exercise drives tests/helpers/fake_process.lua behind tasker._uv on a fresh module instance, restoring both; nothing leaks into the shared vault module.
          round: 3
        - id: BR-10
          disposition: addressed
          note: Carried into the plan as M4 row W18 with both options named and a cancellation-during-finalize test.
          round: 3
        - id: BR-11
          disposition: addressed
          note: sidecar_degrade_spec builds a `cases` list and iterates it with ipairs. A new instance appeared elsewhere in the same commit — see the Minor.
          round: 3
        - id: BR-12
          disposition: addressed
          note: The exit-code assertion moved next to its systemlist call inside arch_helper.worktree_files; the census now asserts a floor on the hit count instead.
          round: 3
        - id: BR-13
          disposition: addressed
          note: atlas/providers/tool_execution.md:11-19, :142-147 and :194-209 are reflowed; no orphan or over-joined line remains in the touched paragraphs.
          round: 3
      findings:
        - id: BR-14
          severity: Critical
          title: custom_prompts.set's new false return is dropped by the prompt editor, which clears `modified` and reports "System prompt saved"
          detail: |-
            2nd in this family — fix the rule, not the site: every call reporting whether an effect
            happened must be consumed by whatever tells the user it happened. Enumeration to sweep:
            helper.table_to_file (returns nothing on open failure), custom_prompts.save/set/remove,
            system_prompt_picker.lua:104 and :197, plus the W18 handle. Reproduced live: with an
            unreadable custom_system_prompts.json, :w on an edited prompt leaves the file untouched,
            sets modified=false (bufhidden=wipe then discards the text) and notifies "System prompt
            saved: mine". Before this diff the same path raised and the edit survived. Needs a
            picker-level regression test that fails without the fix.
          family: returned-handle-has-no-consumer
          round: 3
        - id: BR-15
          severity: Important
          title: custom_prompts.load re-reads and re-conforms the file on every call, and the picker calls it once per prompt
          detail: |-
            2nd in this family — BR-7 fixed the per-field warning; the call itself is per item.
            system_prompt_picker.lua:20 calls source() -> get() -> load() for every prompt. Measured on
            this HEAD: one wrongly typed entry gives 5 warnings per picker build, an unreadable file
            gives 10, scaling with the user's prompt count; each is a log-file open plus a vim.notify.
            The rule: a diagnostic about a file's contents belongs to that file's parse, and a parse
            belongs to a user action, never to a loop iteration. Enforce it where the family can be
            caught wholesale — count logger.warning calls per exercise in sidecar_degrade_spec and
            assert at most one per file.
          family: per-item-diagnostic-unbounded
          round: 3
        - id: BR-16
          severity: Important
          title: vault.lua:215 decodes the copilot token endpoint's body without a pcall, in the function whose file read this diff just hardened
          detail: |-
            curl -s exits 0 on an HTML proxy page or an empty body, so a non-JSON 200 raises inside the
            tasker callback and the continuation that resumes the provider request is never reached.
            It is the only unguarded decode of external process output left in lua/ — all nine siblings
            in oauth.lua are pcall'ed. W6 names the code~=0 and early-return paths that skip the
            callback but not this third one; either pcall it now and call back with the error, or add
            the raise path to W6.
          family: untrusted-input-unparsed
          round: 3
        - id: BR-17
          severity: Minor
          title: helper_io_spec.lua:228 generates its F3b cases by iterating a keyed table with pairs
          detail: |-
            2nd in this family, introduced in the same commit that fixed BR-11's instance, and there is
            no guard to catch the next one. State the rule instead of converting only this site:
            generated `it(` cases iterate an ordered list, never a keyed table — add it to
            workshop/lessons.md beside this round's three entries. A mechanical guard is possible but
            noisy against roughly five pre-existing pairs-driven arch specs, so the lesson plus the two
            conversions is the proportionate class fix.
          family: nondeterministic-test-generation
          round: 3
        - id: BR-18
          severity: Minor
          title: Every M1 step in the durable plan is still unticked, as is the M1 row in the issue's Plan
          detail: |-
            workshop/plans/000261-transcript-is-the-whole-truth-plan.md:277-598 and the issue's
            `- [ ] M1` row. The durable plan is the record of what landed (AGENTS.md section 8); with no
            box ticked a reader cannot tell M1 from M2 by looking at it.
          family: plan-tracking-not-updated
          round: 3
      boundary: M1
      recipe: milestone-review
      blocked: true
    - "n": 4
      timestamp: "2026-09-19T00:50:01-07:00"
      agent: claude
      dispose:
        - id: BR-14
          disposition: addressed
          note: picker.lua:109/173/210/254 consume set/remove/rename; P1 goes red when the fix is reverted in a scratch copy; bare-write guard present. The close-unchecked report gap is raised separately.
          round: 4
        - id: BR-15
          disposition: addressed
          note: _build_items reads once via source(...,loaded); generic per-action bound in sidecar_degrade_spec; revert turns P3 plus 3 degrade cases red.
          round: 4
        - id: BR-16
          disposition: addressed
          note: vault.lua:217 pcall plus type check; W6 names the non-decoding body path; json_decode_spec fails any unguarded vim.json.decode (33 found, all guarded).
          round: 4
        - id: BR-17
          disposition: addressed
          note: helper_io_spec F3b iterates an ordered list; lesson recorded in workshop/lessons.md; no other pairs-driven it( generation in the window's specs.
          round: 4
        - id: BR-18
          disposition: addressed
          note: Chunk 1 steps ticked in the durable plan; the issue's M1 row is ticked by sdlc milestone-close itself (its --help, step 1).
          round: 4
      findings:
        - id: BR-19
          severity: Important
          title: table_to_file drops file:close()'s result, so it reports true for a write that failed at flush and left the file truncated
          detail: '3rd in this family. Reproduced: under ulimit -f 1, table_to_file returned true and left 512 bytes of a 2.8 KB JSON file; table_to_file_atomic returned false with "close failed: File too large". The picker then says "System prompt saved" over a truncated custom_system_prompts.json, losing every authored prompt, and the dispatcher posts a truncated body. DROPPED''s "has already warned" holds only for a failed open. Rule: a success result is derived from the last fallible step of the effect and consumed up to the user-visible claim; no fallible result is dropped on a path that reports success. Class fix: one JSON writer. table_to_file_atomic (helper.lua:596) already checks encode, open, write, close and rename and preserves the original file on failure. Move its 4 production callers (custom_prompts.save, dispatcher.query, vault, chat_respond) to it, retire table_to_file or make it delegate, and extend sidecar_authority_spec to reject non-atomic sidecar writes. Prevalence: 18 write-mode io.open sites in lua/; only this one is in the state-directory family.'
          family: returned-handle-has-no-consumer
          round: 4
        - id: BR-20
          severity: Minor
          title: The copilot token response is typed on token only, while the file read of the same bearer also types expires_at
          detail: '2nd in this family. vault.lua:218 stores the fetched table in V._state, so a non-numeric expires_at raises at :180 on the next request. Rule: one schema per external value, applied at every boundary it crosses. Hoist { token = "string", expires_at = "number" } and apply it to both the file read and the network response.'
          family: untrusted-input-unparsed
          round: 4
        - id: BR-21
          severity: Minor
          title: The dispatcher's new abort for an unwritten request body has no behavioural test
          detail: dispatcher.lua:676-680. Only the bare-write guard would notice a revert; nothing checks that the request stops and the user sees the reason.
          family: behavior-change-without-regression-test
          round: 4
        - id: BR-22
          severity: Minor
          title: json_decode_spec matches only vim.json.decode, and the lesson says it fails any unguarded decode
          detail: '2nd in this family. vim.fn.json_decode (file_tracker.lua:47, currently guarded) escapes the pattern. Rule: a guard''s pattern covers every API that does the job, not just the spelling the finding named.'
          family: enumeration-claims-completeness
          round: 4
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

## Round 3 — 2026-09-19T00:36:19-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — addressed — W13 now names all ten Deferred owners with a scope reason each (verified: nine live owners plus the deleted chat_recovery:258); W16 corrected to response_topic.lua:80 from :154 with s.started at :59 — all three line references check out.
- BR-2 — addressed — Task 3.3 now names tasker_run_spec.lua, its 43 option-less calls (grep -c confirms 43) and a re-grep that would also surface chat_async_tools_spec.
- BR-3 — addressed — Task 5.4's inventory now names the legacy directory as safe to delete; the page it belongs to does not exist until M5, so deferring it there is the right home.
- BR-4 — withdrawn — Operator decision recorded in the plan's Revisions with an explicit authority rule; the divergence it predicted has already appeared (Task 1.4's body lacks the schema arg) and that rule governs it — see the plan-revision recommendation rather than re-raising.
- BR-5 — addressed — read_authored/load split plus A2b/A2c pin the file-preservation half; the writes/preserve declaration is enforced by the census. The refusal half it introduced is now C1.
- BR-6 — addressed — Verified by counterfactual: an untracked lua/parley/zz_probe_reader.lua returning config.state_dir turns the census red, and arch_helper_spec fails any arch spec that lists through the index.
- BR-7 — addressed — conform emits one warning per call with a count and a five-path sample; 300 bad leaves produce exactly one (helper_io_spec). The per-call-per-item level above it is I1.
- BR-8 — addressed — submits() nils parley._remote_reference_cache immediately before the command, so resolve_remote_references reads the corrupt file on the submission path (get_chat_remote_reference_cache is unconditional at chat_respond.lua:1200).
- BR-9 — addressed — The vault exercise drives tests/helpers/fake_process.lua behind tasker._uv on a fresh module instance, restoring both; nothing leaks into the shared vault module.
- BR-10 — addressed — Carried into the plan as M4 row W18 with both options named and a cancellation-during-finalize test.
- BR-11 — addressed — sidecar_degrade_spec builds a `cases` list and iterates it with ipairs. A new instance appeared elsewhere in the same commit — see the Minor.
- BR-12 — addressed — The exit-code assertion moved next to its systemlist call inside arch_helper.worktree_files; the census now asserts a floor on the hit count instead.
- BR-13 — addressed — atlas/providers/tool_execution.md:11-19, :142-147 and :194-209 are reflowed; no orphan or over-joined line remains in the touched paragraphs.

### Raised

- **BR-14** [Critical] `returned-handle-has-no-consumer` custom_prompts.set's new false return is dropped by the prompt editor, which clears `modified` and reports "System prompt saved"
  2nd in this family — fix the rule, not the site: every call reporting whether an effect
  happened must be consumed by whatever tells the user it happened. Enumeration to sweep:
  helper.table_to_file (returns nothing on open failure), custom_prompts.save/set/remove,
  system_prompt_picker.lua:104 and :197, plus the W18 handle. Reproduced live: with an
  unreadable custom_system_prompts.json, :w on an edited prompt leaves the file untouched,
  sets modified=false (bufhidden=wipe then discards the text) and notifies "System prompt
  saved: mine". Before this diff the same path raised and the edit survived. Needs a
  picker-level regression test that fails without the fix.
- **BR-15** [Important] `per-item-diagnostic-unbounded` custom_prompts.load re-reads and re-conforms the file on every call, and the picker calls it once per prompt
  2nd in this family — BR-7 fixed the per-field warning; the call itself is per item.
  system_prompt_picker.lua:20 calls source() -> get() -> load() for every prompt. Measured on
  this HEAD: one wrongly typed entry gives 5 warnings per picker build, an unreadable file
  gives 10, scaling with the user's prompt count; each is a log-file open plus a vim.notify.
  The rule: a diagnostic about a file's contents belongs to that file's parse, and a parse
  belongs to a user action, never to a loop iteration. Enforce it where the family can be
  caught wholesale — count logger.warning calls per exercise in sidecar_degrade_spec and
  assert at most one per file.
- **BR-16** [Important] `untrusted-input-unparsed` vault.lua:215 decodes the copilot token endpoint's body without a pcall, in the function whose file read this diff just hardened
  curl -s exits 0 on an HTML proxy page or an empty body, so a non-JSON 200 raises inside the
  tasker callback and the continuation that resumes the provider request is never reached.
  It is the only unguarded decode of external process output left in lua/ — all nine siblings
  in oauth.lua are pcall'ed. W6 names the code~=0 and early-return paths that skip the
  callback but not this third one; either pcall it now and call back with the error, or add
  the raise path to W6.
- **BR-17** [Minor] `nondeterministic-test-generation` helper_io_spec.lua:228 generates its F3b cases by iterating a keyed table with pairs
  2nd in this family, introduced in the same commit that fixed BR-11's instance, and there is
  no guard to catch the next one. State the rule instead of converting only this site:
  generated `it(` cases iterate an ordered list, never a keyed table — add it to
  workshop/lessons.md beside this round's three entries. A mechanical guard is possible but
  noisy against roughly five pre-existing pairs-driven arch specs, so the lesson plus the two
  conversions is the proportionate class fix.
- **BR-18** [Minor] `plan-tracking-not-updated` Every M1 step in the durable plan is still unticked, as is the M1 row in the issue's Plan
  workshop/plans/000261-transcript-is-the-whole-truth-plan.md:277-598 and the issue's
  `- [ ] M1` row. The durable plan is the record of what landed (AGENTS.md section 8); with no
  box ticked a reader cannot tell M1 from M2 by looking at it.

## Round 4 — 2026-09-19T00:50:01-07:00 (claude) — BLOCKED

### Disposed

- BR-14 — addressed — picker.lua:109/173/210/254 consume set/remove/rename; P1 goes red when the fix is reverted in a scratch copy; bare-write guard present. The close-unchecked report gap is raised separately.
- BR-15 — addressed — _build_items reads once via source(...,loaded); generic per-action bound in sidecar_degrade_spec; revert turns P3 plus 3 degrade cases red.
- BR-16 — addressed — vault.lua:217 pcall plus type check; W6 names the non-decoding body path; json_decode_spec fails any unguarded vim.json.decode (33 found, all guarded).
- BR-17 — addressed — helper_io_spec F3b iterates an ordered list; lesson recorded in workshop/lessons.md; no other pairs-driven it( generation in the window's specs.
- BR-18 — addressed — Chunk 1 steps ticked in the durable plan; the issue's M1 row is ticked by sdlc milestone-close itself (its --help, step 1).

### Raised

- **BR-19** [Important] `returned-handle-has-no-consumer` table_to_file drops file:close()'s result, so it reports true for a write that failed at flush and left the file truncated
  3rd in this family. Reproduced: under ulimit -f 1, table_to_file returned true and left 512 bytes of a 2.8 KB JSON file; table_to_file_atomic returned false with "close failed: File too large". The picker then says "System prompt saved" over a truncated custom_system_prompts.json, losing every authored prompt, and the dispatcher posts a truncated body. DROPPED's "has already warned" holds only for a failed open. Rule: a success result is derived from the last fallible step of the effect and consumed up to the user-visible claim; no fallible result is dropped on a path that reports success. Class fix: one JSON writer. table_to_file_atomic (helper.lua:596) already checks encode, open, write, close and rename and preserves the original file on failure. Move its 4 production callers (custom_prompts.save, dispatcher.query, vault, chat_respond) to it, retire table_to_file or make it delegate, and extend sidecar_authority_spec to reject non-atomic sidecar writes. Prevalence: 18 write-mode io.open sites in lua/; only this one is in the state-directory family.
- **BR-20** [Minor] `untrusted-input-unparsed` The copilot token response is typed on token only, while the file read of the same bearer also types expires_at
  2nd in this family. vault.lua:218 stores the fetched table in V._state, so a non-numeric expires_at raises at :180 on the next request. Rule: one schema per external value, applied at every boundary it crosses. Hoist { token = "string", expires_at = "number" } and apply it to both the file read and the network response.
- **BR-21** [Minor] `behavior-change-without-regression-test` The dispatcher's new abort for an unwritten request body has no behavioural test
  dispatcher.lua:676-680. Only the bare-write guard would notice a revert; nothing checks that the request stops and the user sees the reason.
- **BR-22** [Minor] `enumeration-claims-completeness` json_decode_spec matches only vim.json.decode, and the lesson says it fails any unguarded decode
  2nd in this family. vim.fn.json_decode (file_tracker.lua:47, currently guarded) escapes the pattern. Rule: a guard's pattern covers every API that does the job, not just the spelling the finding named.

## Open findings

- **BR-19** [Important] `returned-handle-has-no-consumer` table_to_file drops file:close()'s result, so it reports true for a write that failed at flush and left the file truncated
- **BR-20** [Minor] `untrusted-input-unparsed` The copilot token response is typed on token only, while the file read of the same bearer also types expires_at
- **BR-21** [Minor] `behavior-change-without-regression-test` The dispatcher's new abort for an unwritten request body has no behavioural test
- **BR-22** [Minor] `enumeration-claims-completeness` json_decode_spec matches only vim.json.decode, and the lesson says it fails any unguarded decode
