# Boundary Review — parley.nvim#224 (whole-issue close)

| field | value |
|-------|-------|
| issue | 224 — Forked chat loses its parent context after a slug rename |
| repo | parley.nvim |
| issue file | workshop/issues/000224-ancestor-chain-slug-rename.md |
| boundary | whole-issue close |
| milestone | — |
| window | 6425abc72bb87f821802840a69e614e7d1c70606..4cb1cc74cf9e25ff7f22d02bab739cc11333237d |
| command | sdlc close --issue 224 |
| reviewer | claude |
| timestamp | 2026-09-09T12:07:24-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The consolidation is the right shape and the primary defect is genuinely fixed and genuinely pinned — I reverted `chat_respond.lua:193` to the naive resolver in a scratch clone and `ancestor_chain_rename_spec` went red, which is the seen-red the issue promised. The arch guard also goes red on a re-added local resolver, the six `resolve_path` locals are gone, all consumers derive from `resolve_chat_path` (shadow-sweep clean), `_read_repair_reference` is fully removed, and the full suite plus lint is green (0 warnings / 0 errors, 364 files). What blocks SHIP is that deleting the exact-match tier went one step too far: `resolve_chat_path` now globs *before* checking whether the reference names a file that exists, and the glob only covers `base_dir` + the chat roots. A reference naming a readable file in any *other* directory (absolute, `~`, or `../`-relative) now silently resolves to a different, same-timestamp file in a chat root. I reproduced this and confirmed a one-line fix that keeps the whole suite green. Secondarily, three claims of test coverage — two checked Plan rows and one atlas sentence — are not backed by tests; I verified each by mutation.

## 1. Strengths

- **The seen-red is real, not asserted.** Reverting `lua/parley/chat_respond.lua:193` to `helper.resolve_relative_path` fails `tests/integration/ancestor_chain_rename_spec.lua`; reverting `lua/parley/outline.lua`'s three sites fails `tests/arch/single_resolver_spec.lua`. Both mutations are the mistake the guard exists to catch.
- **The guard is over the right term.** `tests/arch/single_resolver_spec.lua:60` scans for `resolve_relative_path` reachability with a per-*function* allowlist (`init.lua:_resolve_chat_path_candidates`), plus a dead-entry test so the allowlist can't rot. The PQ-2 correction (resolution, not joining) landed correctly.
- **`vim.fn.resolve` on the glob result is pinned.** Dropping it (`init.lua:3329`) fails the `branch_after` arm — the `/tmp` vs `/private/tmp` normalization is real coverage, not a comment.
- **`chat_slug.resolve_candidates` / `rewrite_reference` are genuinely PURE** (`lua/parley/chat_slug.lua:107,163`): unit-tested with no filesystem, and the `%`-escape trap has its own test (`tests/unit/rewrite_reference_spec.lua:37`).
- **The trigger is reachable.** I wired a scratch spec that sets the cursor and runs `doautocmd CursorHold` — the line is repaired. The autocmd is not a field set at zero call sites.
- **Atlas is substantive**, not a checkbox: `atlas/chat/lifecycle.md:9-66` states prefix identity, the one-resolver rule and the repair trigger, and `traceability.yaml` maps all four new specs.

## 2. Critical findings

**`lua/parley/init.lua:3297` — glob-first resolution outranks a reference that already names an existing file outside the globbed dirs.**

`search_dirs` is `{ base_dir } ∪ get_chat_dirs()`. For any reference whose own directory is neither — an absolute path, a `~/…` path, or `../archive/…` — the glob searches everywhere *except* where the reference points. `resolve_candidates` then never sees the exact basename, so a same-timestamp file in a chat root wins and the exact, readable target is silently discarded. The existence loop at `:3336` is unreachable in that case because `ordered[1]` is already truthy.

Reproduced (scratch spec, clone at HEAD):

```
archive/2026-09-09.22-00-00.001.md          <- exists, referenced by absolute path
chats/2026-09-09.22-00-00.001_live-topic.md <- unrelated file, same timestamp

resolve_chat_path("<archive>/2026-09-09.22-00-00.001.md", chat_dir)
  → .../chats/2026-09-09.22-00-00.001_live-topic.md   (WRONG FILE)
```

