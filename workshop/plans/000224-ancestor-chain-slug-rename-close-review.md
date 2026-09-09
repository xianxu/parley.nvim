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

---

## Re-review — 2026-09-09T12:31:08-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 224 — Forked chat loses its parent context after a slug rename |
| repo | parley.nvim |
| issue file | workshop/issues/000224-ancestor-chain-slug-rename.md |
| boundary | whole-issue close |
| milestone | — |
| window | 6425abc72bb87f821802840a69e614e7d1c70606..4c67f9b7d8063503404fb667cb216048a165d107 |
| command | sdlc close --issue 224 |
| reviewer | claude |
| timestamp | 2026-09-09T12:31:08-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Full suite + lint green at HEAD (`make test`, exit 0). I verified the round-1 fixes by mutation in a scratch export of HEAD, reproduced one residual failure, and measured the perf claim against the base commit.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The round-1 Critical and both Importants are genuinely fixed and genuinely pinned — I reverted each fix in a scratch clone and watched the named test go red, not just the arch guard. `ref_dir` in the glob set is pinned by the new out-of-roots arm; the `<M-t>` regression now drives `_find_tree_root` (the upward, defective half) rather than the downward builder; the `branch_after` fixture now renames the child so the naive resolver actually fails it; the insert-mode guard has a test. What stops a clean SHIP is that BR-1's *class* is only half closed — the glob set gained `candidates[1]`'s directory but not the directories of candidates 2..N, and I reproduced a reference that names an existing file still resolving silently to an unrelated same-timestamp file, with no ambiguity warning because only one candidate matched. Second, deleting the exact-hit short-circuit changed the cost class of `resolve_chat_path` for every pre-existing consumer from O(1) to O(files in the chat roots) — measured 0.033 ms → 2.5 ms at 2000 files/root, 0.041 ms → 7.7 ms at 3 roots — and the issue's declared envelope covers only the new `CursorHold` path.

## 1. Strengths

- **The BR-2 fixes are pinned at the defective seam, not the reachable one.** Reverting `outline.lua:227` to the naive resolver fails the new `<M-t>` arm (`ancestor_chain_rename_spec.lua:138`) with the child returned as tree root; reverting `chat_respond.lua:213` fails the `branch_after` arm; deleting `init.lua:3140-3143` fails the insert-mode arm. All three verified by mutation, all three previously caught only by the arch guard.
- **The BR-1 fix is real.** Replacing `{ base_dir, ref_dir }` with `{ base_dir }` fails `ancestor_chain_rename_spec.lua:121` with exactly the wrong-file resolution the finding described.
- **The arch guard goes red on the mutation it exists to catch.** Re-adding a `local function resolve_path` delegating to `helper.resolve_relative_path` in `outline.lua` fails two of `single_resolver_spec`'s four arms. The per-function `NAIVE_ALLOW` plus the dead-entry test is the right shape.
- **`chat_slug.resolve_candidates` / `rewrite_reference` are honestly PURE** (`lua/parley/chat_slug.lua:107,152`) — unit-tested with no filesystem, and the `%`-in-replacement trap has its own test.
- **The `CursorHold` trigger works end to end.** I drove `doautocmd CursorHold` with the cursor on a stale `🌿:` line in a scratch clone and the line was repaired in the buffer; the autocmd is registered under `ParleyReadRepair` with `pattern = "*.md"`.
- **`buffer_edit.replace_line_at`** (`init.lua:3190`) is the correct seam and the right direction for #90's shrinking allowlist.

## 2. Critical findings

None.

## 3. Important findings

**A. `lua/parley/init.lua:3311` — the glob set covers `candidates[1]`'s directory but not the other candidates', so BR-1's silent-wrong-file is still reachable.**

