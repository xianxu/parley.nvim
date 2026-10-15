---
type: continuation
slug: parley-327-approved-build
agent: codex
created: 2026-10-14T23:30:55
issues: [000327]
---

# Continuation: parley-327-approved-build

## NEXT ACTION

Run sdlc state, read the approved durable plan workshop/plans/000327-entity-link-navigation-plan.md in full, then run sdlc change-code --issue 327 --flow full. Plan-quality admission precedes the estimate. After admission, derive the estimate using the binary's estimate-source and setter contract, then implement with TDD. Do not restart planning or seek approval again: TL explicitly approved the design in delivery 9c9ad248-287c-4ac9-9340-c8b4527dc3c0, already verified submitted. Build, suite, close review, then stage on parley.nvim:0; do not land until operator morning acceptance.

## State of play

#327 is claimed by parley.nvim:2, working on its issue branch. No implementation or change-code yet. Approval is committed at acdd718f27116724993cf1d493489f1cb084060d. Current branch includes main after #330 and #331. All prior work (#324 PR236, #330 PR237, #331 PR238) landed and was reported. No old report needs resending. TL says :0 is on main at 41899819. Full flow is approved because this exceeds the quick shell. There is one atomic close review boundary, no Mx tags. Estimate remains unset pending plan-quality admission.

## Thread arc & user model

The operator uses session-sync markdown every day: earlier fixes made normal edits, auto-save undo lock release and couch-owner migration reliable. This item makes Alt+o follow an answer at the end of a long numbered instruction without moving onto the link. They want familiar direct-reference behavior preserved. TL owns acceptance and operator coordination; the operator is asleep, so implement autonomously and leave a reviewed stage for morning testing.

## Artifact map

Read the active #327 issue in workshop/issues/ first for the Spec, Done when and latest Log; then workshop/plans/000327-entity-link-navigation-plan.md for exact APIs, ownership, tests and delivery. Both are committed. The issue records approval and current staging hold. No continuation open questions require another permission request.

The pure boundary belongs to lua/parley/entity_range.lua navigation_range; existing deletion/textobjects must remain unchanged. New reference_candidates.lua owns shared occurrence scanning and pure picker completion. issues.lua's Markdown cursor parser and init.lua's @@/branch cursor parsers derive from it, retaining legacy behavior. Root owns init.lua opening/picker integration and documentation. Existing source-relative paths, backtick refusal, resolver and gf seams stay authoritative. #323 URL/fragment behavior remains separate.

## Decisions & dead ends

Navigation-only ranges recognize top-level column-zero numbered anchors, repeated numbers as boundaries, interior blanks, trim trailing blanks, exclude fence boundaries/targets, and obey chat/header limits. Heading range follows existing section rules. Direct refs (including artifact refs) retain priority. One occurrence opens, several use vim.ui.select, zero follows existing resolve then gf. Count occurrences even repeated targets, mask overlaps in Markdown spans. Guard cancellation, duplicate/late callbacks, edited/deleted origins, switched windows and invocation generation before effects. Keep Insert restoration semantics.

Main announced executing-plans and TDD with bounded pure range/scanner agents; none spawned yet. AGENTS explicitly authorizes bounded delegation. Use focused prompts, fork_turns none, disjoint files. Root should own init.lua integration. Do not add a duplicate fresh-eyes review: sdlc close owns it.

## Lessons learned

Do not run concurrent make targets in this checkout: test process census can reap sibling tests, and separate TEST_ENV_ROOT alone does not isolate it. Agents may author tests but root should serialize harness runs. Use make -k test-spec SPEC=context/file_references and SPEC=chat/entity_delete; full suite via sdlc local-check run --name suite, which may queue many minutes on machine leases. Do not bypass the queue. Keep commentary within 60 seconds while working. File-backed readiness tests require complete newline-terminated payloads, not existence.

Couch and sdlc must be whole bare shell calls (exec workdir is fine); no shell prefix/suffix/pipes/redirects/substitution text. Report stage outcome to hub with exact git-verified SHA, test and SHIP review evidence, PR, and live pickup instructions (restart Neovim loads staged Lua). Staging is authorized; no further prompt. Keep stage overnight pending operator acceptance. TL owns the real status file; never edit it yourself.

Potential detail to assess during implementation: snapshot guards detect a different window at callback, but a focus excursion and return may need cancellation semantics. Do not blindly invalidate WinLeave if a picker itself opens windows. Follow approved stale/cancel behavior with realistic integration tests.
