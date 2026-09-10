---
gate: boundary-review
issue: 224
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-09T12:07:24-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Critical
          title: resolve_chat_path returns a same-timestamp file instead of the readable file the reference names
          detail: |-
            lua/parley/init.lua:3297 globs only base_dir plus the chat roots, so a
            reference whose own directory is neither (absolute, ~/, or ../relative)
            never produces an exact-basename candidate and loses to an unrelated
            same-timestamp file in a chat root. Reproduced: an existing
            archive/TS.md referenced by absolute path resolves to
            chats/TS_live-topic.md. The existence loop at :3336 is unreachable
            because ordered[1] is already truthy. Verified fix, suite stays green:
            seed search_dirs with vim.fn.fnamemodify(candidates[1], ":h").
          family: prefix-identity-scope
          round: 1
        - id: BR-2
          severity: Important
          title: Three claims of test coverage have no test behind them
          detail: |-
            Verified by mutation. (1) Plan row 6 claims a <M-t> tree test; none
            exists, and reverting outline.lua:227/270/274 to the naive resolver
            fails only the arch guard. (2)
            tests/integration/ancestor_chain_rename_spec.lua:99 never renames the
            child, so reverting chat_respond.lua:213 fails only the arch guard and
            Done-when row 2 is unasserted. (3) atlas/chat/lifecycle.md:55 says
            "five guards, each with its own test"; deleting the insert-mode guard
            at init.lua:3142 breaks nothing.
          family: claimed-test-not-pinned
          round: 1
        - id: BR-3
          severity: Important
          title: repair_reference_at_cursor writes the buffer directly instead of through buffer_edit
          detail: |-
            lua/parley/init.lua:3189 calls vim.api.nvim_buf_set_lines in a file that
            sits on tests/arch/buffer_mutation_spec.lua's deliberately shrinking #90
            baseline allowlist. buffer_edit.replace_line_at(buf, line_0_indexed,
            text) is exactly this operation and is the declared final home.
          family: buffer-edit-seam
          round: 1
        - id: BR-4
          severity: Minor
          title: outline.lua resolves the same branch.path twice, now two globs per branch
          detail: |-
            lua/parley/outline.lua:270 and :274 resolve the same input when
            topic == ""; each is a glob per chat root since the resolver stopped
            short-circuiting on an exact hit. Hoist to one local above the if.
          family: redundant-resolution
          round: 1
        - id: BR-5
          severity: Minor
          title: The CursorHold callback pcalls repair and discards the error unlogged
          detail: |-
            lua/parley/init.lua:1100. A failure inside repair_reference_at_cursor is
            invisible forever; log at debug on the false branch.
          family: silent-error-swallow
          round: 1
        - id: BR-6
          severity: Minor
          title: The new dir-dedup key hand-rolls resolve_dir_key and evades the one-normalizer guard
          detail: |-
            lua/parley/init.lua:3298 spells it vim.fn.resolve(fnamemodify(d, ":p")):gsub("/+$", "")
            while resolve_dir_key (init.lua:68) is the canonical form;
            buffer_mutation_spec's "one normalizer" assertion greps the literal
            resolve(expand( spelling and so cannot see it. The dedup is also
            redundant with the per-match `seen` table two loops below.
          family: guard-must-match-class
          round: 1
        - id: BR-7
          severity: Minor
          title: The same-timestamp ambiguity warning fires on every resolve
          detail: |-
            lua/parley/init.lua:3319. The highlighter re-resolves visible branch
            lines every 500ms and the outline walk re-resolves per branch, so one
            colliding reference emits unboundedly. Once-per-reference or debug level.
          family: unbounded-log-emission
          round: 1
        - id: BR-8
          severity: Minor
          title: The insert/replace-mode guard cannot fire from its only trigger
          detail: |-
            lua/parley/init.lua:3142. CursorHold does not fire in insert mode
            (CursorHoldI does), so the branch is dead in production and untested.
            Drop it or document it as defence for direct API callers.
          family: unreachable-guard
          round: 1
        - id: BR-9
          severity: Minor
          title: not_chat's full-buffer read runs before the cheap line test the docstring credits
          detail: |-
            lua/parley/init.lua:3139 reads the whole buffer via nvim_buf_get_lines
            before the reference-present string test at :3155. Measured 0.17 ms on a
            5000-line chat against a >=4s updatetime, so immaterial — but the cheap
            test is the natural first guard and is what the envelope describes.
          family: guard-ordering
          round: 1
        - id: BR-10
          severity: Minor
          title: exporter.lua keeps a local resolver shadow the new guard cannot see
          detail: |-
            lua/parley/exporter.lua:32 defines `local function resolve_chat_path`.
            single_resolver_spec forbids only the name `resolve_path`. Not a hole
            today (a hand-rolled naive join there is caught by untrusted_path_spec),
            but it is the shape just removed from three other modules.
          family: single-resolver-rule
          round: 1
        - id: BR-11
          severity: Minor
          title: README not updated for the cursor-hold repair behavior
          detail: |-
            Resting the cursor on a stale branch reference now marks the buffer
            modified, and responsiveness depends on the user's updatetime. Worth a
            line near the existing <M-o> / branch-reference documentation.
          family: docs-user-surface
          round: 1
        - id: BR-12
          severity: Minor
          title: single_resolver_spec re-derives file enumeration and line reading
          detail: |-
            tests/arch/single_resolver_spec.lua:15-25 duplicates what
            tests/arch/arch_helper.lua already does. Function-scoped allowlisting is
            genuinely new; it belongs in the helper so the next guard reuses it.
          family: arch-helper-reuse
          round: 1
        - id: BR-13
          severity: Minor
          title: A filesystem-derived basename is written into the buffer unvalidated
          detail: |-
            lua/parley/init.lua:3189. A filename containing a newline makes
            nvim_buf_set_lines raise — swallowed by the autocmd pcall, propagated
            for direct callers. An explicit newline check would fail visibly.
          family: untrusted-input-writeback
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-09-09T12:31:08-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: Verified by mutation — reverting {base_dir, ref_dir} to {base_dir} fails ancestor_chain_rename_spec's out-of-roots arm; see new finding for the unswept remainder of the class.
          round: 2
        - id: BR-2
          disposition: addressed
          note: 'All three verified by mutation: naive find_tree_root fails the new <M-t> arm, naive chat_respond:213 fails the branch_after arm, deleting the insert-mode guard fails read_repair_spec.'
          round: 2
        - id: BR-3
          disposition: addressed
          note: buffer_edit.replace_line_at now used at init.lua:3190; static property, unpinnable while buffer_mutation_spec allowlists init.lua wholesale.
          round: 2
        - id: BR-4
          disposition: addressed
          note: outline.lua:271 resolves once into child_abs above the topic branch.
          round: 2
        - id: BR-5
          disposition: not-addressed
          note: init.lua:1099 still pcalls and discards; a failure inside repair stays invisible.
          round: 2
        - id: BR-6
          disposition: not-addressed
          note: init.lua:3313 still spells the dir key by hand instead of resolve_dir_key.
          round: 2
        - id: BR-7
          disposition: not-addressed
          note: init.lua:3334 still warns on every resolve; the warning branch also never executes in the suite.
          round: 2
        - id: BR-8
          disposition: not-addressed
          note: The guard gained a test (mocked nvim_get_mode) but is still unreachable from CursorHold in production and the docstring still frames it as protecting the cursor path.
          round: 2
        - id: BR-9
          disposition: not-addressed
          note: not_chat's full-buffer read still precedes the cheap reference test at init.lua:3155.
          round: 2
        - id: BR-10
          disposition: not-addressed
          note: exporter.lua:32 still defines local function resolve_chat_path; the guard greps only the name resolve_path.
          round: 2
        - id: BR-11
          disposition: not-addressed
          note: README.md unchanged in the window; the branch-reference section at README.md:170-190 is the natural home.
          round: 2
        - id: BR-12
          disposition: not-addressed
          note: single_resolver_spec:15-25 still re-derives repo_lua_files/lines_of rather than extending arch_helper.
          round: 2
        - id: BR-13
          disposition: not-addressed
          note: No newline check before the filesystem-derived basename is written into the buffer.
          round: 2
      findings:
        - id: BR-14
          severity: Important
          title: The glob set covers only candidates[1]'s directory, so an existing exact target still loses silently
          detail: |-
            2nd finding in this family — do NOT fix this instance. The rule is that
            every directory _resolve_chat_path_candidates can point into must be in
            the glob set; derive search_dirs from the candidate list instead of
            naming base_dir and candidates[1] by hand. Reproduced at HEAD with two
            roots: resolve_chat_path("sub/<ts>.md", root1) returns
            root1/<ts>_unrelated.md while root2/sub/<ts>.md exists and is named by
            the reference. No warning fires, because a single non-exact match sets
            ambiguous=false — a single glob hit is not evidence of staleness.
          family: prefix-identity-scope
          round: 2
        - id: BR-15
          severity: Important
          title: Deleting the exact-hit short-circuit made every pre-existing consumer's resolve O(chat-root size)
          detail: |-
            Measured base 6425abc vs HEAD on an exact-name hit: 0.026->0.209 ms at
            1 root x 100 files, 0.033->2.486 ms at 1x2000, 0.041->7.685 ms at
            3x2000 (~1.2 us per file scanned). Paid per tree node and per branch by
            find_tree_root_file / collect_tree_files / outline.build_file_outline_items
            (<M-t>, delete_chat_tree, ChatMove), per branch of every ancestor by
            chat_respond.lua:213, and per visible branch line by the highlighter's
            500 ms topic refresh. The issue's ARCH-CONSTRAINTS block budgets only
            the CursorHold path. Bound it (memoize safe_glob per (dir, pattern) for
            the duration of a walk) or declare it.
          family: undeclared-envelope-change
          round: 2
        - id: BR-16
          severity: Important
          title: Nothing drives the CursorHold autocmd — the feature's only production entry point
          detail: |-
            2nd finding in this family — do NOT fix this instance. The rule: a test
            must enter through the path production enters through, the trigger and
            not just the function behind it. All nine read_repair_spec arms call
            repair_reference_at_cursor directly, so the autocmd's event, its "*.md"
            pattern and its ev.buf / nvim_win_get_cursor(0) pairing are unpinned. I
            confirmed by hand (doautocmd CursorHold) that it works today, so this is
            regression exposure, not a shipped bug; one arm closes it.
          family: claimed-test-not-pinned
          round: 2
        - id: BR-17
          severity: Minor
          title: Atlas and the arch spec both say six modules had a local resolve_path; there were three
          detail: |-
            atlas/chat/lifecycle.md:32 and tests/arch/single_resolver_spec.lua:74-77
            state "six modules ... two exact-match-only, three delegated, one
            correct". At base 6425abc there were exactly three definitions
            (chat_respond.lua:176, highlighter.lua:65, outline.lua:208) — two naive,
            one correct. "Six" is the Spec's count of call sites transcribed as
            modules; the 2+3+1 breakdown double-counts.
          family: doc-claim-unverified
          round: 2
      blocked: true
    - "n": 3
      timestamp: "2026-09-09T13:07:20-07:00"
      agent: claude
      dispose:
        - id: BR-5
          disposition: not-addressed
          note: init.lua:1104 still pcalls and discards; no debug log on the false branch.
          round: 3
        - id: BR-6
          disposition: not-addressed
          note: init.lua:3343 still spells the key by hand; buffer_mutation_spec.lua:97 greps the literal resolve(vim.fn.expand form and cannot see it.
          round: 3
        - id: BR-7
          disposition: not-addressed
          note: M.logger.warning still fires inside resolve_chat_path on every ambiguous resolve.
          round: 3
        - id: BR-8
          disposition: not-addressed
          note: The insert/replace guard is unchanged and still unreachable from CursorHold; its test reaches it only by stubbing nvim_get_mode.
          round: 3
        - id: BR-9
          disposition: not-addressed
          note: not_chat's full-buffer read still precedes the reference string test.
          round: 3
        - id: BR-10
          disposition: not-addressed
          note: exporter.lua:32 still defines a local resolve_chat_path wrapper the guard's name rule does not cover.
          round: 3
        - id: BR-11
          disposition: not-addressed
          note: README has nothing on cursor-hold repair; under this round's docs gate this is the Important-class gap, and it is one line.
          round: 3
        - id: BR-12
          disposition: not-addressed
          note: single_resolver_spec.lua:15-25 still re-derives what arch_helper.lua already provides.
          round: 3
        - id: BR-13
          disposition: not-addressed
          note: No newline check before replace_line_at; a filesystem basename still reaches the buffer unvalidated.
          round: 3
        - id: BR-14
          disposition: addressed
          note: 'Mutation-verified: reverting dirs to candidates[1] alone reddens the sub/-under-a-second-root arm.'
          round: 3
        - id: BR-15
          disposition: addressed
          note: 'Re-measured base vs HEAD on an exact hit at 1 root x 2000 files: 0.031 ms vs 0.039 ms (2.43 ms without the short-circuit).'
          round: 3
        - id: BR-16
          disposition: addressed
          note: 'Mutation-verified: changing the autocmd pattern to *.txt reddens the CursorHold arm.'
          round: 3
        - id: BR-17
          disposition: not-addressed
          note: 'Counted at base 6425abc: three local resolve_path definitions, not six. Atlas and the spec comment both still say six.'
          round: 3
      findings:
        - id: BR-18
          severity: Minor
          title: The second existence loop in resolve_chat_path is dead code the docstring still credits
          detail: |-
            This is the 2nd finding in family `unreachable-guard` (BR-8 is the 1st, still
            open). Do NOT fix this instance. The rule that covers both: a branch is only
            allowed to exist if you can name an input that reaches it, and a fix that
            re-introduces an earlier guard (BR-15's short-circuit) must be checked for
            branches it has just made unreachable. The enumeration for this diff is two:
            the insert/replace-mode guard at init.lua:3143, unreachable because CursorHold
            does not fire in insert mode; and the existence loop at init.lua:3385, byte-
            identical to the short-circuit at init.lua:3305 over the same `candidates`
            with nothing between them that touches the list or the filesystem. Confirmed
            by replacing the loop body with error() — read_repair, ancestor_chain_rename,
            chat_respond, not_chat and resolve_candidates all stayed green. The docstring
            at init.lua:3277 still describes it as the non-chat-filename fallback, which
            is now what the short-circuit does.
          family: unreachable-guard
          round: 3
        - id: BR-19
          severity: Minor
          title: The stale-reference path now globs every search dir instead of stopping at the first hit
          detail: |-
            This is the 2nd finding in family `undeclared-envelope-change` (BR-15 is the
            1st). Do NOT fix this instance. The rule: when a resolver's control flow
            changes, every path through it whose cost class moved must be measured and
            declared, not only the one the previous finding named. BR-15 measured and
            restored the exact-hit path; the stale path was not measured. Base returned as
            soon as one directory yielded a verified match; HEAD globs all of search_dirs
            before calling resolve_candidates, so the extra globs buy only BR-7's
            ambiguity warning. Measured base 6425abc vs HEAD, reference whose target was
            renamed: 2.536 -> 7.223 ms at 3 roots x 2000 files (2.8x); 0.192 -> 0.297 ms
            at the operator's actual 116+28 files. Immaterial at real scale today, but it
            is the case this issue exists for, and the highlighter re-resolves it per
            visible branch line every 500 ms. The issue's ARCH-CONSTRAINTS block budgets
            only the CursorHold path.
          family: undeclared-envelope-change
          round: 3
      blocked: false
---

# Gate ledger — parley.nvim#224 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-09T12:07:24-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Critical] `prefix-identity-scope` resolve_chat_path returns a same-timestamp file instead of the readable file the reference names
  lua/parley/init.lua:3297 globs only base_dir plus the chat roots, so a
  reference whose own directory is neither (absolute, ~/, or ../relative)
  never produces an exact-basename candidate and loses to an unrelated
  same-timestamp file in a chat root. Reproduced: an existing
  archive/TS.md referenced by absolute path resolves to
  chats/TS_live-topic.md. The existence loop at :3336 is unreachable
  because ordered[1] is already truthy. Verified fix, suite stays green:
  seed search_dirs with vim.fn.fnamemodify(candidates[1], ":h").
- **BR-2** [Important] `claimed-test-not-pinned` Three claims of test coverage have no test behind them
  Verified by mutation. (1) Plan row 6 claims a <M-t> tree test; none
  exists, and reverting outline.lua:227/270/274 to the naive resolver
  fails only the arch guard. (2)
  tests/integration/ancestor_chain_rename_spec.lua:99 never renames the
  child, so reverting chat_respond.lua:213 fails only the arch guard and
  Done-when row 2 is unasserted. (3) atlas/chat/lifecycle.md:55 says
  "five guards, each with its own test"; deleting the insert-mode guard
  at init.lua:3142 breaks nothing.
- **BR-3** [Important] `buffer-edit-seam` repair_reference_at_cursor writes the buffer directly instead of through buffer_edit
  lua/parley/init.lua:3189 calls vim.api.nvim_buf_set_lines in a file that
  sits on tests/arch/buffer_mutation_spec.lua's deliberately shrinking #90
  baseline allowlist. buffer_edit.replace_line_at(buf, line_0_indexed,
  text) is exactly this operation and is the declared final home.
- **BR-4** [Minor] `redundant-resolution` outline.lua resolves the same branch.path twice, now two globs per branch
  lua/parley/outline.lua:270 and :274 resolve the same input when
  topic == ""; each is a glob per chat root since the resolver stopped
  short-circuiting on an exact hit. Hoist to one local above the if.
- **BR-5** [Minor] `silent-error-swallow` The CursorHold callback pcalls repair and discards the error unlogged
  lua/parley/init.lua:1100. A failure inside repair_reference_at_cursor is
  invisible forever; log at debug on the false branch.
- **BR-6** [Minor] `guard-must-match-class` The new dir-dedup key hand-rolls resolve_dir_key and evades the one-normalizer guard
  lua/parley/init.lua:3298 spells it vim.fn.resolve(fnamemodify(d, ":p")):gsub("/+$", "")
  while resolve_dir_key (init.lua:68) is the canonical form;
  buffer_mutation_spec's "one normalizer" assertion greps the literal
  resolve(expand( spelling and so cannot see it. The dedup is also
  redundant with the per-match `seen` table two loops below.
- **BR-7** [Minor] `unbounded-log-emission` The same-timestamp ambiguity warning fires on every resolve
  lua/parley/init.lua:3319. The highlighter re-resolves visible branch
  lines every 500ms and the outline walk re-resolves per branch, so one
  colliding reference emits unboundedly. Once-per-reference or debug level.
- **BR-8** [Minor] `unreachable-guard` The insert/replace-mode guard cannot fire from its only trigger
  lua/parley/init.lua:3142. CursorHold does not fire in insert mode
  (CursorHoldI does), so the branch is dead in production and untested.
  Drop it or document it as defence for direct API callers.
- **BR-9** [Minor] `guard-ordering` not_chat's full-buffer read runs before the cheap line test the docstring credits
  lua/parley/init.lua:3139 reads the whole buffer via nvim_buf_get_lines
  before the reference-present string test at :3155. Measured 0.17 ms on a
  5000-line chat against a >=4s updatetime, so immaterial — but the cheap
  test is the natural first guard and is what the envelope describes.
- **BR-10** [Minor] `single-resolver-rule` exporter.lua keeps a local resolver shadow the new guard cannot see
  lua/parley/exporter.lua:32 defines `local function resolve_chat_path`.
  single_resolver_spec forbids only the name `resolve_path`. Not a hole
  today (a hand-rolled naive join there is caught by untrusted_path_spec),
  but it is the shape just removed from three other modules.
- **BR-11** [Minor] `docs-user-surface` README not updated for the cursor-hold repair behavior
  Resting the cursor on a stale branch reference now marks the buffer
  modified, and responsiveness depends on the user's updatetime. Worth a
  line near the existing <M-o> / branch-reference documentation.
- **BR-12** [Minor] `arch-helper-reuse` single_resolver_spec re-derives file enumeration and line reading
  tests/arch/single_resolver_spec.lua:15-25 duplicates what
  tests/arch/arch_helper.lua already does. Function-scoped allowlisting is
  genuinely new; it belongs in the helper so the next guard reuses it.
- **BR-13** [Minor] `untrusted-input-writeback` A filesystem-derived basename is written into the buffer unvalidated
  lua/parley/init.lua:3189. A filename containing a newline makes
  nvim_buf_set_lines raise — swallowed by the autocmd pcall, propagated
  for direct callers. An explicit newline check would fail visibly.

## Round 2 — 2026-09-09T12:31:08-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — addressed — Verified by mutation — reverting {base_dir, ref_dir} to {base_dir} fails ancestor_chain_rename_spec's out-of-roots arm; see new finding for the unswept remainder of the class.
- BR-2 — addressed — All three verified by mutation: naive find_tree_root fails the new <M-t> arm, naive chat_respond:213 fails the branch_after arm, deleting the insert-mode guard fails read_repair_spec.
- BR-3 — addressed — buffer_edit.replace_line_at now used at init.lua:3190; static property, unpinnable while buffer_mutation_spec allowlists init.lua wholesale.
- BR-4 — addressed — outline.lua:271 resolves once into child_abs above the topic branch.
- BR-5 — not-addressed — init.lua:1099 still pcalls and discards; a failure inside repair stays invisible.
- BR-6 — not-addressed — init.lua:3313 still spells the dir key by hand instead of resolve_dir_key.
- BR-7 — not-addressed — init.lua:3334 still warns on every resolve; the warning branch also never executes in the suite.
- BR-8 — not-addressed — The guard gained a test (mocked nvim_get_mode) but is still unreachable from CursorHold in production and the docstring still frames it as protecting the cursor path.
- BR-9 — not-addressed — not_chat's full-buffer read still precedes the cheap reference test at init.lua:3155.
- BR-10 — not-addressed — exporter.lua:32 still defines local function resolve_chat_path; the guard greps only the name resolve_path.
- BR-11 — not-addressed — README.md unchanged in the window; the branch-reference section at README.md:170-190 is the natural home.
- BR-12 — not-addressed — single_resolver_spec:15-25 still re-derives repo_lua_files/lines_of rather than extending arch_helper.
- BR-13 — not-addressed — No newline check before the filesystem-derived basename is written into the buffer.

### Raised

- **BR-14** [Important] `prefix-identity-scope` The glob set covers only candidates[1]'s directory, so an existing exact target still loses silently
  2nd finding in this family — do NOT fix this instance. The rule is that
  every directory _resolve_chat_path_candidates can point into must be in
  the glob set; derive search_dirs from the candidate list instead of
  naming base_dir and candidates[1] by hand. Reproduced at HEAD with two
  roots: resolve_chat_path("sub/<ts>.md", root1) returns
  root1/<ts>_unrelated.md while root2/sub/<ts>.md exists and is named by
  the reference. No warning fires, because a single non-exact match sets
  ambiguous=false — a single glob hit is not evidence of staleness.
- **BR-15** [Important] `undeclared-envelope-change` Deleting the exact-hit short-circuit made every pre-existing consumer's resolve O(chat-root size)
  Measured base 6425abc vs HEAD on an exact-name hit: 0.026->0.209 ms at
  1 root x 100 files, 0.033->2.486 ms at 1x2000, 0.041->7.685 ms at
  3x2000 (~1.2 us per file scanned). Paid per tree node and per branch by
  find_tree_root_file / collect_tree_files / outline.build_file_outline_items
  (<M-t>, delete_chat_tree, ChatMove), per branch of every ancestor by
  chat_respond.lua:213, and per visible branch line by the highlighter's
  500 ms topic refresh. The issue's ARCH-CONSTRAINTS block budgets only
  the CursorHold path. Bound it (memoize safe_glob per (dir, pattern) for
  the duration of a walk) or declare it.
- **BR-16** [Important] `claimed-test-not-pinned` Nothing drives the CursorHold autocmd — the feature's only production entry point
  2nd finding in this family — do NOT fix this instance. The rule: a test
  must enter through the path production enters through, the trigger and
  not just the function behind it. All nine read_repair_spec arms call
  repair_reference_at_cursor directly, so the autocmd's event, its "*.md"
  pattern and its ev.buf / nvim_win_get_cursor(0) pairing are unpinned. I
  confirmed by hand (doautocmd CursorHold) that it works today, so this is
  regression exposure, not a shipped bug; one arm closes it.
- **BR-17** [Minor] `doc-claim-unverified` Atlas and the arch spec both say six modules had a local resolve_path; there were three
  atlas/chat/lifecycle.md:32 and tests/arch/single_resolver_spec.lua:74-77
  state "six modules ... two exact-match-only, three delegated, one
  correct". At base 6425abc there were exactly three definitions
  (chat_respond.lua:176, highlighter.lua:65, outline.lua:208) — two naive,
  one correct. "Six" is the Spec's count of call sites transcribed as
  modules; the 2+3+1 breakdown double-counts.

## Round 3 — 2026-09-09T13:07:20-07:00 (claude) — passed

### Disposed

- BR-5 — not-addressed — init.lua:1104 still pcalls and discards; no debug log on the false branch.
- BR-6 — not-addressed — init.lua:3343 still spells the key by hand; buffer_mutation_spec.lua:97 greps the literal resolve(vim.fn.expand form and cannot see it.
- BR-7 — not-addressed — M.logger.warning still fires inside resolve_chat_path on every ambiguous resolve.
- BR-8 — not-addressed — The insert/replace guard is unchanged and still unreachable from CursorHold; its test reaches it only by stubbing nvim_get_mode.
- BR-9 — not-addressed — not_chat's full-buffer read still precedes the reference string test.
- BR-10 — not-addressed — exporter.lua:32 still defines a local resolve_chat_path wrapper the guard's name rule does not cover.
- BR-11 — not-addressed — README has nothing on cursor-hold repair; under this round's docs gate this is the Important-class gap, and it is one line.
- BR-12 — not-addressed — single_resolver_spec.lua:15-25 still re-derives what arch_helper.lua already provides.
- BR-13 — not-addressed — No newline check before replace_line_at; a filesystem basename still reaches the buffer unvalidated.
- BR-14 — addressed — Mutation-verified: reverting dirs to candidates[1] alone reddens the sub/-under-a-second-root arm.
- BR-15 — addressed — Re-measured base vs HEAD on an exact hit at 1 root x 2000 files: 0.031 ms vs 0.039 ms (2.43 ms without the short-circuit).
- BR-16 — addressed — Mutation-verified: changing the autocmd pattern to *.txt reddens the CursorHold arm.
- BR-17 — not-addressed — Counted at base 6425abc: three local resolve_path definitions, not six. Atlas and the spec comment both still say six.

### Raised

- **BR-18** [Minor] `unreachable-guard` The second existence loop in resolve_chat_path is dead code the docstring still credits
  This is the 2nd finding in family `unreachable-guard` (BR-8 is the 1st, still
  open). Do NOT fix this instance. The rule that covers both: a branch is only
  allowed to exist if you can name an input that reaches it, and a fix that
  re-introduces an earlier guard (BR-15's short-circuit) must be checked for
  branches it has just made unreachable. The enumeration for this diff is two:
  the insert/replace-mode guard at init.lua:3143, unreachable because CursorHold
  does not fire in insert mode; and the existence loop at init.lua:3385, byte-
  identical to the short-circuit at init.lua:3305 over the same `candidates`
  with nothing between them that touches the list or the filesystem. Confirmed
  by replacing the loop body with error() — read_repair, ancestor_chain_rename,
  chat_respond, not_chat and resolve_candidates all stayed green. The docstring
  at init.lua:3277 still describes it as the non-chat-filename fallback, which
  is now what the short-circuit does.
- **BR-19** [Minor] `undeclared-envelope-change` The stale-reference path now globs every search dir instead of stopping at the first hit
  This is the 2nd finding in family `undeclared-envelope-change` (BR-15 is the
  1st). Do NOT fix this instance. The rule: when a resolver's control flow
  changes, every path through it whose cost class moved must be measured and
  declared, not only the one the previous finding named. BR-15 measured and
  restored the exact-hit path; the stale path was not measured. Base returned as
  soon as one directory yielded a verified match; HEAD globs all of search_dirs
  before calling resolve_candidates, so the extra globs buy only BR-7's
  ambiguity warning. Measured base 6425abc vs HEAD, reference whose target was
  renamed: 2.536 -> 7.223 ms at 3 roots x 2000 files (2.8x); 0.192 -> 0.297 ms
  at the operator's actual 116+28 files. Immaterial at real scale today, but it
  is the case this issue exists for, and the highlighter re-resolves it per
  visible branch line every 500 ms. The issue's ARCH-CONSTRAINTS block budgets
  only the CursorHold path.

## Open findings

- **BR-5** [Minor] `silent-error-swallow` The CursorHold callback pcalls repair and discards the error unlogged
- **BR-6** [Minor] `guard-must-match-class` The new dir-dedup key hand-rolls resolve_dir_key and evades the one-normalizer guard
- **BR-7** [Minor] `unbounded-log-emission` The same-timestamp ambiguity warning fires on every resolve
- **BR-8** [Minor] `unreachable-guard` The insert/replace-mode guard cannot fire from its only trigger
- **BR-9** [Minor] `guard-ordering` not_chat's full-buffer read runs before the cheap line test the docstring credits
- **BR-10** [Minor] `single-resolver-rule` exporter.lua keeps a local resolver shadow the new guard cannot see
- **BR-11** [Minor] `docs-user-surface` README not updated for the cursor-hold repair behavior
- **BR-12** [Minor] `arch-helper-reuse` single_resolver_spec re-derives file enumeration and line reading
- **BR-13** [Minor] `untrusted-input-writeback` A filesystem-derived basename is written into the buffer unvalidated
- **BR-17** [Minor] `doc-claim-unverified` Atlas and the arch spec both say six modules had a local resolve_path; there were three
- **BR-18** [Minor] `unreachable-guard` The second existence loop in resolve_chat_path is dead code the docstring still credits
- **BR-19** [Minor] `undeclared-envelope-change` The stale-reference path now globs every search dir instead of stopping at the first hit
