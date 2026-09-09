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

---

## Re-review — 2026-09-08T19:54:08-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 225 — Open a link with <M-o>, falling back to gf |
| repo | parley.nvim |
| issue file | workshop/issues/000225-open-link-alt-o.md |
| boundary | whole-issue close |
| milestone | — |
| window | 4fc595d084904410aa5ed82d7c8a3c81f987949d..5029f4a7c706357fc0e795698cfd500b74002ab5 |
| command | sdlc close --issue 225 |
| reviewer | claude |
| timestamp | 2026-09-08T19:54:08-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The extraction itself is excellent and I confirmed it by mutation rather than by reading the commit messages: flipping `is_chat` to `true` at `init.lua:4387` now reddens exactly one test (BR-5 genuinely fixed), the `deleted`-row matcher fires on a control symbol and stays silent on `open_chat_reference` (BR-8 reachable), and the runner seam is threaded to a real caller (BR-3). Eleven of twelve prior findings are addressed. What blocks SHIP is three things I verified by running the code: **`make test` is red at HEAD** (`tests/arch/single_source_sweeps_spec.lua` — the two new spec files are unrouted in `atlas/traceability.yaml`), the BR-4 guard makes `resolve_chat_path` return `nil` and **two callers crash on it** instead of taking their not-found branch (I reproduced a Lua error on both the `🌿:` and inline-link arms, hidden by a bare `pcall` in the new spec), and the backtick class sweep **stopped short of `outline.lua`**, which I confirmed still executes `` `touch …` `` from a transcript-derived branch path.

## 1. Strengths

- **The three-valued contract is real, not decorative.** `init.lua:4306-4326` states why `"failed"` must not fall through, and the gf spec (`open_reference_spec.lua:288-297`) asserts `calls == 0` for it separately from `"none"`. This is the ARCH-ORDER tagged-enum shape replacing a boolean that meant two things.
- **BR-5 is mutation-verified, by me, not just claimed.** Rewriting `init.lua:4387` to `if true and (…)` turns exactly `D4 — a directory reference does NOT Explore in a markdown buffer` red and leaves the other 17 green. The negative half is doing the work the positive half could not.
- **The BR-8 inversion is reachable.** I ran the guard's own `definition_pattern` grep against a control (`glob_base` → hit in `helper.lua`) and against the deleted symbol (`open_chat_reference` → no hit). The row would fire if the deletion were fake.
- **BR-3's seam is threaded to a real caller.** `artifact_ref.lua:233` passes `opts.runner`, and `artifact_ref_spec.lua:250-262` now asserts the constructed argv (`resolve`, `ariadne#144`) instead of swapping the module function — production and test share `run_resolve`. The `<M-o>` test goes one level lower and fakes `vim.system`, so argv construction, the default runner, JSON decode and dispatch all execute.
- **#226 is a good filing, not a shelf.** It names the ARCH-ORDER extent (staleness after leaving the buffer) that the review only implied, and its Done-when reuses the seam #225 built.
- **BR-12's rebuild is verifiable.** `git diff --name-status` over the pinned range contains no `workshop/parley/` paths; the transcripts are back to untracked.

## 2. Critical findings

**C1 — `atlas/traceability.yaml:190` / `tests/arch/single_source_sweeps_spec.lua:646`: the suite is RED at HEAD.**
```
=== Failed integration test files ===
tests/arch/single_source_sweeps_spec.lua
  a new spec routes nowhere under `make test-changed`
  Passed in: { [1] = 'tests/integration/untrusted_path_spec.lua', [2] = 'tests/unit/glob_base_spec.lua' }
```
`make test` (lint + 356 spec files) is otherwise clean — this is the only failure, and it is caused by this round's own fix commit. The round added three spec files and routed one. Fix: add both to `atlas/traceability.yaml` (`untrusted_path_spec` under `context/file_references`, `glob_base_spec` under whichever doc owns `process_directory_pattern`). The prior round's ledger states "Full suite (356 files) and `make lint` both clean at HEAD" — that was true of the *previous* window, and was not re-established after the fixes.

**C2 — `lua/parley/init.lua:4246` and `:3292`: the BR-4 guard degrades into a Lua error, not a warning.**
`_resolve_chat_path_candidates` (`init.lua:3184`) now returns `{}` on refusal, so `resolve_chat_path` falls to `return candidates[1]` → `nil`. `helper.lua:264` documents the contract as *"Callers treat nil as 'this path is not usable' and take whatever their existing not-found branch is"*, and two callers do not:

