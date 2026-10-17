---
id: 000378
status: open
deps: []
github_issue:
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'a3d313746ad08552ef53163cc3b4b1802c939323' # card fields mirrored from issue-cards; edit via sdlc
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

- [ ]

## Log

### 2026-10-17

Deterministic fake-only reproduction through the actual opener: register parent.md to ops:0, select pane actor parley.nvim:1, open [side](parent.side/child.md) with OpenFileUnderCursor. Navigation issued exactly couch --session-sync lookup ABS_CHILD --json. Child phase was plain, identity null, registry entry absent, send count zero. Parent registration retained Owner and RegisteredOwner ops:0. Scratch removed and process census clean. Local evidence: /tmp/parley-373-side-open-gap.log; runner /tmp/parley-373-side-open-gap.lua, invoked by make -f /tmp/parley-373-side-open-gap.mk test-373-side-open-gap. The observed argv and state above are the durable evidence; temporary paths are not required to understand the failure.
