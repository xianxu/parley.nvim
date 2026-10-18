# Boundary Review — parley.nvim#388 (whole-issue close)

| field | value |
|-------|-------|
| issue | 388 — Scope the attention finder to the submitting Couch slot |
| repo | parley.nvim |
| issue file | workshop/issues/000388-scope-the-attention-finder-to-the-submitting-couch-slot.md |
| boundary | whole-issue close |
| milestone | — |
| window | 938aae45c6fff478e65364aadf21766e303b102b..5ddcb829a5655916d2769f889162701abd4e7009 |
| command | sdlc close --issue 388 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-18T12:14:25-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The implementation satisfies the issue’s slot-scoping contract while preserving the shared store and tracking lifecycle. The mapped suite passes on both Neovim runtimes. No blocking findings; one minor duplication merits cleanup.

Done-when: current — its clauses still cover submit origin, scoped/all views, legacy entries, outside-Couch behavior, side-doc inheritance, and shared tracking.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: single-source-receipt-parsing
    title: |
      ARCH-DRY: Couch receipt grammar is duplicated.
    detail: |
      The complete family is lua/parley/attention.lua:43 (message-ID extraction) and :67 (sender extraction). Both encode the same receipt structure independently. Extract one pure receipt parser returning ID and sender, retaining parse_message_id as a compatibility wrapper, so receipt-format changes cannot update only one field.
```

1. **Strengths**

   - Submit records use the receipt’s sender, independently of the routed recipient; both submission paths have regression assertions.
   - Pure model filtering includes legacy entries and preserves ordering.
   - Scope changes repaint the latest snapshot; integration coverage exercises late probes and the actual picker mapping.
   - Optional typed storage preserves backward compatibility. README and atlas document the new surface.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** Receipt-parser duplication described above.

5. **Test coverage:** `make test-spec SPEC=ui/attention_finder` passed all 191 cases on preferred and installed Neovim. Both runs reported no surviving test processes. `git diff --check` passed. The separately required recorded full-suite pass remains a landing gate; this review does not attest to its pending result.

6. **Architecture:** ARCH-DRY flagged only for receipt parsing. ARCH-PURE passes: membership and transitions remain pure, with injected integration seams. ARCH-PURPOSE passes: both submission consumers, scoped presentation, legacy compatibility, and shared tracking are covered.

7. **Plan revisions:** None required.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"c5e5467d-01dc-442b-8885-c14945e170b5","repository":"github.com/xianxu/parley.nvim","issue_id":"000388","recipe":"small-diff-review","round":1,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/6650dfef42f8e674","reviewed_head":"5ddcb829a5655916d2769f889162701abd4e7009","slot":"parley.nvim:1","requested_at":"2026-10-18T19:12:41.230424Z"},"phase":"finished","pid":74847,"started_at":"2026-10-18T19:12:41.422592Z","finished_at":"2026-10-18T19:14:25.159493Z","session_id":"01a1506e-33d4-7211-b312-fa7dc1aa5bc1","outcome":"returned"}] -->