```
🌿: ~/`touch /tmp/M && echo /nope`.md: Topic   → ./lua/parley/init.lua:4246: attempt to index local 'expanded' (a nil value)
[🌿:c](~/`touch /tmp/M && echo /nope`.md)      → ./lua/parley/init.lua:3292: attempt to index local 'expanded' (a nil value)
```
(Both reproduced through the real `M.cmd.OpenFileUnderCursor`; the marker file is *not* created, so the security property holds — the failure mode does not.) The reason this shipped is the oracle: `untrusted_path_spec.lua:99` wraps the call in a bare `pcall` and asserts only the marker, so it cannot tell "refused cleanly" from "crashed". Fix: guard `expanded` for `nil` at both sites with the existing `"failed"`/warning exit, sweep the other `resolve_chat_path` consumers (`init.lua:3325`, `:3348`, `:3445`, `exporter.lua:151`, `:180`, `highlighter.lua:66`), and make each untrusted-path arm assert `ok == true` plus the expected warning, not just the absent marker.

**C3 — `lua/parley/outline.lua:207`: the backtick class sweep stopped short; a transcript path still reaches a shell.**

> **This is the 2nd finding in family `untrusted-path-expansion`.** Earlier rounds fixed instances. Do NOT fix this instance — state the rule that covers all of them, and fix that.

The rule: **a path parsed out of buffer text — anything derived from `chat_parser` output (`branches[].path`, `parent_link.path`, `@@` refs, inline links) — may be expanded only via `helper.expand_path`; `vim.fn.expand(<variable>)` in any module that consumes `chat_parser` output is the enumeration, and it should be an arch test with an explicit config-derived allowlist, not a memorised list.** The measured prevalence is now 4 rounds of the same shape: BR-4 named 3 sites, the fix found 10, and a mechanical grep finds the residue the fix did not:

| site | status |
|---|---|
| `outline.lua:207` (`resolve_path`, a **4th** copy of the same 5-line function) | unguarded |
| `outline.lua:221`, `:243`, `:320` | unguarded |
| `exporter.lua:117`, `:128`, `:140`, `:163` | unguarded |
| `chat_respond.lua:176`, `init.lua:3184` | guarded this round |
| `highlighter.lua:66`, `exporter.lua:32` | delegate to the guarded one |

Reproduced end-to-end: a chat with `🌿: ~/`` `touch <marker>` ``.md: Child`, driven through `outline._build_tree_outline_items` → `MARKER CREATED: true`. Reachable from `<M-t>` (outline picker). Note `outline.lua:205` and `chat_respond.lua:176` were *byte-identical* functions; the round guarded one and not the other, which is exactly the drift the third copy predicts (ARCH-DRY + ARCH-PURPOSE: instance, not class).

## 3. Important findings

