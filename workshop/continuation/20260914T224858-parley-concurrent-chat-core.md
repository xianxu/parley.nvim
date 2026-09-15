---
type: continuation
slug: parley-concurrent-chat-core
agent: codex
created: 2026-09-14T22:48:58
branch: 000254-chat-ownership-concurrency
worktree: /Users/xianxu/workspace/worktree/parley.nvim/000254-chat-ownership-concurrency
issues: [000254]
---

# Continuation: parley-concurrent-chat-core

## NEXT ACTION

Run `sdlc state` in `/Users/xianxu/workspace/worktree/parley.nvim/000254-chat-ownership-concurrency`, then read #254's issue and durable plan. Finish M1's representative concurrent-stream and fold-maintenance baseline coverage, inspect the committed containment integration, and run its single automatic `sdlc milestone-close --issue 254 --milestone M1` review after checking off genuinely completed M1 steps. Do not repeat plan approval or dispatch a redundant boundary-review agent. Then implement M2–M6 autonomously from the approved plan.

## State of play

#254 is working, claimed and approved. Plan-quality round 2 CLEAN, estimate 33.107 focused ship-hours accepted with advisory calibration notes. Implementation is isolated on `000254-chat-ownership-concurrency`. Commit `ffb7fa2c` checkpoints M1 code/tests/counters; no milestone closed. Mapped lifecycle 530 tests and exchange-model 281 tests passed, zero failures/errors. Scoped lint and whitespace checks passed. Worktree was clean after the checkpoint. Read the issue Log for baseline measurements and progress; `/tmp/parley-254-m1-lifecycle.log`, `/tmp/parley-254-m1-exchange.log`, and `/tmp/parley-254-m1-perf.json` are optional local raw evidence, not required source artifacts.

## Thread arc & user model

The user wanted a clear model for arbitrary human buffer edits during generation: deleting multiple exchanges or partial headers cannot be treated as a sequence of valid domain commands. They also insisted that highlighting, coloring and folding remain fast without document scans. Scope is one Neovim instance, reload invalidates writers, and concurrent tool calls are a real requirement. The usual interaction is typing the next question while an answer streams. They approved the full design and asked to proceed through plan review; it passed and implementation began. They expect sustained autonomous work, not another permission loop.

## Artifact map

Read `workshop/issues/000254-chat-ownership-concurrency.md` first for confirmed scope and logs, then `workshop/plans/000254-chat-ownership-concurrency-plan.md` for the approved contracts, function-level adversarial strategy table, operating budgets, and six milestone boundaries. The generated sibling `-plan-gate.md` contains the accepted round-2 review.

M1 introduced `lua/parley/attempt.lua` and private tasker lifecycle authority; dispatcher carries generation/admission options and rejects unlaunched query preparation. Response lease invalidation stops its captured owner and completion preserves typed-ahead nonblank content. The new ownership integration specs exercise actual response/dispatcher/tasker paths with `tests/helpers/fake_process.lua`. Legacy tasker synthetic fixture in `chat_respond_spec.lua` now uses the fake process. Instrumentation extends LineReader, anchor and native-fold counters through one WORK_FIELDS list; TOOLING documents schema 2. Atlas lifecycle and traceability map this limited shipped surface, not future concurrency.

All code lives in the implementation worktree named above. The original `/Users/xianxu/workspace/parley.nvim` main checkout has unrelated defaults/chat-file user changes and an uncommitted generated plan ledger; preserve them. The identical accepted ledger was copied into the implementation branch and committed. No peer modifications are needed. Agents m1_transport and m1_metrics finished with all assigned edits committed; no active agent task needs rescue.

## Live deliberations

M1 checklist still requires representative fold maintenance and concurrent stream baseline coverage beyond ordinary typing/newline metrics; do not tick this merely because added counters exist. Review transport integration before the automatic boundary gate. Current tasker uses explicit unresolved retention without reconciliation timers; later scheduler work owns bounded admission and global resource enforcement. Current UI still has per-buffer pending state and existing explicit Stop behavior, intentionally not the completed regional architecture.

## Decisions & dead ends

The buffer is authoritative. One document coordinator consumes byte edits and owns a balanced chunked structural index shared by all rendering and semantic consumers. Identity follows live-root membership, never ordinal or text equality. Immediate overlap revocation plus suspended uncertain grants protects writes while bounded repair establishes structure. Grammar tracks backward and negative dependencies, including reasoning and unmatched fences. Publication validates local provenance rather than global changedtick to avoid starvation from independent streams.

Neovim API mutations serialize on the main loop; independent IO proceeds concurrently. Child tool slots preserve provider declaration order while completion may be out of order. External resource claims and unknown effects outlive document teardown. Reload invalidates active grants. Recovery snapshots are immutable private records with evidence-based association after restart, never persisted exchange IDs or guessed duplicate-question ordinals.

Manual folds remain; normal unchanged-topology edits do no fold operations. Broad native fold clear has explicitly span-dependent cost within 50k rows, with folds disabled for sliced cleanup above that envelope. No constant-time claim for that exceptional operation. Baseline newline insert/join at 5k rows copies 20,002 slots: M2 must remove that suffix cost, not merely improve elapsed timing.

## Lessons learned

Plan-quality requires named functions tied to adversarial verification strategies; a repeated case list is insufficient. Accepted-plan caching allowed estimate entry without a second review. Keep review boundaries singular: sdlc owns fresh-context review at each milestone and final close. The local issue-sync checkpoint is necessary before context transition; uncommitted design is not durable. Use explicit implementation workdir for every tool and isolated test envs; full make test cleans its scratch tree and must not race another run there.
