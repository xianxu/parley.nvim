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
    - "n": 5
      timestamp: "2026-09-19T01:16:00-07:00"
      agent: claude
      dispose:
        - id: BR-19
          disposition: addressed
          note: table_to_file delegates to table_to_file_atomic (helper.lua:580-587); F3f goes red when the old writer is restored. The sidecar-spec extension was not added, but it is moot while the only JSON writer checks every step.
          round: 5
        - id: BR-20
          disposition: not-addressed
          note: BEARER_SCHEMA is applied to the response (vault.lua:223-225), but deleting that conform call leaves sidecar_degrade (14), vault_spec (27) and sidecar_authority (5) all green. Drive the fake_process curl with stdout of token "t" and a string expires_at, and assert the next refresh re-fetches instead of raising.
          round: 5
        - id: BR-21
          disposition: addressed
          note: 'R1 (dispatcher_query_spec.lua:136) goes red when the abort is removed: curl is not started and the reason reaches on_exit.'
          round: 5
        - id: BR-22
          disposition: addressed
          note: decodes() matches both APIs. A planted unguarded vim.fn.json_decode line was reported as lua/parley/file_tracker.lua:183.
          round: 5
      findings:
        - id: BR-23
          severity: Minor
          title: Routing table_to_file through the rename-based writer replaces symlinked sidecars, resets permissions, and leaves crash files the query cleanup never deletes
          detail: '2nd in this family. Rule: changing a shared seam''s contract means listing each caller, what it relied on from the old contract, and which of those the new contract keeps, all in the same change. The old io.open("w") wrote through a symlink and kept the file''s mode. Reproduced: a symlinked custom_system_prompts.json became a regular 0644 file and its 0600 dotfiles target kept the old prompt. A user-restricted vault_state.json (bearer cache) also reverts to 0644. A crash mid-write now leaves *.json.tmp-* files that the query cleanup (dispatcher.lua:71, glob *.json) never matches (ARCH-FUNERAL). Fix at the one writer: resolve an existing destination with uv.fs_realpath, create the temp file beside the real target, and copy its mode before the rename. Make the query cleanup also match *.json.tmp-*. Add helper_io tests for the symlink and the mode.'
          family: seam-change-collateral
          round: 5
        - id: BR-24
          severity: Minor
          title: The sidecar census finds readers by the text state_dir, so file_access.json escapes it, and a wrongly typed entry makes opening a chat raise
          detail: '3rd in this family. Rule: a guard that claims to cover a class selects members by the property that defines the class, not by how one member happens to be spelled. Here the class is files persisted across sessions and read back by a chat action. file_tracker.lua:23 builds its own path under stdpath("data")/parley. open_buf (init.lua:3112) then calls track_file_access, which raises "attempt to index a number value" (:92, reproduced) on {"/a.md": 3}. Quit and reopen does not clear it. The same module has a second, non-atomic JSON writer (:70) that returns true regardless of the write result. Measured: grepping for stdpath( in lua/ finds one more session-persisted JSON reader on the chat path, this one. Fix the rule: derive every profile sidecar''s path from one helper (or from state_dir), have the census select on that, add file_access.json to tests/helpers/sidecars.lua with a schema, and write it through table_to_file.'
          family: enumeration-claims-completeness
          round: 5
      boundary: M1
      recipe: milestone-review
      blocked: false
    - "n": 6
      timestamp: "2026-09-19T01:56:43-07:00"
      agent: claude
      findings:
        - id: BR-25
          severity: Important
          title: Task 2.6's loaded-target move_chat_tree test is missing, and the Log claims the task landed as planned
          detail: 'The plan requires a test that the branch-link rewrite at init.lua:3798, with the target loaded, rewrites the buffer and does not write the file under it. No such test exists. Counterfactual: forcing live=false plus readfile in move_chat_tree (write the file under the live buffer, never update the buffer) leaves all 10 specs reaching move_chat_tree green. The sub-chat cases also call _collect_ancestor_messages instead of submitting in C, and neither gap is in the Log''s deviation list. Second finding in this family. Rule: before milestone-close, every Step-1 test bullet maps to a named test in the diff or to a logged deviation, and a bullet with neither blocks the close. Add the test and put the rule in workshop/lessons.md.'
          family: plan-step-not-as-specified
          round: 6
        - id: BR-26
          severity: Important
          title: chat_lines fixes the bufnr(path) partial-match defect at 1 of 5 sites; 4 remain, one confirmed to destroy a buffer
          detail: 'Still using bufnr(<name>): init.lua:4405 and 4428 (child topic after a prune), outline.lua:407 and system_prompt_picker.lua:83. Verified on nvim 0.11.7: bufnr of parley://system_prompt/foo returns the foobar buffer, which line 85 force-deletes, discarding its unsaved edits. The plan''s consumer list for chat_lines carries no query, against its own header rule. Fourth finding in this family. Rule: a site list comes from a recorded query, and a primitive-class query becomes an arch guard. Split the exact-name lookup out of chat_lines, route all four sites through it, and add a guard failing any vim.fn.bufnr(arg) outside the helper.'
          family: enumeration-claims-completeness
          round: 6
        - id: BR-27
          severity: Minor
          title: lifecycle.md scopes the stale exemption to a regeneration; the code exempts every generation's owned writes
          detail: state.lua exempts any other generation's write inside its own live grant, including a first answer and topic header writes, as ownership.md and document.md say. A request captured mid-stream of a first answer took partial text, and its tool rounds now continue without the stale pause. lifecycle.md's rationale (the previous answer stays valid) does not cover that case; state the broader rule and why that capture is final.
          family: rule-statement-scope-drift
          round: 6
        - id: BR-28
          severity: Minor
          title: Several exchanges regenerating at once are pinned only at the coordinator, not in substitution or a request
          detail: document_previous_answer_spec lists two slots, but no test runs previous_answer.substitute with two entries, or a request carrying both old answers. The behavior is correct when probed; add one pure two-entry case.
          family: done-when-clause-untested
          round: 6
        - id: BR-29
          severity: Minor
          title: The capture-then-late-build test restores its resolve_remote_references stub outside a protected call
          detail: A timeout in wait_for(held) leaks the stub into every later test in chat_respond_spec. with_json_yaml in the same file already restores through pcall.
          family: stub-restored-outside-finally
          round: 6
      boundary: M2
      recipe: milestone-review
      blocked: true
    - "n": 7
      timestamp: "2026-09-19T02:12:56-07:00"
      agent: claude
      dispose:
        - id: BR-25
          disposition: addressed
          note: Bullet withdrawn with a verified reason (a timestamped ref resolves to the moved file, so ref_abs==old_abs never matches), parley#270 filed, sub-chat seam deviation logged, lessons rule added. The stand-in test is raised separately.
          round: 7
        - id: BR-26
          disposition: addressed
          note: All 5 sites use helper.buffer_for. A grep for every bufname-style primitive finds no other offenders. Reverting the picker lookup turns P4 and the arch guard red.
          round: 7
        - id: BR-27
          disposition: addressed
          note: lifecycle.md now states the rule for every generated write and why an earlier capture is final. This matches state.lua, where owner must be a valid grant containing the edit.
          round: 7
        - id: BR-28
          disposition: addressed
          note: A pure two-entry substitute test with out-of-order entries now pins conversation order.
          round: 7
        - id: BR-29
          disposition: addressed
          note: The resolve_remote_references stub is restored after a pcall-wrapped wait. No other stub in this window's tests is restored outside a protected call.
          round: 7
      findings:
        - id: BR-30
          severity: Important
          title: The BR-25 stand-in test passes only because its chat is a nofile scratch buffer; with a real chat buffer the tree move saves it and aborts with ENOENT
          detail: 'chat_move_spec create_chat uses nvim_create_buf(false, true), so the silent! write in sync_moved_chat_buffers (init.lua:3146) fails silently and the file looks untouched. Reproduced with bufadd plus bufload: the write fires, the save hook slug-renames tree-root.md to move-test.md, and os.rename fails with No such file or directory, aborting move_chat_tree. That abort predates this window, but the new test asserts the opposite. Second in this family. Rule: a test stand-in must have every behavior the code under test branches on; build chat buffers the way production does, not as a named scratch buffer. Prevalence: 14 spec files name a scratch buffer as a chat, and 1 (chat_move_spec) also runs a writing path. Fix: use a file-backed buffer, record the ENOENT repro in parley#270 or a new issue, and either assert the real behavior or delete the stand-in. Also correct the Log line saying a characterization stands in.'
          family: stateless-double-at-stateful-seam
          round: 7
        - id: BR-31
          severity: Minor
          title: buffer_lookup_spec matches only the first vim.fn.bufnr call on a line, and only when the call fits on one line
          detail: 'There are no offenders today. The wider class of name-matching functions (bufwinnr, bufwinid, bufname, getbufvar) cannot be checked statically, because their number-argument forms are legitimate. The rule is the BR-24 one: a guard selects members by the class property. Here the property can only be checked by spelling, so record that limit in the guard''s header comment.'
          family: enumeration-claims-completeness
          round: 7
      boundary: M2
      recipe: milestone-review
      blocked: true
    - "n": 8
      timestamp: "2026-09-19T02:40:57-07:00"
      agent: claude
      dispose:
        - id: BR-30
          disposition: addressed
          note: Stand-in deleted (chat_move_spec is net-zero across the window); plan Revisions + issue Log record the withdrawal, and parley#270's Log carries the ENOENT repro and the 14-spec fixture prevalence.
          round: 8
        - id: BR-31
          disposition: addressed
          note: tests/arch/buffer_lookup_spec.lua:7-12 states the limit — checks by spelling, first call per line, single-line calls, and names the statically-uncheckable siblings.
          round: 8
      findings:
        - id: BR-32
          severity: Important
          title: The new generated-write staleness exemption is pinned only on its positive side; a cross-generation write that escapes its grant has no test
          detail: 'state.lua:294 computes `generated` from the `owner` that line 267 nils when the grant is revoked or does not contain the edit; that nil''ing is the whole safety of the exemption. Both new cases use a contained, valid grant, and the existing ''invalid owners'' case uses the reader''s OWN grant, where `generated` is false regardless. Probed against HEAD: writer grant 10..20, reader dep 0..30 — an observed_edit{first=9,last=10,owner_grant=writer} still stales the reader (true), as does a write whose grant was revoked first (true). Correct today, unpinned. Move `generated` above line 267 and captured input silently stops going stale with nothing red. Add two unit cases: writer''s owned edit outside its grant, and writer''s grant revoked, reader stale in both.'
          family: exemption-boundary-untested
          round: 8
        - id: BR-33
          severity: Minor
          title: D.set_previous_answer returns a did-it-happen boolean that chat_respond.lua:1545 drops as a bare statement
          detail: 'This is the 4th finding in family returned-handle-has-no-consumer. Earlier rounds fixed instances. Do NOT fix this instance. The rule is already written (workshop/lessons.md, M1 round 2: a "did it happen?" result must be consumed by whoever tells the user), but its guard, tests/arch/sidecar_authority_spec.lua:69-91, enumerates members by spelling — `table_to_file`, `table_to_file_atomic`, `custom_prompts.*` — so every new boolean-returning API is a fresh instance. Measured prevalence: the guard covers 3 named call shapes; this window added a 4th boolean-returning API outside them. Fix the rule, per BR-24: select guard members by the class property (a function annotated ---@return boolean meaning "did it happen") rather than by name, or drop the boolean and have set_previous_answer warn on refusal. A silent false here means the next request carries the buffer''s partial text as an earlier answer with no message.'
          family: returned-handle-has-no-consumer
          round: 8
        - id: BR-34
          severity: Minor
          title: buffer_for's private key() adds an 11th copy of the resolve(fnamemodify(x,':p')) path-canonicalisation idiom
          detail: 'helper.lua:694-697 hand-rolls the same canonicalisation that tools/file_refresh.lua:6 already names `canonical`, in the same file whose resolve_chat_path comment (helper.lua:337-341) records that four copies of path resolution drifted and shipped a bug (#225 C3). ARCH-DRY: extract one `helper.canonical_path(name)` and route buffer_for, file_refresh and the eight other `vim.fn.resolve(vim.fn.fnamemodify(...,":p"))` sites through it, so the ~-vs-$VAR and symlink semantics have one definition.'
          family: canonical-form-not-shared
          round: 8
        - id: BR-35
          severity: Minor
          title: The fixture obligation BR-30 deferred to parley#270 lives only in its Log, not in its Done-when contract
          detail: 'This is the 2nd finding in family plan-tracking-not-updated. Do NOT fix this instance alone — state the rule. parley#270''s Log says "Add to this issue''s Done-when: chat_move_spec builds its chats as file-backed buffers … and a tree move of a loaded chat succeeds", but `## Done when` still carries only its two original bullets. The rule that covers both instances: work deferred into a receiving artifact lands in that artifact''s CONTRACT section (`## Done when` / `## Plan`) in the same edit that writes the Log entry, because the Log is narrative and the close gate reads the contract. A deferral recorded only in prose is a deferral the gate cannot enforce.'
          family: plan-tracking-not-updated
          round: 8
      boundary: M2
      recipe: milestone-review
      blocked: true
    - "n": 9
      timestamp: "2026-09-19T02:52:33-07:00"
      agent: claude
      dispose:
        - id: BR-32
          disposition: addressed
          note: document_state_spec.lua:389-401 adds both negative cases; computing `generated` from the raw owner in a scratch copy turns both red (32/34).
          round: 9
        - id: BR-33
          disposition: addressed
          note: 'Fixed as a rule: ---@nodiscard on 7 functions plus nodiscard_spec, which selects by annotation; a planted bare custom_prompts.set goes red; the set_previous_answer drop is declared, with a reason that matches every reachable false path.'
          round: 9
        - id: BR-34
          disposition: not-addressed
          note: helper.lua:694-697 still hand-rolls the idiom (10 copies in lua/); the deferral lives only in the Log and Revisions narrative, with no receiving issue, contrary to the lessons.md rule written in the same commit.
          round: 9
        - id: BR-35
          disposition: addressed
          note: e1540f4a adds the fixture obligation to parley#270's Done when; the rule is recorded in workshop/lessons.md.
          round: 9
      findings:
        - id: BR-36
          severity: Minor
          title: nodiscard_spec only sees calls at the start of a line; three calling forms that drop the result pass green
          detail: 'This is the 6th finding in family enumeration-claims-completeness. Planted and confirmed green: `if c then custom_prompts.set(a, {}) end` on one line, `pcall(custom_prompts.remove, a)`, and `local cp = custom_prompts; cp.rename(a, ''x'')`. The rule is BR-31''s: a regex guard''s header lists the forms it cannot see, and nothing (commit message, lessons.md) claims "any bare-statement call" beyond what is matched. Cheap fixes: match statement starts after then/do/else/semicolon, and pcall/xpcall whose first argument is a member; record the rest in the header. Measured prevalence: 6 findings in the family; 0 live offenders today (all 9 call sites enumerated).'
          family: enumeration-claims-completeness
          round: 9
        - id: BR-37
          severity: Minor
          title: nodiscard_spec's DROPPED count is only a ceiling, so a declaration outlives the call it excuses
          detail: Changing chat_respond.lua:1546 to consume its result leaves the D.set_previous_answer entry silently in place. Sibling guards reject dead entries (single_resolver_spec.lua:79-82, sidecar_authority_spec.lua:69, single_source_sweeps_spec.lua:692). Assert seen == declared.count for every DROPPED entry.
          family: allowlist-without-dead-entry-check
          round: 9
      boundary: M2
      recipe: milestone-review
      blocked: false
    - "n": 10
      timestamp: "2026-09-19T03:51:20-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          round: 10
        - id: BR-2
          disposition: addressed
          round: 10
        - id: BR-3
          disposition: addressed
          round: 10
        - id: BR-4
          disposition: withdrawn
          round: 10
      findings:
        - id: BR-38
          severity: Important
          title: A killed content fetch writes "curl exited with code nil" into the transcript and drops the io_error that names the cause
          detail: |-
            This is the 3rd finding in family `seam-change-collateral`. Do NOT fix
            oauth.lua:1424 alone. The rule: when a seam's contract changes the meaning
            of a value it hands out, sweep every consumer that RENDERS the value, not
            only those that BRANCH on it. Tasker now sets `code = nil` whenever
            `io_error` is set (tasker.lua:504-510); the branchers were swept by
            construction, the renderers were not. The enumeration over tasker exit
            callbacks is four: vault.lua:218 (fixed this round), dispatcher.lua:786
            (already prints io_error), dispatcher.lua:740 (log-only, now reads
            "exit code=nil signal=15"), and oauth.lua:1424 — the only user-visible
            one, which formats tostring(code) into transcript text that is then cached
            as that URL's error. The Done-when clause "User-visible errors identify
            the recoverable action" fails there. unscoped_kill_spec.lua:103 asserts
            only that the body is not used, so it stays green on the bad message.
          family: seam-change-collateral
          round: 10
        - id: BR-39
          severity: Important
          title: README still says Stop keeps running tools and their claims, which M3 inverted
          detail: |-
            This is the 4th finding in family `seam-change-collateral`, and the second
            this round — which is the ledger reporting the enumeration was never
            written. Same rule as above, applied to prose consumers: a contract change
            must sweep every STATEMENT of the old contract, not only the code. The Stop
            contract changed (TERM to the group, SIGKILL at 2 s, claim released on
            resolution). atlas/chat/lifecycle.md and atlas/providers/tool_execution.md
            were updated in this range, tests/manual/chat-concurrency.md was updated,
            README.md:115-117 was not: "while the process supervisor keeps tools that
            are still running and their resource claims". The enumeration a boundary
            needs is "every file that states this contract", produced once, not per
            finding.
          family: seam-change-collateral
          round: 10
        - id: BR-40
          severity: Important
          title: The new atlas section quantifies over every process Parley starts, but five spawn families sit outside the tasker seam
          detail: |-
            This is the 7th finding in family `enumeration-claims-completeness`.
            Earlier rounds fixed instances. Do NOT fix this instance — state the rule
            and fix that. The rule: a statement quantified over a whole category
            ("every process", "all N sites") must either be produced by an executable
            enumeration over that category, or be scoped in words to the seam it
            actually covers. atlas/providers/tool_execution.md:71 says "Every process
            Parley starts is scoped or unscoped" and :113 says tasker.leave() sends
            "SIGKILL to every live process"; its own "Residuals, stated once" list
            names only a kernel hold, a secret command's grandchild, and an nvim
            crash. Measured exceptions: cliproxy.lua:665 (uv.spawn, detached,
            uv.unref, whose docstring says it is spawned to OUTLIVE nvim — a
            deliberate counterexample), cliproxy.lua:1380 (jobstart), ~13 vim.system
            calls in cliproxy.lua, git_markdown_source.lua:140 (uv.spawn with its own
            TERM-only cancel, no group, no deadline), and the vim.fn.system fallbacks
            in tools/builtin/{ls,grep,find,ack,chat_history_search}.lua plus
            init.lua:4740. The class fix that matches this repo's own convention is an
            arch guard over the spawn seam (tests/arch/), which also makes the atlas
            quantifier true by construction; if it carries an allowlist, note family
            `allowlist-without-dead-entry-check` already fired once on this issue.
          family: enumeration-claims-completeness
          round: 10
        - id: BR-41
          severity: Minor
          title: generate_topic replaces rather than merges transport_opts, so partial opts lose the deadline and are refused
          detail: |-
            chat_respond.lua:1049 uses `transport_opts or { deadline_ms = ... }`. One
            production caller today (init.lua:4429, passes nothing), so no defect
            ships. M4's W16 touches topic generation and is the likely trigger: a
            caller passing `{alive = fn}` with no generation gets refused at spawn.
            Set deadline_ms into the table when unscoped and unset instead.
          family: seam-change-collateral
          round: 10
        - id: BR-42
          severity: Minor
          title: The process fake models group signals and pid signals with two different semantics
          detail: |-
            fake_process.lua:95-113: the group branch always delivers the signal and
            ignores process.probe and process.signal_result; the pid branch honours
            probe, signal_result and opts.finish_on_signal. A scoped record therefore
            cannot be made to observe unknown/EPERM at all — which is why
            tasker_run_spec.lua:913 had to move its failed-signal-retry case from a
            scoped attempt to an unscoped one, losing that coverage for groups rather
            than extending it.
          family: stateless-double-at-stateful-seam
          round: 10
        - id: BR-43
          severity: Minor
          title: target() has no pid == 0 guard, and -0 == 0 would signal Neovim's own process group
          detail: |-
            tasker.lua:212-216. Unreachable today (uv.spawn never yields pid 0, and a
            failed spawn is rejected before the record is armed), but the fake added
            `if pid == 0 then error("signalled Neovim's own process group") end`
            precisely because the failure mode is catastrophic and silent. The
            production side should be at least as defensive as its double.
          family: untrusted-input-unparsed
          round: 10
        - id: BR-44
          severity: Minor
          title: The one-shot deadline timer is closed only by retire, the one path a held record never takes
          detail: |-
            tasker.lua:564-571 arms the timer and tasker.lua:191 closes it in retire().
            A record that reaches unresolved-visible is retained by design and never
            retires, so its already-fired uv timer handle is retained with it. Bounded
            by held records, but it is a handle whose only removal path is the one
            branch that by definition does not run.
          family: residue-names-no-end
          round: 10
      boundary: M3
      recipe: milestone-review
      blocked: true
    - "n": 11
      timestamp: "2026-09-19T04:11:34-07:00"
      agent: claude
      boundary: M3
      recipe: milestone-review
      blocked: true
      protocol_error: no valid findings block
    - "n": 12
      timestamp: "2026-09-19T07:53:50-07:00"
      agent: claude
      dispose:
        - id: BR-38
          disposition: addressed
          note: tasker.exit_reason plus the raw-render guard; verified red on revert in unscoped_kill_spec and spawn_seam_spec. Its stated four-callback enumeration is fully swept; the wider renderer class is raised anew below.
          round: 12
        - id: BR-39
          disposition: addressed
          note: README.md:115-120 now states TERM then SIGKILL at 2 s and scopes the claim-holding to "until the process has ended"; I re-ran the superseded-claim sweep and found no other stale statement.
          round: 12
        - id: BR-40
          disposition: addressed
          note: Atlas quantifiers scoped to tasker.run, and spawn_seam_spec is an executable per-file census with a dead-entry check; verified red on a planted spawn in logger.lua.
          round: 12
        - id: BR-41
          disposition: not-addressed
          note: The merge is correct but untested; I wrote the 8-line test and it goes red on the old `transport_opts or {…}` form.
          round: 12
        - id: BR-42
          disposition: addressed
          note: Both kill paths share one scripted() helper and the failed-signal-retry case is parameterised over pid and group; verified red when the group branch's scripted() call is removed.
          round: 12
        - id: BR-43
          disposition: not-addressed
          note: The guard is correct but has no test, and the fake has no seam to spawn a pid other than 4242 — add a spawn_pid option, then assert a pid-0 record records `missing` and signals nothing.
          round: 12
        - id: BR-44
          disposition: not-addressed
          note: The in-callback close is correct but untested; the existing supervision assertion at :232 passes via retire either way. I wrote the held-record test and it goes red without the fix.
          round: 12
      findings:
        - id: BR-45
          severity: Important
          title: The dispatcher re-exports code/io_error on its failure table, and both of that table's renderers still drop io_error
          detail: |-
            This is the 5th finding in family `seam-change-collateral`. Do NOT fix
            chat_respond.lua:24 and response_provider.lua:13 alone. The rule BR-38
            stated was "sweep every consumer that RENDERS the value"; it was
            implemented as "every file containing the literal tasker.run(", which is
            a call-site anchor, not a value anchor. The value crosses one more seam:
            dispatcher.lua:760-768 builds failure = {code, signal, io_error, …} and
            hands it to on_error. chat_respond._failure_notice (chat_respond.lua:23-24)
            renders tostring(failure.code) — now dead, since code is nil on every
            kill — then up to 500 chars of raw partial body; response_provider
            failure_reason (response_provider.lua:11-15) renders
            "provider request failed (HTTP unknown)". Neither reads io_error, so a
            deadline- or leave-killed stream never names its cause to the user, the
            same Done-when clause BR-38 cited. Neither file is in the guard's scope,
            and its pattern tostring%(%s*[%w_]*code%d*%s*%) cannot match
            tostring(failure.code) because `.` is outside [%w_]. The rule-level fix:
            render once at the seam that produces the value (failure.reason =
            tasker.exit_reason(code, signal, io_error)), have both consumers read it,
            widen the guard's scope predicate from "calls tasker.run(" to "reads a
            .code off a table that also carries io_error", and list the forms the
            matcher cannot see in its header, as single_source_sweeps_spec does.
            M5 Task 5.3 plans to keep _failure_notice as `detail`, so it inherits this.
          family: seam-change-collateral
          round: 12
        - id: BR-46
          severity: Important
          title: The out-of-seam spawn list's per-entry reasons are unchecked prose, and two of eighteen are wrong
          detail: |-
            This is the 8th finding in family `enumeration-claims-completeness`. Do
            NOT fix the two entries alone. atlas/providers/tool_execution.md:125-128
            now defers to tests/arch/spawn_seam_spec.lua as the list of each
            out-of-seam spawn "with how it ends", which makes every `reason` string
            load-bearing documentation — but the test asserts only that it is a
            non-empty string. spawn_seam_spec.lua:33 calls git_markdown_source "a
            bounded `git show` read with its own cancel": the command is `git ls-files
            -z --cached --others --exclude-standard -- *.md`
            (git_markdown_source.lua:135-143), markdown_finder arms no timer, and
            request_kill (git_markdown_source.lua:37-43) sends one sigterm with no
            escalation, only on caller cancel. spawn_seam_spec.lua:31-32 says
            cliproxy's calls "carry curl or vim.system timeouts": false for lsof
            (cliproxy.lua:842), `<bin> -h` (:1024), `ps ax` (:1066), sha256sum (:2027)
            and tar (:2106) — all synchronous :wait() with no timeout, which is an
            answer, but not the one given. The rule: an enumeration whose entries
            justify a documented claim must make each justification checkable — assert
            a classification derived from the call form (sync ⇔ :wait()/vim.fn.system*;
            bounded ⇔ the call carries `timeout =` or `--max-time`) and keep free text
            only for genuine exceptions such as the managed proxy.
          family: enumeration-claims-completeness
          round: 12
      boundary: M3
      recipe: milestone-review
      blocked: true
    - "n": 13
      timestamp: "2026-09-19T08:39:37-07:00"
      agent: claude
      boundary: M3
      recipe: milestone-review
      blocked: false
      protocol_error: no valid findings block
    - "n": 14
      timestamp: "2026-09-19T09:54:45-07:00"
      agent: claude
      findings:
        - id: BR-47
          severity: Important
          title: Three atlas passages and six stop_owner doubles still state the contract M4 replaced
          detail: |-
            7th in this family: do not patch the sites. Rule — a change to how a seam
            behaves, or that makes a previously-ignored part of its contract
            load-bearing, updates every restatement of it (prose, comments, doubles)
            in the same commit, enumerated by grepping the seam name and the old
            claim. Instances: tool_execution.md:88 still lists content fetches as
            unscoped while lifecycle.md:337 links there claiming the scope kill reaches
            them; architecture.md:44 keeps "a zero-match stop can still mean
            asynchronous readiness is pending" (reversed by W5); ownership.md:71-73
            keeps "a cancellation request alone does not prove an effect stopped" two
            lines under the new sentence that contradicts it; stop_owner's count is now
            load-bearing at response_provider.lua:124 but respond_fixture.lua:23 and
            five inline copies return nil, so no chat-level test takes the branch
            (ARCH-MOCK, and ARCH-DRY for the six copies).
          family: seam-change-collateral
          round: 14
        - id: BR-48
          severity: Important
          title: W15, the Copilot pre_query forward and 11 of 12 oauth scope sites redden nothing on revert
          detail: |-
            2nd in this family. Rule — every behavior-changing edit site has a test
            that goes red when that site alone is reverted, and the as-built
            "red on revert" line is written per edited site, not per W-row; a pcall
            guard is a behavior change only once a test makes its callee throw.
            Measured: W15's three guards (chat_respond.lua:1337, 1338, 1716) have no
            test, yet Task 4.2 Step 1 is ticked as covering W15; removing on_error from
            providers.lua:1081 in a scratch export left vault, dispatcher_query,
            providers_pre_query, cliproxy_catalog, cliproxy_dispatch, response_provider
            and unscoped_kill all passing; only the public hop of the oauth content
            tree asserts its scope (unscoped_kill_spec.lua:201).
          family: behavior-change-without-regression-test
          round: 14
        - id: BR-49
          severity: Important
          title: Only Stop drives the settle and scope kill; edit, reload and detach are untested
          detail: |-
            2nd in this family. Rule — a Done-when clause that enumerates alternatives
            is tested per alternative, parametrized over the list so a missing one is
            visible in the test name. Every M4 case stops via Runner.cancel or
            cancel_responses; the plan's own strategy (plan:1329-1333) required each
            applicable stop cause per case, and the Done-when names "Stop, an edit that
            revokes it, reload or detach". The E2E only reloads after terminal, so the
            shape #261 was filed from — an edit during generation — never drives the
            kill path. submit_and_stop already has the harness.
          family: done-when-clause-untested
          round: 14
        - id: BR-50
          severity: Important
          title: Atlas says the settles spec holds one case per wait; it holds 7 of 18
          detail: |-
            9th in this family. Rule — prose never asserts a count or completeness over
            an enumeration it does not carry: give the W-table a `test:` column naming
            the spec and case for each row (including "none"), and have the prose point
            at the table. atlas/chat/lifecycle.md:347 claims one case per wait, while
            W2-W8, W12, W13 and W15-W18 live in seven other specs and W10 was dropped;
            plan:1329 and plan:1335 still state the superseded strategy, including an
            after_each assertion on tasker.stats().active that was not built.
          family: enumeration-claims-completeness
          round: 14
        - id: BR-51
          severity: Minor
          title: After a fault the runner's snapshot reports the machine's non-terminal phase
          detail: |-
            generation_runner.lua:470-474 ends the generation outside the pure machine,
            so M.snapshot (:685) reports e.g. phase='streaming' while the host was given
            phase='terminal', outcome='fault' (ARCH-ORDER: two authorities for the same
            fact). Make fault a machine event, or have M.snapshot report the final it
            delivered.
          family: state-change-bypasses-model
          round: 14
        - id: BR-52
          severity: Minor
          title: W16 keys on a missing handle, the condition Task 4.1 rejected for W1
          detail: |-
            response_topic.lua:45-46 infers "the request threw" from `not s.handle`,
            while the runner marks `start_threw` because a nil handle is not the same
            thing. It makes response_topic.lua:88-92 unreachable and retires the topic
            while a process spawned during a re-entrant stop is still unconfirmed.
          family: canonical-form-not-shared
          round: 14
        - id: BR-53
          severity: Minor
          title: A fetch chain resuming after the scope kill spawns into a dead scope
          detail: |-
            chat_respond.lua:1577-1580 says whatever the fetch started dies with the
            scope kill. A chain paused at an unscoped hop (keychain, refresh, auth
            prompt) resumes after the kill and spawns fresh scoped processes nothing
            will signal, bounded only by their 120 s/60 s deadline. State the residual,
            or refuse a scoped run whose scope has already been stopped.
          family: one-shot-cleanup-not-a-gate
          round: 14
        - id: BR-54
          severity: Minor
          title: A thrown start_child is resolved as "nothing was started"
          detail: |-
            generation_runner.lua:360-364 resolves the child at once on the rationale
            that nothing started; a throw is not proof of that — the same assumption the
            remote-preparation spec used to pin against. The `unknown` outcome is
            honest, but the residual (a tool process started before its adapter threw
            runs into the next round and dies only at the generation's terminal kill)
            should be stated rather than denied.
          family: absence-inferred-from-throw
          round: 14
        - id: BR-55
          severity: Minor
          title: W14's pcall stops one statement short of the admission increment
          detail: |-
            generation_runner.lua:675-678 increments `active` before `sync(s)` and
            `dispatch(s,{type='start'})`, both outside the guard that W14 added; a throw
            there reopens the same leak in narrower form.
          family: partial-guard-window
          round: 14
        - id: BR-56
          severity: Minor
          title: D.subscribe and FS.new stubs are restored outside a pcall
          detail: |-
            2nd in this family. Rule — a spec replaces a module field only through a
            with_stub(tbl, key, value, body) helper that restores on every path, so a
            regression fails one case instead of cascading. Instances:
            generation_settles_spec.lua:56-59 (D.subscribe) and
            skill_invoke_spec.lua:250-256 (FS.new).
          family: stub-restored-outside-finally
          round: 14
      boundary: M4
      recipe: milestone-review
      blocked: true
    - "n": 15
      timestamp: "2026-09-19T10:25:53-07:00"
      agent: claude
      dispose:
        - id: BR-47
          disposition: addressed
          note: Atlas passages a-c corrected; one returning stop_owner double plus an arch guard. Chat-level reachability of W5 raised separately (Minor).
          round: 15
        - id: BR-48
          disposition: addressed
          note: Reverting the cancel_entry guard, the Copilot forward, or any of 7 of 7 sampled oauth sites (1393,1756,1926,2059,2143,2371,2505) turns a test red.
          round: 15
        - id: BR-49
          disposition: addressed
          note: With SIGKILL escalation disabled, all four stop-cause cases (stop, edit, reload, detach) and the 3 other end-to-end cases go red.
          round: 15
        - id: BR-50
          disposition: addressed
          note: WAITS list accurate (29/29 citations resolve); atlas points at it; plan revision supersedes Chunk 4. The check's self-match raised as a new Minor.
          round: 15
        - id: BR-51
          disposition: addressed
          note: Removing the final_outcome line from M.snapshot reddens the fault case.
          round: 15
        - id: BR-52
          disposition: not-addressed
          note: Code now keys on start_threw, but reverting to `not s.handle` leaves response_topic_spec 13/13 green; no test drives a stop arriving during provider.request.
          round: 15
        - id: BR-53
          disposition: addressed
          note: tasker refuses a run into a stopped scope; removing the refusal reddens tasker_supervision_spec.
          round: 15
        - id: BR-54
          disposition: addressed
          note: generation_runner.lua:362-365 now states the residual (a process spawned before the throw runs until the scope kill).
          round: 15
        - id: BR-55
          disposition: addressed
          note: Moving sync and dispatch back outside the pcall errors the W14 dispatch case.
          round: 15
        - id: BR-56
          disposition: addressed
          note: Both named sites use with_stub, which restores on every path.
          round: 15
      findings:
        - id: BR-57
          severity: Important
          title: stop_scope now closes a scope for good and tasker.run refuses into it, but the atlas says neither
          detail: |-
            8th in family. The rule already exists (grep the seam's name); the fix round
            applied it to the review's list, not to the seams it changed itself.
            tool_execution.md:100 still says only that stop_scope stops every process
            of one generation, and lifecycle.md:334-337 omits the refusal. Rule-level
            fix: each round's close greps every public function whose body the round
            changed across atlas/, fix rounds included. Instance: document the refusal,
            the 1024-key bound, and what happens to an evicted key.
          family: seam-change-collateral
          round: 15
        - id: BR-58
          severity: Important
          title: The fix commit's own new cancel_responses batch guard reddens nothing when reverted
          detail: |-
            3rd in family. The commit claims every edited site has a red-on-revert test,
            but the sweep covered the prior review's list, not the commit's own new
            hunks. Reverting chat_respond.lua:1357 leaves chat_cancel_entry,
            batch_lifecycle, batch_respond, batch_validation_budget, chat_stop_generation
            and generation_settles green. Rule: the mutation sweep runs over every
            behavior-changing hunk of the whole boundary diff, including the fix round's.
          family: behavior-change-without-regression-test
          round: 15
        - id: BR-59
          severity: Minor
          title: The WAITS check always passes for the 7 citations that name generation_settles_spec itself
          detail: |-
            generation_settles_spec.lua:379 does a raw-text find over the named file, and
            that file contains the WAITS list with every case name in it. Renaming the W11
            case left the check green. Fix: match `it(` followed by the case name, and
            strip the WAITS block before searching.
          family: allowlist-without-dead-entry-check
          round: 15
        - id: BR-60
          severity: Minor
          title: No chat-level spec can reach W5's zero-match branch, though the plan says they now do
          detail: |-
            4th in family. Instrumenting response_provider.lua:125 gave 0 hits across the
            six chat specs and generation_settles; the only hits came from
            response_provider_spec. The dispatcher.query doubles register calls
            synchronously (no pre_query window), and the stop_owner double only marks a
            call stopped through its own stop. Rule: a double models every phase of the
            seam the consumer branches on, and a claim that a test level takes a branch
            is measured, not inferred. plan:2215 claims otherwise.
          family: stateless-double-at-stateful-seam
          round: 15
      boundary: M4
      recipe: milestone-review
      blocked: true
    - "n": 16
      timestamp: "2026-09-19T10:57:35-07:00"
      agent: claude
      dispose:
        - id: BR-52
          disposition: addressed
          note: 'Measured: keying on `not s.handle`, or widening `elseif s.handle` back to `else`, each fails the new stop-during-request case.'
          round: 16
        - id: BR-57
          disposition: addressed
          note: tool_execution.md:103-109 documents the refusal, the 1024 bound and the evicted key; lifecycle.md:337 says the scope stays closed. Matches tasker.lua:389-393,500-502.
          round: 16
        - id: BR-58
          disposition: addressed
          note: Reverting chat_respond.lua:1357 fails batch_lifecycle_spec's new throwing-batch-cancel case.
          round: 16
        - id: BR-59
          disposition: addressed
          note: '`declares` strips the WAITS block and matches a real it(/describe( opener; renaming the W11 case now fails the check, and a counterfactual case pins both directions.'
          round: 16
        - id: BR-60
          disposition: addressed
          note: The claim is retracted in respond_fixture.lua:9-16 and plan Revisions; W5 stays pinned at response_provider_spec, which is where the branch lives.
          round: 16
        - id: BR-48
          disposition: not-addressed
          note: 'The W15 terminal-handler site (chat_respond.lua:1728) still reddens nothing: reverted to its base unguarded form, 12 related specs stay green. The WAITS W15 row cites a test of the shared helper, not of this site.'
          round: 16
      findings:
        - id: BR-61
          severity: Important
          title: The dispatcher still documents a one-arg pre_query, naming copilot, after W6 made it two-arg
          detail: |-
            9th in family. Do not patch the sites. The rule was written twice and narrowed
            each time (round 2's lesson limits the grep to atlas/, excluding comments), and
            both rounds enumerated from the review's list of seams rather than the change's
            own. The enumeration that covers all nine already exists: the W-table. Rule -
            every change row whose fix alters a seam's contract gets its own
            `grep -rn <seam name> lua/ atlas/ tests/`, and the as-built records the hit list
            with each hit's disposition; fix-round rows are appended to the same table.
            Measured instances, both from rows nobody re-grepped: dispatcher.lua:884-885
            still says a one-arg pre_query "(e.g. copilot) simply ignores the error callback",
            which is the hazard W6 closed and names the wrong example, since providers.lua:1079
            is now two-arg and no production adapter is one-arg; and
            atlas/providers/cliproxy-managed.md:257-266 enumerates the claim contract as
            falsy/truthy/no-hook without W8's new precondition, the transport_alive check at
            dispatcher.lua:808 that stops a dead owner reaching the hook at all.
          family: seam-change-collateral
          round: 16
        - id: BR-62
          severity: Minor
          title: The topic's deferred cancel discharges only on the request's normal exit
          detail: |-
            2nd in family. Round 2 made a stop during the request wait for the handle
            (response_topic.lua:49-55), but request() answers that obligation only when it
            returns normally (:89-94). Probed with a fake whose request stops the topic
            re-entrantly and then throws: stop() at :87 returns false because s.stopping is
            already set, and the topic sits in `stopping` forever holding its generation and
            two user captures. The deferred copy is also not pcall-ed while the inline copy
            is, and neither copy reads cancel_operation's false return (ARCH-ORDER,
            uncertainty collapsed into success). Unreachable through response_provider today,
            hence Minor. One cancel_through(s, handle) helper covering throw, falsy return
            and deferred resolve removes the divergence (ARCH-DRY).
          family: partial-guard-window
          round: 16
        - id: BR-63
          severity: Minor
          title: The Core-concepts tasker row still omits the stopped-scope refusal the prior round asked for
          detail: |-
            3rd in family. plan:113 lists tasker's surface without stop_scope's recording or
            run's refusal; the fact lives only in the Revisions prose (plan:2249, :2265), and
            the greppable table the review cross-checks is what went stale. Round 2 applied
            the prior review's other three plan-revision recommendations and dropped this one
            silently. Rule: a round's revision entry enumerates the prior review's
            plan-revision recommendations and marks each applied or declined-with-reason.
          family: plan-tracking-not-updated
          round: 16
      boundary: M4
      recipe: milestone-review
      blocked: true
    - "n": 17
      timestamp: "2026-09-19T11:34:39-07:00"
      agent: claude
      dispose:
        - id: BR-48
          disposition: addressed
          note: Reverting only chat_respond.lua:1728 to the raw response_topic.cancel call fails chat_onboarding_capture_spec "finishes its ending cleanup when the topic cancel throws"; round 2 confirmed the Copilot forward and oauth sites.
          round: 17
        - id: BR-61
          disposition: not-addressed
          note: Named sites fixed and ledger built, but the W6 row omits dispatcher_query_spec.lua:602-607 (H2 "backward compatible", one-arg double commented "one-arg adapter ignores the error cb") and response_provider_spec.lua:89; ledger scope excluded doubles, and the new guard scans lua/ only while the stop_owner guard (:426) scans tests/.
          round: 17
        - id: BR-62
          disposition: addressed
          note: cancel_through (response_topic.lua:46-52) serves both sites; reverting accepted==false (m62a) or the request-throw branch (m62b) each fails its new case. Untested throw exit raised separately.
          round: 17
        - id: BR-63
          disposition: addressed
          note: plan:113 tasker row now records stop_scope's key and run's refusal (1024, oldest evicted); plan:2294-2311 disposes each prior recommendation.
          round: 17
      findings:
        - id: BR-64
          severity: Minor
          title: cancel_through's throw exit and the direct site's refused-cancel exit fail nothing when reverted
          detail: |-
            4th in family. Rule: record counterfactuals per hunk in a mutation ledger next
            to the seam ledger (hunk -> mutation -> failing test, or "none, unreachable
            because X"); a whole-file or whole-commit revert is not evidence for any single
            hunk. plan:2306's "red on the old code" was a whole-file revert. Measured:
            removing the pcall at response_topic.lua:47 leaves response_topic,
            chat_onboarding_capture, topic_presentation, branch_topic_input,
            chat_stop_generation and generation_settles passing (no test makes a topic's
            cancel_operation throw; the pcall came in with a2ee8102). Reverting :60 to the
            old inline copy that ignores `false` leaves response_topic_spec 16/16 passing.
            Unreachable through response_provider today.
          family: behavior-change-without-regression-test
          round: 17
      boundary: M4
      recipe: milestone-review
      blocked: false
    - "n": 18
      timestamp: "2026-09-19T13:32:03-07:00"
      agent: claude
      findings:
        - id: BR-65
          severity: Important
          title: The provider-detail suppression at chat_respond.lua:1763 is dead, so the diagnosis prints twice and `staging overflow` leaks
          detail: |-
            `result.outcome == 'provider_failed' and failure_notice and nil or result.failure`
            parses as `((A and B) and nil) or result.failure`, so `failure` is always
            `result.failure`; the comment above it ("its reason is not repeated") describes
            behaviour that never happens. Verified against the shipped module: the user gets
            "the model's request failed (provider request failed (HTTP 503)); submit again —
            parley: provider request failed (HTTP 503): upstream down". The same line also
            passes `result.failure` for `overflow`, so the internal token "staging overflow"
            is shown, against M5's "no raw token". **This is the 5th finding in family
            `behavior-change-without-regression-test`.** Earlier rounds fixed instances. Do
            NOT just fix this site — the rule is: a change to a user-visible message needs an
            assertion on the WHOLE message (equality), not a substring probe. The existing
            case asserts `find("HTTP 503")`, which is true before and after the intended
            suppression, so it reports nothing; the two batch cases in the same file already
            use equality and are the model. Apply the rule to every ending that composes
            what + extra + action + notice (`provider_failed`, `overflow`, `prepare_failed`).
          family: behavior-change-without-regression-test
          round: 18
        - id: BR-66
          severity: Important
          title: The refusal census scans call shapes, not the values describe() keys on, so `issue(s,<lit>)` tokens have no words
          detail: |-
            `describe`'s first lookup key is the `failure` string, written directly by
            `issue(s,<lit>)` in generation_runner.lua:152 — a form absent from the spec's
            FORMS list although generation_runner.lua is in FILES. Unkeyed as a result:
            'staging overflow' (:163, user-visible today, see the other Important finding),
            'adapter failed' (:301), 'cancel adapter missing; operation unresolved' (:542).
            Two further blind spots of the same shape: a token that appears only as an
            argument to `refuse(kind, outcome, <lit>)` (chat_respond.lua:1806 'not a chat',
            :1421 'no stale continuation ready') is never scanned; and the new shared-cache
            guard (single_source_sweeps_spec.lua:391) keys on the literal `stdpath('cache')`
            while the hazard is a spec that inherits dispatcher.lua:17's default query_dir
            and writes there without naming it. **This is the 10th finding in family
            `enumeration-claims-completeness`.** Earlier rounds fixed instances (composed
            reasons, `reject(owner,lit)`) — this round adds a third hole in the same guard.
            Do NOT add another regex. The rule: a guard must key on the VALUE that reaches
            the behaviour, not on the syntax that produces it. For the vocabulary, invert it
            — have `describe` record every token that resolves to "unexpected" (or to an
            outcome-row fallback) into a process-global set, and fail a spec that finds the
            set non-empty after the suite; that covers every present and future producer
            form. For the cache guard, assert at runtime that `dispatcher.query_dir` does not
            resolve under `stdpath('cache')` during a spec run.
          family: enumeration-claims-completeness
          round: 18
        - id: BR-67
          severity: Minor
          title: '`unknown effect` tells the user to run :ParleyToolOperations, which cannot let the batch resume'
          detail: |-
            batch.lua:93 sets `s.unknown` and :99 rejects every later resume; nothing ever
            clears it, and tool_operations.lua reconciles producer records only. The action
            that actually works after this round's give-way change is ":ParleyChatRespondAll
            to start a new batch". The unit spec only checks that an action matches
            `:Parley%u` — it cannot see that the named command does not clear the condition.
          family: action-does-not-unblock
          round: 18
        - id: BR-68
          severity: Minor
          title: describe() consults REVOKED only when failure is nil, so a revocation carrying any failure reads "unexpected"
          detail: |-
            refusal.lua:230 gates the cause-specific wording on `failure == nil`, and
            'revoked' has no TOKENS row, so `describe('ended','revoked',<any string>,
            {cause='edit'})` returns "Response stopped: unexpected (...)". Reachable whenever
            a cancel/insert path calls `issue()` before the terminal (generation_runner.lua:542,
            :572, :598). Prefer the cause when one is recorded, and fall back to the failure.
          family: fallback-order-hides-known-cause
          round: 18
        - id: BR-69
          severity: Minor
          title: init.lua:4174 still forwards a 4th argument that chat_respond.respond does not accept
          detail: |-
            The force flag it carried was deleted this round (cmd_respond), but
            `M.chat_respond = function(p, cb, ofc, f) return chat_respond.respond(p, cb, ofc, f) end`
            still passes it to a three-parameter function. **This is the 5th finding in
            family `returned-handle-has-no-consumer`.** The rule, rather than this instance:
            when a parameter or field loses its last reader, delete it at every hop of the
            call chain in the same commit, and grep the symbol before closing the task —
            the same grep Task 5.3 Step 3 already ran for `resubmit_questions_recursively`.
          family: returned-handle-has-no-consumer
          round: 18
        - id: BR-70
          severity: Minor
          title: chat_context.lua's header comment still describes the pre-M5 reporting it no longer owns
          detail: |-
            Lines 4-9 say "chat_respond.respond names the file, and chat_respond.respond_all
            returns `nil, reason` to its caller for the header case". After this round
            respond routes through `refuse('start', nil, 'not a chat', {notice=reason})` and
            no longer names the file, and respond_all warns as well as returning. Not the
            `docs-reflow-after-deletion` family: nothing was deleted from this doc — a
            behaviour moved out from under a comment that describes a collaborator.
          family: comment-outlives-its-behavior
          round: 18
      boundary: M5
      recipe: milestone-review
      blocked: true
    - "n": 19
      timestamp: "2026-09-19T13:53:45-07:00"
      agent: claude
      dispose:
        - id: BR-65
          disposition: addressed
          note: |-
            Verified on the shipped module and by running the spec: the provider, prepare and
            overflow endings now assert whole messages and the internal token no longer leaks.
          round: 19
        - id: BR-66
          disposition: not-addressed
          note: |-
            The census never fails for the outcome-row fallback, which is exactly where
            `issue(s,<lit>)` tokens land: R.describe('ended','provider_failed','brand new runner
            token') returns "...the model's request failed (brand new runner token)..." with
            unkeyed() empty. Where it can fire, the error is thrown inside the terminal callback
            that generation_runner.lua:476 and response_session.lua:14 each pcall and discard.
            Remaining: fail (or assert after each spec) on _detail_only too, report through a
            channel the seam cannot swallow, and correct the atlas/target sentence crediting
            refusal_vocabulary_spec with catching any wordless producer reason.
          round: 19
        - id: BR-67
          disposition: addressed
          note: |-
            The named command genuinely unblocks: respond_all disposes a paused, settled batch
            (chat_respond.lua:2008-2015) and batch.lua:93 leaves exactly that state.
          round: 19
        - id: BR-68
          disposition: addressed
          note: |-
            Cause now outranks a stray failure (refusal.lua:252), asserted by equality in
            refusal_spec.lua:80.
          round: 19
        - id: BR-69
          disposition: addressed
          note: init.lua:4174 forwards three arguments; every call site in lua/ and tests/ passes one.
          round: 19
        - id: BR-70
          disposition: not-addressed
          note: |-
            The stale sentence was replaced by another inaccurate one: "respond and respond_all
            both warn, and both still return `nil, reason`" — respond returns a bare `return` on
            both ctx failures (chat_respond.lua:1813) and respond_all does on its not-a-chat path
            (:2005); init's wrapper logs an ERROR, not a warning, for a broken header
            (init.lua:4300). Rule: a comment about a collaborator cites it (file:line) or states
            only what this module guarantees.
          round: 19
      findings:
        - id: BR-71
          severity: Important
          title: Both new guards live in production code behind PARLEY_TEST_MODE; one makes the pure vocabulary stateful and grows unbounded in production, the other is swallowed by the calling seam
          detail: |-
            refusal.lua:230-235 and dispatcher.lua:677 put harness-only checks on production
            paths. `describe` is declared pure (refusal.lua:3) and listed under the plan's Pure
            entities, but now mutates M._unkeyed/M._detail_only and branches on vim.env
            (ARCH-PURE). M._detail_only is written unconditionally, in production too — one entry
            per distinct provider diagnosis, carrying up to ~500 chars of provider body, with
            forget_unkeyed() called only from specs: a growing structure with no removal path and
            no bound (ARCH-FUNERAL; ARCH-SECURE for the retained body text). The dispatcher's
            error is caught by generation_runner.lua:365 / response_provider.lua:100, so an
            integration spec sees "provider startup failed" instead of the guard's advice. The
            rule: a harness-only check belongs in the harness — record at the boundary (the
            `refuse` wrapper), assert from a spec hook, and default query_dir to $TMPDIR in
            tests/minimal_init.vim so no spec can inherit the shared cache.
          family: test-hook-in-production-path
          round: 19
        - id: BR-72
          severity: Minor
          title: The refusal spec's `one()` helper is a substring probe, so the batch-pause case still cannot see a second detail on the same provider_failed ending
          detail: |-
            chat_refusal_spec.lua:159 asserts find("Response stopped: the model's request failed")
            on the ending BR-65 broke, and one() (:75) matches by substring for all 17 cases, so
            appended text is invisible. This is the 6th finding in family
            behavior-change-without-regression-test. Earlier rounds fixed instances. Do NOT fix
            this line — the rule is that a case asserting a composed message compares the WHOLE
            string; apply it by making one() take the full expected message and use assert.equals,
            so every present and future case inherits it.
          family: behavior-change-without-regression-test
          round: 19
        - id: BR-73
          severity: Minor
          title: '`revoked` has no TOKENS row, so an ending whose cause is not edit/reload/detach reads "unexpected (revoked)"'
          detail: |-
            refusal.lua:252 words a revocation only for a mapped cause; generation.lua:361 stops
            with outcome 'revoked' on any grant_revoked, while generation_runner.lua:132 records a
            cause only for EDIT_REASONS and epoch/detach — 'explicit revoke' and 'generation
            finished' leave it nil. No spec covers a cause-less revocation, so reachability is
            unverified either way. This is the 11th finding in family
            enumeration-claims-completeness. Do NOT add one row — the rule is that the terminal
            outcomes' rows are derived from the machine's outcome set, so an outcome without
            words fails at load rather than at a user's screen.
          family: enumeration-claims-completeness
          round: 19
        - id: BR-74
          severity: Minor
          title: refusal_spec sets the process-global _allow_unkeyed and restores it only on the success path
          detail: |-
            tests/unit/refusal_spec.lua:44 sets R._allow_unkeyed = true and :50 restores it after
            the assertions; a failing assertion leaves the guard disabled for every later case in
            the process (and :35's assignment is already a no-op). This is the 3rd finding in
            family stub-restored-outside-finally. The rule: a spec that mutates a process-global
            restores it from after_each or through the repo's Stub.with_stub, never on the happy
            path.
          family: stub-restored-outside-finally
          round: 19
      boundary: M5
      recipe: milestone-review
      blocked: true
    - "n": 20
      timestamp: "2026-09-19T14:24:16-07:00"
      agent: claude
      dispose:
        - id: BR-66
          disposition: not-addressed
          note: |-
            The value census cannot fire on the ending path: every outcome now has a row, so an
            unworded failure resolves `detail` (refusal.lua:245-254) and prints the raw token in
            parentheses instead of `unkeyed`. Measured today across eight integration specs:
            `start refused | detach` (8x), user-visible as "Response not started: the response could
            not start (detach); submit again". That is the runner/adapter token form BR-66 named, and
            the atlas/target sentences still over-credit the watch. The rule: a producer token and a
            free-text diagnosis must not share the `failure` field — type them at the producer so a
            failure that is neither keyed nor internal resolves `unkeyed` on every kind, and free text
            arrives only through the caller-declared notice channel.
          round: 20
        - id: BR-70
          disposition: addressed
          note: |-
            chat_context.lua:4-9 now states only this module's own guarantee; verified no logger or
            notify call remains in the module, and resolve/parse/chat_buffer return typed errors.
          round: 20
        - id: BR-71
          disposition: addressed
          note: |-
            describe is pure and stateless again (returns message + resolution); the watch lives in
            tests/minimal_init.vim and was verified to fail a spec file with exit 1 through cquit;
            dispatcher reads a plain $PARLEY_QUERY_DIR override with no harness branch.
          round: 20
        - id: BR-72
          disposition: not-addressed
          note: |-
            one() is equality now, but the case BR-72 named (chat_refusal_spec.lua:165, two refusals)
            cannot use one() and still probes with find(); add a refusals_are({...}) helper asserting
            the whole list and have one() delegate to it.
          round: 20
        - id: BR-73
          disposition: addressed
          note: |-
            generation.OUTCOMES declared next to stop() with an assert, and refusal.lua fails at load
            if an outcome has no words; `revoked` has a row. All nine stop() call sites checked against
            the set; removing the row makes every spec that requires refusal.lua fail at load.
          round: 20
        - id: BR-74
          disposition: addressed
          note: |-
            The process-global _allow_unkeyed is gone (no reference remains); the exemption is
            file-scoped vim.g.parley_expected_unkeyed in refusal_spec.lua:5, with nothing to restore.
          round: 20
      findings:
        - id: BR-75
          severity: Important
          title: 'The document-lifecycle cause has no single home: ''detach'' reaches the user raw on the start path, and the detach-to-reload mapping is written twice'
          detail: |-
            response_target.lua:116 retires with event.kind, which reaches refuse('start','start refused',why)
            and prints "Response not started: the response could not start (detach); submit again" — a raw
            token, plus an action the user cannot take because the chat is closed. The silence/wording rule
            for detach and reload is hand-written at chat_respond.lua:1773 and again at :2088-2091, and not at
            all here. This is the 3rd finding in family canonical-form-not-shared. Do NOT fix the one site:
            refusal.lua should own the mapping from a lifecycle token to words or silence for every kind, not
            only for outcome=='revoked', with every path handing it the raw token.
          family: canonical-form-not-shared
          round: 20
        - id: BR-76
          severity: Important
          title: The harness docs still say spec children start without tests/minimal_init.vim, which this milestone changed
          detail: |-
            tests/minimal_init.vim:25-27 and atlas/infra/test_harness.md:42-46 both state that children never
            load the init and that g: variables never reach a spec; spec_runner.lua:19-22 now passes
            minimal_init to every child. This is the 2nd finding in family comment-outlives-its-behavior.
            The rule: a seam's behaviour change sweeps every prose claim naming that seam in the same round
            (grep minimal_init, PlenaryBustedFile, parley_test_mode across atlas, tests and TOOLING.md).
          family: comment-outlives-its-behavior
          round: 20
        - id: BR-77
          severity: Minor
          title: The response pause and the topic abort are still hand-written user notices the vocabulary guard cannot see
          detail: |-
            chat_respond.lua:1702 words a pause with its own actions, and :1166 words a topic abort; neither
            derives from refusal.lua, and the arch spec cannot see them because it keys on the PREFIX literals
            and "Response paused" is not one — while the batch's pause IS in the vocabulary. 4th finding in
            family canonical-form-not-shared. The rule: key the guard on the channel — a logger.warning or
            vim.notify literal inside the submit/generation modules that is not refuse()'s return is a finding.
          family: canonical-form-not-shared
          round: 20
        - id: BR-78
          severity: Minor
          title: NOT_REFUSAL still claims busy, refused, revoked and stale reach no user, while TOKENS words all four
          detail: |-
            Measured against the spec's own tables: those four keys are in both refusal_vocabulary_spec.lua:19-26
            and refusal.lua TOKENS, so the allowlist entries are shadowed and their stated reason is now false.
            3rd finding in family allowlist-without-dead-entry-check. The rule: assert the allowlist is disjoint
            from TOKENS/INTERNAL and that every entry is still produced by the scan, rather than deleting
            whichever entry a reviewer noticed.
          family: allowlist-without-dead-entry-check
          round: 20
        - id: BR-79
          severity: Minor
          title: A batch pause's cause lives in host-side flags outside the batch machine
          detail: |-
            What the pause says depends on phase, active, the weak-keyed user_stopped[batch] and the leg_spoke
            upvalue (chat_respond.lua:2037-2044, :2071-2080); the legal combinations are unwritten and only the
            happy interleaving is pinned. 2nd finding in family state-change-bypasses-model. The rule: the cause
            of a pause is part of the batch's transition (cancel(batch, {cause='user'}) surfaced on the snapshot),
            so it is readable off the model and drivable by a sequence test.
          family: state-change-bypasses-model
          round: 20
        - id: BR-80
          severity: Minor
          title: Round 2's dispositions are recorded one finding id off the ledger in both the issue Log and the plan
          detail: |-
            Logged "BR-73" is ledger BR-72 (the one() helper), logged "BR-74" is BR-73 (the outcome set), and
            "BR-70/72" is BR-70/74 (the file-scoped exemption). 4th finding in family plan-tracking-not-updated.
            The rule: a disposition quotes the ledger id verbatim, so a later round can verify what was claimed.
          family: plan-tracking-not-updated
          round: 20
      boundary: M5
      recipe: milestone-review
      blocked: true
    - "n": 21
      timestamp: "2026-09-19T15:09:22-07:00"
      agent: claude
      dispose:
        - id: BR-66
          disposition: addressed
          note: The value-keyed inversion is built (describe returns a resolution; minimal_init.vim:59-79 fails the file via cquit) and the cache hazard is removed by construction via $PARLEY_QUERY_DIR rather than a runtime assert; all three named runner tokens now have rows. The residual gap — the watch only sees values a spec drives — is raised separately.
          round: 21
        - id: BR-72
          disposition: addressed
          note: chat_refusal_spec.lua:78-86 — refusals_are uses assert.same on the whole list and one() delegates to it, so all 17 cases compare full messages, including the two-message batch case.
          round: 21
        - id: BR-75
          disposition: addressed
          note: refusal.LIFECYCLE (refusal.lua:198-203) is consulted before the token lookup for every kind; response_target.lua:116's raw event.kind now resolves silent/reload, and chat_respond.lua:48-51 is the single detach-to-reload mapping used by both call sites.
          round: 21
        - id: BR-76
          disposition: addressed
          note: tests/minimal_init.vim:3,26-32 and atlas/infra/test_harness.md:43-56 both now describe what spec_runner does and name the specs that set g:parley_test_mode themselves; grep over atlas/TOOLING/Makefile finds no surviving stale claim.
          round: 21
        - id: BR-77
          disposition: addressed
          note: chat_respond.lua:1716 and :1188 go through refuse('paused'/'topic'), and refusal_vocabulary_spec.lua:138-152 keys on the channel. The guard's literal-only match is a new finding, not this one.
          round: 21
        - id: BR-78
          disposition: addressed
          note: refusal_vocabulary_spec.lua:124-136 asserts NOT_REFUSAL is disjoint from TOKENS/INTERNAL/LIFECYCLE and that every entry is still produced by the scan; busy/refused/revoked/stale are gone from the allowlist.
          round: 21
        - id: BR-79
          disposition: addressed
          note: batch.lua:76-81 validates the cause in the transition, :113 clears it on resume, snapshot copies it, and chat_respond.lua:2074 reads it off the model; user_stopped and leg_spoke no longer exist anywhere in lua/ or tests/.
          round: 21
        - id: BR-80
          disposition: not-addressed
          note: The plan's round-2 entry was renumbered but the issue Log was not — at HEAD it still reads BR-73 for the one() helper (ledger BR-72), BR-74 for the outcome set (ledger BR-73), and BR-70/72 for the exemption (ledger BR-70/74).
          round: 21
      findings:
        - id: BR-81
          severity: Important
          title: '`failure` still carries free text on three producers, so a cliproxy start failure and every `fault` reach the user as "unexpected (...)"'
          detail: |-
            Measured: describe("ended","provider_failed","cliproxy: proxy did not become healthy within 30s — try :ParleyProxy status") resolves `unkeyed`. Chain: cliproxy.ensure_running's on_error (cliproxy.lua:731,736,777) or vault.run_with_secret's (vault.lua:251,267) -> dispatcher.lua:926 abort_before_start -> D.query on_abort -> response_provider.lua:99 abort -> failure_reason's string branch (:21) passes any string verbatim -> cb.failed(reason) with no diagnosis -> s.failure -> chat_respond.lua:1781. generation_runner.lua:492 (fault) and :69 (kill_scope) assign a raw Lua error to s.failure, which generation_settles_spec.lua:228 pins, leaving the `fault` TOKENS row (refusal.lua:179) with zero reachable consumers. Neither net sees any of it: the census FILES list omits cliproxy.lua, vault.lua, response_completion.lua, response_preparation.lua and response_topic.lua, and no spec drives these paths through the host.
            This is the 12th finding in family enumeration-claims-completeness. Earlier rounds fixed instances. Do NOT fix these three sites. The rule: `failure` must hold a value `refusal` can resolve, enforced where the value is STORED, not where it is displayed — otherwise coverage of the invariant equals coverage of the specs, which is the syntax-vs-value mistake again. Export refusal.is_token(value) (a row, an INTERNAL entry, a ": " lead-in, or a LIFECYCLE key) and have generation_runner.issue route anything failing it into `diagnosis`, asserting under $PARLEY_TEST_MODE. fault, kill_scope and failure_reason are then covered by construction, and the FILES enumeration stops needing to be complete.
          family: enumeration-claims-completeness
          round: 21
        - id: BR-82
          severity: Important
          title: The channel guard matches only a string-literal first argument, so two live warning channels inside the file it scans are neither routed nor declared
          detail: |-
            tests/arch/refusal_vocabulary_spec.lua:138-152 greps logger%.warning%(%s*(['"]) and vim%.notify%(%s*(['"]). A warning whose argument is a variable is invisible, and two are in chat_respond.lua, which is in CHANNEL_FILES: :437 logger.warning(plan.warning) — the attachment-budget notice, no prefix, no action; and :1364 _parley.logger.warning(label .. ' failed: ' .. tostring(err)) — the guarded() helper behind cancel_topic and stop_batch, so a throwing batch cancel prints a raw traceback on the Stop path. The test "routes every user notice in the submit path through refuse" therefore passes while asserting something untrue, and NOT_A_REFUSAL_NOTICE claims a completeness it does not have.
            Same rule as the finding above, applied to the channel: match on the CALL, not on its first token — scan logger.warning( / vim.notify( regardless of argument shape and require every site to be refuse()'s return or an explicitly declared non-refusal. Then route plan.warning and guarded through the vocabulary.
          family: enumeration-claims-completeness
          round: 21
        - id: BR-83
          severity: Minor
          title: 'Two handles added this round have no reader: the `_lifecycle_cause` test seam and `result.refusal`'
          detail: |-
            chat_respond.lua:52 exports M._lifecycle_cause labelled "-- test seam" with no test referencing it — the only one of the repo's five such exports without a consumer. result.refusal is written at chat_respond.lua:1754 and :1781 and read nowhere in lua/ or tests/, while the plan's round-3 revision claims the batch consumes it; the batch actually derives leg_stopped from generation.OUTCOMES[state.reason] at :2078.
            This is the 6th finding in family returned-handle-has-no-consumer. Do NOT fix the two sites — the rule is that an M._* export labelled a test seam, and a field added to a snapshot or result table, must have a reader in the same commit. A cheap arch assertion over "-- test seam" exports in lua/ would pin the first half permanently.
          family: returned-handle-has-no-consumer
          round: 21
        - id: BR-84
          severity: Minor
          title: Six hand-written variants of "first line of a Lua error", three of which throw on an empty message
          detail: |-
            tostring(x):match('^[^\n]+') appears at chat_respond.lua:1670, :1693, :1297, response_session.lua:95, :164; response_target.lua:113 uses :sub(1,512) instead. Only two carry the `or 'unknown'` fallback. Verified: debug.traceback("") begins with a newline, so the match returns nil and the three unguarded sites raise "attempt to concatenate a nil value" inside the failure handler itself.
            This is the 5th finding in family canonical-form-not-shared. Do NOT fix the individual sites — one helper (refusal.brief(err)) with the fallback and the cap built in, used by all six.
          family: canonical-form-not-shared
          round: 21
        - id: BR-85
          severity: Minor
          title: init.lua's chat_context wrapper still hand-words "not a chat" and the missing header for four commands
          detail: |-
            init.lua:4294-4303 composes its own sentences ("Prune is only available in chat files: <raw reason>", "could not find header separator ---") for ChatPrune, ExchangeCut, ExchangePaste and NewQuestion, in a different voice and with no action, while refusal.lua now owns both facts and chat_respond.respond was converted to refuse('start', nil, 'not a chat'|'chat header unavailable'). Out of M5's declared submit-path scope, but it is the remaining hand-maintained restatement the ARCH-PURPOSE shadow-sweep asks for.
            This is the 6th finding in family canonical-form-not-shared. The rule: a condition the vocabulary keys has one wording for every entry point — give chat_context's reporting wrapper a refuse() kind rather than four sentences.
          family: canonical-form-not-shared
          round: 21
        - id: BR-86
          severity: Minor
          title: lifecycle_cause maps detach to reload on a buffer number alone, and buffer numbers are reused after :bd
          detail: chat_respond.lua:48-51 returns 'reload' whenever nvim_buf_is_valid(buf) and nvim_buf_is_loaded(buf), without checking the buffer is still the same chat. Buffer-number reuse after :bd is the hazard this issue's own audit named, so a closed chat whose number was taken by another file reports "the chat was reloaded while the answer was being written; submit again". The window is narrow (the terminal fires on the next deferred turn) and the fix is one comparison against D.get(buf) or the buffer name.
          family: untrusted-input-unparsed
          round: 21
        - id: BR-87
          severity: Minor
          title: The per-process query directory the harness creates has no removal path, and replaced a bounded artifact
          detail: |-
            tests/minimal_init.vim:56-58 creates $TMPDIR/parley-query-<pid> in every nvim process and nothing removes it; request bodies accumulate inside, one directory per spec file per run. `make test` is bounded by its leading test-clean-env, but `make test-spec`, `make test-changed` and the direct PlenaryBustedFile invocation TOOLING.md documents all leave them. Note also that this replaced an artifact with a writer-side bound (the shared query_dir's >200->100 prune) with an unbounded per-process one.
            This is the 3rd finding in family residue-names-no-end. The removal belongs beside the creation (a VimLeavePre delete of the directory), not in a target the operator must remember to run.
          family: residue-names-no-end
          round: 21
      boundary: M5
      recipe: milestone-review
      blocked: false
    - "n": 22
      timestamp: "2026-09-19T16:03:40-07:00"
      agent: claude
      dispose:
        - id: BR-20
          disposition: addressed
          note: One BEARER_SCHEMA (vault.lua:161) applied to both the file read (:184) and the network response (:229); vault_spec V1 pins a non-numeric expires_at.
          round: 22
        - id: BR-23
          disposition: addressed
          note: helper.lua:622-660 resolves the real target and copies its mode; remove_stale_temps has three call sites; helper_io_spec F3g/F3h/F3i pin symlink, mode and sweep.
          round: 22
        - id: BR-24
          disposition: addressed
          note: sidecar_authority_spec.lua:22-33 selects on state_dir OR stdpath('data'); file_access.json is in sidecars.lua with a schema, an exercise and a table_to_file write.
          round: 22
        - id: BR-34
          disposition: not-addressed
          note: helper.lua:696-699 still hand-rolls resolve(fnamemodify(n,':p')); no helper.canonical_path exists anywhere in lua/, and file_refresh.lua:6 still has its own copy.
          round: 22
        - id: BR-36
          disposition: addressed
          note: nodiscard_spec now matches statement heads after then/do/else/; and bare pcall/xpcall, and its header lists the four forms it cannot see.
          round: 22
        - id: BR-37
          disposition: addressed
          note: The stale check asserts seen == declared.count for every DROPPED entry and reports "declared N, found M".
          round: 22
        - id: BR-41
          disposition: addressed
          note: chat_respond.lua:1088-1090 merges and only defaults deadline_ms when unscoped and unset; topic_gen_spec:76-80 pins partial, bare and scoped opts.
          round: 22
        - id: BR-43
          disposition: addressed
          note: tasker.lua:219 refuses pid <= 0; tasker_supervision_spec "never signals a record whose pid is 0" drives it against a fake that raises if signalled.
          round: 22
        - id: BR-44
          disposition: addressed
          note: tasker.lua:596-598 closes the one-shot timer as it fires; "keeps no deadline handle on a record the kernel holds" pins it.
          round: 22
        - id: BR-45
          disposition: addressed
          note: dispatcher.lua:764-770 exports only failure.exit; response_provider.lua:18 and chat_respond.lua:21-28 both read it, and spawn_seam_spec's FIELDS guard fails any read of failure.code/signal/io_error.
          round: 22
        - id: BR-46
          disposition: addressed
          note: spawn_seam_spec classifies each out-of-seam spawn from its call form and requires `why` iff open > 0, failing a dead `why` too.
          round: 22
        - id: BR-61
          disposition: addressed
          note: dispatcher.lua:883-885 states the two-arg contract and that copilot now forwards it; cliproxy-managed.md:261-263 names the transport_alive precondition; the pre_query guard scans lua/ and tests/.
          round: 22
        - id: BR-64
          disposition: addressed
          note: The plan now carries a per-hunk mutation ledger (five rows), and each named case exists in response_topic_spec.lua:90-115.
          round: 22
        - id: BR-80
          disposition: not-addressed
          note: The issue Log at lines 914-917 still reads BR-73 for the one() helper (ledger BR-72), BR-74 for the outcome set (ledger BR-73), and BR-70/72 for the exemption (ledger BR-70/74).
          round: 22
        - id: BR-81
          disposition: not-addressed
          note: The routing exists at generation_runner.lua:158-166, but reverting it in a worktree leaves chat_refusal_spec 17/17, refusal_spec 15/15, refusal_vocabulary_spec 6/6, generation_settles_spec 19/19, chat_respond_spec 42/42 and batch_lifecycle_spec 8/8 all green; the only specs that observe it are the two it now breaks. No test fails without the fix.
          round: 22
        - id: BR-82
          disposition: addressed
          note: The guard keys on the call, not its first token; planting _parley.logger.warning(x) with a variable argument in chat_respond.lua turns "routes every user notice in the submit path through refuse" red (reproduced).
          round: 22
        - id: BR-83
          disposition: addressed
          note: M._lifecycle_cause and result.refusal are both deleted, and single_source_sweeps_spec now fails any "-- test seam" export with no reader.
          round: 22
        - id: BR-84
          disposition: not-addressed
          note: refusal.brief exists and all six sites route through it, but grep over tests/ finds zero references to brief (or is_token); the crash the finding named — debug.traceback("") with its leading newline — is pinned by nothing.
          round: 22
        - id: BR-85
          disposition: not-addressed
          note: 'The wording is shared now, but the wrapper reuses the `start` kind and passes the command name as `notice`, so ExchangeCut in a headerless buffer reads "Response not started: the chat has no header; edit: restore the chat''s header, then submit again — ExchangeCut" (rendered). No refuse() kind was added and no test covers the four commands.'
          round: 22
        - id: BR-86
          disposition: not-addressed
          note: The not_chat check is in place at chat_respond.lua:56-60, but reverting it to the old two-condition form leaves chat_refusal_spec 17/17 green (verified); the close case uses an unloaded buffer, which both versions treat the same. No test enters the reused-number branch.
          round: 22
        - id: BR-87
          disposition: addressed
          note: tests/minimal_init.vim:50-56 deletes the directory on VimLeavePre beside its creation; after a full run the HEAD tree left one directory out of ~380 spec processes, from the spec that died abnormally.
          round: 22
      findings:
        - id: BR-88
          severity: Critical
          title: The close commit's `failure`-routing change reddens two specs at HEAD, and nothing fails without it
          detail: |-
            This is the 10th finding in family `seam-change-collateral`. Do NOT fix the two
            assertions alone. generation_runner.lua:158-166 changed what the `failure` field
            may hold; the sweep covered production producers but not the readers of that
            field in tests/. Measured at HEAD: cliproxy_caller_teardown_spec.lua:161 expects
            'test abort' and gets nil; response_session_spec.lua:186 expects 'forced
            preparation failure' and gets nil. Both pass at 6b8c7164, and both go green again
            when only the is_token/brief lines are reverted — while chat_refusal_spec 17/17,
            refusal_spec 15/15, refusal_vocabulary_spec 6/6, generation_settles_spec 19/19,
            chat_respond_spec 42/42 and batch_lifecycle_spec 8/8 stay green either way. The
            rule: a change to what a STORED field may hold enumerates every reader of that
            field, production and spec alike, and the round that lands it adds the case that
            goes red when the guard is removed. Move the two assertions to
            `generation.diagnosis` and add that case.
          family: seam-change-collateral
          round: 22
        - id: BR-89
          severity: Important
          title: The plan's new counterfactual table trips the repo's own Core-concepts symbol guard, so tests/arch/single_source_sweeps_spec.lua is red at HEAD
          detail: |-
            This is the 14th finding in family `enumeration-claims-completeness`. Do NOT just
            rename the cell. single_source_sweeps_spec.lua:282 selects rows by shape
            (`^| \``) rather than by the table they belong to, so the mutation-ledger row at
            plan:2700 — `| \`issue\` keeps free text in \`failure\` | the reload cases in
            \`chat_refusal_spec\` |` — is judged a Core-concepts row and its spec name is
            demanded as a symbol definition. The guard passed at 6b8c7164 and fails at HEAD.
            Either scope the row matcher to Core-concepts tables (the property that defines
            the class) or write the cell as a path so the existing module-strip applies.
          family: enumeration-claims-completeness
          round: 22
        - id: BR-90
          severity: Important
          title: '`logger.warning(Refusal.describe(...))` forwards the resolution string into the `sensitive` parameter, so the attachment notice is logged as REDACTED'
          detail: |-
            This is the 11th finding in family `seam-change-collateral`. Do NOT fix only this
            line. `describe` gained a second return value in M5 round 3; chat_respond.lua:448
            calls it as the last argument of logger.warning(msg, sensitive), so "keyed" lands
            in `sensitive` and logger.lua:73-86 writes "[SENSITIVE DATA] REDACTED" to the log
            and keeps the line out of _log_history (reproduced; the parenthesised form logs
            correctly). The channel guard added in the same commit explicitly blesses the
            form `^Refusal%.describe%(` as routed, so it cannot see this. The rule: a
            multi-return function is never called directly as another call's last argument —
            assign it, or parenthesise it — and the channel guard should require the
            parenthesised/assigned form rather than the bare call. Same line: the kind is
            `start`, but the response does start (only images are dropped), so the user reads
            "Response not started: … no images were sent".
          family: seam-change-collateral
          round: 22
        - id: BR-91
          severity: Minor
          title: chat_respond.lua:48-50 duplicates the comment paragraph at :44-47, including its "One statement of it" clause
          detail: |-
            Introduced by ba79d86f: the new paragraph was appended rather than replacing the
            old one, so the same two sentences appear twice above lifecycle_cause, the second
            copy differing only in "a chat still loaded by then". Delete :48-50.
          family: comment-outlives-its-behavior
          round: 22
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

