---
id: 000239
status: open
created: 2026-09-12
updated: 2026-09-12
estimate_hours:
github_issue:
---

# Model-generated images: save to the chat assets folder, link from the answer

## Problem

Operator request, 2026-09-12, while starting #231. #231 opens a fork in the
road: parley had been keeping the whole chat state inside the transcript, and
an image cannot reasonably be embedded in a markdown file, so #231 introduces a
per-chat sidecar folder for operator-pasted images. The same argument applies
to images the *model* produces. Today there is no path for one at all: a
model that can draw has nowhere to put the bytes, and a model that cannot draw
has no tool it could ask.

This is the other side of #231 — the transcript as index, the folder as the
bytes, one writer for both directions.
