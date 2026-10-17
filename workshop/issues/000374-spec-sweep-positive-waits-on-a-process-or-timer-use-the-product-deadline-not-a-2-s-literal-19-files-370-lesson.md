---
id: 000374
status: open
deps: []
github_issue:
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
collaboration-mode: collaboration
card_mirror: '179463aa5568672965731dda74028bcbd767e343' # card fields mirrored from issue-cards; edit via sdlc
---

# Spec sweep: positive waits on a process or timer use the product deadline, not a 2 s literal (19 files; #370 lesson)

## Problem

## Spec

From #370 (2026-10-17). A spec that waits a fixed 2 s for a process or timer it started (`assert.is_true(vim.wait(2000, ...))`) flakes under suite load. In #370 a file that takes about 1 s unloaded took 22–33 s across 141 attempts under a suite. #370 fixed session_sync_spec by tying every positive wait in it to the product's own deadline.

19 other spec files still use the 2 s pattern:
- unit: build_messages, outline, response_preparation, dispatcher_query;
- integration: response_target, chat_tree_context, tasker_supervision, review_send, async_builtin, define, document_registry, skill_invoke, generation_turn, generation_sequences, entity_navigation_native, response_submission, unscoped_kill, session_sync_native, lock_leave_reminder.

Rule (the #370 lesson): a positive wait, one that returns on arrival, is bounded by the product deadline it observes, or by one shared suite arrival budget where no product deadline exists. Absence checks keep their short fixed waits.

## Done when

- Each positive 2 s wait on a process or timer in those files uses the product deadline or the shared budget. Waits on pure in-memory state may stay, with the reason noted.
- A lint or arch test refuses a new literal positive `vim.wait(N, ...)` assertion under the integration specs, naming the helper to use.
- The suite still passes, and a passing run is not slower, since positive waits return on arrival.

## Plan

- [ ]

## Log

### 2026-10-17
