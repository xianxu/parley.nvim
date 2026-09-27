---
id: '000085'
status: wontfix
created: 2026-04-09
updated: 2026-06-29
---

# file reference freshness: staleness indicator + reload command

## Problem

Parent: [issue 000081](./000081-support-anthropic-tool-use-protocol.md)

Parley's chat transcript holds *snapshots* of file content in two places, both of which can silently drift from disk:

1. **`@@file` embeds** — existing feature; content is pulled in at submit time and baked into the transcript.
2. **`📎: read_file` tool results** — new in #81; same semantics (content captured when the tool ran).

When the underlying file changes on disk after the snapshot, the transcript becomes stale without any visual signal. This ticket adds freshness visibility and a reload story that treats both reference types uniformly.
