---
id: 000395
status: open
deps: []
github_issue:
created: 2026-10-19
updated: 2026-10-19
estimate_hours:
severity: low
collaboration-mode: collaboration
card_mirror: 'ffdf171fd9c7720868325e2091182eb0d8afb858' # card fields mirrored from issue-cards; edit via sdlc
---

# jit_tuning_spec foreign JIT trace count is 0 under suite load (flake)

## Problem

`tests/unit/jit_tuning_spec.lua` "module-scoped compiler protection in a real VM keeps unrelated JIT traces active while protecting the entire document pipeline" failed at line 126 (`assert.is_true(result.foreign > 0)`) in the full suite on parley.nvim#391's head 0c9ab358, a diff that touches no JIT or document-pipeline code. The child VM's foreign trace never reached `stop`: an abort or flush under suite load clears `foreign_trace`, so the count stays 0. The same file passed three isolated runs (`make test-spec SPEC=infra/test_harness`) on the same head, and the previous full suite on c3c50006 passed.

Evidence: suite log /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/8f1ede4b55ff8fded222bbfdcb96c6e5.log (sha256 ee66cec1ac34), recorded as sdlc-local/suite on 0c9ab358.

## Spec

## Done when

- The test proves foreign traces stay enabled without depending on a single trace completing under load (for example, a loop that retries until a foreign trace stops, bounded), and it passes under a loaded full suite.

## Plan

- [ ]

## Log

### 2026-10-19
