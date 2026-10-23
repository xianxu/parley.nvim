---
id: 000421
status: open
deps: []
github_issue:
created: 2026-10-22
updated: 2026-10-22
estimate_hours:
collaboration-mode: collaboration
card_mirror: '84e0208544282d5402b41266cbd25103eccad2ca' # card fields mirrored from issue-cards; edit via sdlc
---

# flake: lua:tests/integration/remote_runtime_spec.lua#private editor RPC runtime ownership keeps inspection bounded when all 256 marked directory owners differ from this editor, lua:tests/integration/remote_runtime_spec.lua#private editor RPC runtime ownership retains a directory whose inode changes after inspection begins

## Problem

Known flaky tests (#394), registered with same-head fail→pass evidence:

- lua:tests/integration/remote_runtime_spec.lua#private editor RPC runtime ownership keeps inspection bounded when all 256 marked directory owners differ from this editor: Same exact Git head a63c43605526bec39444f699060047790908366e on nvim0.12.5: focused make test-spec SPEC=modes/remote_session failed these two cases (266PASS/2FAIL/0ERROR, clean census), /Volumes/TestScratch/parley-405-landed-focused-green.log. Follow-up diagnostic make test-spec mapped only the unchanged remote_runtime_spec.lua:44PASS/0FAIL/0ERROR, clean census, /Volumes/TestScratch/parley-405-runtime-diagnostic.log. First case returned runtime deadline despite timeout_ms=arrival.MS; second did not reach fake source read before arrival wait. Native0.11.7 full mapping268PASS on the same head. Evidence is local targeted runs, not recorded-suite or CI evidence. Root cause not yet established; do not increase product deadlines or claim the failing mapping passed.
- lua:tests/integration/remote_runtime_spec.lua#private editor RPC runtime ownership retains a directory whose inode changes after inspection begins: Same exact Git head a63c43605526bec39444f699060047790908366e on nvim0.12.5: focused make test-spec SPEC=modes/remote_session failed these two cases (266PASS/2FAIL/0ERROR, clean census), /Volumes/TestScratch/parley-405-landed-focused-green.log. Follow-up diagnostic make test-spec mapped only the unchanged remote_runtime_spec.lua:44PASS/0FAIL/0ERROR, clean census, /Volumes/TestScratch/parley-405-runtime-diagnostic.log. First case returned runtime deadline despite timeout_ms=arrival.MS; second did not reach fake source read before arrival wait. Native0.11.7 full mapping268PASS on the same head. Evidence is local targeted runs, not recorded-suite or CI evidence. Root cause not yet established; do not increase product deadlines or claim the failing mapping passed.

## Spec

## Done when

- The root cause is fixed (never a retry loop or a longer timeout); closing this issue unregisters the tests.

## Plan

- [ ]

## Log

### 2026-10-22
