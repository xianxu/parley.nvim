---
id: 000230
status: done
deps: []
github_issue:
created: 2026-09-10
updated: 2026-10-15
estimate_hours:
card_mirror: '7e1859d7c99076fc4b7e880460f14ec52793e1d1' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-15T19:35:17-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: full, provenance: inferred}
actual_hours: 0.66
---

# a later provider filter term is silently starved by the per-provider cap

## Problem

The operator added `gpt-6` to the codex filter and it never appeared in the
cliproxyapi model picker:

```lua
providers = { "claude:opus,sonnet,fable", "codex:gpt-5,gpt-6", "antigravity" },
```

**It is not a discovery problem.** The model is in cliproxy's catalog
(`~/.local/share/nvim/parley/cliproxy/catalog.json`, fetched 2026-09-10 10:05) as
`gpt-6-astra`, with `owner: "openai"` — the **same owner** as every `gpt-5.x`, so
it is not a provider-mapping miss either. The term matches it. It is dropped
afterwards.

### Measured — `M.curate` on the real catalog

```
codex:gpt-5,gpt-6  ->  gpt-5.6-luna, gpt-5.6-sol, gpt-5.6-terra     ← gpt-6-astra absent
codex:gpt-6,gpt-5  ->  gpt-6-astra,  gpt-5.6-luna, gpt-5.6-sol      ← present
```

Same terms, different order, different result.

### Mechanism — `cliproxy_catalog.lua`, `M.curate`

```lua
local per = opts.per_provider or 3
...
for _, term in ipairs(#parsed.terms > 0 and parsed.terms or { "" }) do
    for _, m in ipairs(pool) do
        if #taken >= per then break end
        if not seen[m.series] and (term == "" or matches(m, term)) then
            seen[m.series] = true
            taken[#taken + 1] = m
        end
    end
end
```

Terms are processed **in config order**, and the slot cap is shared across all of
them. `gpt-5` matches **five** distinct series in the catalog (`gpt`, `gpt-sol`,
`gpt-luna`, `gpt-terra`, `gpt-codex-spark`), so it fills all three slots on its
own. By the time `gpt-6` is considered, `#taken >= per` and it contributes
nothing.

The behaviour is half-intended. The docstring says *"Term order is display
order, so the config expresses preference"* — and preference is a reasonable
reading. But preference plus a shared cap means **a later term can be dropped
entirely**, which is not preference, it is exclusion. The operator named two
terms and got one.

**And it is silent.** Nothing indicates `gpt-6` matched a model and was
discarded; it simply does not render, which reads exactly like "cliproxy does
not have it" and sent the investigation toward discovery.

### Workaround until fixed

Put the term you most want to see first: `"codex:gpt-6,gpt-5"`.

## Spec

**No limit unless you write one.** A search shows every matching series; `!N` is the
only way to hide anything. This makes the starvation in this issue impossible by
construction — a model can only disappear because the operator asked for it — rather
than patching the order in which a shared cap is consumed.

### Syntax

```lua
providers = { "claude:opus,sonnet,fable", "codex:gpt-5!3,gpt-6", "antigravity!2" },
```

**`!N` caps the search it is attached to.** One rule, two positions:

- on a term — `gpt-5!3` — at most 3 series from that term;
- on a bare provider — `antigravity!2` — at most 2 series from the provider. A bare
  provider *is* the search with the empty term, so this is the same rule, not a
  second meaning.

**No `!` means no limit** on that search. The global `per_provider` default is
**removed**, not repurposed as the default `N`: a hidden global cap is precisely what
caused this issue.

Why `!`: `*` is taken — catalog agent names end in it (`gpt-5.6-sol*`, the suffix
`cliproxy_catalog` appends) — and `:` already separates provider from terms.

### Semantics that must hold

- **"All" means all *series*, not all ids.** One row per series, the newest, exactly
  as today. Otherwise every superseded point release lists beside its successor.
- **Series de-duplication stays global across a provider's terms.** A model never
  renders twice when two terms match it (`gpt` and `gpt-5`). An earlier term can still
  claim a shared series first; it can no longer consume another term's *slots* — that
  was the defect.
- **Term order still governs display order.** `gpt-5!3,gpt-6` lists the gpt-5 picks
  before gpt-6-astra.
