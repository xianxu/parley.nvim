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

## Open findings

- **BR-1** [Critical] `prefix-identity-scope` resolve_chat_path returns a same-timestamp file instead of the readable file the reference names
- **BR-2** [Important] `claimed-test-not-pinned` Three claims of test coverage have no test behind them
- **BR-3** [Important] `buffer-edit-seam` repair_reference_at_cursor writes the buffer directly instead of through buffer_edit
- **BR-4** [Minor] `redundant-resolution` outline.lua resolves the same branch.path twice, now two globs per branch
- **BR-5** [Minor] `silent-error-swallow` The CursorHold callback pcalls repair and discards the error unlogged
- **BR-6** [Minor] `guard-must-match-class` The new dir-dedup key hand-rolls resolve_dir_key and evades the one-normalizer guard
- **BR-7** [Minor] `unbounded-log-emission` The same-timestamp ambiguity warning fires on every resolve
- **BR-8** [Minor] `unreachable-guard` The insert/replace-mode guard cannot fire from its only trigger
- **BR-9** [Minor] `guard-ordering` not_chat's full-buffer read runs before the cheap line test the docstring credits
- **BR-10** [Minor] `single-resolver-rule` exporter.lua keeps a local resolver shadow the new guard cannot see
- **BR-11** [Minor] `docs-user-surface` README not updated for the cursor-hold repair behavior
- **BR-12** [Minor] `arch-helper-reuse` single_resolver_spec re-derives file enumeration and line reading
- **BR-13** [Minor] `untrusted-input-writeback` A filesystem-derived basename is written into the buffer unvalidated
