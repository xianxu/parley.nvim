# Boundary Review — parley.nvim#294 (whole-issue close)

| field | value |
|-------|-------|
| issue | 294 — Heavy specs fail only under parallel make test (document_semantic, perf_document, document_fold_batches) |
| repo | parley.nvim |
| issue file | workshop/issues/000294-parallel-load-spec-failures.md |
| boundary | whole-issue close |
| milestone | — |
| window | a09307631295f188f73d7fce01780e0921f05cb5..bab752f6a8ff651dabda9fb01a92388a1c002b70 |
| command | sdlc close --issue 294 |
| reviewer | claude |
| timestamp | 2026-10-01T17:43:43-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: medium
```

The diagnosis is well supported by evidence. Each failing spec is classified in the Log with a captured cause. The fixes target each class rather than raising deadlines across the board. The Done-when evidence is recorded: 5 consecutive green `make test` runs, 0 FAIL and 0 DEADLINE. Two things keep this from SHIP:

- **A vacuous regression test.** The new `diag_display` "re-wraps" test still passes with the re-wrap fix removed. I checked this in a scratch copy. The fix is currently pinned only by the older `:232` test, and only on Neovim 0.12.
- **A user-facing change not mentioned anywhere.** Treesitter is now stopped in every chat buffer, in production code. Users lose treesitter features in chats, and there is no opt-out and no docs.

Neither needs a redesign. Both are cheap to fix.

**1. Strengths**
- `tests/helpers/reachability.lua` sweeps the whole class. All 8 weak-reference probes now go through it. `grep collectgarbage` finds only `document_sequence_spec`, which is the documented deliberate exception. **ARCH-PURPOSE: pass.**
- `jit_tuning.lua` is the only place that decides the version rule. `scripts/test-nvim.sh` asks it rather than restating the version. **ARCH-DRY: pass.**
- `load_factor`, `has_mcode_fix` and `options` are pure functions with unit tests that cover the boundaries: exactly at `MCODE_FIX`, one below it, zero CPUs, and the cap. `apply` is a thin IO shell around them. **ARCH-PURE: pass.**
- Two tests fail without their fixes, both checked by reverting in a scratch copy:
  - The `shown`-token guard is pinned by the "does not bring back a display hidden" test.
  - The original `review_diag_display_spec:239` fails on 0.12 without the re-wrap.
- Turning a silent plenary kill into a named `DEADLINE:` line, and adding wall time to PASS/FAIL lines, directly fixes the "no assertion output" problem from #293.

**2. Critical findings**
None.

**3. Important findings**
- **The new re-wrap test passes without the fix** (`tests/integration/review_diag_display_spec.lua:267`). I removed the scheduled re-wrap block from `diag_display.lua:338-346`, ran on 0.12.5, and "re-wraps once a sign column opened in the same update" still passed. Setting `signcolumn` from outside apparently reaches a correct width by another path. Only the pre-existing test at `:239` went red, and only on 0.12.
  - The case this test was written for has no regression coverage on 0.11.
  - Fix sketch: reproduce the real ordering. Let the diagnostic signs handler open the column in the same `vim.diagnostic.set` (`signcolumn=auto`, signs enabled). Confirm the test goes red with the block removed.
  - Family in this window: this is the only new test that fails to pin its fix. `chat_treesitter_spec` and the hidden-display test both pin theirs.
- **Stopping treesitter in chat buffers is an undeclared user-facing change** (`lua/parley/init.lua:2684-2692`).
  - Users who enabled treesitter markdown highlighting on 0.11 (for example through nvim-treesitter) lose it in chats. That includes fenced-code injection highlighting and conceal.
  - `highlighter.lua` was written to coexist with treesitter: see the `priority = 200` comment at :1187 and the `@markup.strikethrough` handling at :741.
  - There is no config opt-out and no README note, and the change was motivated by test runtime.
  - Fix sketch: add a config key (default stop, documented in README), or limit the stop to when the ftplugin started treesitter. Add a `## Revisions` note that this is a product change.

