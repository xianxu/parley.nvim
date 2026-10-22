---
id: 000414
status: open
deps: []
github_issue:
created: 2026-10-22
updated: 2026-10-22
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'cbdf1e98e6563e06f6be6f6bdeb7433cb33d77d8' # card fields mirrored from issue-cards; edit via sdlc
---

# Investigate registered-saveas timing flake under load

## Problem

The existing registered native saveas test intermittently exceeds its fixed elapsed-time assertion under load. The same code failed in the full session-sync mapping and passed in one isolated rerun during #410 close review. Related class: #412 (fixed-budget native timing under load); this is a separate test and must not silently inherit that case's exception.

## Spec

Investigate `tests/integration/agentic_document_spec.lua`, case `agentic markdown admission under a slow Couch (#357) a registered :saveas onto an absent file returns at once and lands (row 1)`. It registers the file, configures a 2-second delayed fake registry, invokes native saveas, and asserts the call returns in less than 500 ms before waiting for the move to settle. The failure is line257, `the rename waited on Couch`; saveas itself returned successfully. Determine which native/file/protection stage consumes time under load and distinguish a real synchronous wait regression from a fixture timing assumption. Preserve #410's separate real 500 ms input-admission requirement.

## Done when

- Capture stage timing/outcome evidence under the failing load and classify the source of the elapsed-time breach.
- Make the nonblocking-saveas assertion reject the intended regression with controlled evidence rather than a blind passing retry or blanket timeout increase.
- Verify a regression negative control and the affected mapping on supported Neovim runtimes.

## Plan

- [ ]

## Log

2026-10-22: Filed unclaimed at TL direction cb8f8ce2 while #410's recorded suite remains queued. Both observations use reviewed head199c3b90373e3007fc023d50a8f00652588aec93 (same product code as ff71df2b2f2fc69b57d3ccca4001de3d7dd47825; subsequent #410 fixes are documentation only). Reviewer used preferred Neovim0.12.5.

Failure: full32-file session-sync mapping853 passed/1 failed/0 errors. `/tmp/parley-410-review-tests.log:269` names this exact case; line271 reports `agentic_document_spec.lua:257: the rename waited on Couch`, boolean false where true expected. The assertion establishes elapsed >=500 ms; an exact duration and machine CPU/load snapshot were not emitted. The review also ran bounded focused/substitution checks in a distinct disposable checkout during the session; no claim about a measured load level.

Pass: `/tmp/parley-410-review-extra.log:85` names the identical case, followed by1 passed/0 failed/0 errors. The reviewer restored all Lua modules with git checkout from its199c3b90 checkout before selecting just this case. The successful assertion establishes elapsed <500 ms, with no exact duration emitted. The rest of that extra run passed Couch25 and owner architecture7. The earlier `/tmp/parley-410-review-negative.log` is a deliberate pre-correction control for other #410 cases and is NOT this passing rerun.

The implementer's own preferred mapping and complete operator Neovim0.11.7 mapping also passed this test (operator854/0/0). Raw local logs are diagnostic pointers; the assertion, setup, counts and limits above are durable evidence independent of those temporary files.

TL permits #410 to proceed with its retained queued suite; if that recorded suite fails on this exact case, one evidenced rerun is authorized. This does not authorize accepting other unknown failures or changing test budgets in #410.
