# #189 close review

- Review window: `925c046..b71fec1`
- Verdict: `REWORK`
- Confidence: high
- Reviewer: SDLC-dispatched fresh-context Codex

## Findings

1. Critical — `lua/parley/issue_finder.lua` reset `_issue_finder.opened`
   immediately after starting asynchronous acquisition. A second invocation
   could create a concurrent picker while the first was loading or settled.
2. Critical — `lua/parley/async_file_enrichment.lua` removed a descriptor from
   its ownership set before a queued `fs_close` began. Cancellation could clear
   that queued close and then find no descriptor to close directly.

`ARCH-DRY` passed. The findings flagged `ARCH-PURPOSE` for inconsistent picker
lifetime ownership and `ARCH-PURE` for the descriptor-ownership race at the IO
boundary. No Important or Minor findings were reported. The reviewer otherwise
confirmed the shared async architecture, pure materializers, Git boundary,
documentation, atlas, and full green suite.

## Resolution

- Issue Finder now retains its guard until selection, cancellation, or an
  action-owned reopen. The focused regression invokes the finder during loading
  and after settlement, then proves selection and cancellation release it.
- Async enrichment now relinquishes a descriptor only when the queued close
  actually starts. A focused saturated-queue regression cancels while close is
  pending and proves direct closure occurs exactly once.
- The plan revision, issue Log, and `workshop/lessons.md` record both ownership
  rules.

## Evidence

- `tests/unit/issue_finder_spec.lua`: 27 successes, 0 failures.
- `tests/unit/async_file_source_spec.lua`: 14 successes, 0 failures.
- `make test-changed`: exit 0.
- `make lint`: zero warnings/errors across 301 files.
- `make test`: exit 0 with every unit, architecture, and integration spec PASS.
- `git diff --check`: clean.