**4. Minor findings**
- The deferred re-wrap renders `vim.diagnostic.get(bufnr, …)` rather than the `diagnostics` captured in `show`, which `vim.diagnostic` had already filtered. This matches `refresh`, but the token already guarantees that the captured list is current.
- `PARLEY_TEST_NVIM` only works if the binary is named `nvim`, because only its directory is prepended to PATH. `nvim-0.12` or similar would be silently ignored.
- `TOOLING.md` doesn't mention `PARLEY_TEST_NVIM` or `PARLEY_TEST_JITSTAT=1`. They are documented only in atlas.
- The `DEADLINE` timer fires at the same tick as plenary's own wait timeout. A child that exits right at the deadline can still be reported as "killed". In plenary's parallel path the child is orphaned, not SIGTERMed, so the word "killed" is loose.
- `test-nvim.sh` warns about an old LuaJIT on every platform, though the risk is specific to arm64 macOS. The second warning line says so, so this is fine.

**5. Test coverage notes**
- The `spell_source` move to `buffer_edit` is covered by the existing single-undo test (`spell_source_spec.lua:88`) and by `buffer_mutation_spec`.
- `chat_treesitter_spec` covers both states: a chat, and markdown that isn't a chat. It also covers the FileType re-run.
- `load_factor` tests cover the 1x floor, exactly at ncpu, the midpoint, the cap, and divide-by-zero.
- Nothing pins `scripts/test-nvim.sh` candidate selection. That is acceptable for a dev script.

**6. Architectural notes**
- The thinnest margin left is `entity_delete_parity` at 41–42s against a 50s deadline. If the treesitter stop becomes configurable, that spec should pin the stop explicitly so the margin doesn't quietly come back.
- The `jit_tuning` gating is worth reusing if any non-test runtime ever wants the mcode tuning.

**7. Plan revision recommendations**
- Add a `## Revisions` entry noting the production change to chat buffers (the treesitter stop) and its user-visible effect, plus whatever opt-out is chosen.

```findings
findings:
  - id: new
    severity: Important
    family: regression-test-must-fail-without-fix
    title: |
      New diag_display re-wrap test passes with the re-wrap fix removed
    detail: |
      Reverting diag_display.lua:338-346 in a scratch copy on nvim 0.12.5 leaves "re-wraps once a sign column opened in the same update" green; only the pre-existing :239 test goes red (0.12 only). Rebuild the test so the signs handler opens the column in the same vim.diagnostic.set and confirm it fails without the fix. Only instance in this window.
  - id: new
    severity: Important
    family: user-facing-change-undeclared
    title: |
      Chat buffers now unconditionally stop treesitter, a user-visible change with no opt-out or docs
    detail: |
      init.lua:2684-2692 stops treesitter in every chat, so users with treesitter markdown on 0.11 lose fenced-code injection highlighting and conceal in chats; highlighter.lua (:741, :1187) was written to coexist with treesitter. Add a config key (documented in README) or stop only when the ftplugin started it, and record it in Revisions.
  - id: new
    severity: Minor
    family: rewrap-source-of-truth
    title: |
      Deferred re-wrap re-reads vim.diagnostic.get instead of the filtered diagnostics show received
    detail: |
      diag_display.lua:344; the token already guarantees the captured list is current.
  - id: new
    severity: Minor
    family: dev-docs-missing-env
    title: |
      PARLEY_TEST_NVIM and PARLEY_TEST_JITSTAT not in TOOLING.md; PARLEY_TEST_NVIM requires a binary named nvim
```

---

## Re-review — 2026-10-01T17:51:15-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 294 — Heavy specs fail only under parallel make test (document_semantic, perf_document, document_fold_batches) |
| repo | parley.nvim |
| issue file | workshop/issues/000294-parallel-load-spec-failures.md |
| boundary | whole-issue close |
| milestone | — |
| window | a09307631295f188f73d7fce01780e0921f05cb5..380831d8685885cc9563c832e12af018c73a53f1 |
| command | sdlc close --issue 294 |
| reviewer | claude |
| timestamp | 2026-10-01T17:51:15-07:00 |
| verdict | SHIP |

## Review

All prior findings check out. Writing up the verdict.

```verdict
verdict: SHIP
confidence: high
```

