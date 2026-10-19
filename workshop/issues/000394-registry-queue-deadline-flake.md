---
id: 000394
status: open
deps: []
github_issue:
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'f5900cbdaf6cae0399a65af11229018fe78d9c55' # card fields mirrored from issue-cards; edit via sdlc
---

# Registry queue deadline flake

## Problem

The existing document_registry_spec queue/deadline case is intermittent under parallel suite load. In #393 recorded suite cb7588a68bab3b4b10fa36c1e134718c on d6e05403, request 1 returned unavailable: Couch registry deadline exceeded after 1000 ms; queued_ms=0, ran_ms=1000, instead of absent. All other preferred-runtime spec files passed; make stopped before the compatibility pass. The same unchanged spec passed all 11 cases alone immediately afterwards (/tmp/parley-393-registry-alone.log).

The test starts eight Python-backed fake lookups with a 0.6-second sleep and a one-second per-child deadline, leaving only 0.4 seconds for interpreter/startup/scheduling under load. Neither registry code nor its spec differs between #393 and origin/main; #393 changes only the spelling default.

## Spec

Remove the load-sensitive timing assumption while preserving the actual invariant: a queued request gets its execution deadline only when its child spawns. Reproduce deterministically through controlled scheduling, not a larger timeout alone. Keep separate real process-boundary coverage.

## Done when

- A deterministic regression catches a deadline started at queue admission.
- Parallel suite load no longer causes this case to classify a valid request as unavailable because of the test's narrow real-time slack.

## Plan

- [ ]

## Log

### 2026-10-18

Failed evidence: /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/cb7588a68bab3b4b10fa36c1e134718c.log (SHA-256 prefix 1fb5f695372b). File: tests/integration/document_registry_spec.lua, case starts a request's deadline when its child spawns, not when it queues. Failure assertion line 115. The isolated unchanged run passed 11/11. Filed unclaimed for the hub; #393 will retain this failure and make one unchanged recorded rerun per the worker flake rule.
