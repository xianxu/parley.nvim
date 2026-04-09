---
id: 000085
status: open
deps: [000081]
created: 2026-04-09
updated: 2026-04-09
---

# file reference freshness: staleness indicator + reload command

Parent: [issue 000081](./000081-support-anthropic-tool-use-protocol.md)

Parley's chat transcript holds *snapshots* of file content in two places, both of which can silently drift from disk:

1. **`@@file` embeds** — existing feature; content is pulled in at submit time and baked into the transcript.
2. **`📎: read_file` tool results** — new in #81; same semantics (content captured when the tool ran).

When the underlying file changes on disk after the snapshot, the transcript becomes stale without any visual signal. This ticket adds freshness visibility and a reload story that treats both reference types uniformly.

## Scope

- **Visual staleness indicator.** A highlight group / sigil on any `@@` embed or `📎: read_file` block whose recorded content differs from the current disk content. Stale = mismatched hash.
- **Reload command — single reference.** Re-freshen the cached content of the reference under the cursor, rewriting the transcript in place.
- **Reload command — current exchange.** Re-freshen all stale references within the exchange under the cursor.
- **Reload command — whole buffer.** Re-freshen everything.
- **Submit-time freshness warning** (optional): warn if the user is about to submit with stale references; offer to refresh first.

## Why this is not in #81

It applies equally to `@@` (predates #81) and to `📎: read_file` (introduced by #81), so it sits *above* #81's tool system. Building it alongside #81 would conflate tool-use plumbing with a cross-cutting cache-coherence feature.

## Done when

- (TBD — brainstorm when ticket becomes active)

## Plan

- [ ] Brainstorm after #81 lands

## Log

### 2026-04-09

- Created as a follow-up to the #81 brainstorm
- User observed that the read_file tool has the same "cached historical fact" property as existing `@@` embeds and wanted them treated consistently