- **Budgets are independent per search.** The provider's total is the sum of what its
  searches yield; there is no provider-level ceiling above them.
- **A term matching nothing is logged** — once per catalog refresh at the caller, not
  inside `curate`, which re-runs on every `<C-a>` toggle and background repaint and
  documents itself as side-effect-free (`ARCH-PURE`). Without this, a typo like
  `gtp-6` is indistinguishable from a model the provider does not offer.

### Parser

`parse_provider_spec` splits at the first colon, so today `antigravity!2` would parse
as a provider **named** `antigravity!2` — and an unknown provider contributes nothing,
so it would silently vanish. The `!N` suffix must be stripped from the provider half
as well as from each term. A malformed count (`gpt-5!`, `gpt-5!x`, `gpt-5!0`) should
be rejected loudly rather than read as "no limit", since that is the permissive
reading of an error.

### Measured cost of "no limit" on the current catalog

One row per series, no caps:

| search | series |
|---|---|
| `opus`, `sonnet`, `fable` | 1 each |
| `gpt-5` | **5** |
| `gpt-6` | 1 |
| `antigravity` (bare) | **8** |
| **total** | **17** of 41 catalog models |

So the uncapped default is bounded in practice by series de-duplication. The two
places `!N` earns its keep are exactly the broad searches — `gpt-5` and a bare
provider. Specific terms rarely need it: the operator's first draft
`"claude:opus!2,sonnet!2,fable!2"` caps searches that each yield one series, so the
`!2`s are no-ops. The recommended config above renders **9** rows.

## Done when

- `codex:gpt-5,gpt-6` against the current catalog includes `gpt-6-astra` — the measured
  failing case, as a test that fails against today's `curate`.
- A search with no `!` returns every matching series; the 17-row count above is
  reproduced from a catalog fixture.
- `!N` on a term caps that term; `!N` on a bare provider caps the provider; both
  asserted, including `antigravity!2` resolving to provider `antigravity`.
- The recommended config renders exactly its 9 rows, in term order.
- A model matched by two terms renders once.
- Malformed counts are rejected with a message naming the spec.
- A term matching nothing is logged once per refresh; `curate` stays side-effect-free.
- `per_provider` is gone from the code path and from any documentation or default
  config that mentions it.

## Core concepts

| Entity | Kind | Status | Location | Responsibility |
| --- | --- | --- | --- | --- |
| `parse_provider_spec` | PURE | modified | `lua/parley/cliproxy_catalog.lua` | Parses `!N` on each term and on a bare provider; rejects a malformed count with an error naming the spec. |
| `curate` | PURE | modified | `lua/parley/cliproxy_catalog.lua` | Per-search budgets, no limit without `!N`, global series de-dup, term order kept; no `per_provider`. |
| `_select` | PURE | new | `lua/parley/cliproxy_catalog.lua` | One parsed spec's rows in display order; the selection both `curate` and `diagnose` use. |
| `_operator_specs` | PURE | new | `lua/parley/agent_picker.lua` | The configured specs that are not verbatim shipped defaults; what the picker diagnoses (BR-1). |
| `diagnose` | PURE | new | `lua/parley/cliproxy_catalog.lua` | The specs that are malformed and the terms that match nothing, for a caller to report. |
| `agent_picker` | INTEGRATION | modified | `lua/parley/agent_picker.lua` | Logs `diagnose` once per catalog refresh; stops passing `per_provider`. |
| `live_models_config_spec` | INTEGRATION | new | `tests/integration/live_models_config_spec.lua` | The one setup notice for a leftover `per_provider`. |
| `cliproxy_catalog_230.json` | INTEGRATION | new | `tests/fixtures/cliproxy_catalog_230.json` | The v1 fixture plus `gpt-6-astra` (owner openai): the shape #230 was measured on. |

## Plan

