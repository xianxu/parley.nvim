# Boundary Review — parley.nvim#396 (whole-issue close)

| field | value |
|-------|-------|
| issue | 396 — Repair issue vocabulary provenance |
| repo | parley.nvim |
| issue file | workshop/issues/000396-issue-vocabulary-provenance.md |
| boundary | whole-issue close |
| milestone | — |
| window | 67a33bc5dbb734ee2d384263fdeba70cbe91aa33..ef2039131025cd0c480c06ecf857cff3b5ff5bbc |
| command | sdlc close --issue 396 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-19T00:37:07-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned change correctly refreshes the canonical vocabulary and matching provenance digest. No blocking defects found. The exact-head GitHub merge-check passed without workflow or gate changes.

```findings
{}
```

1. **Strengths**
   - The shipped JSON is byte-identical to the canonical exporter, including `flake_tests`; its SHA-256 matches the sidecar.
   - Canonical comparison fails for BASE and passes for HEAD; repeated exports produce identical bytes.
   - Card consumers derive field names from the vocabulary (`lua/parley/issue_cards.lua:172`), so the added field reaches existing consumers without another maintained list.
   - The runtime artifact and existing ship declaration remain intact.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage notes**
   - Independently ran all 23 focused vocabulary, drift, and fresh-clone tests: passed.
   - `git diff --check` passed.
   - [Exact-head merge-check](https://github.com/xianxu/parley.nvim/actions/runs/39216876210/job/117942685138) passed.
   - Inspected cold-compilation logs and compiler ownership logic; did not independently rerun full weave compilation.

6. **Architectural notes**
   - **ARCH-DRY — Pass:** retains the canonical producer and existing declaration.
   - **ARCH-PURE — Pass:** introduces no business logic or IO coupling.
   - **ARCH-PURPOSE — Pass:** repairs stale shipped bytes; dynamic consumers derive the added field.
   - **ARCH-EVOLVE — Pass:** additive metadata change; existing fields and format version remain unchanged.
   - Existing atlas documentation covers vocabulary-derived fields. This refresh introduces no new Parley command, configuration, or architectural flow requiring README/atlas changes.

7. **Plan revision recommendations:** None required.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"1d1f8381-677b-4b98-af97-b99d714d2244","repository":"github.com/xianxu/parley.nvim","issue_id":"000396","recipe":"small-diff-review","round":1,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/1726283d67c96f58","reviewed_head":"ef2039131025cd0c480c06ecf857cff3b5ff5bbc","slot":"parley.nvim:1","requested_at":"2026-10-19T07:35:06.458651Z"},"phase":"finished","pid":72066,"started_at":"2026-10-19T07:35:06.689846Z","finished_at":"2026-10-19T07:37:05.880132Z","session_id":"01a15315-e817-7d41-9fbe-f4bd333f3bfc","outcome":"returned"}] -->
