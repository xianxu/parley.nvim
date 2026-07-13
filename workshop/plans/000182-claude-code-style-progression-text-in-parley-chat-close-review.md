# Boundary Reviews — #182

## 2026-07-13T03:34:31-07:00 — REWORK

Window: `27a778b7876adfdf3816b8c701e2b355252c357b..3653c0c`

- Synchronous skill setup after terminal registration could bypass Definition
  cleanup.
- The plan overstated the real SSE fixture's implemented modes.

Resolved by `8dd14b4`: protect the complete synchronous setup region, add a real
Definition throwing-payload regression, and distinguish process-fixture modes
from callback-driven activity/tool-only coverage.

## 2026-07-13T03:45:00-07:00 — REWORK

Window: `27a778b7876adfdf3816b8c701e2b355252c357b..49f520e`

- Chat and Definition animation repaints reused creation coordinates, snapping
  extmarks away from their tracked anchors after preceding edits.
- The checked smoke-test title said manual although its revision correctly
  recorded a production-shaped headless substitute.

Resolved in the following commit: both renderers resolve the current extmark
position before repaint, terminate on unexpected invalidation, and have
real-buffer movement regressions. The checklist now names the headless smoke
that was performed.

Raw reviewer prompts and test transcripts were compacted because each embedded
the complete whole-window diff and exceeded 11,000 lines; including that
generated bulk in the next review window exhausts the fresh reviewer before it
can inspect the fix. This durable record retains every actionable finding,
verdict, resolution, window, and verification result.
