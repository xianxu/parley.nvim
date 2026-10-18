---
id: 000378
status: done
deps: []
github_issue:
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
collaboration-mode: collaboration
card_mirror: '6eb0cf1d0a63371dbec521f88269ff0c2d93bf75' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-17T14:45:11-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: full, provenance: inferred}
actual_hours: 0.69
---

# Side documents inherit parent ownership

## Problem

Alt+o opens a side document from a registered parent but does not register the child with the parent's effective owner. The navigation therefore loses the ownership relationship; a later submit can instead select the current pane's actor.

Found during #373's required registration audit, independently of moving files.

## Spec

Opening an unregistered side document from a registered parent should inherit the parent's effective Couch owner without submitting the document. Preserve an existing child registration. Unknown parent or child ownership must not authorize guessed ownership or replacement of a registration.

The real call path is OpenFileUnderCursor → try_open_markdown_link → open_buf → setup_markdown_keymaps → agentic_document.attach → lifecycle open → registry lookup. The opener currently passes only the target path, not the parent identity; lookup absence becomes plain.

## Done when

- A real Alt+o navigation from a registered parent owned by ops:0 in a pane whose actor is parley.nvim:1 registers an absent side child to ops:0, with no send.
- Existing child registration and effective owner remain unchanged.
- Missing, stale or unavailable identity cannot silently guess ownership; tests cover the refusal and a later successful navigation.
- Headless integration coverage exercises the actual opener and persistent registry fake rather than stubbing open_buf.

## Plan

Quick flow. The rule lives in the pure model (`document_session`), and the shell only carries it.

**Scope.** A child inherits only when it is a side doc of the parent: its directory is `document_move_plan.side_path(parent)`, which is the rule the attention finder and the mover already use (ARCH-DRY). Any other Markdown link opened with Alt+o is left alone. Without this, following an ordinary link from a registered doc would register that file to the parent's owner.

**Model (`document_session`, pure)**, with a new event `inherit {parent = {path, id, owner}}`:
- If the child has a registration or a pending mutation, ignore the event. The existing registration is kept.
- If an operation (the attach lookup) is in flight, keep the hint and apply it only if that lookup answers `absent`. Any other answer drops it.
- If the child is plain or unknown, issue a fresh `lookup`, because an earlier "absent" may be stale.
- When the lookup answers absent and a hint is present, issue `confirm_parent`, a lookup of the parent path. This checks the parent's identity at the moment of inheriting, rather than trusting what the buffer last saw.
- When `confirm_parent` returns a valid registration whose ID and effective Owner match the hint, issue `register {owner = parent.owner, resume_only = true}`. The reply attaches the registration and sends nothing, through the existing resume_only path. On a mismatch, absent or unavailable: no register, a band or notification saying "not inherited: parent ownership not confirmed", and the child stays plain.
- If the inherited register is refused (an owner-conflict race), issue a lookup and adopt whatever is registered there. If it is uncertain, fall back to the existing pending/retry path, which is resume_only and so sends nothing.

**Shell.**
- `agentic_document.inherit(child_buf, parent_buf)` takes the parent identity from `M.identity(parent_buf)`. With no parent identity it does nothing, so an unknown parent authorizes nothing. It applies the side-folder rule and dispatches the event.
- `execute` learns `confirm_parent`, using the same `registry.request("lookup")` with the parent's path.
- `try_open_markdown_link` calls `inherit` after `open(target)`.
- The pane actor is never consulted on this path.

**ARCH notes.**
- ARCH-ORDER: the lookup-then-register race is covered. If a second actor registers the child between our lookup and our register, Couch answers owner-conflict and we adopt its registration. A late reply after detach is dropped by the witness check.
- ARCH-CONSTRAINTS: this runs on the keypress, but the registry calls are asynchronous and the editor never waits on them.
- ARCH-FUNERAL: the only durable thing created is a Couch registry row, the same kind and lifetime as a submit registration.
- ARCH-SECURE: the parent's identity is confirmed by Couch, not read from the cached buffer state.

