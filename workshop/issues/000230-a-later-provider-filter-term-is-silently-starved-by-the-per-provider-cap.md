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

**Every term the operator names contributes at least one row, whenever any model
matches it.** Naming a term is an explicit request to see it; order should decide
*priority among the remaining slots and display order*, not whether a term is
represented at all.

Concretely: a first pass takes the best match per term (in term order, still one
per series), then later passes fill the remaining slots by preference as today.
That keeps "config expresses preference" for ordering and fill, and removes the
starvation.

Two edge cases to decide explicitly rather than leave to the loop:

- **More terms than `per_provider`.** A cap of 3 cannot give 4 terms a slot each.
  Recommended: the effective cap is `max(per_provider, #terms)` — the operator
  asked for four families; showing three is the same bug in a larger config.
- **A term matching nothing.** Today indistinguishable from "starved". Recommended:
  log it (once per catalog refresh, not per repaint — `curate` runs on every
  `<C-a>` toggle and background repaint), so a typo like `gtp-6` is catchable.

Keep `curate` pure — its own comment records that it is side-effect-free and
re-run on every repaint (`ARCH-PURE`); any logging belongs at the caller.

## Done when

- `codex:gpt-5,gpt-6` against the current catalog includes `gpt-6-astra` — the
  measured failing case, as a test that fails against today's `curate`.
- Order still governs display and fill: `gpt-5,gpt-6` lists the gpt-5 pick first.
- Four terms with `per_provider = 3` show four rows (or the chosen rule, stated).
- A term that matches nothing is logged, and a starved term can no longer occur.
- `curate` remains side-effect-free.

## Plan

- [ ] Test the measured case against a fixture of the real catalog (red first).
- [ ] Two-pass curate: one per term, then fill by preference.
- [ ] Decide and implement the more-terms-than-cap rule.
- [ ] Caller-side, once-per-refresh log for terms that match nothing.

## Log

### 2026-09-10

Operator report: `gpt-6` absent from the picker despite being in the filter.

Diagnosed in three measurements rather than one assumption. First, whether the
model exists at all — it does, in the catalog, which ruled out discovery. Then
whether its `owner` differed from the gpt-5 family — it does not, which ruled out
provider mapping. Then running `curate` itself on the real catalog in both term
orders, which located the cap. The symptom (a model "not showing up") pointed
confidently at discovery, and the cause was two layers downstream of it.
