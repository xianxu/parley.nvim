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

---

## Re-review — 2026-10-17T19:07:50-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 373 — side docs S3: on a name change the mover rewrites the parent's links and discussions index, suffixes an orphan .side folder, and passes ariadne's shared move fixtures |
| repo | parley.nvim |
| issue file | workshop/issues/000373-side-docs-s3-on-a-name-change-the-mover-rewrites-the-parent-s-links-and-discussions-index-suffixes-an-orphan-side-folder-and-passes-ariadne-s-shared-move-fixtures.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | 521fb362430a3e67802b61cd871011460888e754..e2d99474a999f66a196818ce72ccc88d0e527b76 |
| command | sdlc milestone-close --issue 373 --milestone M2 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-17T19:07:50-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned M2 implementation satisfies the issue’s move, preservation, recovery, and shared-fixture requirements. BR-6 is addressed with persisted finalization progress and meaningful regression coverage. No new blocking findings emerged.

```findings
dispose:
  - id: BR-6
    disposition: addressed
    note: |
      document_move.lua:695-746 persists release authority and retirement progress before journal unlink; editor adoption follows unlink. Fresh/recovered unlink regressions pass at HEAD. Restoring pre-fix production files in disposable checkouts makes both regressions fail, including recovery completion after removing journal-shape assertions.
```

1. **Strengths**

   - Finalization now remains replayable across protection release and journal retirement (`lua/parley/document_move.lua:658`).
   - Editor handoff preserves unexpected read-autocmd edits and outstanding operator turns (`lua/parley/agentic_document.lua:44`, `lua/parley/session_sync.lua:1088`).
   - Shared fixtures exercise actual filesystem moves through the persistent fake registry and compare complete output trees.
   - README and atlas document the new behavior, recovery contract, and reducer ownership.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage notes**

   - `make test-spec SPEC=modes/session_sync`: **593 passing tests across 20 files**, zero failures/errors.
   - Explicit Neovim **0.11.7** lease verification: **11 passing tests**.
   - Lint: **786 files**, zero warnings/errors.
   - Pinned-range whitespace check passed.
   - Negative controls reproduced failed recovery without the BR-6 correction; disposable checkouts were removed. Process checks reported no survivors.
   - Full repository suite and live acceptance were not independently rerun.

6. **Architectural notes**

   - **ARCH-DRY — pass:** Shared projection and finalization helpers serve fresh and recovered moves.
   - **ARCH-PURE — pass:** Projection/reducer remain deterministic; filesystem, registry, and editor effects stay in adapters.
   - **ARCH-PURPOSE — pass:** Parent references, orphan displacement, and shared fixtures are delivered; the permitted registration-gap follow-up is documented in #378.
   - **ARCH-MOCK — pass:** Registry integration uses the existing transport seam and persistent fake; conformance tooling remains available.
   - **ARCH-CONSTRAINTS — pass:** Explicit scan, journal, entry, and pending-operation bounds remain enforced.
   - **ARCH-SECURE — pass:** Persisted authority and observed witnesses are validated; unknown content/protection remains interrupted.
   - **ARCH-ORDER — pass:** Reducer-owned progress, sole-writer enforcement, failure injection, and stale-event tests cover sequencing.
   - **ARCH-FUNERAL — pass:** Journal/temp retirement is explicit and replayable; retained user content and permanent bounded leases have documented lifecycles.

7. **Plan revision recommendations:** None. Existing revisions accurately explain milestone sequencing and BR-6’s finalization refinement.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"eaf92ded-3b0c-49ca-a1c7-715d8386bfc6","repository":"github.com/xianxu/parley.nvim","issue_id":"000373","recipe":"milestone-review","round":2,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/814ab84b1132503e","reviewed_head":"e2d99474a999f66a196818ce72ccc88d0e527b76","slot":"parley.nvim:1","requested_at":"2026-10-18T02:05:04.925828Z"},"phase":"finished","pid":50776,"started_at":"2026-10-18T02:05:05.04447Z","finished_at":"2026-10-18T02:07:49.802395Z","session_id":"01a14cc1-65e0-7bf3-9cd7-b1382106a530","outcome":"returned"}] -->
