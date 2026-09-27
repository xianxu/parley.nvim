---
id: '000200'
status: done
started: 2026-08-19T11:50:43-07:00
created: 2026-08-18
updated: 2026-08-21
estimate_hours: 6.35
actual_hours: 33.41
---

# user question is folded

## Problem

Two invariants are violated:

1. A user question (`💬:`) can end up as a fold header, rendered
   `💬: … (N lines)`. Confirmed by the operator and reproduced.
2. Tool calls (`🔧:`), tool results (`📎:`) and summaries (`📝:`) can fail to
   fold, or be swallowed into a neighbouring fold.

The intended policy was already correct — `fold_projection.FOLDABLE` is
`{thinking, summary, tool_use, tool_result}` and excludes questions. The
failures are in how that desired state is *applied* and in how answer sections
are *segmented*, not in the policy.
