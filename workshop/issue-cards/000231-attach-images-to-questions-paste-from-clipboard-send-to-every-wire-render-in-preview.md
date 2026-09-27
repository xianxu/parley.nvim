---
id: '000231'
status: done
started: 2026-09-12T18:17:30-07:00
created: 2026-09-10
updated: 2026-09-13
estimate_hours: 6.93
actual_hours: 4.89
---

# Attach images to questions: paste from clipboard, send to every wire, render in preview

## Problem

Operator request, 2026-09-10. Chats are text-only. A question that needs a
screenshot — a UI bug, a plot, a photograph, a diagram — currently has to be
described in words, which is both lossy and the kind of work the model is good
at doing for you if it can see the thing.

Three parts, and they are independent enough to fail separately:

1. **Capture.** Paste an image from the system clipboard into the transcript,
   saved to disk with a unique name.
2. **Send.** Get it to the model. Every wire encodes images differently.
3. **Read.** The transcript is a markdown file the operator reads and previews;
   an attached image should render in `:MarkdownPreview`, not appear as a path.

Part 3 comes free if part 1 writes ordinary markdown, which is the argument for
doing so.