## Round 5 — 2026-09-19T01:16:00-07:00 (claude) — passed

### Disposed

- BR-19 — addressed — table_to_file delegates to table_to_file_atomic (helper.lua:580-587); F3f goes red when the old writer is restored. The sidecar-spec extension was not added, but it is moot while the only JSON writer checks every step.
- BR-20 — not-addressed — BEARER_SCHEMA is applied to the response (vault.lua:223-225), but deleting that conform call leaves sidecar_degrade (14), vault_spec (27) and sidecar_authority (5) all green. Drive the fake_process curl with stdout of token "t" and a string expires_at, and assert the next refresh re-fetches instead of raising.
- BR-21 — addressed — R1 (dispatcher_query_spec.lua:136) goes red when the abort is removed: curl is not started and the reason reaches on_exit.
- BR-22 — addressed — decodes() matches both APIs. A planted unguarded vim.fn.json_decode line was reported as lua/parley/file_tracker.lua:183.

### Raised

- **BR-23** [Minor] `seam-change-collateral` Routing table_to_file through the rename-based writer replaces symlinked sidecars, resets permissions, and leaves crash files the query cleanup never deletes
  2nd in this family. Rule: changing a shared seam's contract means listing each caller, what it relied on from the old contract, and which of those the new contract keeps, all in the same change. The old io.open("w") wrote through a symlink and kept the file's mode. Reproduced: a symlinked custom_system_prompts.json became a regular 0644 file and its 0600 dotfiles target kept the old prompt. A user-restricted vault_state.json (bearer cache) also reverts to 0644. A crash mid-write now leaves *.json.tmp-* files that the query cleanup (dispatcher.lua:71, glob *.json) never matches (ARCH-FUNERAL). Fix at the one writer: resolve an existing destination with uv.fs_realpath, create the temp file beside the real target, and copy its mode before the rename. Make the query cleanup also match *.json.tmp-*. Add helper_io tests for the symlink and the mode.