**This is the 2nd finding in family `prefix-identity-scope`.** BR-1 fixed the instance it named (absolute / `~` / `../` references, whose directory is `candidates[1]`'s). The class is: *every directory `_resolve_chat_path_candidates` can point into must be in the glob set, or an existing exact target loses to an unrelated same-timestamp hit.* `_resolve_chat_path_candidates` produces one candidate per chat root (`init.lua:3253`: `vim.fn.resolve(dir .. "/" .. path)`), so for a reference with a directory component the candidate dirs are `<root>/sub` — and only `<root>` is globbed.

Reproduced at HEAD (two roots, `chat_dirs = { root1, root2 }`):

```
root2/sub/2026-05-05.10-00-00.777.md            <- exists, named by "sub/<ts>.md"
root1/2026-05-05.10-00-00.777_unrelated.md      <- unrelated, same timestamp

resolve_chat_path("sub/2026-05-05.10-00-00.777.md", root1)
  → root1/2026-05-05.10-00-00.777_unrelated.md   (WRONG FILE, and silent)
```

No warning fires, because `matched` has exactly one element so `resolve_candidates` returns `ambiguous = false`. That is the sharper form of the rule: **a single non-exact glob hit is not evidence the reference is stale — it can mean the reference's directory was never searched.** Reachability is narrower than BR-1's (auto-written references are basename-only or absolute per `init.lua:2231`, so this needs a hand- or model-authored `sub/…` reference), which is why this is Important and not Critical.

Fix the rule, not the site — derive the glob set from the candidate list instead of naming directories one at a time:

```lua
local seen_dir, search_dirs = {}, {}
local dirs = { base_dir }
for _, c in ipairs(candidates) do dirs[#dirs + 1] = vim.fn.fnamemodify(c, ":h") end
vim.list_extend(dirs, M.get_chat_dirs() or {})
```

Then the enumeration cannot go stale when `_resolve_chat_path_candidates` gains a source. Pin it with the probe above.

**B. `lua/parley/init.lua:3288` — deleting the exact-hit short-circuit changed the cost class of every pre-existing consumer, and the declared envelope only covers the new trigger.**

Family: `undeclared-envelope-change` (new). Round 1 noted this in prose under ARCH-CONSTRAINTS but raised no finding, so it stands unmeasured. Measured, same fixture on base `6425abc` vs HEAD, exact-name hit (the overwhelmingly common case — every reference whose parent has not been renamed, and every reference after a repair):

| roots × files | base | HEAD |
|---|---|---|
| 1 × 100 | 0.026 ms | 0.209 ms |
| 1 × 500 | 0.029 ms | 0.647 ms |
| 1 × 2000 | 0.033 ms | 2.486 ms |
| 3 × 2000 | 0.041 ms | 7.685 ms |

Cost is now O(files across the searched dirs) per resolve, ~1.2 µs/file, where it was a single `filereadable`. The consumers that pay it are not the new `CursorHold` path: `collect_ancestor_chain` resolves the parent *and then every branch of the parent* until one matches (`chat_respond.lua:213`) per level of the chain; `find_tree_root_file` + `collect_tree_files` + `outline.build_file_outline_items` resolve once per tree node and once per branch (`<M-t>`, `delete_chat_tree`, `:ParleyChatMove`); `highlighter.render_chat_branch_line` resolves per visible branch line on the 500 ms topic-refresh timer. Chat roots grow monotonically, so 2000 files is a one-to-two-year horizon for the fork-heavy use that motivated this issue, not a stress case.

The issue's `**Operating envelope (ARCH-CONSTRAINTS)**` block budgets "one `glob` per idle pause" for the cursor trigger and says nothing about the existing callers. Either bound the cost or declare it. Preferred bound, because it preserves the one-rule design the Spec argues for: memoize `safe_glob` per `(dir, pattern)` for the duration of a walk (a table threaded through `collect_tree_files` / `build_file_outline_items` / `collect_ancestor_chain`), so a tree walk pays one listing per directory instead of one per reference. The cheaper alternative — return an exact `filereadable` candidate before globbing — is answer-preserving in every case *except* when two searched directories hold the identical basename (candidate order vs. lexicographic), and it reads as the deleted tier even though it is not a second resolver; if you take it, say so in the Spec.

**C. `tests/integration/read_repair_spec.lua` — nothing drives the feature's only production entry point.**

**This is the 2nd finding in family `claimed-test-not-pinned`.** Earlier rounds fixed instances (the `<M-t>` row, the `branch_after` fixture, the insert-mode guard). The rule underneath all of them, including this one: **a test must enter through the path production enters through — the trigger, not just the function behind it.** BR-2's own lesson was stated as "testing the reachable seam instead of the defective one"; here every one of the nine arms calls `parley.repair_reference_at_cursor(buf, lnum)` directly, so the `CursorHold` autocmd (`init.lua:1090-1101`) — its event, its `*.md` pattern, its `ev.buf` / `nvim_win_get_cursor(0)` pairing — is pinned by nothing. I confirmed by hand that it works today, so this is regression exposure rather than a shipped bug; the fix is one arm that sets the cursor and calls `vim.cmd("doautocmd CursorHold")`.

## 4. Minor findings

- `atlas/chat/lifecycle.md:32` and `tests/arch/single_resolver_spec.lua:74-77` both state "**Six** modules once had a `local resolve_path`; two were exact-match-only, three delegated to a naive shared helper, one was correct." At base `6425abc` there were exactly **three** (`chat_respond.lua:176`, `highlighter.lua:65`, `outline.lua:208`): two delegating to the naive helper, one to `resolve_chat_path`. "Six" is the Spec's count of *call sites* (five consumers + highlighter) transcribed as *modules*, and the 2+3+1 breakdown double-counts. Family `doc-claim-unverified` (new). A reader who greps for six and finds three concludes the sweep is unfinished.
- `lua/parley/outline.lua:307-311` — the `_find_tree_root` seam assignment was inserted between `_build_tree_outline_items`'s doc comment and its function, so the "expanded_set: …" contract now documents the wrong symbol.
- `tests/arch/single_resolver_spec.lua:37` — `NO_RESOLVE` has no dead-entry test, unlike `NAIVE_ALLOW`, so it can rot into the stale list the allowlist pattern exists to avoid.
- Repair rewrites only the basename inside a reference (`init.lua:3173-3181`), so a `sub/<ts>.md` reference resolving to a file in a different root is rewritten to a name that does not exist at that relative path. Harmless under prefix identity, surprising to a human reading the transcript.

## 5. Test coverage notes

Mutation results at HEAD (scratch export of `4c67f9b`, per-spec run):

| mutation | result |
|---|---|
| `init.lua:3311` drop `ref_dir` from the glob set | `ancestor_chain_rename_spec` red ✅ |
| `outline.lua:227` → `helper.resolve_relative_path` | `ancestor_chain_rename_spec` (`<M-t>` arm) red ✅ |
| `chat_respond.lua:213` → `helper.resolve_relative_path` | `ancestor_chain_rename_spec` (`branch_after` arm) red ✅ |
| delete the insert-mode guard `init.lua:3140-3143` | `read_repair_spec` red ✅ |
| re-add `local function resolve_path` in `outline.lua` | `single_resolver_spec` red ×2 ✅ |
| BR-3 (`replace_line_at` → `nvim_buf_set_lines`) | nothing — `buffer_mutation_spec` allows `init.lua` wholesale; the fix is a static allowlist-direction property, correct by inspection but undefended against reversal |

Still unpinned beyond the findings above: the ambiguity-warning branch (`init.lua:3334`) never executes in the suite; `outline.lua:271`'s `child_abs` with a *renamed child* is guarded only structurally (Plan row 4 claims no test for it, so this is a note, not a false claim); `single_resolver_spec`'s fourth arm is per-file (`does this file mention resolve_chat_path anywhere`), so a module with one resolving and one non-resolving site passes.

## 6. Architectural notes

- **ARCH-DRY** — pass on the core consolidation (three `local resolve_path` definitions and five naive call sites down to one resolver, with the *more correct* implementation chosen as the survivor — the right reading of #225). BR-4's double resolve is fixed. Residual: `single_resolver_spec` still re-derives `arch_helper`'s file enumeration (BR-12, open), and `init.lua:3313` still hand-rolls `resolve_dir_key` (BR-6, open).
- **ARCH-PURE** — pass. `resolve_candidates` / `rewrite_reference` are pure and tested without a filesystem; the glob is the only IO left in the resolver; `_collect_ancestor_chain` / `_collect_ancestor_messages` / `_find_tree_root` are honest IO seams rather than pretending the walk is pure. The `_find_tree_root` addition is the sharpest structural improvement this round.
- **ARCH-PURPOSE** — flagged (Important A). BR-1's class was named correctly in the Revisions entry but swept only to `candidates[1]`; the enumeration `_resolve_chat_path_candidates` already writes down was not reused as the glob set. This is the finding-answers-the-instance pattern, one round later.
- **ARCH-MOCK** — N/A. No new external binary or service; the arch spec's `find`/`grep` shell-outs follow the established `tests/arch` pattern.
- **ARCH-CONSTRAINTS** — flagged (Important B). The declared envelope is complete for the new trigger and silent about the cost class it changed for six existing consumers.
- **ARCH-SECURE** — pass with a note. `safe_glob` is retained with its rationale, `resolve_relative_path`'s TOTAL contract is preserved, and the `%`-escape has a test. New surface: a transcript-derived directory (`ref_dir`) now selects which directory gets listed, where the set was previously confined to `base_dir` plus configured roots. Read-only and within the #225 seam, so not a finding — worth one sentence in the Spec's Trust paragraph, which currently claims the guard "already covers any new sink this introduces". BR-13 (unvalidated filesystem basename written into the buffer) remains open.
- **ARCH-ORDER** — pass. `repair_reference_at_cursor` is synchronous and holds no state between events; `is_busy` is injectable and `read_repair_spec:148` observes the busy interleaving *and* the retry-after-free transition, which is the ordering seam the entry asks for. IGNORE-not-queue is stated and tested.

## 7. Plan revision recommendations

Append to the `## Revisions` section of `workshop/issues/000224-ancestor-chain-slug-rename.md` (and note the file now carries two separate `## Revisions` headings — fold them):

1. **`2026-09-09 — the glob set is the candidate set, not two named directories.`** BR-1's fix added `candidates[1]`'s directory. `_resolve_chat_path_candidates` produces one candidate per chat root, so a reference with a directory component still globs everywhere except `<root>/sub`. Restate the Spec's resolution rule as `reference → timestamp → glob "<ts>*" across {directory of every candidate} ∪ {base_dir}`, and record that a single non-exact glob hit is not evidence of staleness.
2. **`2026-09-09 — the operating envelope changed for the pre-existing consumers, not only the new one.`** Removing the exact-hit short-circuit makes every resolve O(files in the searched directories) — measured 0.033 ms → 2.486 ms at 2000 files/root. Add the tree walk, the ancestor walk and the highlighter's topic refresh to the ARCH-CONSTRAINTS block with the bound chosen (glob memoization per walk, or an exact-hit fast path with its caveat).
3. Correct `atlas/chat/lifecycle.md:32` and `tests/arch/single_resolver_spec.lua:74-77`: three modules defined a `local resolve_path`, not six; five *call sites* reached the naive resolver.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Verified by mutation — reverting {base_dir, ref_dir} to {base_dir} fails ancestor_chain_rename_spec's out-of-roots arm; see new finding for the unswept remainder of the class.
  - id: BR-2
    disposition: addressed
    note: |
      All three verified by mutation: naive find_tree_root fails the new <M-t> arm, naive chat_respond:213 fails the branch_after arm, deleting the insert-mode guard fails read_repair_spec.
  - id: BR-3
    disposition: addressed
    note: |
      buffer_edit.replace_line_at now used at init.lua:3190; static property, unpinnable while buffer_mutation_spec allowlists init.lua wholesale.
  - id: BR-4
    disposition: addressed
    note: |
      outline.lua:271 resolves once into child_abs above the topic branch.
  - id: BR-5
    disposition: not-addressed
    note: |
      init.lua:1099 still pcalls and discards; a failure inside repair stays invisible.
  - id: BR-6
    disposition: not-addressed
    note: |
      init.lua:3313 still spells the dir key by hand instead of resolve_dir_key.
  - id: BR-7
    disposition: not-addressed
    note: |
      init.lua:3334 still warns on every resolve; the warning branch also never executes in the suite.
  - id: BR-8
    disposition: not-addressed
    note: |
      The guard gained a test (mocked nvim_get_mode) but is still unreachable from CursorHold in production and the docstring still frames it as protecting the cursor path.
  - id: BR-9
    disposition: not-addressed
    note: |
      not_chat's full-buffer read still precedes the cheap reference test at init.lua:3155.
  - id: BR-10
    disposition: not-addressed
    note: |
      exporter.lua:32 still defines local function resolve_chat_path; the guard greps only the name resolve_path.
  - id: BR-11
    disposition: not-addressed
    note: |
      README.md unchanged in the window; the branch-reference section at README.md:170-190 is the natural home.
  - id: BR-12
    disposition: not-addressed
    note: |
      single_resolver_spec:15-25 still re-derives repo_lua_files/lines_of rather than extending arch_helper.
  - id: BR-13
    disposition: not-addressed
    note: |
      No newline check before the filesystem-derived basename is written into the buffer.
findings:
  - id: new
    severity: Important
    family: prefix-identity-scope
    title: |
      The glob set covers only candidates[1]'s directory, so an existing exact target still loses silently
    detail: |
      2nd finding in this family — do NOT fix this instance. The rule is that
      every directory _resolve_chat_path_candidates can point into must be in
      the glob set; derive search_dirs from the candidate list instead of
      naming base_dir and candidates[1] by hand. Reproduced at HEAD with two
      roots: resolve_chat_path("sub/<ts>.md", root1) returns
      root1/<ts>_unrelated.md while root2/sub/<ts>.md exists and is named by
      the reference. No warning fires, because a single non-exact match sets
      ambiguous=false — a single glob hit is not evidence of staleness.
  - id: new
    severity: Important
    family: undeclared-envelope-change
    title: |
      Deleting the exact-hit short-circuit made every pre-existing consumer's resolve O(chat-root size)
    detail: |
      Measured base 6425abc vs HEAD on an exact-name hit: 0.026->0.209 ms at
      1 root x 100 files, 0.033->2.486 ms at 1x2000, 0.041->7.685 ms at
      3x2000 (~1.2 us per file scanned). Paid per tree node and per branch by
      find_tree_root_file / collect_tree_files / outline.build_file_outline_items
      (<M-t>, delete_chat_tree, ChatMove), per branch of every ancestor by
      chat_respond.lua:213, and per visible branch line by the highlighter's
      500 ms topic refresh. The issue's ARCH-CONSTRAINTS block budgets only
      the CursorHold path. Bound it (memoize safe_glob per (dir, pattern) for
      the duration of a walk) or declare it.
  - id: new
    severity: Important
    family: claimed-test-not-pinned
    title: |
      Nothing drives the CursorHold autocmd — the feature's only production entry point
    detail: |
      2nd finding in this family — do NOT fix this instance. The rule: a test
      must enter through the path production enters through, the trigger and
      not just the function behind it. All nine read_repair_spec arms call
      repair_reference_at_cursor directly, so the autocmd's event, its "*.md"
      pattern and its ev.buf / nvim_win_get_cursor(0) pairing are unpinned. I
      confirmed by hand (doautocmd CursorHold) that it works today, so this is
      regression exposure, not a shipped bug; one arm closes it.
  - id: new
    severity: Minor
    family: doc-claim-unverified
    title: |
      Atlas and the arch spec both say six modules had a local resolve_path; there were three
    detail: |
      atlas/chat/lifecycle.md:32 and tests/arch/single_resolver_spec.lua:74-77
      state "six modules ... two exact-match-only, three delegated, one
      correct". At base 6425abc there were exactly three definitions
      (chat_respond.lua:176, highlighter.lua:65, outline.lua:208) — two naive,
      one correct. "Six" is the Spec's count of call sites transcribed as
      modules; the 2+3+1 breakdown double-counts.
```
