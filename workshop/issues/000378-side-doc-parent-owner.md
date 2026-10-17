---
id: 000378
status: working
deps: []
github_issue:
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
collaboration-mode: collaboration
card_mirror: '24d98dc86127fdb0cdf4433ce1f52d348c754f2a' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-17T14:45:11-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
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
- [ ] Unit (`document_session`), as event sequences:
  - absent → confirm_parent → register with no send;
  - a registered child keeps its registration;
  - a stale parent (ID or Owner mismatch) and an unavailable parent lookup both refuse;
  - an unavailable child lookup drops the hint;
  - a hint that arrives during the attach lookup is applied;
  - an owner-conflict leads to a lookup and adoption;
  - after a refusal, a later inherit succeeds.
- [ ] Integration (new `tests/integration/agentic_document_side_inherit_spec.lua`, using the real `OpenFileUnderCursor` and the persistent fake registry; open_buf is not stubbed):
  - the parent is registered to ops:0 and the pane actor is parley.nvim:1. Alt+o onto `parent.side/child.md` registers the child to ops:0, and the send count stays 0;
  - a child already registered to another owner is unchanged;
  - a non-side link registers nothing;
  - with `FAKE_COUCH_REGISTRY_MODE=malformed` nothing is registered and the band says so, and a later navigation with the fake healthy succeeds.
- [ ] Atlas: one paragraph on side-doc ownership inheritance.

Open question for the TL: should inheritance also require the side doc's `type: side-doc` frontmatter (the attention finder's filter)? My default is folder membership only.

## Log

### 2026-10-17

Deterministic fake-only reproduction through the actual opener: register parent.md to ops:0, select pane actor parley.nvim:1, open [side](parent.side/child.md) with OpenFileUnderCursor. Navigation issued exactly couch --session-sync lookup ABS_CHILD --json. Child phase was plain, identity null, registry entry absent, send count zero. Parent registration retained Owner and RegisteredOwner ops:0. Scratch removed and process census clean. Local evidence: /tmp/parley-373-side-open-gap.log; runner /tmp/parley-373-side-open-gap.lua, invoked by make -f /tmp/parley-373-side-open-gap.mk test-373-side-open-gap. The observed argv and state above are the durable evidence; temporary paths are not required to understand the failure.
