# Boundary Review — parley.nvim#389 (whole-issue close)

| field | value |
|-------|-------|
| issue | 389 — Document mover skips pending side-doc links inside proposal markers |
| repo | parley.nvim |
| issue file | workshop/issues/000389-document-mover-skips-pending-side-doc-links-inside-proposal-markers.md |
| boundary | whole-issue close |
| milestone | — |
| window | 77f29ab3d6390c4f20aaa43bd13fab81c4878e5b..2e5e9b73518ef4d5f95051c1e43bcb37e9b710e2 |
| command | sdlc close --issue 389 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-18T12:54:52-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned change fulfills #389: pending proposal destinations move through the existing reference rewrite path while preserving marker bytes and code exclusions. No blocking defects found.

Done-when: current — the revision separates future workflow gates; the existing clauses still cover the implemented behavior.

```findings
{}
```

1. **Strengths**
   - Reuses destination validation and byte-span edits rather than adding a parallel rewrite path (`lua/parley/document_move_plan.lua:206`).
   - Tests both escape spellings, both labels, CRLF, fragments, idempotence, and excluded examples (`tests/unit/document_move_plan_spec.lua:274`).
   - Native migration verifies the index, folder, backlink, and resolving pending destination together (`tests/integration/document_move_spec.lua:530`).

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage:** Independently passed 51 unit and 78 integration cases, focused luacheck, and whitespace checks. Replacing the implementation with the base version in a disposable archive produced one unit and two integration failures, confirming meaningful regression coverage. Archive removed; checkout unchanged. Full suite not rerun.

6. **Architecture:** ARCH-DRY passes through shared scanning and editing. ARCH-PURE passes: recognition remains deterministic string processing. ARCH-PURPOSE passes: both supported marker labels reach the complete move flow. Atlas documentation matches the change; no new command, configuration, or keybinding requires a README update.

7. **Plan revision recommendations:** None.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"120c95c8-6676-4ad4-9280-e8986aa866ed","repository":"github.com/xianxu/parley.nvim","issue_id":"000389","recipe":"small-diff-review","round":1,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/ec1545e17a8153e5","reviewed_head":"2e5e9b73518ef4d5f95051c1e43bcb37e9b710e2","slot":"parley.nvim:2","requested_at":"2026-10-18T19:53:27.011618Z"},"phase":"finished","pid":71310,"started_at":"2026-10-18T19:53:27.116038Z","finished_at":"2026-10-18T19:54:51.609049Z","session_id":"01a15093-866f-7552-a0e3-cc1fdfe99843","outcome":"returned"}] -->
