---
id: '000104'
status: punt
created: 2026-04-13
updated: 2026-05-05
---

# Chat-to-document lineage and context threading

## Problem

When a chat session produces a document (e.g. "create a letter at docs/letter.md"), that document loses its provenance — the reasoning that created it. This issue is about making that lineage explicit and usable.

The mental model: **the chat tree is the reasoning process, the documents are the fruits.** When reviewing a document, the chats that produced it should be available as context.