**Tests.**
- [x] Unit (`document_session`), as event sequences:
  - absent → confirm_parent → register with no send;
  - a registered child keeps its registration;
  - a stale parent (ID or Owner mismatch) and an unavailable parent lookup both refuse;
  - an unavailable child lookup drops the hint;
  - a hint that arrives during the attach lookup is applied;
  - an owner-conflict leads to a lookup and adoption;
  - after a refusal, a later inherit succeeds.
- [x] Integration (new `tests/integration/agentic_document_side_inherit_spec.lua`, using the real `OpenFileUnderCursor` and the persistent fake registry; open_buf is not stubbed):
  - the parent is registered to ops:0 and the pane actor is parley.nvim:1. Alt+o onto `parent.side/child.md` registers the child to ops:0, and the send count stays 0;
  - a child already registered to another owner is unchanged;
  - a non-side link registers nothing;
  - with `FAKE_COUCH_REGISTRY_MODE=malformed` nothing is registered and the band says so, and a later navigation with the fake healthy succeeds.
- [x] Atlas: one paragraph on side-doc ownership inheritance.

Open question for the TL: should inheritance also require the side doc's `type: side-doc` frontmatter (the attention finder's filter)? My default is folder membership only.

## Log

### 2026-10-17
- 2026-10-17: closed — BR-6 via TL-approved re-plan: the pure model owns the queued press (queue_submit; admits = attach lookup, confirm_parent, inherited register/re-lookup) and every dispatch settles it in one place, emitting exactly one flush_queued (registration, or plain-doc submit with no inheritance) or drop_queued (any other inheritance ending, pending, detach); the shell submits only on flush_queued, tail flush and s.queued_submit removed. Table test walks 22 endings x 6 starts: one decision each, stale witness decides nothing, no second decision; always-flush mutation fails it. Integration: reload during inheritance (detach ending) and forgotten/re-owned parent each 0 sends; always-flush mutation fails all 3. document_session 46, side_inherit 9, agentic_document 47, session_sync 64; full suite passed on d4ecabfb (record failed: api.github.com unreachable). (done-when: contract moved since change-code; judged by the close review); review verdict: SHIP
- 2026-10-17: flow upgraded quick → full — 122 added lines in code files (limit 100)

Deterministic fake-only reproduction through the actual opener: register parent.md to ops:0, select pane actor parley.nvim:1, open [side](parent.side/child.md) with OpenFileUnderCursor. Navigation issued exactly couch --session-sync lookup ABS_CHILD --json. Child phase was plain, identity null, registry entry absent, send count zero. Parent registration retained Owner and RegisteredOwner ops:0. Scratch removed and process census clean. Local evidence: /tmp/parley-373-side-open-gap.log; runner /tmp/parley-373-side-open-gap.lua, invoked by make -f /tmp/parley-373-side-open-gap.mk test-373-side-open-gap. The observed argv and state above are the durable evidence; temporary paths are not required to understand the failure.
- The TL approved the plan and answered the open question: folder membership only, so a hand-made side doc with no frontmatter still inherits. The band is short and says how to retry: "navigate again".
- Implemented as planned. `document_session` gained the `inherit` event, the `confirm_parent` step and the inherited-register adoption. `agentic_document.inherit` and `confirm_parent` are in the shell, and `try_open_markdown_link` calls `inherit`.
- The first draft of the integration spec called `setup_markdown_keymaps` on the parent by hand. Without `parley.setup`'s BufEnter handler, the child was attached only by `M.inherit`'s own `attach`, so the spec never exercised the real opener path. Mutation check: with the opener call removed, all 4 cases failed, including the two that should be independent of it. The spec now installs `setup_buf_handler`, so the product attaches every buffer. Re-run with the call removed, exactly the two inheriting cases fail, and with the side-folder rule removed only the non-side case fails.
- Targeted runs pass: document_session 45, side_inherit 4, agentic_document 47, owned_move 16, lifetime 10, document_registry 7, file_history 45, nodiscard 2.
- Close review round 1: FIX-THEN-SHIP. Each finding was fixed as a class.
  - BR-1 (Important, effect-executor-shared-tail): `confirm_parent` had its own copy of the lookup callback, missing the shared tail (the queued-submit flush and the retry). An Alt+Return during inheritance was dropped, and the doc was left move-busy. `confirm_parent` now goes through the one lookup/register executor (ARCH-DRY). Sweeping the same class turned up a second drop: `M.submit` queued a press only during a plain lookup, so a press during `confirm_parent` or the inherited register was ignored. Both steps now queue.
    - New integration cases: one press at the parent check (inherits, sends once to ops:0); one press during the child lookup with the parent forgotten (not inherited; the explicit press submits once).
    - Mutation checks: a lookup-only queue fails the first case, and no flush after `confirm_parent` fails the second.
  - BR-2 (Important): an integration case for a parent with no registration. Alt+o leaves the side child absent, with 0 sends.
  - BR-3 (Minor): the atlas now says exactly which band each refusal shows, that a parent with no registration offers nothing, and that a press during inheritance waits. The adoption comment now covers any refused or lost register, not only owner-conflict.
  - Targeted runs pass: side_inherit 7, document_session 45, agentic_document 47, owned_move 16, lifetime 10.