Measurement (2026-10-15, :3):
- #247 already made the cap per term (`curate` counts `term_count`), so the measured starvation is gone: on a catalog with `gpt-6-astra`, `codex:gpt-5,gpt-6` includes it today. That Done-when bullet becomes a guard test, not a red one.
- The approved Spec is otherwise unmet. A hidden default of 3 per term remains: `gpt-5` matches 6 series in the v1 fixture and 3 are hidden silently. There is no `!N`, `antigravity!2` still parses as a provider named `antigravity!2` (contributes nothing), no malformed-count rejection, no log for a term matching nothing, and `per_provider` remains in config.lua, cliproxy_catalog.lua, agent_picker.lua, the atlas and 6 specs.
- The catalog the 17-row count came from was overwritten (see #342). On the v1 fixture plus `gpt-6-astra`, the uncapped searches yield opus 1, sonnet 1, fable 1, gpt-5 6, gpt-6 1 and bare antigravity 12 = **22**. The recommended config (`claude:opus,sonnet,fable`, `codex:gpt-5!3,gpt-6`, `antigravity!2`) still yields exactly **9**.

- [x] Fixture `cliproxy_catalog_230.json`; guard test for the measured case; red tests per Done-when (uncapped search returns every series, 22; `!N` on a term and on a bare provider; the 9-row recommended config in term order; a model matched by two terms renders once).
- [x] `parse_provider_spec`: strip and validate `!N` on terms and on the provider half (`antigravity!2` gives provider `antigravity`, cap 2). `gpt-5!`, `gpt-5!x` and `gpt-5!0` return an error naming the spec. In `curate` a malformed spec contributes nothing, never "no limit".
- [x] `curate`: per-search budget from `!N`, no limit without it, no provider ceiling, global series de-dup, term order. `per_provider` removed.
- [x] `diagnose(models, providers)` (pure): malformed specs and terms matching nothing. agent_picker logs it when a catalog fetch resolves (once per refresh, not per repaint or toggle). An empty catalog reports nothing (that is the logged-out case, already shown).
- [x] Remove `per_provider` from config defaults, the atlas and specs. The default `live_models.providers` writes explicit `!N` where the old hidden 3 mattered (`codex:gpt-6,gpt-5!3`, `gemini!3`), so the default view keeps its size. An operator config still setting `per_provider` gets one notice at setup: removed, write `!N`. Without it the option would be silently ignored, the same silence class.
- [x] Atlas providers/cliproxy-managed: the `!N` grammar and the logging.
- [x] Verify: catalog, picker and options specs, then the full suite.

## Log

### 2026-09-10

Operator report: `gpt-6` absent from the picker despite being in the filter.

Diagnosed in three measurements rather than one assumption. First, whether the
model exists at all — it does, in the catalog, which ruled out discovery. Then
whether its `owner` differed from the gpt-5 family — it does not, which ruled out
provider mapping. Then running `curate` itself on the real catalog in both term
orders, which located the cap. The symptom (a model "not showing up") pointed
confidently at discovery, and the cause was two layers downstream of it.

### 2026-10-15 (:3)
- 2026-10-15: closed — Post-close delta only: moved _providers_without_models annotations back onto their function (superseded_comment_spec 9/0, the guard the merge suite tripped) and added _select/_operator_specs Core-concepts rows (single_source_sweeps 25/0). picker_items 57/0, lint clean. Full suite on 296d98f8 clean apart from the Core-concepts rows, now fixed. (fixed-then-ship); review verdict: SHIP
- 2026-10-15: closed — Prior evidence stands (19/77 red vs main, 77/0 green; full suite on e0c389cc, only starter_config default strings, fixed 7/0). BR-1: picker diagnoses only operator-written specs; defaults plus a typo against a catalog lacking gpt-6 and fable gives exactly the typo warning; red without the filter (56/1), green 57/0. Minors: diagnose reuses _select; docs state provider cap beside terms is rejected. Lint clean.; review verdict: SHIP
- 2026-10-15: flow upgraded quick → full — 151 added lines in code files (limit 100); an earlier round of this close already ran the full review

- Red against main's `cliproxy_catalog.lua` (temporary copy, restored): 19 of the 77 catalog unit cases fail. These cover the `!N` parse, the malformed rejection naming the spec, the uncapped renders (22 total; `codex:gpt-5` 6), the recommended config as exactly its 9 rows in term order, single rendering under two terms, and `diagnose`. The reported case (`codex:gpt-5,gpt-6` includes `gpt-6-astra`) passes on main, being #247's fix, and is kept as a guard. Green: 77/0.
- Rows that pinned the hidden cap now write it (`claude!3`, `antigravity!3`, `antigravity:pro!3,flash!3`, `codex!3`), keeping their renders. The uncapped forms are pinned beside them (`claude` now 4 with haiku; `antigravity:pro,flash` 9).
- Picker: login rows read `antigravity!2` as antigravity and skip a malformed spec. The refresh logs each diagnosis once (a typo'd term and a malformed count, against a non-empty catalog). picker_items 56/0, agent_picker_options 6/0, integration cliproxy_catalog 22/0. Only one picker case relied on the hidden cap ("expanding bypasses curation"); it now writes `claude!1`.
- Setup notice: `live_models_config_spec` 2/0, and red with the notice disabled (1/1).
- Defaults: `codex:gpt-6,gpt-5!3` and `gemini!3`, per the TL decision, keep the default view its prior size. `per_provider` is gone from config, code, atlas and specs, except the notice that names it.
- Lint clean (737 files).
- Full suite on e0c389cc: one failure, starter_config_spec "retains product search terms". It pinned the old default strings; this issue deliberately replaced them with the written caps. Updated the expectation; 7/0, lint clean. Every other file passed.
- Close review round 1. BR-1 (Important): the shipped default `codex:gpt-6,gpt-5!3` made diagnose warn on every refresh for any catalog without gpt-6, and `claude:opus,sonnet,fable` does the same where fable is absent. The class is shipped defaults naming lines an account may lack. Fix: the picker diagnoses only `_operator_specs`, the configured specs that are not verbatim shipped defaults; diagnose stays pure. Regression: defaults plus an operator typo against a catalog with neither gpt-6 nor fable gives exactly the typo's warning (and asserts the fixture would have warned for the defaults). Red with the filter removed (56/1), green 57/0.
- Minors, same round: diagnose reuses `_select` (one search, cap 1) instead of its own match loop; the parser docstring, config comment and atlas state that a provider cap beside terms is rejected. Catalog 77/0, lint clean.
- Lesson: a pure diagnostic over config needs the provenance of each entry. A shipped default and an operator's typo look the same to it.
- Merge local suite on 4011859e failed tests/arch/superseded_comment_spec: the round-2 Minor (an annotation block separated from `_providers_without_models` by the inserted `_operator_specs`) is enforced by an existing guard. My last full suite predated the BR-1 commit. Moved the annotations back to their function: superseded_comment 9/0, picker_items 57/0, lint clean.
- Full suite on 296d98f8: one failure, single_source_sweeps "Core-concepts tables name every entity THIS issue added" (`_operator_specs`, `_select` missing). Added both rows; the guard passes 25/0. Every other file passed, lint clean.

## Revisions

### 2026-09-10 — design replaced: per-search budgets with `!N`, no default cap

**Reason.** The operator proposed a `term!N` syntax and a per-search limit; asked
whether a search without `!` should show every match, and the measurement above showed
the uncapped default is bounded (17 rows for the operator's terms). Adopted because it
removes the defect instead of routing around it.

**Delta — superseded design.** The first Spec kept a shared per-provider cap and fixed
starvation with a **two-pass curate**: one row per term first, then fill remaining
slots by preference, with the effective cap raised to `max(per_provider, #terms)` so
more terms than slots could not starve either. Replaced because:

- it needed an extra rule precisely for the case where terms outnumber the cap, and a
  design that needs a special case for its own limit is keeping the limit that caused
  the bug;
- it still let a *global, unwritten* number decide what the operator sees — the
  property that made `gpt-6` vanish silently in the first place;
- per-search budgets give the operator explicit, local control and make silent
  omission impossible, which the two-pass design only made less likely.

The Problem and measurements are unchanged; only Spec, Done when, and Plan were
rewritten.

### 2026-10-15 — measured against today's code; counts restated

**Reason.** #247 made the cap per term after this issue was filed, and the catalog behind the 17-row count was overwritten (#342).

**Delta.** The measured failing case is now a guard test, since it passes today. The uncapped total is 22 on `tests/fixtures/cliproxy_catalog_230.json` (v1 fixture plus `gpt-6-astra`) instead of 17; the 9-row recommended config is unchanged. Added: a one-time setup notice for a leftover `per_provider`, and explicit `!N` in the shipped defaults so the default view keeps its size.