All four findings from round 1 are fixed, and I checked each fix by running the specs myself, not by reading the commit messages. I made two scratch copies of HEAD with `git archive`: one as-is, and one with the re-wrap block and the treesitter stop removed. I ran both on Neovim 0.11.7 and 0.12.5. The fixed copy passes on both versions. The reverted copy fails on both: "re-wraps once a sign column opened later…" fails on 0.11.7 and 0.12.5, and both chat_treesitter "stops" cases fail on both versions. A third mutation removed only the `shown[bufnr] == token` guard, and it turns "does not bring back a display hidden…" red on both versions. Every `__mode='v'` reachability probe under `tests/` now goes through `reachability.collect()`. The one exception is `document_sequence_spec`, which keeps its traces on purpose, so that Done-when clause holds. Nothing blocks SHIP.

**Strengths**
1. `diag_display.lua:27-29,63,279,335-346`: one token per display. Every clear and every BufWipeout retires it, so the deferred re-wrap can't bring back a hidden display, and the table never outgrows the set of displayed buffers.
2. `tests/helpers/jit_tuning.lua` is the only place that encodes the version rule. `scripts/test-nvim.sh` asks it instead of restating it (ARCH-DRY). Its pure functions take `version, arch, os` as arguments and have unit tests (ARCH-PURE).
3. `spec_runner.load_factor` is pure, capped and guarded against a zero CPU count, and the unit tests cover all three edges.
4. `reachability.collect()` fixes the whole JIT-anchoring class: all 8 probes now use it.
5. The regression cases start from `silent! only` and plant the late sign themselves, so they no longer depend on which order `pairs` runs the diagnostic handlers in. Both changes are recorded in lessons.md.

**Critical:** none.

**Important:** none.

**Minor**
- `scripts/test-nvim.sh:19-21`: `PARLEY_TEST_NVIM` isn't checked. A wrong path, or a binary not named `nvim`, puts a useless directory first on `PATH`, and the tests quietly run the system nvim. Checking it's executable with `[ -x ]` and the name with `basename = nvim`, and warning otherwise, would fix that. This is the only instance.

**Test coverage notes**
- Both Done-when clauses that name two Neovim versions are exercised on both. The `chat_treesitter = true` case covers the opt-out.
- No test covers the warning branch in `test-nvim.sh`. That's acceptable for a shell probe.
- `load_factor` has unit tests. The `DEADLINE:` message has none, which is fine for harness output.

**Architecture**
- ARCH-DRY passes: the version rule has one owner, and the probe collection is shared.
- ARCH-PURE passes: `load_factor`, `has_mcode_fix` and `options` are pure. The IO stays in `apply`, `install`, `run` and the shell script.
- ARCH-PURPOSE passes: every failing spec is classified and fixed by its class (the Log has the full table), and the reachability sweep is complete.

**Plan revisions:** none needed. The Revisions entry already records the growth in scope and the round-1 dispositions.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Verified by scratch revert of diag_display.lua:335-346 - the re-wrap case fails on 0.11.7 and 0.12.5, passes with the fix; token-guard mutation also red on both.
  - id: BR-2
    disposition: addressed
    note: |
      chat_treesitter config key (config.lua:315, default false) gates the stop at init.lua:2689; documented in atlas/ui/highlights.md (README defers config to atlas); opt-out case in chat_treesitter_spec passes.
  - id: BR-3
    disposition: addressed
    note: |
      diag_display.lua:345 now renders the diagnostics show received, guarded by the token.
  - id: BR-4
    disposition: addressed
    note: |
      TOOLING.md documents PARLEY_TEST_NVIM (including the binary-must-be-named-nvim constraint) and PARLEY_TEST_JITSTAT.
findings:
  - id: new
    severity: Minor
    family: dev-docs-missing-env
    title: |
      PARLEY_TEST_NVIM override is not validated; a bad path silently falls back to the PATH nvim
    detail: |
      scripts/test-nvim.sh:19-21 prints dirname without checking -x or basename=nvim; warn instead. Only instance in this window. Related to, not a repeat of, BR-4 (now documented); the rule is that an operator override is checked where it is read.
```