## Revisions

- 2026-10-17, close review round 2 (BR-4). After round 1, a press queued during inheritance flushed as an ordinary plain-doc submit once a refusal left no operation. That re-aimed it at the pane's actor, and the reviewer reproduced it with a stale parent and with an unavailable one. This was the third change to the queued-press handling, so it went to the hub instead of becoming another increment. The hub approved this rule:
  - A press queued during inheritance is authorized only by the inheritance.
  - A registration (inherited, or adopted after a refused register) means one submit to that owner.
  - Every ending without one emits `drop_queued` from the pure model: parent stale, gone or unavailable, child lookup unavailable, or a refused register whose re-lookup finds nothing. The result is 0 sends and no registration.
  - The band names the retry first and then the deliberate fallback: `not inherited · reopen from parent to retry, or Alt+Return here`. The hub's example wording was cut off by the 80-column band before the retry, so it was shortened to fit.
- The round-1 integration case that asserted a pane-actor submit is flipped. A stale-parent case (re-registered to ops:9) is added, and both assert 0 sends, no registration and the band. Mutation check: with the shell ignoring `drop_queued`, both fail with "submitted to parley.nvim:1".
- Minor: the new spec is now mapped in `atlas/traceability.yaml` under modes/session_sync.
- Targeted runs pass: document_session 46, side_inherit 8, agentic_document 47, lifetime 10, single_source_sweeps 28.
- 2026-10-17, close review round 3 (BR-6, the third finding in family effect-executor-shared-tail). The queued press still leaked when inheritance ended through `changed` or a stale witness, because the shell inferred the flush from `operation == nil`. Under the third-delta rule I stopped and re-planned; the hub approved the structural fix.
  - The pure model owns the held press. `queue_submit` asks it to hold one, and only for an operation that `admits` it: the attach lookup, `confirm_parent`, an inherited register, or its re-lookup.
  - Every dispatch settles the press in one place. When the holding operation ends, by any event, the model emits exactly one `flush_queued` (into a registration, or into the plain-doc submit when no inheritance was involved) or `drop_queued` (any other inheritance ending, pending, or detach).
  - The shell submits only on `flush_queued`. `migration_busy` reads `snapshot.queued`, and the tail flush and `s.queued_submit` are gone.
  - The hub's table test (`settles a queued press exactly once on every ending`) walks 22 endings across 6 starting operations. Each case asserts one decision of the expected kind, that a stale-witness reply decides nothing, and that no second decision follows.
    - Mutation check: an always-flushing release fails it (attach → detach).
    - Writing it showed that a register outliving a `changed` goes pending, and the approved rule makes that a drop.
  - The new integration case reloads the file during inheritance with a press held: 0 sends and no registration. For an ordinary side doc the reload unloads the buffer, so this exercises the detach ending; the always-flush mutation fails it along with the two refusal cases. The `changed` ending is covered by the unit table.
- Targeted runs pass: document_session 46, side_inherit 9, agentic_document 47, owned_move 16, lifetime 10, session_sync 64.
