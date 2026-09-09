# Boundary Review — parley.nvim#225 (whole-issue close)

| field | value |
|-------|-------|
| issue | 225 — Open a link with <M-o>, falling back to gf |
| repo | parley.nvim |
| issue file | workshop/issues/000225-open-link-alt-o.md |
| boundary | whole-issue close |
| milestone | — |
| window | 4fc595d084904410aa5ed82d7c8a3c81f987949d..25c028189553dcfc2a18409685cc12ddd505f7aa |
| command | sdlc close --issue 225 |
| reviewer | claude |
| timestamp | 2026-09-08T19:16:06-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The extraction is genuinely good work. Two drifted chains collapse into one `open_reference_under_cursor` with an explicit three-valued contract, the four measured divergences are each disposed with a stated verdict rather than silently flattened, and the whole thing is backed by a 17-test integration spec that I confirmed by mutation actually bites: flipping `"failed"` into the fall-through goes red, and reintroducing the `<M-o>` collision in `config.lua` reddens the generalised guard. Full suite (356 files) and `make lint` both clean at HEAD. What holds it back from SHIP is four Important items: the resolve-arm test does not use the injected-runner seam the Done-when and PQ-5 both promised (it monkeypatches `run_resolve` instead, because the seam is unreachable from `goto_ref_at_cursor`); the `is_chat` divergence — the one the Spec says "must NOT be flattened" — is asserted positively only, and I verified by mutation that deleting the gate leaves all 17 tests green; `focus_other_split` sweeps two of three copies of the two-split preference and leaves `open_buf`'s; and the now-single-sited `vim.fn.expand(ref_path)` executes backticks from transcript content, which I confirmed end-to-end.

## 1. Strengths

- **The three-valued contract is the right call and is genuinely pinned.** `init.lua:4340-4350` documents why `"failed"` must not fall through, and mutating `if outcome == "none"` → `or outcome == "failed"` (`init.lua:4467`) turns the spec red. This is exactly the ARCH-ORDER "tagged enum, not a boolean constellation" shape, arrived at from the right reasoning.
- **The divergence table was honoured, not rationalised away.** The issue's own `## Spec` records the `branch_inserters` near-miss ("consolidating implementations ≠ erasing situational differences") and the code does keep the chat-only `Explore` arm behind a named parameter rather than deleting the "second copy."
- **The D3 finding is a real bug fix, not a nicety.** `open_reference_spec.lua:243-256` asserts the chat-file *count* after opening a bare `@@name@@`, which pins the actual old behaviour (silently forking a second empty chat) rather than just which path came back.
- **The collision guard was generalised correctly, including the negative case.** `keybindings_spec.lua:906-963` reasons about scope *overlap* (ancestor, not equality), and the sibling test at `:955` proves the guard would still fire on a parent/child pair — so the `<M-CR>` exemption isn't accidental passing. I reproduced its red state by putting `<M-o>` back in `config.lua:464`.
- **Docs sweep is thorough.** README, `atlas/context/file_references.md` (rewritten with the outcome table), `atlas/context/artifact_refs.md`, `atlas/modes/review.md`, `atlas/ui/keybindings.md`, `atlas/index.md` and `atlas/traceability.yaml` all move together; a tree-wide grep finds no stale `<M-g>` or `open_chat_reference` outside history/plan prose.

## 2. Critical findings

None.

## 3. Important findings

**I1 — `lua/parley/artifact_ref.lua:208` / `tests/integration/open_reference_spec.lua:315-345`: the resolve arm does not use the seam it was required to use (ARCH-MOCK).**
The Done-when says the resolve arm is "exercised through `artifact_ref.run_resolve`'s existing injected-runner seam (`artifact_ref.lua:112-134`)", and PQ-5 was disposed `addressed` on that basis. The test instead replaces `artifact_ref.run_resolve` wholesale (`:338-339`) and honestly documents why at `:315-318`: `goto_ref_at_cursor` calls `run_resolve` with three arguments, so the `runner` parameter is dead on the production path. That means production flow and test flow do not share a boundary — the `sdlc` dependency is faked by swapping a module function, which is the stateless-mock shape ARCH-MOCK asks you to avoid.
Fix: thread it — `M.run_resolve(hit.ref, {...}, cb, opts.runner)` at `artifact_ref.lua:208`, `opts.runner` documented on `goto_ref_at_cursor`, and the spec passes a fake runner that returns canned `sdlc resolve --json` stdout. The same change retires the identical wholesale stub at `tests/unit/artifact_ref_spec.lua:249-252`.

