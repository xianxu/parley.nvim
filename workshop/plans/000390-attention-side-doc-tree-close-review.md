# Boundary Review — parley.nvim#390 (whole-issue close)

| field | value |
|-------|-------|
| issue | 390 — Show side-document trees in the attention finder |
| repo | parley.nvim |
| issue file | workshop/issues/000390-attention-side-doc-tree.md |
| boundary | whole-issue close |
| milestone | — |
| window | 04076256358d0a398f36be6201293559afa96b90..42956aba6b01b0b8232eaf6fc2ed864e6f2f18b8 |
| command | sdlc close --issue 390 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-18T15:32:25-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The implementation delivers normal tree ordering, indentation, ancestor search, and picker integration cleanly. The mapped test suite passes, and README/atlas updates are present. One blocking edge case remains: descendants of malformed cycles can become disconnected roots, causing child searches to lose their ancestor context.

Done-when: current — the existing clauses still cover tree rendering, malformed cycles, ancestor search, and picker behavior under the revised contract.

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: cycle-recovery-preserves-parentage
    title: |
      Cycle recovery detaches descendants whose entries precede the cycle
    detail: |
      lua/parley/attention_rows.lua:42 promotes every unvisited entry directly, including descendants of cycles. With input ordered leaf→a, a→b, b→a, layout emits leaf as a root, then a as another root with child b; searching leaf returns only leaf despite its listed ancestors being present. This contradicts ancestor retention and the Plan's one-root-per-component contract (ARCH-PURPOSE). The complete affected family is descendants preceding their cyclic ancestors: children of self-cycles, children of multi-node cycles, and nested descendant chains; direct pure-Lua checks reproduced respectively two, two, and three roots for single connected components. Resolve each remaining component to a deterministic cycle member before traversing its children, breaking only a cycle edge. Add regression cases for all three shapes, checking parentage, ancestor search, uniqueness, and traversal bounds.
```

1. **Strengths**
   
   - Layout and filtering remain pure; the picker receives one optional callback using its existing scorer.
   - The real-picker integration verifies nested search, physical parent-first order, selected-child opening, query retention, and late repaint.
   - README, atlas, and traceability changes document and route the new behavior.

2. **Critical findings**
   
   - The finding above originates at [attention_rows.lua:42](/Users/xianxu/Library/Caches/sdlc/review-checkouts/1bd5848e4d0ad76a/lua/parley/attention_rows.lua:42). Recovery must preserve non-cycle parent links while choosing a root within the cycle.

3. **Important findings**
   
   None.

4. **Minor findings**
   
   None.

5. **Test coverage notes**
   
   `make test-spec SPEC=ui/attention_finder` completed successfully. `git diff --check` passed. An independent pure-Lua 256-node chain check passed. Existing [cycle tests](/Users/xianxu/Library/Caches/sdlc/review-checkouts/1bd5848e4d0ad76a/tests/unit/attention_rows_spec.lua:62) cover bare cycles and self-parents, but omit their attached descendants—the failing family above. Branch-specific architecture checks reported pending because this checkout is detached.

6. **Architectural notes**
   
   - **ARCH-DRY: pass.** Scoring is reused; no duplicate query grammar was introduced.
   - **ARCH-PURE: pass.** Tree construction and ancestor filtering run directly without IO or mocks.
   - **ARCH-PURPOSE: flag.** Cyclic components retain entries but can lose the parent relationships this issue exists to display.

7. **Plan revision recommendations**
   
   Add a `## Revisions` entry specifying deterministic cycle-member promotion and the three descendant regression shapes. Reopen the cycle coverage checkbox until those tests fail on this head and pass with the correction.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"9eb0c234-5429-48d7-b80e-dc8e0f24d2a7","repository":"github.com/xianxu/parley.nvim","issue_id":"000390","recipe":"small-diff-review","round":1,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/1bd5848e4d0ad76a","reviewed_head":"42956aba6b01b0b8232eaf6fc2ed864e6f2f18b8","slot":"parley.nvim:1","requested_at":"2026-10-18T22:30:51.532028Z"},"phase":"finished","pid":4960,"started_at":"2026-10-18T22:30:51.786528Z","finished_at":"2026-10-18T22:32:24.881637Z","session_id":"01a15123-a364-7011-99b8-34a9ec96e252","outcome":"returned"}] -->
