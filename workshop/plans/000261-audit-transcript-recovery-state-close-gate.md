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

## Open findings

- **BR-20** [Minor] `untrusted-input-unparsed` The copilot token response is typed on token only, while the file read of the same bearer also types expires_at
- **BR-23** [Minor] `seam-change-collateral` Routing table_to_file through the rename-based writer replaces symlinked sidecars, resets permissions, and leaves crash files the query cleanup never deletes
- **BR-24** [Minor] `enumeration-claims-completeness` The sidecar census finds readers by the text state_dir, so file_access.json escapes it, and a wrongly typed entry makes opening a chat raise
- **BR-34** [Minor] `canonical-form-not-shared` buffer_for's private key() adds an 11th copy of the resolve(fnamemodify(x,':p')) path-canonicalisation idiom
- **BR-36** [Minor] `enumeration-claims-completeness` nodiscard_spec only sees calls at the start of a line; three calling forms that drop the result pass green
- **BR-37** [Minor] `allowlist-without-dead-entry-check` nodiscard_spec's DROPPED count is only a ceiling, so a declaration outlives the call it excuses
- **BR-41** [Minor] `seam-change-collateral` generate_topic replaces rather than merges transport_opts, so partial opts lose the deadline and are refused
- **BR-43** [Minor] `untrusted-input-unparsed` target() has no pid == 0 guard, and -0 == 0 would signal Neovim's own process group
- **BR-44** [Minor] `residue-names-no-end` The one-shot deadline timer is closed only by retire, the one path a held record never takes
- **BR-45** [Important] `seam-change-collateral` The dispatcher re-exports code/io_error on its failure table, and both of that table's renderers still drop io_error
- **BR-46** [Important] `enumeration-claims-completeness` The out-of-seam spawn list's per-entry reasons are unchecked prose, and two of eighteen are wrong
