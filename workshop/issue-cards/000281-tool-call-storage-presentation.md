---
id: '000281'
status: done
started: 2026-09-27T11:38:12-07:00
created: 2026-09-26
updated: 2026-09-27
actual_hours: 0.11
---

# Rethink tool-call storage and streaming presentation

## Problem

Tool-call content embedded in Markdown fences makes transcript parsing fragile,
especially while responses stream. The user reports that the current presentation
repeatedly expands and collapses those fenced blocks during streaming. Keeping
large tool payloads inline may not justify the parsing and display complexity.

Parley already stores images separately in a per-chat assets folder. Tool results
could follow that pattern: store the content beside the chat and keep a compact,
inspectable reference in the transcript.
