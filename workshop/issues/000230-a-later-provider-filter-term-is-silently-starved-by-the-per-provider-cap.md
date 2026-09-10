---
id: 000230
status: open
deps: []
github_issue:
created: 2026-09-10
updated: 2026-09-10
estimate_hours:
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

## Plan

- [ ] Fixture: the current catalog. Red test for the measured failing case.
- [ ] `parse_provider_spec`: strip and validate `!N` on terms and on the bare provider.
- [ ] `curate`: per-search budgets, no provider ceiling, global series de-dup, term
      order preserved.
- [ ] Remove `per_provider`; sweep docs and defaults for it.
- [ ] Caller-side, once-per-refresh log for terms that match nothing.
- [ ] Tests per Done-when, including the 17-row and 9-row counts.

## Log

### 2026-09-10

Operator report: `gpt-6` absent from the picker despite being in the filter.

Diagnosed in three measurements rather than one assumption. First, whether the
model exists at all — it does, in the catalog, which ruled out discovery. Then
whether its `owner` differed from the gpt-5 family — it does not, which ruled out
provider mapping. Then running `curate` itself on the real catalog in both term
orders, which located the cap. The symptom (a model "not showing up") pointed
confidently at discovery, and the cause was two layers downstream of it.

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