`<M-o>` opens the wrong chat; the ancestor walk submits the wrong chat as parent context — the same silent-wrong-context failure mode this issue exists to remove, from the opposite cause. Reachability is bounded (every auto-written reference is a basename via `fnamemodify(…, ":t")`, so this needs a hand- or model-written path), but transcript references are exactly the input `tests/arch/untrusted_path_spec.lua` treats as untrusted, and the failure is silent rather than not-found.

Fix (verified — makes a new absolute-reference test pass and leaves the entire suite green):

```lua
for _, d in ipairs(vim.list_extend(
        { base_dir, vim.fn.fnamemodify(candidates[1], ":h") },
        M.get_chat_dirs() or {})) do
```

This keeps the one-rule design intact — the reference's own directory joins the glob set, so an exact hit wins through `resolve_candidates` exactly as the Spec argues it should — rather than reintroducing the tier the Spec deliberately deleted. Add a regression test for the absolute/out-of-root reference.

## 3. Important findings

**A. Three claims of test coverage are not backed by a test (verified by mutation).**

- `workshop/issues/000224-…md` Plan row 6 — "*Test the `<M-t>` tree: a renamed parent must not make the CHILD the tree root*" — is checked, but no such test exists. Reverting all three `outline.lua` call sites (`:227`, `:270`, `:274`) to the naive resolver fails **only** `single_resolver_spec`; no behavioral test notices. The Spec calls this site "**verified**" as a live defect, so its fix has no regression test.
- `tests/integration/ancestor_chain_rename_spec.lua:99` — "*sets branch_after from the parent's branch back to the child*" — does not exercise the renamed-**child** case. The fixture writes the parent's branch line as `kid_name`, which is the child's actual on-disk name, so the naive resolver resolves it fine: reverting `chat_respond.lua:213` to `helper.resolve_relative_path` fails only the arch guard. Done-when row 2 ("`branch_after` is correct when the CHILD was renamed") is therefore unasserted. Fix: write the child under a slugged name and have the parent's `🌿:` line name the pre-slug basename.
- `atlas/chat/lifecycle.md:55` — "*Five guards, **each with its own test***" — the insert-mode guard has none. Deleting `init.lua:3142-3145` breaks nothing.

**B. `lua/parley/init.lua:3189` — the new writer bypasses `buffer_edit`.** `vim.api.nvim_buf_set_lines` is called directly, in a file that is on `tests/arch/buffer_mutation_spec.lua`'s *shrinking* #90 baseline allowlist ("After Phase 3, ONLY buffer_edit.lua remains"). `buffer_edit.replace_line_at(buf, line_0_indexed, text)` already exists and is exactly this operation. Adding a new call to the list #90 is trying to empty moves the wrong way (ARCH-DRY). Fix: `require("parley.buffer_edit").replace_line_at(buf, lnum - 1, updated)`.

## 4. Minor findings