- **BR-24** [Minor] `enumeration-claims-completeness` The sidecar census finds readers by the text state_dir, so file_access.json escapes it, and a wrongly typed entry makes opening a chat raise
  3rd in this family. Rule: a guard that claims to cover a class selects members by the property that defines the class, not by how one member happens to be spelled. Here the class is files persisted across sessions and read back by a chat action. file_tracker.lua:23 builds its own path under stdpath("data")/parley. open_buf (init.lua:3112) then calls track_file_access, which raises "attempt to index a number value" (:92, reproduced) on {"/a.md": 3}. Quit and reopen does not clear it. The same module has a second, non-atomic JSON writer (:70) that returns true regardless of the write result. Measured: grepping for stdpath( in lua/ finds one more session-persisted JSON reader on the chat path, this one. Fix the rule: derive every profile sidecar's path from one helper (or from state_dir), have the census select on that, add file_access.json to tests/helpers/sidecars.lua with a schema, and write it through table_to_file.

## Round 6 — 2026-09-19T01:56:43-07:00 (claude) — BLOCKED

### Raised

- **BR-25** [Important] `plan-step-not-as-specified` Task 2.6's loaded-target move_chat_tree test is missing, and the Log claims the task landed as planned
  The plan requires a test that the branch-link rewrite at init.lua:3798, with the target loaded, rewrites the buffer and does not write the file under it. No such test exists. Counterfactual: forcing live=false plus readfile in move_chat_tree (write the file under the live buffer, never update the buffer) leaves all 10 specs reaching move_chat_tree green. The sub-chat cases also call _collect_ancestor_messages instead of submitting in C, and neither gap is in the Log's deviation list. Second finding in this family. Rule: before milestone-close, every Step-1 test bullet maps to a named test in the diff or to a logged deviation, and a bullet with neither blocks the close. Add the test and put the rule in workshop/lessons.md.
- **BR-26** [Important] `enumeration-claims-completeness` chat_lines fixes the bufnr(path) partial-match defect at 1 of 5 sites; 4 remain, one confirmed to destroy a buffer
  Still using bufnr(<name>): init.lua:4405 and 4428 (child topic after a prune), outline.lua:407 and system_prompt_picker.lua:83. Verified on nvim 0.11.7: bufnr of parley://system_prompt/foo returns the foobar buffer, which line 85 force-deletes, discarding its unsaved edits. The plan's consumer list for chat_lines carries no query, against its own header rule. Fourth finding in this family. Rule: a site list comes from a recorded query, and a primitive-class query becomes an arch guard. Split the exact-name lookup out of chat_lines, route all four sites through it, and add a guard failing any vim.fn.bufnr(arg) outside the helper.
- **BR-27** [Minor] `rule-statement-scope-drift` lifecycle.md scopes the stale exemption to a regeneration; the code exempts every generation's owned writes
  state.lua exempts any other generation's write inside its own live grant, including a first answer and topic header writes, as ownership.md and document.md say. A request captured mid-stream of a first answer took partial text, and its tool rounds now continue without the stale pause. lifecycle.md's rationale (the previous answer stays valid) does not cover that case; state the broader rule and why that capture is final.
- **BR-28** [Minor] `done-when-clause-untested` Several exchanges regenerating at once are pinned only at the coordinator, not in substitution or a request
  document_previous_answer_spec lists two slots, but no test runs previous_answer.substitute with two entries, or a request carrying both old answers. The behavior is correct when probed; add one pure two-entry case.
- **BR-29** [Minor] `stub-restored-outside-finally` The capture-then-late-build test restores its resolve_remote_references stub outside a protected call
  A timeout in wait_for(held) leaks the stub into every later test in chat_respond_spec. with_json_yaml in the same file already restores through pcall.

## Round 7 — 2026-09-19T02:12:56-07:00 (claude) — BLOCKED

### Disposed

- BR-25 — addressed — Bullet withdrawn with a verified reason (a timestamped ref resolves to the moved file, so ref_abs==old_abs never matches), parley#270 filed, sub-chat seam deviation logged, lessons rule added. The stand-in test is raised separately.
- BR-26 — addressed — All 5 sites use helper.buffer_for. A grep for every bufname-style primitive finds no other offenders. Reverting the picker lookup turns P4 and the arch guard red.
- BR-27 — addressed — lifecycle.md now states the rule for every generated write and why an earlier capture is final. This matches state.lua, where owner must be a valid grant containing the edit.
- BR-28 — addressed — A pure two-entry substitute test with out-of-order entries now pins conversation order.
- BR-29 — addressed — The resolve_remote_references stub is restored after a pcall-wrapped wait. No other stub in this window's tests is restored outside a protected call.

### Raised

- **BR-30** [Important] `stateless-double-at-stateful-seam` The BR-25 stand-in test passes only because its chat is a nofile scratch buffer; with a real chat buffer the tree move saves it and aborts with ENOENT
  chat_move_spec create_chat uses nvim_create_buf(false, true), so the silent! write in sync_moved_chat_buffers (init.lua:3146) fails silently and the file looks untouched. Reproduced with bufadd plus bufload: the write fires, the save hook slug-renames tree-root.md to move-test.md, and os.rename fails with No such file or directory, aborting move_chat_tree. That abort predates this window, but the new test asserts the opposite. Second in this family. Rule: a test stand-in must have every behavior the code under test branches on; build chat buffers the way production does, not as a named scratch buffer. Prevalence: 14 spec files name a scratch buffer as a chat, and 1 (chat_move_spec) also runs a writing path. Fix: use a file-backed buffer, record the ENOENT repro in parley#270 or a new issue, and either assert the real behavior or delete the stand-in. Also correct the Log line saying a characterization stands in.
- **BR-31** [Minor] `enumeration-claims-completeness` buffer_lookup_spec matches only the first vim.fn.bufnr call on a line, and only when the call fits on one line
  There are no offenders today. The wider class of name-matching functions (bufwinnr, bufwinid, bufname, getbufvar) cannot be checked statically, because their number-argument forms are legitimate. The rule is the BR-24 one: a guard selects members by the class property. Here the property can only be checked by spelling, so record that limit in the guard's header comment.

## Round 8 — 2026-09-19T02:40:57-07:00 (claude) — BLOCKED

### Disposed

- BR-30 — addressed — Stand-in deleted (chat_move_spec is net-zero across the window); plan Revisions + issue Log record the withdrawal, and parley#270's Log carries the ENOENT repro and the 14-spec fixture prevalence.
- BR-31 — addressed — tests/arch/buffer_lookup_spec.lua:7-12 states the limit — checks by spelling, first call per line, single-line calls, and names the statically-uncheckable siblings.

### Raised

- **BR-32** [Important] `exemption-boundary-untested` The new generated-write staleness exemption is pinned only on its positive side; a cross-generation write that escapes its grant has no test
  state.lua:294 computes `generated` from the `owner` that line 267 nils when the grant is revoked or does not contain the edit; that nil'ing is the whole safety of the exemption. Both new cases use a contained, valid grant, and the existing 'invalid owners' case uses the reader's OWN grant, where `generated` is false regardless. Probed against HEAD: writer grant 10..20, reader dep 0..30 — an observed_edit{first=9,last=10,owner_grant=writer} still stales the reader (true), as does a write whose grant was revoked first (true). Correct today, unpinned. Move `generated` above line 267 and captured input silently stops going stale with nothing red. Add two unit cases: writer's owned edit outside its grant, and writer's grant revoked, reader stale in both.
- **BR-33** [Minor] `returned-handle-has-no-consumer` D.set_previous_answer returns a did-it-happen boolean that chat_respond.lua:1545 drops as a bare statement
  This is the 4th finding in family returned-handle-has-no-consumer. Earlier rounds fixed instances. Do NOT fix this instance. The rule is already written (workshop/lessons.md, M1 round 2: a "did it happen?" result must be consumed by whoever tells the user), but its guard, tests/arch/sidecar_authority_spec.lua:69-91, enumerates members by spelling — `table_to_file`, `table_to_file_atomic`, `custom_prompts.*` — so every new boolean-returning API is a fresh instance. Measured prevalence: the guard covers 3 named call shapes; this window added a 4th boolean-returning API outside them. Fix the rule, per BR-24: select guard members by the class property (a function annotated ---@return boolean meaning "did it happen") rather than by name, or drop the boolean and have set_previous_answer warn on refusal. A silent false here means the next request carries the buffer's partial text as an earlier answer with no message.
- **BR-34** [Minor] `canonical-form-not-shared` buffer_for's private key() adds an 11th copy of the resolve(fnamemodify(x,':p')) path-canonicalisation idiom
  helper.lua:694-697 hand-rolls the same canonicalisation that tools/file_refresh.lua:6 already names `canonical`, in the same file whose resolve_chat_path comment (helper.lua:337-341) records that four copies of path resolution drifted and shipped a bug (#225 C3). ARCH-DRY: extract one `helper.canonical_path(name)` and route buffer_for, file_refresh and the eight other `vim.fn.resolve(vim.fn.fnamemodify(...,":p"))` sites through it, so the ~-vs-$VAR and symlink semantics have one definition.
- **BR-35** [Minor] `plan-tracking-not-updated` The fixture obligation BR-30 deferred to parley#270 lives only in its Log, not in its Done-when contract
  This is the 2nd finding in family plan-tracking-not-updated. Do NOT fix this instance alone — state the rule. parley#270's Log says "Add to this issue's Done-when: chat_move_spec builds its chats as file-backed buffers … and a tree move of a loaded chat succeeds", but `## Done when` still carries only its two original bullets. The rule that covers both instances: work deferred into a receiving artifact lands in that artifact's CONTRACT section (`## Done when` / `## Plan`) in the same edit that writes the Log entry, because the Log is narrative and the close gate reads the contract. A deferral recorded only in prose is a deferral the gate cannot enforce.

## Round 9 — 2026-09-19T02:52:33-07:00 (claude) — passed

### Disposed

- BR-32 — addressed — document_state_spec.lua:389-401 adds both negative cases; computing `generated` from the raw owner in a scratch copy turns both red (32/34).
- BR-33 — addressed — Fixed as a rule: ---@nodiscard on 7 functions plus nodiscard_spec, which selects by annotation; a planted bare custom_prompts.set goes red; the set_previous_answer drop is declared, with a reason that matches every reachable false path.
- BR-34 — not-addressed — helper.lua:694-697 still hand-rolls the idiom (10 copies in lua/); the deferral lives only in the Log and Revisions narrative, with no receiving issue, contrary to the lessons.md rule written in the same commit.
- BR-35 — addressed — e1540f4a adds the fixture obligation to parley#270's Done when; the rule is recorded in workshop/lessons.md.

### Raised

- **BR-36** [Minor] `enumeration-claims-completeness` nodiscard_spec only sees calls at the start of a line; three calling forms that drop the result pass green
  This is the 6th finding in family enumeration-claims-completeness. Planted and confirmed green: `if c then custom_prompts.set(a, {}) end` on one line, `pcall(custom_prompts.remove, a)`, and `local cp = custom_prompts; cp.rename(a, 'x')`. The rule is BR-31's: a regex guard's header lists the forms it cannot see, and nothing (commit message, lessons.md) claims "any bare-statement call" beyond what is matched. Cheap fixes: match statement starts after then/do/else/semicolon, and pcall/xpcall whose first argument is a member; record the rest in the header. Measured prevalence: 6 findings in the family; 0 live offenders today (all 9 call sites enumerated).
- **BR-37** [Minor] `allowlist-without-dead-entry-check` nodiscard_spec's DROPPED count is only a ceiling, so a declaration outlives the call it excuses
  Changing chat_respond.lua:1546 to consume its result leaves the D.set_previous_answer entry silently in place. Sibling guards reject dead entries (single_resolver_spec.lua:79-82, sidecar_authority_spec.lua:69, single_source_sweeps_spec.lua:692). Assert seen == declared.count for every DROPPED entry.

## Round 10 — 2026-09-19T03:51:20-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — addressed
- BR-2 — addressed
- BR-3 — addressed
- BR-4 — withdrawn

### Raised

- **BR-38** [Important] `seam-change-collateral` A killed content fetch writes "curl exited with code nil" into the transcript and drops the io_error that names the cause
  This is the 3rd finding in family `seam-change-collateral`. Do NOT fix
  oauth.lua:1424 alone. The rule: when a seam's contract changes the meaning
  of a value it hands out, sweep every consumer that RENDERS the value, not
  only those that BRANCH on it. Tasker now sets `code = nil` whenever
  `io_error` is set (tasker.lua:504-510); the branchers were swept by
  construction, the renderers were not. The enumeration over tasker exit
  callbacks is four: vault.lua:218 (fixed this round), dispatcher.lua:786
  (already prints io_error), dispatcher.lua:740 (log-only, now reads
  "exit code=nil signal=15"), and oauth.lua:1424 — the only user-visible
  one, which formats tostring(code) into transcript text that is then cached
  as that URL's error. The Done-when clause "User-visible errors identify
  the recoverable action" fails there. unscoped_kill_spec.lua:103 asserts
  only that the body is not used, so it stays green on the bad message.
- **BR-39** [Important] `seam-change-collateral` README still says Stop keeps running tools and their claims, which M3 inverted
  This is the 4th finding in family `seam-change-collateral`, and the second
  this round — which is the ledger reporting the enumeration was never
  written. Same rule as above, applied to prose consumers: a contract change
  must sweep every STATEMENT of the old contract, not only the code. The Stop
  contract changed (TERM to the group, SIGKILL at 2 s, claim released on
  resolution). atlas/chat/lifecycle.md and atlas/providers/tool_execution.md
  were updated in this range, tests/manual/chat-concurrency.md was updated,
  README.md:115-117 was not: "while the process supervisor keeps tools that
  are still running and their resource claims". The enumeration a boundary
  needs is "every file that states this contract", produced once, not per
  finding.
- **BR-40** [Important] `enumeration-claims-completeness` The new atlas section quantifies over every process Parley starts, but five spawn families sit outside the tasker seam
  This is the 7th finding in family `enumeration-claims-completeness`.
  Earlier rounds fixed instances. Do NOT fix this instance — state the rule
  and fix that. The rule: a statement quantified over a whole category
  ("every process", "all N sites") must either be produced by an executable
  enumeration over that category, or be scoped in words to the seam it
  actually covers. atlas/providers/tool_execution.md:71 says "Every process
  Parley starts is scoped or unscoped" and :113 says tasker.leave() sends
  "SIGKILL to every live process"; its own "Residuals, stated once" list
  names only a kernel hold, a secret command's grandchild, and an nvim
  crash. Measured exceptions: cliproxy.lua:665 (uv.spawn, detached,
  uv.unref, whose docstring says it is spawned to OUTLIVE nvim — a
  deliberate counterexample), cliproxy.lua:1380 (jobstart), ~13 vim.system
  calls in cliproxy.lua, git_markdown_source.lua:140 (uv.spawn with its own
  TERM-only cancel, no group, no deadline), and the vim.fn.system fallbacks
  in tools/builtin/{ls,grep,find,ack,chat_history_search}.lua plus
  init.lua:4740. The class fix that matches this repo's own convention is an
  arch guard over the spawn seam (tests/arch/), which also makes the atlas
  quantifier true by construction; if it carries an allowlist, note family
  `allowlist-without-dead-entry-check` already fired once on this issue.
- **BR-41** [Minor] `seam-change-collateral` generate_topic replaces rather than merges transport_opts, so partial opts lose the deadline and are refused
  chat_respond.lua:1049 uses `transport_opts or { deadline_ms = ... }`. One
  production caller today (init.lua:4429, passes nothing), so no defect
  ships. M4's W16 touches topic generation and is the likely trigger: a
  caller passing `{alive = fn}` with no generation gets refused at spawn.
  Set deadline_ms into the table when unscoped and unset instead.
- **BR-42** [Minor] `stateless-double-at-stateful-seam` The process fake models group signals and pid signals with two different semantics
  fake_process.lua:95-113: the group branch always delivers the signal and
  ignores process.probe and process.signal_result; the pid branch honours
  probe, signal_result and opts.finish_on_signal. A scoped record therefore
  cannot be made to observe unknown/EPERM at all — which is why
  tasker_run_spec.lua:913 had to move its failed-signal-retry case from a
  scoped attempt to an unscoped one, losing that coverage for groups rather
  than extending it.
- **BR-43** [Minor] `untrusted-input-unparsed` target() has no pid == 0 guard, and -0 == 0 would signal Neovim's own process group
  tasker.lua:212-216. Unreachable today (uv.spawn never yields pid 0, and a
  failed spawn is rejected before the record is armed), but the fake added
  `if pid == 0 then error("signalled Neovim's own process group") end`
  precisely because the failure mode is catastrophic and silent. The
  production side should be at least as defensive as its double.
- **BR-44** [Minor] `residue-names-no-end` The one-shot deadline timer is closed only by retire, the one path a held record never takes
  tasker.lua:564-571 arms the timer and tasker.lua:191 closes it in retire().
  A record that reaches unresolved-visible is retained by design and never
  retires, so its already-fired uv timer handle is retained with it. Bounded
  by held records, but it is a handle whose only removal path is the one
  branch that by definition does not run.

## Round 11 — 2026-09-19T04:11:34-07:00 (claude) — BLOCKED

**Protocol error:** no valid findings block — this round contributed no findings.

## Round 12 — 2026-09-19T07:53:50-07:00 (claude) — BLOCKED

### Disposed

- BR-38 — addressed — tasker.exit_reason plus the raw-render guard; verified red on revert in unscoped_kill_spec and spawn_seam_spec. Its stated four-callback enumeration is fully swept; the wider renderer class is raised anew below.
- BR-39 — addressed — README.md:115-120 now states TERM then SIGKILL at 2 s and scopes the claim-holding to "until the process has ended"; I re-ran the superseded-claim sweep and found no other stale statement.
- BR-40 — addressed — Atlas quantifiers scoped to tasker.run, and spawn_seam_spec is an executable per-file census with a dead-entry check; verified red on a planted spawn in logger.lua.
- BR-41 — not-addressed — The merge is correct but untested; I wrote the 8-line test and it goes red on the old `transport_opts or {…}` form.
- BR-42 — addressed — Both kill paths share one scripted() helper and the failed-signal-retry case is parameterised over pid and group; verified red when the group branch's scripted() call is removed.
- BR-43 — not-addressed — The guard is correct but has no test, and the fake has no seam to spawn a pid other than 4242 — add a spawn_pid option, then assert a pid-0 record records `missing` and signals nothing.
- BR-44 — not-addressed — The in-callback close is correct but untested; the existing supervision assertion at :232 passes via retire either way. I wrote the held-record test and it goes red without the fix.

### Raised

- **BR-45** [Important] `seam-change-collateral` The dispatcher re-exports code/io_error on its failure table, and both of that table's renderers still drop io_error
  This is the 5th finding in family `seam-change-collateral`. Do NOT fix
  chat_respond.lua:24 and response_provider.lua:13 alone. The rule BR-38
  stated was "sweep every consumer that RENDERS the value"; it was
  implemented as "every file containing the literal tasker.run(", which is
  a call-site anchor, not a value anchor. The value crosses one more seam:
  dispatcher.lua:760-768 builds failure = {code, signal, io_error, …} and
  hands it to on_error. chat_respond._failure_notice (chat_respond.lua:23-24)
  renders tostring(failure.code) — now dead, since code is nil on every
  kill — then up to 500 chars of raw partial body; response_provider
  failure_reason (response_provider.lua:11-15) renders
  "provider request failed (HTTP unknown)". Neither reads io_error, so a
  deadline- or leave-killed stream never names its cause to the user, the
  same Done-when clause BR-38 cited. Neither file is in the guard's scope,
  and its pattern tostring%(%s*[%w_]*code%d*%s*%) cannot match
  tostring(failure.code) because `.` is outside [%w_]. The rule-level fix:
  render once at the seam that produces the value (failure.reason =
  tasker.exit_reason(code, signal, io_error)), have both consumers read it,
  widen the guard's scope predicate from "calls tasker.run(" to "reads a
  .code off a table that also carries io_error", and list the forms the
  matcher cannot see in its header, as single_source_sweeps_spec does.
  M5 Task 5.3 plans to keep _failure_notice as `detail`, so it inherits this.
- **BR-46** [Important] `enumeration-claims-completeness` The out-of-seam spawn list's per-entry reasons are unchecked prose, and two of eighteen are wrong
  This is the 8th finding in family `enumeration-claims-completeness`. Do
  NOT fix the two entries alone. atlas/providers/tool_execution.md:125-128
  now defers to tests/arch/spawn_seam_spec.lua as the list of each
  out-of-seam spawn "with how it ends", which makes every `reason` string
  load-bearing documentation — but the test asserts only that it is a
  non-empty string. spawn_seam_spec.lua:33 calls git_markdown_source "a
  bounded `git show` read with its own cancel": the command is `git ls-files
  -z --cached --others --exclude-standard -- *.md`
  (git_markdown_source.lua:135-143), markdown_finder arms no timer, and
  request_kill (git_markdown_source.lua:37-43) sends one sigterm with no
  escalation, only on caller cancel. spawn_seam_spec.lua:31-32 says
  cliproxy's calls "carry curl or vim.system timeouts": false for lsof
  (cliproxy.lua:842), `<bin> -h` (:1024), `ps ax` (:1066), sha256sum (:2027)
  and tar (:2106) — all synchronous :wait() with no timeout, which is an
  answer, but not the one given. The rule: an enumeration whose entries
  justify a documented claim must make each justification checkable — assert
  a classification derived from the call form (sync ⇔ :wait()/vim.fn.system*;
  bounded ⇔ the call carries `timeout =` or `--max-time`) and keep free text
  only for genuine exceptions such as the managed proxy.

## Round 13 — 2026-09-19T08:39:37-07:00 (claude) — passed

**Protocol error:** no valid findings block — this round contributed no findings.

## Round 14 — 2026-09-19T09:54:45-07:00 (claude) — BLOCKED

### Raised

- **BR-47** [Important] `seam-change-collateral` Three atlas passages and six stop_owner doubles still state the contract M4 replaced
  7th in this family: do not patch the sites. Rule — a change to how a seam
  behaves, or that makes a previously-ignored part of its contract
  load-bearing, updates every restatement of it (prose, comments, doubles)
  in the same commit, enumerated by grepping the seam name and the old
  claim. Instances: tool_execution.md:88 still lists content fetches as
  unscoped while lifecycle.md:337 links there claiming the scope kill reaches
  them; architecture.md:44 keeps "a zero-match stop can still mean
  asynchronous readiness is pending" (reversed by W5); ownership.md:71-73
  keeps "a cancellation request alone does not prove an effect stopped" two
  lines under the new sentence that contradicts it; stop_owner's count is now
  load-bearing at response_provider.lua:124 but respond_fixture.lua:23 and
  five inline copies return nil, so no chat-level test takes the branch
  (ARCH-MOCK, and ARCH-DRY for the six copies).
- **BR-48** [Important] `behavior-change-without-regression-test` W15, the Copilot pre_query forward and 11 of 12 oauth scope sites redden nothing on revert
  2nd in this family. Rule — every behavior-changing edit site has a test
  that goes red when that site alone is reverted, and the as-built
  "red on revert" line is written per edited site, not per W-row; a pcall
  guard is a behavior change only once a test makes its callee throw.
  Measured: W15's three guards (chat_respond.lua:1337, 1338, 1716) have no
  test, yet Task 4.2 Step 1 is ticked as covering W15; removing on_error from
  providers.lua:1081 in a scratch export left vault, dispatcher_query,
  providers_pre_query, cliproxy_catalog, cliproxy_dispatch, response_provider
  and unscoped_kill all passing; only the public hop of the oauth content
  tree asserts its scope (unscoped_kill_spec.lua:201).
- **BR-49** [Important] `done-when-clause-untested` Only Stop drives the settle and scope kill; edit, reload and detach are untested
  2nd in this family. Rule — a Done-when clause that enumerates alternatives
  is tested per alternative, parametrized over the list so a missing one is
  visible in the test name. Every M4 case stops via Runner.cancel or
  cancel_responses; the plan's own strategy (plan:1329-1333) required each
  applicable stop cause per case, and the Done-when names "Stop, an edit that
  revokes it, reload or detach". The E2E only reloads after terminal, so the
  shape #261 was filed from — an edit during generation — never drives the
  kill path. submit_and_stop already has the harness.
- **BR-50** [Important] `enumeration-claims-completeness` Atlas says the settles spec holds one case per wait; it holds 7 of 18
  9th in this family. Rule — prose never asserts a count or completeness over
  an enumeration it does not carry: give the W-table a `test:` column naming
  the spec and case for each row (including "none"), and have the prose point
  at the table. atlas/chat/lifecycle.md:347 claims one case per wait, while
  W2-W8, W12, W13 and W15-W18 live in seven other specs and W10 was dropped;
  plan:1329 and plan:1335 still state the superseded strategy, including an
  after_each assertion on tasker.stats().active that was not built.
- **BR-51** [Minor] `state-change-bypasses-model` After a fault the runner's snapshot reports the machine's non-terminal phase
  generation_runner.lua:470-474 ends the generation outside the pure machine,
  so M.snapshot (:685) reports e.g. phase='streaming' while the host was given
  phase='terminal', outcome='fault' (ARCH-ORDER: two authorities for the same
  fact). Make fault a machine event, or have M.snapshot report the final it
  delivered.
- **BR-52** [Minor] `canonical-form-not-shared` W16 keys on a missing handle, the condition Task 4.1 rejected for W1
  response_topic.lua:45-46 infers "the request threw" from `not s.handle`,
  while the runner marks `start_threw` because a nil handle is not the same
  thing. It makes response_topic.lua:88-92 unreachable and retires the topic
  while a process spawned during a re-entrant stop is still unconfirmed.
- **BR-53** [Minor] `one-shot-cleanup-not-a-gate` A fetch chain resuming after the scope kill spawns into a dead scope
  chat_respond.lua:1577-1580 says whatever the fetch started dies with the
  scope kill. A chain paused at an unscoped hop (keychain, refresh, auth
  prompt) resumes after the kill and spawns fresh scoped processes nothing
  will signal, bounded only by their 120 s/60 s deadline. State the residual,
  or refuse a scoped run whose scope has already been stopped.
- **BR-54** [Minor] `absence-inferred-from-throw` A thrown start_child is resolved as "nothing was started"
  generation_runner.lua:360-364 resolves the child at once on the rationale
  that nothing started; a throw is not proof of that — the same assumption the
  remote-preparation spec used to pin against. The `unknown` outcome is
  honest, but the residual (a tool process started before its adapter threw
  runs into the next round and dies only at the generation's terminal kill)
  should be stated rather than denied.
- **BR-55** [Minor] `partial-guard-window` W14's pcall stops one statement short of the admission increment
  generation_runner.lua:675-678 increments `active` before `sync(s)` and
  `dispatch(s,{type='start'})`, both outside the guard that W14 added; a throw
  there reopens the same leak in narrower form.
- **BR-56** [Minor] `stub-restored-outside-finally` D.subscribe and FS.new stubs are restored outside a pcall
  2nd in this family. Rule — a spec replaces a module field only through a
  with_stub(tbl, key, value, body) helper that restores on every path, so a
  regression fails one case instead of cascading. Instances:
  generation_settles_spec.lua:56-59 (D.subscribe) and
  skill_invoke_spec.lua:250-256 (FS.new).

## Round 15 — 2026-09-19T10:25:53-07:00 (claude) — BLOCKED

### Disposed

- BR-47 — addressed — Atlas passages a-c corrected; one returning stop_owner double plus an arch guard. Chat-level reachability of W5 raised separately (Minor).
- BR-48 — addressed — Reverting the cancel_entry guard, the Copilot forward, or any of 7 of 7 sampled oauth sites (1393,1756,1926,2059,2143,2371,2505) turns a test red.
- BR-49 — addressed — With SIGKILL escalation disabled, all four stop-cause cases (stop, edit, reload, detach) and the 3 other end-to-end cases go red.
- BR-50 — addressed — WAITS list accurate (29/29 citations resolve); atlas points at it; plan revision supersedes Chunk 4. The check's self-match raised as a new Minor.
- BR-51 — addressed — Removing the final_outcome line from M.snapshot reddens the fault case.
- BR-52 — not-addressed — Code now keys on start_threw, but reverting to `not s.handle` leaves response_topic_spec 13/13 green; no test drives a stop arriving during provider.request.
- BR-53 — addressed — tasker refuses a run into a stopped scope; removing the refusal reddens tasker_supervision_spec.
- BR-54 — addressed — generation_runner.lua:362-365 now states the residual (a process spawned before the throw runs until the scope kill).
- BR-55 — addressed — Moving sync and dispatch back outside the pcall errors the W14 dispatch case.
- BR-56 — addressed — Both named sites use with_stub, which restores on every path.

### Raised

- **BR-57** [Important] `seam-change-collateral` stop_scope now closes a scope for good and tasker.run refuses into it, but the atlas says neither
  8th in family. The rule already exists (grep the seam's name); the fix round
  applied it to the review's list, not to the seams it changed itself.
  tool_execution.md:100 still says only that stop_scope stops every process
  of one generation, and lifecycle.md:334-337 omits the refusal. Rule-level
  fix: each round's close greps every public function whose body the round
  changed across atlas/, fix rounds included. Instance: document the refusal,
  the 1024-key bound, and what happens to an evicted key.
- **BR-58** [Important] `behavior-change-without-regression-test` The fix commit's own new cancel_responses batch guard reddens nothing when reverted
  3rd in family. The commit claims every edited site has a red-on-revert test,
  but the sweep covered the prior review's list, not the commit's own new
  hunks. Reverting chat_respond.lua:1357 leaves chat_cancel_entry,
  batch_lifecycle, batch_respond, batch_validation_budget, chat_stop_generation
  and generation_settles green. Rule: the mutation sweep runs over every
  behavior-changing hunk of the whole boundary diff, including the fix round's.
- **BR-59** [Minor] `allowlist-without-dead-entry-check` The WAITS check always passes for the 7 citations that name generation_settles_spec itself
  generation_settles_spec.lua:379 does a raw-text find over the named file, and
  that file contains the WAITS list with every case name in it. Renaming the W11
  case left the check green. Fix: match `it(` followed by the case name, and
  strip the WAITS block before searching.
- **BR-60** [Minor] `stateless-double-at-stateful-seam` No chat-level spec can reach W5's zero-match branch, though the plan says they now do
  4th in family. Instrumenting response_provider.lua:125 gave 0 hits across the
  six chat specs and generation_settles; the only hits came from
  response_provider_spec. The dispatcher.query doubles register calls
  synchronously (no pre_query window), and the stop_owner double only marks a
  call stopped through its own stop. Rule: a double models every phase of the
  seam the consumer branches on, and a claim that a test level takes a branch
  is measured, not inferred. plan:2215 claims otherwise.

## Round 16 — 2026-09-19T10:57:35-07:00 (claude) — BLOCKED

### Disposed

- BR-52 — addressed — Measured: keying on `not s.handle`, or widening `elseif s.handle` back to `else`, each fails the new stop-during-request case.
- BR-57 — addressed — tool_execution.md:103-109 documents the refusal, the 1024 bound and the evicted key; lifecycle.md:337 says the scope stays closed. Matches tasker.lua:389-393,500-502.
- BR-58 — addressed — Reverting chat_respond.lua:1357 fails batch_lifecycle_spec's new throwing-batch-cancel case.
- BR-59 — addressed — `declares` strips the WAITS block and matches a real it(/describe( opener; renaming the W11 case now fails the check, and a counterfactual case pins both directions.
- BR-60 — addressed — The claim is retracted in respond_fixture.lua:9-16 and plan Revisions; W5 stays pinned at response_provider_spec, which is where the branch lives.
- BR-48 — not-addressed — The W15 terminal-handler site (chat_respond.lua:1728) still reddens nothing: reverted to its base unguarded form, 12 related specs stay green. The WAITS W15 row cites a test of the shared helper, not of this site.

### Raised

- **BR-61** [Important] `seam-change-collateral` The dispatcher still documents a one-arg pre_query, naming copilot, after W6 made it two-arg
  9th in family. Do not patch the sites. The rule was written twice and narrowed
  each time (round 2's lesson limits the grep to atlas/, excluding comments), and
  both rounds enumerated from the review's list of seams rather than the change's
  own. The enumeration that covers all nine already exists: the W-table. Rule -
  every change row whose fix alters a seam's contract gets its own
  `grep -rn <seam name> lua/ atlas/ tests/`, and the as-built records the hit list
  with each hit's disposition; fix-round rows are appended to the same table.
  Measured instances, both from rows nobody re-grepped: dispatcher.lua:884-885
  still says a one-arg pre_query "(e.g. copilot) simply ignores the error callback",
  which is the hazard W6 closed and names the wrong example, since providers.lua:1079
  is now two-arg and no production adapter is one-arg; and
  atlas/providers/cliproxy-managed.md:257-266 enumerates the claim contract as
  falsy/truthy/no-hook without W8's new precondition, the transport_alive check at
  dispatcher.lua:808 that stops a dead owner reaching the hook at all.
- **BR-62** [Minor] `partial-guard-window` The topic's deferred cancel discharges only on the request's normal exit
  2nd in family. Round 2 made a stop during the request wait for the handle
  (response_topic.lua:49-55), but request() answers that obligation only when it
  returns normally (:89-94). Probed with a fake whose request stops the topic
  re-entrantly and then throws: stop() at :87 returns false because s.stopping is
  already set, and the topic sits in `stopping` forever holding its generation and
  two user captures. The deferred copy is also not pcall-ed while the inline copy
  is, and neither copy reads cancel_operation's false return (ARCH-ORDER,
  uncertainty collapsed into success). Unreachable through response_provider today,
  hence Minor. One cancel_through(s, handle) helper covering throw, falsy return
  and deferred resolve removes the divergence (ARCH-DRY).
- **BR-63** [Minor] `plan-tracking-not-updated` The Core-concepts tasker row still omits the stopped-scope refusal the prior round asked for
  3rd in family. plan:113 lists tasker's surface without stop_scope's recording or
  run's refusal; the fact lives only in the Revisions prose (plan:2249, :2265), and
  the greppable table the review cross-checks is what went stale. Round 2 applied
  the prior review's other three plan-revision recommendations and dropped this one
  silently. Rule: a round's revision entry enumerates the prior review's
  plan-revision recommendations and marks each applied or declined-with-reason.

## Round 17 — 2026-09-19T11:34:39-07:00 (claude) — passed

### Disposed

- BR-48 — addressed — Reverting only chat_respond.lua:1728 to the raw response_topic.cancel call fails chat_onboarding_capture_spec "finishes its ending cleanup when the topic cancel throws"; round 2 confirmed the Copilot forward and oauth sites.
- BR-61 — not-addressed — Named sites fixed and ledger built, but the W6 row omits dispatcher_query_spec.lua:602-607 (H2 "backward compatible", one-arg double commented "one-arg adapter ignores the error cb") and response_provider_spec.lua:89; ledger scope excluded doubles, and the new guard scans lua/ only while the stop_owner guard (:426) scans tests/.
- BR-62 — addressed — cancel_through (response_topic.lua:46-52) serves both sites; reverting accepted==false (m62a) or the request-throw branch (m62b) each fails its new case. Untested throw exit raised separately.
- BR-63 — addressed — plan:113 tasker row now records stop_scope's key and run's refusal (1024, oldest evicted); plan:2294-2311 disposes each prior recommendation.

### Raised

- **BR-64** [Minor] `behavior-change-without-regression-test` cancel_through's throw exit and the direct site's refused-cancel exit fail nothing when reverted
  4th in family. Rule: record counterfactuals per hunk in a mutation ledger next
  to the seam ledger (hunk -> mutation -> failing test, or "none, unreachable
  because X"); a whole-file or whole-commit revert is not evidence for any single
  hunk. plan:2306's "red on the old code" was a whole-file revert. Measured:
  removing the pcall at response_topic.lua:47 leaves response_topic,
  chat_onboarding_capture, topic_presentation, branch_topic_input,
  chat_stop_generation and generation_settles passing (no test makes a topic's
  cancel_operation throw; the pcall came in with a2ee8102). Reverting :60 to the
  old inline copy that ignores `false` leaves response_topic_spec 16/16 passing.
  Unreachable through response_provider today.

## Round 18 — 2026-09-19T13:32:03-07:00 (claude) — BLOCKED

### Raised

- **BR-65** [Important] `behavior-change-without-regression-test` The provider-detail suppression at chat_respond.lua:1763 is dead, so the diagnosis prints twice and `staging overflow` leaks
  `result.outcome == 'provider_failed' and failure_notice and nil or result.failure`
  parses as `((A and B) and nil) or result.failure`, so `failure` is always
  `result.failure`; the comment above it ("its reason is not repeated") describes
  behaviour that never happens. Verified against the shipped module: the user gets
  "the model's request failed (provider request failed (HTTP 503)); submit again —
  parley: provider request failed (HTTP 503): upstream down". The same line also
  passes `result.failure` for `overflow`, so the internal token "staging overflow"
  is shown, against M5's "no raw token". **This is the 5th finding in family
  `behavior-change-without-regression-test`.** Earlier rounds fixed instances. Do
  NOT just fix this site — the rule is: a change to a user-visible message needs an
  assertion on the WHOLE message (equality), not a substring probe. The existing
  case asserts `find("HTTP 503")`, which is true before and after the intended
  suppression, so it reports nothing; the two batch cases in the same file already
  use equality and are the model. Apply the rule to every ending that composes
  what + extra + action + notice (`provider_failed`, `overflow`, `prepare_failed`).
- **BR-66** [Important] `enumeration-claims-completeness` The refusal census scans call shapes, not the values describe() keys on, so `issue(s,<lit>)` tokens have no words
  `describe`'s first lookup key is the `failure` string, written directly by
  `issue(s,<lit>)` in generation_runner.lua:152 — a form absent from the spec's
  FORMS list although generation_runner.lua is in FILES. Unkeyed as a result:
  'staging overflow' (:163, user-visible today, see the other Important finding),
  'adapter failed' (:301), 'cancel adapter missing; operation unresolved' (:542).
  Two further blind spots of the same shape: a token that appears only as an
  argument to `refuse(kind, outcome, <lit>)` (chat_respond.lua:1806 'not a chat',
  :1421 'no stale continuation ready') is never scanned; and the new shared-cache
  guard (single_source_sweeps_spec.lua:391) keys on the literal `stdpath('cache')`
  while the hazard is a spec that inherits dispatcher.lua:17's default query_dir
  and writes there without naming it. **This is the 10th finding in family
  `enumeration-claims-completeness`.** Earlier rounds fixed instances (composed
  reasons, `reject(owner,lit)`) — this round adds a third hole in the same guard.
  Do NOT add another regex. The rule: a guard must key on the VALUE that reaches
  the behaviour, not on the syntax that produces it. For the vocabulary, invert it
  — have `describe` record every token that resolves to "unexpected" (or to an
  outcome-row fallback) into a process-global set, and fail a spec that finds the
  set non-empty after the suite; that covers every present and future producer
  form. For the cache guard, assert at runtime that `dispatcher.query_dir` does not
  resolve under `stdpath('cache')` during a spec run.
- **BR-67** [Minor] `action-does-not-unblock` `unknown effect` tells the user to run :ParleyToolOperations, which cannot let the batch resume
  batch.lua:93 sets `s.unknown` and :99 rejects every later resume; nothing ever
  clears it, and tool_operations.lua reconciles producer records only. The action
  that actually works after this round's give-way change is ":ParleyChatRespondAll
  to start a new batch". The unit spec only checks that an action matches
  `:Parley%u` — it cannot see that the named command does not clear the condition.
- **BR-68** [Minor] `fallback-order-hides-known-cause` describe() consults REVOKED only when failure is nil, so a revocation carrying any failure reads "unexpected"
  refusal.lua:230 gates the cause-specific wording on `failure == nil`, and
  'revoked' has no TOKENS row, so `describe('ended','revoked',<any string>,
  {cause='edit'})` returns "Response stopped: unexpected (...)". Reachable whenever
  a cancel/insert path calls `issue()` before the terminal (generation_runner.lua:542,
  :572, :598). Prefer the cause when one is recorded, and fall back to the failure.
- **BR-69** [Minor] `returned-handle-has-no-consumer` init.lua:4174 still forwards a 4th argument that chat_respond.respond does not accept
  The force flag it carried was deleted this round (cmd_respond), but
  `M.chat_respond = function(p, cb, ofc, f) return chat_respond.respond(p, cb, ofc, f) end`
  still passes it to a three-parameter function. **This is the 5th finding in
  family `returned-handle-has-no-consumer`.** The rule, rather than this instance:
  when a parameter or field loses its last reader, delete it at every hop of the
  call chain in the same commit, and grep the symbol before closing the task —
  the same grep Task 5.3 Step 3 already ran for `resubmit_questions_recursively`.
- **BR-70** [Minor] `comment-outlives-its-behavior` chat_context.lua's header comment still describes the pre-M5 reporting it no longer owns
  Lines 4-9 say "chat_respond.respond names the file, and chat_respond.respond_all
  returns `nil, reason` to its caller for the header case". After this round
  respond routes through `refuse('start', nil, 'not a chat', {notice=reason})` and
  no longer names the file, and respond_all warns as well as returning. Not the
  `docs-reflow-after-deletion` family: nothing was deleted from this doc — a
  behaviour moved out from under a comment that describes a collaborator.

## Round 19 — 2026-09-19T13:53:45-07:00 (claude) — BLOCKED

### Disposed

- BR-65 — addressed — Verified on the shipped module and by running the spec: the provider, prepare and
overflow endings now assert whole messages and the internal token no longer leaks.
- BR-66 — not-addressed — The census never fails for the outcome-row fallback, which is exactly where
`issue(s,<lit>)` tokens land: R.describe('ended','provider_failed','brand new runner
token') returns "...the model's request failed (brand new runner token)..." with
unkeyed() empty. Where it can fire, the error is thrown inside the terminal callback
that generation_runner.lua:476 and response_session.lua:14 each pcall and discard.
Remaining: fail (or assert after each spec) on _detail_only too, report through a
channel the seam cannot swallow, and correct the atlas/target sentence crediting
refusal_vocabulary_spec with catching any wordless producer reason.
- BR-67 — addressed — The named command genuinely unblocks: respond_all disposes a paused, settled batch
(chat_respond.lua:2008-2015) and batch.lua:93 leaves exactly that state.
- BR-68 — addressed — Cause now outranks a stray failure (refusal.lua:252), asserted by equality in
refusal_spec.lua:80.
- BR-69 — addressed — init.lua:4174 forwards three arguments; every call site in lua/ and tests/ passes one.
- BR-70 — not-addressed — The stale sentence was replaced by another inaccurate one: "respond and respond_all
both warn, and both still return `nil, reason`" — respond returns a bare `return` on
both ctx failures (chat_respond.lua:1813) and respond_all does on its not-a-chat path
(:2005); init's wrapper logs an ERROR, not a warning, for a broken header
(init.lua:4300). Rule: a comment about a collaborator cites it (file:line) or states
only what this module guarantees.

### Raised

- **BR-71** [Important] `test-hook-in-production-path` Both new guards live in production code behind PARLEY_TEST_MODE; one makes the pure vocabulary stateful and grows unbounded in production, the other is swallowed by the calling seam
  refusal.lua:230-235 and dispatcher.lua:677 put harness-only checks on production
  paths. `describe` is declared pure (refusal.lua:3) and listed under the plan's Pure
  entities, but now mutates M._unkeyed/M._detail_only and branches on vim.env
  (ARCH-PURE). M._detail_only is written unconditionally, in production too — one entry
  per distinct provider diagnosis, carrying up to ~500 chars of provider body, with
  forget_unkeyed() called only from specs: a growing structure with no removal path and
  no bound (ARCH-FUNERAL; ARCH-SECURE for the retained body text). The dispatcher's
  error is caught by generation_runner.lua:365 / response_provider.lua:100, so an
  integration spec sees "provider startup failed" instead of the guard's advice. The
  rule: a harness-only check belongs in the harness — record at the boundary (the
  `refuse` wrapper), assert from a spec hook, and default query_dir to $TMPDIR in
  tests/minimal_init.vim so no spec can inherit the shared cache.
- **BR-72** [Minor] `behavior-change-without-regression-test` The refusal spec's `one()` helper is a substring probe, so the batch-pause case still cannot see a second detail on the same provider_failed ending
  chat_refusal_spec.lua:159 asserts find("Response stopped: the model's request failed")
  on the ending BR-65 broke, and one() (:75) matches by substring for all 17 cases, so
  appended text is invisible. This is the 6th finding in family
  behavior-change-without-regression-test. Earlier rounds fixed instances. Do NOT fix
  this line — the rule is that a case asserting a composed message compares the WHOLE
  string; apply it by making one() take the full expected message and use assert.equals,
  so every present and future case inherits it.
- **BR-73** [Minor] `enumeration-claims-completeness` `revoked` has no TOKENS row, so an ending whose cause is not edit/reload/detach reads "unexpected (revoked)"
  refusal.lua:252 words a revocation only for a mapped cause; generation.lua:361 stops
  with outcome 'revoked' on any grant_revoked, while generation_runner.lua:132 records a
  cause only for EDIT_REASONS and epoch/detach — 'explicit revoke' and 'generation
  finished' leave it nil. No spec covers a cause-less revocation, so reachability is
  unverified either way. This is the 11th finding in family
  enumeration-claims-completeness. Do NOT add one row — the rule is that the terminal
  outcomes' rows are derived from the machine's outcome set, so an outcome without
  words fails at load rather than at a user's screen.
- **BR-74** [Minor] `stub-restored-outside-finally` refusal_spec sets the process-global _allow_unkeyed and restores it only on the success path
  tests/unit/refusal_spec.lua:44 sets R._allow_unkeyed = true and :50 restores it after
  the assertions; a failing assertion leaves the guard disabled for every later case in
  the process (and :35's assignment is already a no-op). This is the 3rd finding in
  family stub-restored-outside-finally. The rule: a spec that mutates a process-global
  restores it from after_each or through the repo's Stub.with_stub, never on the happy
  path.

## Round 20 — 2026-09-19T14:24:16-07:00 (claude) — BLOCKED

### Disposed

- BR-66 — not-addressed — The value census cannot fire on the ending path: every outcome now has a row, so an
unworded failure resolves `detail` (refusal.lua:245-254) and prints the raw token in
parentheses instead of `unkeyed`. Measured today across eight integration specs:
`start refused | detach` (8x), user-visible as "Response not started: the response could
not start (detach); submit again". That is the runner/adapter token form BR-66 named, and
the atlas/target sentences still over-credit the watch. The rule: a producer token and a
free-text diagnosis must not share the `failure` field — type them at the producer so a
failure that is neither keyed nor internal resolves `unkeyed` on every kind, and free text
arrives only through the caller-declared notice channel.
- BR-70 — addressed — chat_context.lua:4-9 now states only this module's own guarantee; verified no logger or
notify call remains in the module, and resolve/parse/chat_buffer return typed errors.
- BR-71 — addressed — describe is pure and stateless again (returns message + resolution); the watch lives in
tests/minimal_init.vim and was verified to fail a spec file with exit 1 through cquit;
dispatcher reads a plain $PARLEY_QUERY_DIR override with no harness branch.
- BR-72 — not-addressed — one() is equality now, but the case BR-72 named (chat_refusal_spec.lua:165, two refusals)
cannot use one() and still probes with find(); add a refusals_are({...}) helper asserting
the whole list and have one() delegate to it.
- BR-73 — addressed — generation.OUTCOMES declared next to stop() with an assert, and refusal.lua fails at load
if an outcome has no words; `revoked` has a row. All nine stop() call sites checked against
the set; removing the row makes every spec that requires refusal.lua fail at load.
- BR-74 — addressed — The process-global _allow_unkeyed is gone (no reference remains); the exemption is
file-scoped vim.g.parley_expected_unkeyed in refusal_spec.lua:5, with nothing to restore.

### Raised

- **BR-75** [Important] `canonical-form-not-shared` The document-lifecycle cause has no single home: 'detach' reaches the user raw on the start path, and the detach-to-reload mapping is written twice
  response_target.lua:116 retires with event.kind, which reaches refuse('start','start refused',why)
  and prints "Response not started: the response could not start (detach); submit again" — a raw
  token, plus an action the user cannot take because the chat is closed. The silence/wording rule
  for detach and reload is hand-written at chat_respond.lua:1773 and again at :2088-2091, and not at
  all here. This is the 3rd finding in family canonical-form-not-shared. Do NOT fix the one site:
  refusal.lua should own the mapping from a lifecycle token to words or silence for every kind, not
  only for outcome=='revoked', with every path handing it the raw token.
- **BR-76** [Important] `comment-outlives-its-behavior` The harness docs still say spec children start without tests/minimal_init.vim, which this milestone changed
  tests/minimal_init.vim:25-27 and atlas/infra/test_harness.md:42-46 both state that children never
  load the init and that g: variables never reach a spec; spec_runner.lua:19-22 now passes
  minimal_init to every child. This is the 2nd finding in family comment-outlives-its-behavior.
  The rule: a seam's behaviour change sweeps every prose claim naming that seam in the same round
  (grep minimal_init, PlenaryBustedFile, parley_test_mode across atlas, tests and TOOLING.md).
- **BR-77** [Minor] `canonical-form-not-shared` The response pause and the topic abort are still hand-written user notices the vocabulary guard cannot see
  chat_respond.lua:1702 words a pause with its own actions, and :1166 words a topic abort; neither
  derives from refusal.lua, and the arch spec cannot see them because it keys on the PREFIX literals
  and "Response paused" is not one — while the batch's pause IS in the vocabulary. 4th finding in
  family canonical-form-not-shared. The rule: key the guard on the channel — a logger.warning or
  vim.notify literal inside the submit/generation modules that is not refuse()'s return is a finding.
- **BR-78** [Minor] `allowlist-without-dead-entry-check` NOT_REFUSAL still claims busy, refused, revoked and stale reach no user, while TOKENS words all four
  Measured against the spec's own tables: those four keys are in both refusal_vocabulary_spec.lua:19-26
  and refusal.lua TOKENS, so the allowlist entries are shadowed and their stated reason is now false.
  3rd finding in family allowlist-without-dead-entry-check. The rule: assert the allowlist is disjoint
  from TOKENS/INTERNAL and that every entry is still produced by the scan, rather than deleting
  whichever entry a reviewer noticed.
- **BR-79** [Minor] `state-change-bypasses-model` A batch pause's cause lives in host-side flags outside the batch machine
  What the pause says depends on phase, active, the weak-keyed user_stopped[batch] and the leg_spoke
  upvalue (chat_respond.lua:2037-2044, :2071-2080); the legal combinations are unwritten and only the
  happy interleaving is pinned. 2nd finding in family state-change-bypasses-model. The rule: the cause
  of a pause is part of the batch's transition (cancel(batch, {cause='user'}) surfaced on the snapshot),
  so it is readable off the model and drivable by a sequence test.
- **BR-80** [Minor] `plan-tracking-not-updated` Round 2's dispositions are recorded one finding id off the ledger in both the issue Log and the plan
  Logged "BR-73" is ledger BR-72 (the one() helper), logged "BR-74" is BR-73 (the outcome set), and
  "BR-70/72" is BR-70/74 (the file-scoped exemption). 4th finding in family plan-tracking-not-updated.
  The rule: a disposition quotes the ledger id verbatim, so a later round can verify what was claimed.

## Round 21 — 2026-09-19T15:09:22-07:00 (claude) — passed

### Disposed

- BR-66 — addressed — The value-keyed inversion is built (describe returns a resolution; minimal_init.vim:59-79 fails the file via cquit) and the cache hazard is removed by construction via $PARLEY_QUERY_DIR rather than a runtime assert; all three named runner tokens now have rows. The residual gap — the watch only sees values a spec drives — is raised separately.
- BR-72 — addressed — chat_refusal_spec.lua:78-86 — refusals_are uses assert.same on the whole list and one() delegates to it, so all 17 cases compare full messages, including the two-message batch case.
- BR-75 — addressed — refusal.LIFECYCLE (refusal.lua:198-203) is consulted before the token lookup for every kind; response_target.lua:116's raw event.kind now resolves silent/reload, and chat_respond.lua:48-51 is the single detach-to-reload mapping used by both call sites.
- BR-76 — addressed — tests/minimal_init.vim:3,26-32 and atlas/infra/test_harness.md:43-56 both now describe what spec_runner does and name the specs that set g:parley_test_mode themselves; grep over atlas/TOOLING/Makefile finds no surviving stale claim.
- BR-77 — addressed — chat_respond.lua:1716 and :1188 go through refuse('paused'/'topic'), and refusal_vocabulary_spec.lua:138-152 keys on the channel. The guard's literal-only match is a new finding, not this one.
- BR-78 — addressed — refusal_vocabulary_spec.lua:124-136 asserts NOT_REFUSAL is disjoint from TOKENS/INTERNAL/LIFECYCLE and that every entry is still produced by the scan; busy/refused/revoked/stale are gone from the allowlist.
- BR-79 — addressed — batch.lua:76-81 validates the cause in the transition, :113 clears it on resume, snapshot copies it, and chat_respond.lua:2074 reads it off the model; user_stopped and leg_spoke no longer exist anywhere in lua/ or tests/.
- BR-80 — not-addressed — The plan's round-2 entry was renumbered but the issue Log was not — at HEAD it still reads BR-73 for the one() helper (ledger BR-72), BR-74 for the outcome set (ledger BR-73), and BR-70/72 for the exemption (ledger BR-70/74).

### Raised

- **BR-81** [Important] `enumeration-claims-completeness` `failure` still carries free text on three producers, so a cliproxy start failure and every `fault` reach the user as "unexpected (...)"
  Measured: describe("ended","provider_failed","cliproxy: proxy did not become healthy within 30s — try :ParleyProxy status") resolves `unkeyed`. Chain: cliproxy.ensure_running's on_error (cliproxy.lua:731,736,777) or vault.run_with_secret's (vault.lua:251,267) -> dispatcher.lua:926 abort_before_start -> D.query on_abort -> response_provider.lua:99 abort -> failure_reason's string branch (:21) passes any string verbatim -> cb.failed(reason) with no diagnosis -> s.failure -> chat_respond.lua:1781. generation_runner.lua:492 (fault) and :69 (kill_scope) assign a raw Lua error to s.failure, which generation_settles_spec.lua:228 pins, leaving the `fault` TOKENS row (refusal.lua:179) with zero reachable consumers. Neither net sees any of it: the census FILES list omits cliproxy.lua, vault.lua, response_completion.lua, response_preparation.lua and response_topic.lua, and no spec drives these paths through the host.
  This is the 12th finding in family enumeration-claims-completeness. Earlier rounds fixed instances. Do NOT fix these three sites. The rule: `failure` must hold a value `refusal` can resolve, enforced where the value is STORED, not where it is displayed — otherwise coverage of the invariant equals coverage of the specs, which is the syntax-vs-value mistake again. Export refusal.is_token(value) (a row, an INTERNAL entry, a ": " lead-in, or a LIFECYCLE key) and have generation_runner.issue route anything failing it into `diagnosis`, asserting under $PARLEY_TEST_MODE. fault, kill_scope and failure_reason are then covered by construction, and the FILES enumeration stops needing to be complete.
- **BR-82** [Important] `enumeration-claims-completeness` The channel guard matches only a string-literal first argument, so two live warning channels inside the file it scans are neither routed nor declared
  tests/arch/refusal_vocabulary_spec.lua:138-152 greps logger%.warning%(%s*(['"]) and vim%.notify%(%s*(['"]). A warning whose argument is a variable is invisible, and two are in chat_respond.lua, which is in CHANNEL_FILES: :437 logger.warning(plan.warning) — the attachment-budget notice, no prefix, no action; and :1364 _parley.logger.warning(label .. ' failed: ' .. tostring(err)) — the guarded() helper behind cancel_topic and stop_batch, so a throwing batch cancel prints a raw traceback on the Stop path. The test "routes every user notice in the submit path through refuse" therefore passes while asserting something untrue, and NOT_A_REFUSAL_NOTICE claims a completeness it does not have.
  Same rule as the finding above, applied to the channel: match on the CALL, not on its first token — scan logger.warning( / vim.notify( regardless of argument shape and require every site to be refuse()'s return or an explicitly declared non-refusal. Then route plan.warning and guarded through the vocabulary.
- **BR-83** [Minor] `returned-handle-has-no-consumer` Two handles added this round have no reader: the `_lifecycle_cause` test seam and `result.refusal`
  chat_respond.lua:52 exports M._lifecycle_cause labelled "-- test seam" with no test referencing it — the only one of the repo's five such exports without a consumer. result.refusal is written at chat_respond.lua:1754 and :1781 and read nowhere in lua/ or tests/, while the plan's round-3 revision claims the batch consumes it; the batch actually derives leg_stopped from generation.OUTCOMES[state.reason] at :2078.
  This is the 6th finding in family returned-handle-has-no-consumer. Do NOT fix the two sites — the rule is that an M._* export labelled a test seam, and a field added to a snapshot or result table, must have a reader in the same commit. A cheap arch assertion over "-- test seam" exports in lua/ would pin the first half permanently.
- **BR-84** [Minor] `canonical-form-not-shared` Six hand-written variants of "first line of a Lua error", three of which throw on an empty message
  tostring(x):match('^[^\n]+') appears at chat_respond.lua:1670, :1693, :1297, response_session.lua:95, :164; response_target.lua:113 uses :sub(1,512) instead. Only two carry the `or 'unknown'` fallback. Verified: debug.traceback("") begins with a newline, so the match returns nil and the three unguarded sites raise "attempt to concatenate a nil value" inside the failure handler itself.
  This is the 5th finding in family canonical-form-not-shared. Do NOT fix the individual sites — one helper (refusal.brief(err)) with the fallback and the cap built in, used by all six.
- **BR-85** [Minor] `canonical-form-not-shared` init.lua's chat_context wrapper still hand-words "not a chat" and the missing header for four commands
  init.lua:4294-4303 composes its own sentences ("Prune is only available in chat files: <raw reason>", "could not find header separator ---") for ChatPrune, ExchangeCut, ExchangePaste and NewQuestion, in a different voice and with no action, while refusal.lua now owns both facts and chat_respond.respond was converted to refuse('start', nil, 'not a chat'|'chat header unavailable'). Out of M5's declared submit-path scope, but it is the remaining hand-maintained restatement the ARCH-PURPOSE shadow-sweep asks for.
  This is the 6th finding in family canonical-form-not-shared. The rule: a condition the vocabulary keys has one wording for every entry point — give chat_context's reporting wrapper a refuse() kind rather than four sentences.
- **BR-86** [Minor] `untrusted-input-unparsed` lifecycle_cause maps detach to reload on a buffer number alone, and buffer numbers are reused after :bd
  chat_respond.lua:48-51 returns 'reload' whenever nvim_buf_is_valid(buf) and nvim_buf_is_loaded(buf), without checking the buffer is still the same chat. Buffer-number reuse after :bd is the hazard this issue's own audit named, so a closed chat whose number was taken by another file reports "the chat was reloaded while the answer was being written; submit again". The window is narrow (the terminal fires on the next deferred turn) and the fix is one comparison against D.get(buf) or the buffer name.
- **BR-87** [Minor] `residue-names-no-end` The per-process query directory the harness creates has no removal path, and replaced a bounded artifact
  tests/minimal_init.vim:56-58 creates $TMPDIR/parley-query-<pid> in every nvim process and nothing removes it; request bodies accumulate inside, one directory per spec file per run. `make test` is bounded by its leading test-clean-env, but `make test-spec`, `make test-changed` and the direct PlenaryBustedFile invocation TOOLING.md documents all leave them. Note also that this replaced an artifact with a writer-side bound (the shared query_dir's >200->100 prune) with an unbounded per-process one.
  This is the 3rd finding in family residue-names-no-end. The removal belongs beside the creation (a VimLeavePre delete of the directory), not in a target the operator must remember to run.

## Round 22 — 2026-09-19T16:03:40-07:00 (claude) — BLOCKED

### Disposed

- BR-20 — addressed — One BEARER_SCHEMA (vault.lua:161) applied to both the file read (:184) and the network response (:229); vault_spec V1 pins a non-numeric expires_at.
- BR-23 — addressed — helper.lua:622-660 resolves the real target and copies its mode; remove_stale_temps has three call sites; helper_io_spec F3g/F3h/F3i pin symlink, mode and sweep.
- BR-24 — addressed — sidecar_authority_spec.lua:22-33 selects on state_dir OR stdpath('data'); file_access.json is in sidecars.lua with a schema, an exercise and a table_to_file write.
- BR-34 — not-addressed — helper.lua:696-699 still hand-rolls resolve(fnamemodify(n,':p')); no helper.canonical_path exists anywhere in lua/, and file_refresh.lua:6 still has its own copy.
- BR-36 — addressed — nodiscard_spec now matches statement heads after then/do/else/; and bare pcall/xpcall, and its header lists the four forms it cannot see.
- BR-37 — addressed — The stale check asserts seen == declared.count for every DROPPED entry and reports "declared N, found M".
- BR-41 — addressed — chat_respond.lua:1088-1090 merges and only defaults deadline_ms when unscoped and unset; topic_gen_spec:76-80 pins partial, bare and scoped opts.
- BR-43 — addressed — tasker.lua:219 refuses pid <= 0; tasker_supervision_spec "never signals a record whose pid is 0" drives it against a fake that raises if signalled.
- BR-44 — addressed — tasker.lua:596-598 closes the one-shot timer as it fires; "keeps no deadline handle on a record the kernel holds" pins it.
- BR-45 — addressed — dispatcher.lua:764-770 exports only failure.exit; response_provider.lua:18 and chat_respond.lua:21-28 both read it, and spawn_seam_spec's FIELDS guard fails any read of failure.code/signal/io_error.
- BR-46 — addressed — spawn_seam_spec classifies each out-of-seam spawn from its call form and requires `why` iff open > 0, failing a dead `why` too.
- BR-61 — addressed — dispatcher.lua:883-885 states the two-arg contract and that copilot now forwards it; cliproxy-managed.md:261-263 names the transport_alive precondition; the pre_query guard scans lua/ and tests/.
- BR-64 — addressed — The plan now carries a per-hunk mutation ledger (five rows), and each named case exists in response_topic_spec.lua:90-115.
- BR-80 — not-addressed — The issue Log at lines 914-917 still reads BR-73 for the one() helper (ledger BR-72), BR-74 for the outcome set (ledger BR-73), and BR-70/72 for the exemption (ledger BR-70/74).
- BR-81 — not-addressed — The routing exists at generation_runner.lua:158-166, but reverting it in a worktree leaves chat_refusal_spec 17/17, refusal_spec 15/15, refusal_vocabulary_spec 6/6, generation_settles_spec 19/19, chat_respond_spec 42/42 and batch_lifecycle_spec 8/8 all green; the only specs that observe it are the two it now breaks. No test fails without the fix.
- BR-82 — addressed — The guard keys on the call, not its first token; planting _parley.logger.warning(x) with a variable argument in chat_respond.lua turns "routes every user notice in the submit path through refuse" red (reproduced).
- BR-83 — addressed — M._lifecycle_cause and result.refusal are both deleted, and single_source_sweeps_spec now fails any "-- test seam" export with no reader.
- BR-84 — not-addressed — refusal.brief exists and all six sites route through it, but grep over tests/ finds zero references to brief (or is_token); the crash the finding named — debug.traceback("") with its leading newline — is pinned by nothing.
- BR-85 — not-addressed — The wording is shared now, but the wrapper reuses the `start` kind and passes the command name as `notice`, so ExchangeCut in a headerless buffer reads "Response not started: the chat has no header; edit: restore the chat's header, then submit again — ExchangeCut" (rendered). No refuse() kind was added and no test covers the four commands.
- BR-86 — not-addressed — The not_chat check is in place at chat_respond.lua:56-60, but reverting it to the old two-condition form leaves chat_refusal_spec 17/17 green (verified); the close case uses an unloaded buffer, which both versions treat the same. No test enters the reused-number branch.
- BR-87 — addressed — tests/minimal_init.vim:50-56 deletes the directory on VimLeavePre beside its creation; after a full run the HEAD tree left one directory out of ~380 spec processes, from the spec that died abnormally.

### Raised

- **BR-88** [Critical] `seam-change-collateral` The close commit's `failure`-routing change reddens two specs at HEAD, and nothing fails without it
  This is the 10th finding in family `seam-change-collateral`. Do NOT fix the two
  assertions alone. generation_runner.lua:158-166 changed what the `failure` field
  may hold; the sweep covered production producers but not the readers of that
  field in tests/. Measured at HEAD: cliproxy_caller_teardown_spec.lua:161 expects
  'test abort' and gets nil; response_session_spec.lua:186 expects 'forced
  preparation failure' and gets nil. Both pass at 6b8c7164, and both go green again
  when only the is_token/brief lines are reverted — while chat_refusal_spec 17/17,
  refusal_spec 15/15, refusal_vocabulary_spec 6/6, generation_settles_spec 19/19,
  chat_respond_spec 42/42 and batch_lifecycle_spec 8/8 stay green either way. The
  rule: a change to what a STORED field may hold enumerates every reader of that
  field, production and spec alike, and the round that lands it adds the case that
  goes red when the guard is removed. Move the two assertions to
  `generation.diagnosis` and add that case.
- **BR-89** [Important] `enumeration-claims-completeness` The plan's new counterfactual table trips the repo's own Core-concepts symbol guard, so tests/arch/single_source_sweeps_spec.lua is red at HEAD
  This is the 14th finding in family `enumeration-claims-completeness`. Do NOT just
  rename the cell. single_source_sweeps_spec.lua:282 selects rows by shape
  (`^| \``) rather than by the table they belong to, so the mutation-ledger row at
  plan:2700 — `| \`issue\` keeps free text in \`failure\` | the reload cases in
  \`chat_refusal_spec\` |` — is judged a Core-concepts row and its spec name is
  demanded as a symbol definition. The guard passed at 6b8c7164 and fails at HEAD.
  Either scope the row matcher to Core-concepts tables (the property that defines
  the class) or write the cell as a path so the existing module-strip applies.
- **BR-90** [Important] `seam-change-collateral` `logger.warning(Refusal.describe(...))` forwards the resolution string into the `sensitive` parameter, so the attachment notice is logged as REDACTED
  This is the 11th finding in family `seam-change-collateral`. Do NOT fix only this
  line. `describe` gained a second return value in M5 round 3; chat_respond.lua:448
  calls it as the last argument of logger.warning(msg, sensitive), so "keyed" lands
  in `sensitive` and logger.lua:73-86 writes "[SENSITIVE DATA] REDACTED" to the log
  and keeps the line out of _log_history (reproduced; the parenthesised form logs
  correctly). The channel guard added in the same commit explicitly blesses the
  form `^Refusal%.describe%(` as routed, so it cannot see this. The rule: a
  multi-return function is never called directly as another call's last argument —
  assign it, or parenthesise it — and the channel guard should require the
  parenthesised/assigned form rather than the bare call. Same line: the kind is
  `start`, but the response does start (only images are dropped), so the user reads
  "Response not started: … no images were sent".
- **BR-91** [Minor] `comment-outlives-its-behavior` chat_respond.lua:48-50 duplicates the comment paragraph at :44-47, including its "One statement of it" clause
  Introduced by ba79d86f: the new paragraph was appended rather than replacing the
  old one, so the same two sentences appear twice above lifecycle_cause, the second
  copy differing only in "a chat still loaded by then". Delete :48-50.

## Open findings

- **BR-34** [Minor] `canonical-form-not-shared` buffer_for's private key() adds an 11th copy of the resolve(fnamemodify(x,':p')) path-canonicalisation idiom
- **BR-80** [Minor] `plan-tracking-not-updated` Round 2's dispositions are recorded one finding id off the ledger in both the issue Log and the plan
- **BR-81** [Important] `enumeration-claims-completeness` `failure` still carries free text on three producers, so a cliproxy start failure and every `fault` reach the user as "unexpected (...)"
- **BR-84** [Minor] `canonical-form-not-shared` Six hand-written variants of "first line of a Lua error", three of which throw on an empty message
- **BR-85** [Minor] `canonical-form-not-shared` init.lua's chat_context wrapper still hand-words "not a chat" and the missing header for four commands
- **BR-86** [Minor] `untrusted-input-unparsed` lifecycle_cause maps detach to reload on a buffer number alone, and buffer numbers are reused after :bd
- **BR-88** [Critical] `seam-change-collateral` The close commit's `failure`-routing change reddens two specs at HEAD, and nothing fails without it
- **BR-89** [Important] `enumeration-claims-completeness` The plan's new counterfactual table trips the repo's own Core-concepts symbol guard, so tests/arch/single_source_sweeps_spec.lua is red at HEAD
- **BR-90** [Important] `seam-change-collateral` `logger.warning(Refusal.describe(...))` forwards the resolution string into the `sensitive` parameter, so the attachment notice is logged as REDACTED
- **BR-91** [Minor] `comment-outlives-its-behavior` chat_respond.lua:48-50 duplicates the comment paragraph at :44-47, including its "One statement of it" clause