**I2 — `lua/parley/init.lua:4382` and `:4396`: `vim.fn.expand()` on transcript-derived text executes shell commands (ARCH-SECURE).**
`ref_path` comes straight from buffer content, and `vim.fn.expand()` performs backtick expansion. I confirmed this end-to-end through the real command: a chat line ``@@`touch /tmp/.../PWNED && echo /nope`@@`` with the cursor on it and `<M-o>` pressed creates the file. Chat buffers hold model output, so provenance is untrusted regardless of who wrote the file.
This is **pre-existing** — both deleted chains called `vim.fn.expand()` on the same value — so it is not drift introduced here, but this diff is what makes it a single site to fix. The class is "transcript-derived string handed to a vim function that shells out"; its enumeration is `init.lua:4382`, `init.lua:4396` (both derive from `ref_path`, so one guard right after extraction covers both) and the sibling consumer `helper.find_files:313`, reached from `@@`-content-inclusion via `chat_respond.lua:847`. `resolve_chat_path` is clean (`glob`/`filereadable` only). Fix sketch: reject or escape `` ` `` in `ref_path` before expanding — degrade to `"none"` or warn, rather than expanding. If the operator prefers to keep #225 scoped, split it to its own issue rather than leaving it unrecorded.

**I3 — `lua/parley/init.lua:4387`: the one deliberate divergence is not defended by a test.**
The Spec calls D4 "the one that must NOT be flattened" and the Plan row promises "characterisation tests for all four... so a dropped arm fails rather than passing silently." The spec asserts D4 twice, but only positively (chat *does* `Explore`). I mutated the gate to `if true and (...)` — flattening precisely the divergence the issue exists to preserve — and all 17 tests stayed green. The `is_chat` parameter is currently a comment with a signature.
Fix: add the negative half — a directory `@@dir/@@` reference in a *markdown* buffer must not issue `Explore` (assert no `Explore` in the `vim.cmd` spy, and that it takes the `"failed"`/warning exit).

**I4 — `lua/parley/init.lua:4314` vs `2960-2984`: the two-split preference still has two copies (ARCH-DRY, ARCH-PURPOSE).**
`focus_other_split` is a verbatim extraction of the block `open_buf` still carries inline at `2960-2984`. The diff removed two of three copies and the comment ("`open_buf` already had its own copy for files; this one exists because netrw does not go through `open_buf`") explains why a separate *call site* is needed — not why the *logic* must be duplicated. Given DRY is the stated rationale for the entire extraction, stopping at the two instances the issue named is the instance-not-class pattern.
Fix: move `focus_other_split` above `open_buf` (Lua `local function` visibility) and have `open_buf` call `if not from_chat_finder then focus_other_split() end` before its `edit`. Only observable delta is the debug log wording.

## 4. Minor findings

- `lua/parley/init.lua:4395` vs `lua/parley/helper.lua:370-379`: the glob→base-dir derivation (`gsub("/%*%*?/?.*$",""):gsub("/%*%.%w+$","")`) is a near-duplicate of `process_directory_pattern`'s. Moved code, not new, but it is the pure fragment that belongs in one tested helper — and it is the counterexample to the Core-concepts table's "Pure entities: None."
- `tests/arch/single_source_sweeps_spec.lua:192`: skipping `deleted` rows outright means the sweep can no longer catch "claimed deleted, still present." Stronger: for a `deleted` row, assert the symbol has **no** definition.
- `tests/integration/keybinding_agreement_spec.lua:370`: the markdown "is mapped" list gained `<M-s>` but never got `<M-o>`. "Works in both buffer types" is pinned at the command level (`open_reference_spec`) but not at the binding level, which is where the collision actually lived.
- `lua/parley/init.lua:4475`: `<M-o>` now routes into `sdlc resolve` (a subprocess) with no in-flight guard or dedup — two presses before the first returns start two spawns and can open twice. Pre-existing on `gf`, but this puts it on the key the operator presses most (ARCH-CONSTRAINTS).
- `lua/parley/init.lua:4356-4358`: chat's chain order flipped — inline branch links are now tried before `open_branch_ref`. Only observable on a `🌿:` line that also contains an inline `[🌿:…](file)` with the cursor inside it. Intentional (markdown's order won), just unrecorded.
- Commit `bb7050a` swept twelve unrelated `workshop/parley/*.md` transcripts (~1,300 lines on pi, special relativity, Io's orbital period) into the implementation commit. `git log --grep "^#225"` now returns a commit whose diff is mostly unrelated prose (AGENTS.md §12).

## 5. Test coverage notes

Mutation results, run against the real spec: `"failed"`→fall-through **red** (contract pinned); `<M-o>` collision restored in `config.lua` **red** (guard pinned, and it correctly reads resolved config keys, not `default_key`); `is_chat` gate removed **green** (I3). `make lint`: 0 warnings / 0 errors over 356 files. Full suite: no failures.

Two gaps beyond I1/I3: neither the inline `[🌿:…](file)` arm nor the `🌿:` reference-line arm has a `<M-o>`-level test in either buffer type — they were the two capabilities present in *both* old chains, so they weren't characterisation targets, but their return contract changed from `boolean` to the three-valued status, which is exactly the kind of edit that silently swaps `"failed"` for `"opened"`. And the landing-mode tests (`:357-403`) stub `vim.cmd` entirely, so they assert that `stopinsert`/`startinsert` were *issued*, not that the editor ended in that mode; my attempt to drive real insert mode headlessly showed `startinsert` doesn't engage under `--headless`, so this may simply be the ceiling here — worth a comment saying so.

## 6. Architectural notes

ARCH-DRY: **flag** (I4, plus the glob-derivation nit) — the consolidation is real and large, it just stopped one instance short of the class. ARCH-PURE: **pass** — declaring "Pure entities: None" is honest for a function whose behaviour *is* the IO, and `M._open_reference_under_cursor` follows the repo's existing `M._` test-seam idiom; the pure fragments noted above are the future extraction. ARCH-PURPOSE: **flag** (I1, I3) — the diff fulfils the issue's purpose in the code, but two Done-when bullets are stated more strongly than what shipped. ARCH-MOCK: **flag** (I1). ARCH-CONSTRAINTS: **pass** — nothing unbounded is introduced; `not_chat`'s full-buffer read moved from 2× to 1× for chat and 1× to 2× for markdown, which is the right way round given chat is the release surface. ARCH-SECURE: **flag** (I2). ARCH-ORDER: **pass** — the component carries no state between events (each invocation re-reads the line), and the boolean→tagged-status change is this principle applied by hand; the one unbounded extent is the async `run_resolve` → `vim.schedule` → `open_buf` with no cancellation if the user leaves the buffer mid-flight, which is pre-existing in `artifact_ref` and worth an issue rather than a gate finding.

For #224 (the read-repair follow-up): the Log's decision not to extend `referring_file` to the `@@` path is the right seam, and it now has exactly one place to be extended — `init.lua:4400`, the `resolve_chat_path(expanded_path, current_dir)` call.

## 7. Plan revision recommendations

Two `## Revisions` entries on `workshop/issues/000225-open-link-alt-o.md`:

1. **Done-when, resolve-arm bullet.** It claims the arm is "exercised through `artifact_ref.run_resolve`'s existing injected-runner seam (`artifact_ref.lua:112-134`) rather than spawning `sdlc`." Delivered instead by replacing `run_resolve` itself, because `goto_ref_at_cursor` (`artifact_ref.lua:208`) never passes `runner`. Either land I1 and keep the bullet, or revise it to say what shipped and record the seam gap as a follow-up.
2. **`## Core concepts` / Done-when, D4.** The Plan row claims "characterisation tests for all four... so a dropped arm fails rather than passing silently"; measured, removing the `is_chat` gate leaves the suite green. Add the negative assertion (I3) and the row becomes true; otherwise the row should say the divergence is documented but unasserted.

```findings
findings:
  - id: new
    severity: Important
    family: external-seam-not-shared
    title: |
      The resolve arm stubs run_resolve wholesale; the injected-runner seam the Done-when promised is unreachable from goto_ref_at_cursor
    detail: |
      artifact_ref.lua:208 calls M.run_resolve with three arguments, so the documented
      runner(argv, on_complete) seam is dead on the production path. open_reference_spec.lua:338
      therefore replaces artifact_ref.run_resolve itself, which means the test flow and the
      production flow do not share a boundary (ARCH-MOCK). Thread opts.runner through
      goto_ref_at_cursor and let the spec inject a fake returning canned `sdlc resolve --json`
      stdout; the same change retires the identical stub at artifact_ref_spec.lua:249-252.
  - id: new
    severity: Important
    family: untrusted-path-expansion
    title: |
      vim.fn.expand on transcript-derived text executes backticks, reachable from the unified chain
    detail: |
      Verified end-to-end through the real command: a chat line @@`touch <path> && echo /nope`@@
      with the cursor on it creates the file when <M-o> is pressed. ref_path comes from buffer
      content whose provenance is model output. Pre-existing (both deleted chains expanded the
      same value), but this diff makes it single-sited. Class enumeration: init.lua:4382 and
      init.lua:4396 (both derive from ref_path, so one guard after extraction covers both), plus
      the sibling consumer helper.find_files:313 reached via chat_respond.lua:847. Reject or
      escape a backtick in ref_path and degrade to "none"/warn rather than expanding.
  - id: new
    severity: Important
    family: divergence-not-pinned
    title: |
      The is_chat directory divergence has no negative test; flattening it leaves the suite green
    detail: |
      The Spec names D4 "the one that must NOT be flattened" and the Plan promises
      characterisation tests for all four arms. Mutating init.lua:4387 to `if true and (...)`
      -- flattening exactly that divergence -- leaves all 17 tests in open_reference_spec
      passing. Add the negative half: a directory reference in a MARKDOWN buffer must not issue
      Explore and must take the "failed"/warning exit.
  - id: new
    severity: Important
    family: two-split-preference-duplicated
    title: |
      focus_other_split swept two of three copies; open_buf still carries its own inline version
    detail: |
      init.lua:4314 is a verbatim extraction of the block open_buf still holds at 2960-2984.
      The comment explains why a separate CALL SITE is needed (netrw does not go through
      open_buf) but not why the logic must be duplicated. Since ARCH-DRY is the stated
      rationale for the whole extraction, stopping at the two instances the issue named is
      instance-not-class. Move focus_other_split above open_buf and call it there.
  - id: new
    severity: Minor
    family: two-split-preference-duplicated
    title: |
      The glob-to-base-dir derivation duplicates helper.process_directory_pattern
    detail: |
      init.lua:4395's gsub pair is a near-duplicate of helper.lua:370-379. Moved code rather
      than new, but it is the pure fragment that belongs in one tested helper -- and the
      counterexample to the Core-concepts table's "Pure entities: None".
  - id: new
    severity: Minor
    family: divergence-not-pinned
    title: |
      The sweep now skips `deleted` rows entirely instead of asserting the symbol is gone
    detail: |
      single_source_sweeps_spec.lua:192 short-circuits the whole row, so a plan can mark a row
      deleted while the symbol survives. Stronger: for a deleted row, assert no definition
      exists. (open_chat_reference is in fact gone -- I grepped -- but the guard would not know.)
  - id: new
    severity: Minor
    family: binding-level-coverage-gap
    title: |
      The markdown "is mapped" list gained <M-s> but never <M-o>
    detail: |
      keybinding_agreement_spec.lua:370 pins <C-g>ve/<M-s>/<M-CR> on a markdown buffer. The
      Done-when's "in both buffer types" is asserted at the command level only; the collision
      this issue fixed lived at the binding level.
  - id: new
    severity: Minor
    family: unbounded-inflight-spawn
    title: |
      The <M-o> fall-through spawns sdlc resolve with no in-flight guard
    detail: |
      init.lua:4475 routes the most-pressed key into an uncancelled subprocess; two presses
      before the first returns start two spawns and can open twice or show two pickers.
      Pre-existing on gf, but the key it now sits behind is pressed far more often
      (ARCH-CONSTRAINTS / ARCH-ORDER extent).
  - id: new
    severity: Minor
    family: chain-order-change-unrecorded
    title: |
      Chat's chain order flipped: inline branch links now precede open_branch_ref
    detail: |
      init.lua:4356-4358 adopts markdown's order. Observable only on a 🌿: line that also
      contains an inline [🌿:…](file) with the cursor inside it. Intentional, but not recorded
      in the divergence table or the Log.
  - id: new
    severity: Minor
    family: commit-scope-hygiene
    title: |
      Twelve unrelated workshop/parley transcripts were swept into implementation commit bb7050a
    detail: |
      ~1,300 lines on pi history, special relativity and Io's orbital period landed in the
      commit titled "#225: one reference chain, three-valued...". git log --grep "^#225" now
      returns a commit whose diff is mostly unrelated prose (AGENTS.md section 12).
```
