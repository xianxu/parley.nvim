---
id: 000105
status: open
deps: []
created: 2026-04-13
updated: 2026-04-13
---

# Review visual feedback and progress component

The review flow (`<C-g>ve` / `<C-g>vr`) sends the whole document to the API and waits — no visual indication of progress. For documents with many markers, this feels unresponsive.

Two parts to this:

## 1. Review-specific feedback

Parse the streaming response as it arrives. The `review_edit` tool call comes back as JSON — detect each `old_string` match in the buffer and highlight it as "being addressed" as the stream progresses. Keep batch processing (one-by-one has problems: later markers may need context from earlier edits). Just show progress visually as the batch resolves.

Options:
- Per-marker status: `㊷` changes color/icon as each marker gets resolved (pending -> processing -> done)
- Statusline progress: "Reviewing 3/7 markers..." via existing lualine integration

## 2. General progress component

As Parley evolves beyond pure chat transcripts (review, file attachments, background projects), a lightweight progress system would be useful across features. Small event-based API:

```lua
parley.progress.start("review", {total = 7, label = "Reviewing markers"})
parley.progress.update("review", {current = 3})
parley.progress.finish("review")
```

Lualine, floating window, or virtual text can subscribe and render. Keep data layer separate from display — different features emit progress events, UI components consume them.

## Done when

- Review mode shows visual progress as markers are addressed
- A reusable progress component exists that other features can hook into

## Plan

- [ ] Design progress event API
- [ ] Implement progress emitter in review flow (parse streaming response for per-edit progress)
- [ ] Add lualine progress display
- [ ] Consider per-marker highlight changes (pending/processing/done)

## Log

### 2026-04-13

Issue created from brainstorming. Current review is batch (correct — one-by-one has interaction problems between markers). Visual feedback should come from parsing the streaming response, not changing the processing model.
