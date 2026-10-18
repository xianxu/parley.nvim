# Boundary Review — parley.nvim#267 (whole-issue close)

| field | value |
|-------|-------|
| issue | 267 — tool_resources_spec dies silently under parallel load in its JIT-off call-hook case |
| repo | parley.nvim |
| issue file | workshop/issues/000267-tool-resources-spec-dies-silently-under-parallel-load-in-its-jit-off-call-hook-case.md |
| boundary | whole-issue close |
| milestone | — |
| window | 6e571cf4a8f0c46687f0329c0c3721f586748742..85d1284c76f86011cb0c0a11d3a8c6c6d3e64619 |
| command | sdlc close --issue 267 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-17T23:41:38-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned change satisfies the issue’s acceptance criteria. Production protection preserves global JIT state, while the harness handles affected allocators separately. Independent stress runs and negative controls passed; no blocking findings remain.

```findings
{}
```

1. **Strengths**

   - One allocator predicate serves production, harness tuning, and runtime selection (`lua/parley/jit_tuning.lua:17`).
   - Chunk validation prevents accidental global JIT disabling (`lua/parley/jit_tuning.lua:29`).
   - Real-VM tests verify unrelated code still compiles and storage reclamation exercises compiled sequence code.
   - Atlas documentation explains the differing production and harness scopes.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage notes**

   - Policy, sequence, and resource specs passed on both installed runtimes: 112 cases total.
   - Resource stress passed **64/64 per runtime**, with 16 concurrent workers.
   - Removing the sequence guard in a disposable copy failed the new regression: 61,011 document trace starts instead of zero.
   - A superlinear pump mutation failed the unchanged bounded-call assertion.
   - Inspected both preserved full-suite logs: matching recorded hashes, 469 passing files each, zero failure blocks. Full suites were not rerun during review.
   - Diff whitespace checks passed; tracked checkout remains unchanged.

6. **Architectural notes**

   - **ARCH-DRY — pass:** shared policy; all 23 protected modules use the helper.
   - **ARCH-PURE — pass:** deterministic predicates remain separate from the small compiler-effect adapter.
   - **ARCH-PURPOSE — pass:** protection covers the enumerated pipeline while preserving unrelated compilation and the active-JIT storage oracle.
   - Atlas updates cover the new internal surface. No new user command or configuration requires a README change.

7. **Plan revision recommendations:** None; existing revisions describe the delivered scope.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"9a799da5-9b10-449c-aeac-74acb0e531b7","repository":"github.com/xianxu/parley.nvim","issue_id":"000267","recipe":"small-diff-review","round":1,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/aa0bb2d15a6956ce","reviewed_head":"85d1284c76f86011cb0c0a11d3a8c6c6d3e64619","slot":"parley.nvim:1","requested_at":"2026-10-18T06:38:43.396731Z"},"phase":"finished","pid":60754,"started_at":"2026-10-18T06:38:43.500274Z","finished_at":"2026-10-18T06:41:37.404726Z","session_id":"01a14dbb-ec17-7c32-bdcc-f040c0403a65","outcome":"returned"}] -->