- `lua/parley/outline.lua:270,274` — `resolve_chat_path(branch.path, file_dir)` runs twice for the same input when `topic == ""`; each is now a glob per chat root, so `<M-t>` pays double. Hoist to one `local child_abs` above the `if` (ARCH-DRY, ARCH-CONSTRAINTS).
- `lua/parley/init.lua:1100` — `pcall(M.repair_reference_at_cursor, …)` discards the error with no log line; a bug in repair is invisible forever. Log at debug on failure.
- `lua/parley/init.lua:3296-3303` — the `seen_dir` dir-dedup is redundant with the `seen` per-match dedup two loops below (same dir globbed twice yields the same resolved paths, which `seen` already filters). It also hand-rolls `resolve_dir_key` (`init.lua:68`) with `fnamemodify(d, ":p")` instead of `expand` — which is why `buffer_mutation_spec`'s "one normalizer" assertion, keyed on the literal `resolve(expand(` spelling, doesn't see it. A guard over a spelling rather than the term, which is the exact class PQ-2 corrected in this issue's own guard.
- `lua/parley/init.lua:3319` — the ambiguity warning fires on *every* resolve. The highlighter re-resolves visible branch lines every 500 ms and the outline walk re-resolves per branch, so one genuinely-colliding reference will emit unboundedly. Consider once-per-reference or debug level.
- `lua/parley/init.lua:3142` — the insert/replace-mode guard cannot fire from its only trigger: `CursorHold` does not fire in insert mode (`CursorHoldI` does). Harmless, but it reads as protection and has no test; either drop it or note it as defence for direct API callers.
- `lua/parley/init.lua:3139` — `M.not_chat` does a full-buffer `nvim_buf_get_lines(buf, 0, -1, false)` and runs *before* the "cheap string test" the docstring says gates the work. Measured at 0.17 ms/call on a 5 000-line chat against a ≥4 s `updatetime`, so immaterial today — but the cheap line test would be the natural first guard.
- `lua/parley/exporter.lua:32` still defines `local function resolve_chat_path(...)`, a local resolver shadow the new guard's "no module defines its own `resolve_path`" cannot see. Not a hole today (I confirmed a hand-rolled naive join there is caught by `untrusted_path_spec`), but it is the same shape as what was just removed; folding the name into the guard, or calling `_parley.resolve_chat_path` directly as the other three modules now do, closes it.
- `README.md` is unchanged. Resting the cursor on a stale `🌿:` link now marks the buffer `modified` and the feature's responsiveness depends on the user's `updatetime` — user-observable ambient behavior worth a line near the `<M-o>` / `🌿:` documentation.
- `tests/arch/single_resolver_spec.lua:15-25` re-derives file enumeration and line reading rather than extending `tests/arch/arch_helper.lua`. Function-scoped allowlisting is a legitimately new capability; it belongs in the helper so the next such guard doesn't re-derive the scanner.
- `lua/parley/init.lua:3189` writes a basename read off the filesystem straight into the buffer. A filename containing a newline makes `nvim_buf_set_lines` raise (swallowed by the autocmd's `pcall`, propagated for direct callers). ARCH-SECURE nit; a `updated:find("\n")` bail would make the failure visible instead.

## 5. Test coverage notes

Mutation results at HEAD (scratch clone, full suite per mutation):

| mutation | caught by |
|---|---|
| `chat_respond.lua:193` → naive | `ancestor_chain_rename_spec` **+** arch guard ✅ |
| `chat_respond.lua:213` → naive | arch guard only ⚠️ (renamed-child case unexercised) |
| `outline.lua:227/270/274` → naive | arch guard only ⚠️ (no behavioral test) |
| drop `vim.fn.resolve(ordered[1])` | `ancestor_chain_rename_spec` ✅ |
| drop the `updated == line` no-op guard | `read_repair_spec` ✅ |
| drop the insert-mode guard | nothing ⚠️ |
| drop the `seen_dir` dedup | nothing (redundant with `seen`) |
| `exporter.lua:32` → hand-rolled join | `untrusted_path_spec` ✅ |

Not covered, worth adding beyond the Critical's regression test: the `CursorHold` autocmd wiring (every read-repair test calls the function directly — I verified reachability by hand with `doautocmd CursorHold`, but nothing pins it), and the ambiguity-warning emission at integration level (`resolve_candidates` is unit-tested; the `M.logger.warning` branch at `init.lua:3319` never runs in the suite).

## 6. Architectural notes

- **ARCH-DRY** — flagged: `outline.lua:270/274` double resolve; the `seen_dir` key duplicating `resolve_dir_key`; `single_resolver_spec` re-deriving `arch_helper`'s scanner. The core consolidation itself is exemplary — six resolvers to one, with the survivor chosen as the *more correct* implementation, which is the lesson the Spec correctly extracts from #225.
- **ARCH-PURE** — pass. `resolve_candidates` and `rewrite_reference` are genuinely pure and unit-tested without a filesystem; the glob is the only IO left in `resolve_chat_path`; `_collect_ancestor_chain` / `_collect_ancestor_messages` are honest IO seams rather than pretending the walk is pure.
- **ARCH-PURPOSE** — flagged, mildly. The class was named well (the *name* `resolve_path`, not just the two broken copies) and swept. But three claimed tests are absent, and one of them (`<M-t>`) covers a site the Spec itself marks "verified" broken — the enumeration was written and then not fully executed.
- **ARCH-MOCK** — N/A. No new external binary or service; the arch spec's `find`/`grep` shell-outs follow the established `tests/arch` pattern.
- **ARCH-CONSTRAINTS** — flagged. The declared envelope covers the `CursorHold` path ("one glob per idle pause") but not the envelope change to *existing* callers: `resolve_chat_path` no longer short-circuits on an exact `filereadable` hit, so the highlighter's 500 ms-debounced viewport pass, `find_tree_root`, `collect_tree_files` and the outline walk all now pay a glob per chat root per reference where they previously paid a stat. Bounded and debounced, so not a defect — but it is an undeclared change to the operating envelope, and `outline.lua`'s double resolve doubles it needlessly.
- **ARCH-SECURE** — mostly pass: `safe_glob` retained with its rationale, `%`-escape tested, `resolve_relative_path`'s TOTAL contract preserved. The Critical is the security-adjacent hole: a transcript-controlled reference resolving to a file other than the one it names. The unvalidated filename write-back is the minor one.
- **ARCH-ORDER** — pass, with one note. `repair_reference_at_cursor` is fully synchronous, holds no state between events, and `is_busy` is injectable, so `read_repair_spec:127` observes the busy interleaving *and* the retry-after-free transition rather than one sample. The concurrent writer (`chat_lease`) is correctly deferred to with explicit IGNORE semantics. Note: the autocmd reads `ev.buf` but takes `lnum` from `nvim_win_get_cursor(0)`; they agree for `CursorHold` today, but passing `ev.buf`'s window line would make the pairing structural rather than incidental.

## 7. Plan revision recommendations

Add a `## Revisions` entry to `workshop/issues/000224-ancestor-chain-slug-rename.md`:

1. **`2026-09-09 — Plan rows 5 and 6 were checked without their tests.** Row 6 (`<M-t>` tree) has no test at all; row 5's `branch_after` fixture never renames the child, so the second consumer site is pinned only by the arch guard. Both rows unchecked pending the tests, and Done-when row 2 restated as the fixture shape it requires.
2. **`2026-09-09 — prefix identity needs the reference's own directory in the glob set.** The Spec's argument that "an exact-name hit is just the case where the glob returns the name the reference already used" holds only when the reference's directory is globbed. It is not, for absolute/`~`/`../` references. Amend the Spec's resolution rule to `reference → timestamp → glob "<ts>*" across {reference's own dir} ∪ {base_dir} ∪ roots`, and note that this preserves the one-rule design rather than restoring the deleted tier.

Also correct `atlas/chat/lifecycle.md:55` — "Five guards, each with its own test" is false until the insert-mode guard is either tested or removed.

```findings
findings:
  - id: new
    severity: Critical
    family: prefix-identity-scope
    title: |
      resolve_chat_path returns a same-timestamp file instead of the readable file the reference names
    detail: |
      lua/parley/init.lua:3297 globs only base_dir plus the chat roots, so a
      reference whose own directory is neither (absolute, ~/, or ../relative)
      never produces an exact-basename candidate and loses to an unrelated
      same-timestamp file in a chat root. Reproduced: an existing
      archive/TS.md referenced by absolute path resolves to
      chats/TS_live-topic.md. The existence loop at :3336 is unreachable
      because ordered[1] is already truthy. Verified fix, suite stays green:
      seed search_dirs with vim.fn.fnamemodify(candidates[1], ":h").
  - id: new
    severity: Important
    family: claimed-test-not-pinned
    title: |
      Three claims of test coverage have no test behind them
    detail: |
      Verified by mutation. (1) Plan row 6 claims a <M-t> tree test; none
      exists, and reverting outline.lua:227/270/274 to the naive resolver
      fails only the arch guard. (2)
      tests/integration/ancestor_chain_rename_spec.lua:99 never renames the
      child, so reverting chat_respond.lua:213 fails only the arch guard and
      Done-when row 2 is unasserted. (3) atlas/chat/lifecycle.md:55 says
      "five guards, each with its own test"; deleting the insert-mode guard
      at init.lua:3142 breaks nothing.
  - id: new
    severity: Important
    family: buffer-edit-seam
    title: |
      repair_reference_at_cursor writes the buffer directly instead of through buffer_edit
    detail: |
      lua/parley/init.lua:3189 calls vim.api.nvim_buf_set_lines in a file that
      sits on tests/arch/buffer_mutation_spec.lua's deliberately shrinking #90
      baseline allowlist. buffer_edit.replace_line_at(buf, line_0_indexed,
      text) is exactly this operation and is the declared final home.
  - id: new
    severity: Minor
    family: redundant-resolution
    title: |
      outline.lua resolves the same branch.path twice, now two globs per branch
    detail: |
      lua/parley/outline.lua:270 and :274 resolve the same input when
      topic == ""; each is a glob per chat root since the resolver stopped
      short-circuiting on an exact hit. Hoist to one local above the if.
  - id: new
    severity: Minor
    family: silent-error-swallow
    title: |
      The CursorHold callback pcalls repair and discards the error unlogged
    detail: |
      lua/parley/init.lua:1100. A failure inside repair_reference_at_cursor is
      invisible forever; log at debug on the false branch.
  - id: new
    severity: Minor
    family: guard-must-match-class
    title: |
      The new dir-dedup key hand-rolls resolve_dir_key and evades the one-normalizer guard
    detail: |
      lua/parley/init.lua:3298 spells it vim.fn.resolve(fnamemodify(d, ":p")):gsub("/+$", "")
      while resolve_dir_key (init.lua:68) is the canonical form;
      buffer_mutation_spec's "one normalizer" assertion greps the literal
      resolve(expand( spelling and so cannot see it. The dedup is also
      redundant with the per-match `seen` table two loops below.
  - id: new
    severity: Minor
    family: unbounded-log-emission
    title: |
      The same-timestamp ambiguity warning fires on every resolve
    detail: |
      lua/parley/init.lua:3319. The highlighter re-resolves visible branch
      lines every 500ms and the outline walk re-resolves per branch, so one
      colliding reference emits unboundedly. Once-per-reference or debug level.
  - id: new
    severity: Minor
    family: unreachable-guard
    title: |
      The insert/replace-mode guard cannot fire from its only trigger
    detail: |
      lua/parley/init.lua:3142. CursorHold does not fire in insert mode
      (CursorHoldI does), so the branch is dead in production and untested.
      Drop it or document it as defence for direct API callers.
  - id: new
    severity: Minor
    family: guard-ordering
    title: |
      not_chat's full-buffer read runs before the cheap line test the docstring credits
    detail: |
      lua/parley/init.lua:3139 reads the whole buffer via nvim_buf_get_lines
      before the reference-present string test at :3155. Measured 0.17 ms on a
      5000-line chat against a >=4s updatetime, so immaterial — but the cheap
      test is the natural first guard and is what the envelope describes.
  - id: new
    severity: Minor
    family: single-resolver-rule
    title: |
      exporter.lua keeps a local resolver shadow the new guard cannot see
    detail: |
      lua/parley/exporter.lua:32 defines `local function resolve_chat_path`.
      single_resolver_spec forbids only the name `resolve_path`. Not a hole
      today (a hand-rolled naive join there is caught by untrusted_path_spec),
      but it is the shape just removed from three other modules.
  - id: new
    severity: Minor
    family: docs-user-surface
    title: |
      README not updated for the cursor-hold repair behavior
    detail: |
      Resting the cursor on a stale branch reference now marks the buffer
      modified, and responsiveness depends on the user's updatetime. Worth a
      line near the existing <M-o> / branch-reference documentation.
  - id: new
    severity: Minor
    family: arch-helper-reuse
    title: |
      single_resolver_spec re-derives file enumeration and line reading
    detail: |
      tests/arch/single_resolver_spec.lua:15-25 duplicates what
      tests/arch/arch_helper.lua already does. Function-scoped allowlisting is
      genuinely new; it belongs in the helper so the next guard reuses it.
  - id: new
    severity: Minor
    family: untrusted-input-writeback
    title: |
      A filesystem-derived basename is written into the buffer unvalidated
    detail: |
      lua/parley/init.lua:3189. A filename containing a newline makes
      nvim_buf_set_lines raise — swallowed by the autocmd pcall, propagated
      for direct callers. An explicit newline check would fail visibly.
```
