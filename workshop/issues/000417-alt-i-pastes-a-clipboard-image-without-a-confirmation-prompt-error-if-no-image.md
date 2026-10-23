---
id: 000417
status: open
deps: []
github_issue:
created: 2026-10-22
updated: 2026-10-22
estimate_hours:
collaboration-mode: collaboration
card_mirror: '26cdece25b8fcc00cbf31fd0a27cf3aa71c1f0a8' # card fields mirrored from issue-cards; edit via sdlc
---

# Alt+i pastes a clipboard image without a confirmation prompt; error if no image

## Problem

## Spec

Operator request (10-22): **Alt+i** (paste the clipboard image as an attachment, #231/#377) currently asks for
confirmation in the Vim command line before inserting. Drop the confirmation: if the clipboard holds an image, insert
it immediately; if it doesn't, show a clear one-line error ("No image in the clipboard") and change nothing.

- Applies in Normal and Insert mode, as today.
- Any naming or placement the confirmation used to let the operator choose falls back to the existing default.
- README and atlas updated.

## Done when

- Alt+i with an image in the clipboard inserts it with no prompt (test with a fake clipboard).
- Alt+i with no image shows the error and leaves the buffer unchanged (test).

## Plan

- [ ]

## Log

### 2026-10-22
