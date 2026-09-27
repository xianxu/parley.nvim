---
id: 000230
status: open
created: 2026-09-10
updated: 2026-09-10
estimate_hours:
github_issue:
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