**I1 — `workshop/issues/000225-open-link-alt-o.md:135`: the Core-concepts table classifies `expand_path` as PURE; it is IO (ARCH-PURE).**
`helper.lua:270` calls `vim.fn.expand`, which reads the environment, globs the filesystem, and — the whole point of the guard — can run a subprocess. Its tests live in `tests/integration/untrusted_path_spec.lua` and need a real Neovim plus a real filesystem to observe the marker; `assert.equals(vim.fn.expand("~"), helpers.expand_path(p))` is asserting against the runtime, not against a pure function. `glob_base` in the row above it *is* pure and its spec proves it. Fix: move `expand_path` to the Integration-points table with `wraps: vim.fn.expand` and add a `## Revisions` note. (The prompt's blanket rule makes a table/code contradiction Critical; I am rating it Important because it is a classification label with no runtime consequence, and the sweep guard already confirms the symbol exists where the row says.)

**I2 — `lua/parley/helper.lua:611-615`: `prepare_dir` returns the unusable input on refusal while every sibling sink returns `nil`/`{}`.**
`read_file_content` → `nil`, `is_directory` → `false`, `find_files` → `{}`, `expand_path` → `nil`; `prepare_dir` alone returns `odir`, the backtick string, which `init.lua:826` (`M.config[k] = M.helpers.prepare_dir(v, k)`) would then store as a config value. Unreachable today because that call site is config-derived, but it is inconsistent error handling introduced by this diff and it makes the guard's contract two-valued in one place and three-valued in another. Fix: return `nil` and let the one config call site keep its existing fallback.

## 4. Minor findings

- `lua/parley/init.lua:4358`: adopting markdown's `^@@%s*([^@]+)@@` narrows chat, which used greedy `^@@(.+)@@`. `@@/tmp/a@b/c.md@@` now falls to `^@@(.+)$` and carries the trailing `@@` into the path → `"failed"` instead of opening. Tiny, but it is a divergence resolved the other way than the four the Spec tabulates, and it is unrecorded.
- `lua/parley/keybinding_registry.lua:750` vs `:256`: `review_menu` (`<M-s>`, `markdown`, desc "open skill picker") and `skill_picker` (`<C-g>s`, `global`, desc "Open Skill Picker") are two ids and two config keys for one action. Now that the key is `<M-s>`, they are the alt/`<C-g>` pair `open_file` models as **one** entry with `default_key = { … }` (ARCH-DRY). Pre-existing, but the rename made it adjacent.
- `atlas/context/file_references.md:52` quotes the surviving diagnostic as `"Chat file not found: …"`; the `@@` arm now emits `"File not found: …"` (`init.lua:4432`). The 🌿: arm still says "Chat file not found", so the doc is half-right.
- `tests/integration/open_reference_spec.lua:305-311` pins the one-call-site invariant by regexing `init.lua` source text for `M%.cmd%.OpenFileUnderCursor = function%(%)(.-)\nend\n`. It works today and the intent is right; it will silently start passing vacuously if the function ever gains a top-level `\nend\n` before its close.

## 5. Test coverage notes

- **The gap that let C2 through is the oracle, not the code.** `untrusted_path_spec.lua:99` and `:112` use `pcall(...)` with no `assert(ok)`. A test whose only assertion is "the marker file is absent" passes identically whether the guard returned cleanly or the interpreter blew up. Every arm should assert `ok == true` *and* the expected warning text.
- **No test pins `open_buf`'s two-split preference**, which is the call site BR-6 added. `focus_other_split` is exercised only through the netrw arm (`open_reference_spec.lua:170-210`); reverting `open_buf` to open in the current window would leave the suite green. BR-6 is structurally correct (I read the diff; the duplicate block is gone), but it is unpinned.
- **Nothing drives `outline`/`exporter` with a hostile branch path** — see C3. The rule-level fix wants one arch test over the module set, not four more per-site cases.
- Positive: the D3 test asserting the chat-file *count* (`open_reference_spec.lua:252`) pins the real old bug (a silent second empty chat) rather than just the path returned. That is the right shape.

## 6. Architectural notes

- **ARCH-DRY — flag.** `focus_other_split` (3→1) and `glob_base` (2→1) are correct consolidations. `resolve_path` is at four copies with two behaviours (C3).
- **ARCH-PURE — flag.** `glob_base` is a clean pure extraction with an IO-free spec; `expand_path` is mislabelled (I1).
- **ARCH-PURPOSE — flag.** The union of D1-D3 genuinely fulfils the issue's purpose and the D4 divergence is defended. The backtick sweep is the under-delivery: the round enumerated ten sinks and stopped at the module boundary rather than at the *provenance* boundary (C3).
- **ARCH-MOCK — pass, with a note.** BR-3 is properly disposed: production and test now share `run_resolve`, and the `<M-o>` test fakes `vim.system` (the OS boundary). But `sdlc` still has no stateful fake and no live conformance check on `resolve --json`'s schema — each test hand-rolls a one-shot response. #226 will inject through the same seam repeatedly; that is the moment a small stateful fake pays for itself.
- **ARCH-CONSTRAINTS — pass.** The keystroke path adds no blocking work; the unbounded-spawn concern is recorded with a real Done-when in #226 rather than waved off.
- **ARCH-SECURE — flag.** Provenance (transcript vs config) is the right axis and is stated in the code, not just the plan. Two gaps: the refusal path crashes rather than degrading (C2), and the enumeration is memorised rather than enforced (C3).
- **ARCH-ORDER — pass.** Replacing `true`-means-two-things with `"opened"|"none"|"failed"` is the principle applied exactly; #226 writes down the interleavings (double press, completion after the user moves) rather than leaving them emergent.

## 7. Plan revision recommendations

- **`## Revisions` — Core concepts, `expand_path` reclassified.** Move the row from *Pure entities* to *Integration points* (`wraps: vim.fn.expand — environment, filesystem glob, and, absent the guard, subprocess`), with the reason: its tests are integration and cannot run without the Neovim runtime and a real filesystem.
- **`## Revisions` — the untrusted-path sweep is incomplete.** Record that the ten routed sinks are the *chat-navigation* consumers only, that `outline.lua` (4 sites, including a 4th copy of `resolve_path`) and `exporter.lua` (4 sites) still expand transcript-derived paths, and that the durable fix is one shared guarded `resolve_path` plus an arch test over `vim.fn.expand(<variable>)` in `chat_parser`-consuming modules — not another hand-maintained list.
- **`## Revisions` — the refusal contract.** State that `resolve_chat_path` may now return `nil`, list its consumers, and record that `open_branch_ref`/`try_open_inline_branch_link` must take their `"failed"` exit rather than indexing it.
- **`## Log`** — the `@@` parser narrowing for `@`-containing paths belongs in the divergence record; it is a fifth resolved difference and currently only visible in the diff.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      The unified file arm goes through open_buf, so the chat path gains file-tracking and window reuse; focus_other_split remains only for the netrw call site.
  - id: BR-2
    disposition: addressed
    note: |
      Plan row now carries the grep-derived list (13 hits / 7 files) and keybinding_agreement + review_menu specs are updated; both suites pass.
  - id: BR-3
    disposition: addressed
    note: |
      opts.runner threaded at artifact_ref.lua:233; artifact_ref_spec asserts the real argv, and the M-o test fakes vim.system rather than the module.
  - id: BR-4
    disposition: addressed
    note: |
      The three named sites plus seven more are routed through helper.expand_path; the residual class outside the chat-navigation modules is raised new (see C3).
  - id: BR-5
    disposition: addressed
    note: |
      Mutation-verified independently: `if true and (...)` at init.lua:4387 reddens exactly the new negative test.
  - id: BR-6
    disposition: addressed
    note: |
      open_buf calls focus_other_split; the inline block is gone. Unpinned by any test — noted under coverage, not re-raised.
  - id: BR-7
    disposition: addressed
    note: |
      helper.glob_base plus an IO-free unit spec; process_directory_pattern now derives from it.
  - id: BR-8
    disposition: addressed
    note: |
      The deleted row inverts, and I confirmed the matcher fires on a control symbol and stays silent on open_chat_reference.
  - id: BR-9
    disposition: addressed
    note: |
      <M-o> added to the markdown mapped list; the journal-sidecar assertion correctly moved to <M-s>.
  - id: BR-10
    disposition: addressed
    note: |
      Deferred deliberately and filed as parley.nvim#226 with a Done-when that reuses the runner seam; recorded in the issue Revisions.
  - id: BR-11
    disposition: addressed
    note: |
      The chain-order flip is now recorded in the issue's Revisions with the reason the inline link is the better match.
  - id: BR-12
    disposition: addressed
    note: |
      No workshop/parley paths appear in the pinned range; the transcripts are untracked again.
findings:
  - id: new
    severity: Critical
    family: doc-consumer-enumeration
    title: |
      make test is RED at HEAD — two new spec files are unrouted in atlas/traceability.yaml
    detail: |
      tests/arch/single_source_sweeps_spec.lua "every spec this branch ADDED is routed somewhere"
      fails on tests/integration/untrusted_path_spec.lua and tests/unit/glob_base_spec.lua. It is
      the only failure in a 356-file run (lint clean), and this round's own fix commit caused it.
      2nd in family, so the RULE: the branch adds artifacts, the registry that indexes them must be
      dispositioned against a mechanical enumeration — and here the repo ALREADY encodes that
      enumeration as an arch guard. So the enforcing rule is narrower and cheaper than a checklist:
      `make test` must be green at the moment the boundary review is REQUESTED, not merely at the
      moment the previous round's ledger was written. The prior ledger's "full suite clean at HEAD"
      described a window three commits back.
  - id: new
    severity: Critical
    family: guard-nil-contract-unswept
    title: |
      The BR-4 guard makes resolve_chat_path return nil; two callers index it and crash
    detail: |
      helper.lua:264 states the contract as "callers treat nil as not usable and take their
      existing not-found branch". init.lua:4246 and init.lua:3292 instead raise "attempt to index
      local 'expanded' (a nil value)" — reproduced through the real M.cmd.OpenFileUnderCursor on a
      backticked 🌿: line and on a backticked inline [🌿:…](file). The security property holds (no
      marker file), the degrade-visibly property does not. It shipped because untrusted_path_spec
      wraps the call in a bare pcall and asserts only the absent marker, so the test cannot
      distinguish a clean refusal from a crash. Sweep the other resolve_chat_path consumers
      (init.lua:3325, :3348, :3445; exporter.lua:151, :180; highlighter.lua:66) and make each arm
      assert ok == true plus the expected warning.
  - id: new
    severity: Critical
    family: untrusted-path-expansion
    title: |
      outline.lua still executes backticks from a transcript-derived branch path — confirmed end-to-end
    detail: |
      2nd in family, so the ask is the RULE, not this site: a path parsed out of buffer text —
      anything derived from chat_parser output (branches[].path, parent_link.path, @@ refs, inline
      links) — may be expanded only via helper.expand_path, and the enumeration is
      `vim.fn.expand(<variable>)` in every module that consumes chat_parser output, enforced as an
      arch test with an explicit config-derived allowlist rather than a memorised list. Measured:
      BR-4 named 3 sites, the fix found 10, and the residue is outline.lua:207/221/243/320 and
      exporter.lua:117/128/140/163. outline.lua:205 and chat_respond.lua:176 were byte-identical
      5-line resolve_path functions; the round guarded one and not the other — a 4th copy of the
      same function, which is why instance-fixing keeps missing (ARCH-DRY + ARCH-PURPOSE).
      Reproduced: a chat with "🌿: ~/`touch <marker>`.md: Child" driven through
      outline._build_tree_outline_items creates the marker. Reachable from <M-t>.
  - id: new
    severity: Important
    family: pure-label-vs-io
    title: |
      Core-concepts table calls expand_path PURE; it expands the environment, globs the fs, and its tests are integration
    detail: |
      workshop/issues/000225-open-link-alt-o.md:135 lists expand_path under "Pure entities", but
      helper.lua:270 calls vim.fn.expand and its only tests live in
      tests/integration/untrusted_path_spec.lua, needing a real Neovim and a real filesystem to
      observe the marker. glob_base in the row above IS pure and its spec proves it. Move the row
      to Integration points (wraps: vim.fn.expand) with a ## Revisions entry.
  - id: new
    severity: Important
    family: guard-nil-contract-unswept
    title: |
      prepare_dir returns the unusable input on refusal while every sibling sink returns nil
    detail: |
      helper.lua:611-615 returns odir (the backtick string) where read_file_content returns nil,
      is_directory false, find_files {} and expand_path nil. init.lua:826 assigns that return
      straight into M.config[k]. Unreachable today because that call site is config-derived, but it
      is inconsistent error handling introduced by this diff.
  - id: new
    severity: Minor
    family: divergence-not-pinned
    title: |
      The @@ parser adopted markdown's [^@]+ form, narrowing chat for @-containing paths, unrecorded
    detail: |
      init.lua:4358 replaces chat's greedy ^@@(.+)@@ with ^@@%s*([^@]+)@@, so @@/tmp/a@b/c.md@@ now
      falls to ^@@(.+)$ and carries a trailing @@ into the path, exiting "failed" instead of
      opening. It is a fifth resolved divergence and belongs in the Spec's table or the Log rather
      than only in the diff.
  - id: new
    severity: Minor
    family: duplicate-registry-entry-one-action
    title: |
      review_menu(<M-s>) and skill_picker(<C-g>s) are two ids and two config keys for one action
    detail: |
      keybinding_registry.lua:750 (markdown scope, config_key review_shortcut_menu) and :256 (global
      scope, config_key skill_shortcut) both call parley.skill_picker.open(). Now that the key is
      <M-s>, they are precisely the alt/<C-g> pair that open_file models as ONE entry with
      default_key = { "<M-o>", "<C-g>o" }. Pre-existing; the rename made it adjacent (ARCH-DRY).
  - id: new
    severity: Minor
    family: doc-consumer-enumeration
    title: |
      atlas quotes a diagnostic the @@ arm no longer emits
    detail: |
      atlas/context/file_references.md:52 justifies the no-fall-through rule with "Chat file not
      found: …", but the @@ arm now warns "File not found: …" (init.lua:4432). The 🌿: arm still
      uses the old wording, so the doc is half-right.
```
