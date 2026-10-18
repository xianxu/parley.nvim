# Boundary Review — parley.nvim#373 (milestone M2)

| field | value |
|-------|-------|
| issue | 373 — side docs S3: on a name change the mover rewrites the parent's links and discussions index, suffixes an orphan .side folder, and passes ariadne's shared move fixtures |
| repo | parley.nvim |
| issue file | workshop/issues/000373-side-docs-s3-on-a-name-change-the-mover-rewrites-the-parent-s-links-and-discussions-index-suffixes-an-orphan-side-folder-and-passes-ariadne-s-shared-move-fixtures.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | 521fb362430a3e67802b61cd871011460888e754..140d8e541dc74626616f496f1d2acf49c7d51d7d |
| command | sdlc milestone-close --issue 373 --milestone M2 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-17T18:24:11-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

M2 delivers parent rewrites, orphan displacement, editor synchronization, and shared-fixture execution with substantial recovery coverage. One confirmed completion-ordering defect blocks shipping: recovery can release its lock before journal deletion, leaving a retained journal that subsequent reopening cannot finish.

```findings
findings:
  - id: new
    severity: Critical
    family: replayable-local-finalization
    title: |
      Recovery releases protection before journal retirement is safely recoverable
    detail: |
      lua/parley/document_move.lua:1084 calls the recovery finish hook before unlinking the journal. That hook releases the synthetic destination lock at lua/parley/agentic_document.lua:859, but the retained complete journal still requires that lock. A targeted fault-injection test confirmed that failing journal unlink after successful handoff leaves the journal permanently interrupted on reopening with "destination protection changed". ARCH-ORDER/ARCH-FUNERAL: model and persist partial finalization so lock release and journal retirement remain safely replayable; enumerate failures and crashes across these effects and add real editor recovery regressions.
```

1. **Strengths**

   - The pure reducer is consumed by the production dispatcher, with an architecture guard against additional checkpoint owners.
   - Shared fixtures exercise actual filesystem moves through the persistent fake registry and compare the complete resulting file tree.
   - Guarded native reads preserve real autocmd edits, including recovery handoffs.
   - README and atlas document the new behavior. Issue #378 records the Alt+o registration gap, satisfying the spec’s permitted follow-up.

2. **Critical findings**

   - **Recovery finalization is not replayable** — `lua/parley/document_move.lua:1084–1087`, with lock release in `lua/parley/agentic_document.lua:859`. Persist recoverable finalization progress without weakening protection checks or deleting recovery authority prematurely.

3. **Important findings**

   None.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - `make -f Makefile.parley test-spec SPEC=modes/session_sync`: all 21 mapped files passed; no surviving test processes.
   - The additional isolated fault-injection test failed as described above: journal phase remained `complete`, destination lock was absent, and reopening refused recovery.
   - Pinned-range whitespace checks passed. Repository files remain unchanged.
   - Existing interrupted-finish coverage refuses before successful handoff; it does not cover successful handoff followed by failed journal deletion.

6. **Architectural notes**

   | Principle | Assessment |
   |---|---|
   | ARCH-DRY | Pass — shared projection and checked writer are reused. |
   | ARCH-PURE | Pass — reducer/projection remain free of IO; editor and filesystem effects stay at integration boundaries. |
   | ARCH-PURPOSE | Pass — requested move behavior and allowed registration-gap disposition are delivered. |
   | ARCH-MOCK | Pass — registry execution uses the existing persistent fake and production transport seam. |
   | ARCH-CONSTRAINTS | Pass — scanning, suffix search, journal size, and pending-operation bounds remain explicit. |
   | ARCH-SECURE | Pass — recovery validates persisted authority and preserves unknown bytes. |
   | ARCH-ORDER | **Flag** — successful local finalization invalidates the retained recovery proof. |
   | ARCH-FUNERAL | **Flag** — a transient deletion failure strands a completed journal. |

7. **Plan revision recommendations**

   Add a `## Revisions` entry defining recoverable partial finalization between editor handoff, protection release, and journal retirement. Require sequence tests for failure or process death after each effect, including reopening after successful handoff but failed journal deletion.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"e43725cd-bf48-4ced-8d9f-1504592838e2","repository":"github.com/xianxu/parley.nvim","issue_id":"000373","recipe":"milestone-review","round":1,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/5c2b202540809e47","reviewed_head":"140d8e541dc74626616f496f1d2acf49c7d51d7d","slot":"parley.nvim:1","requested_at":"2026-10-18T01:15:47.419434Z"},"phase":"finished","pid":40843,"started_at":"2026-10-18T01:15:47.796452Z","finished_at":"2026-10-18T01:24:11.101548Z","session_id":"01a14c94-466a-77e1-b674-8fdf41abf9fb","outcome":"returned"}] -->
