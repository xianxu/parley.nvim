---
id: 000104
status: open
deps: []
created: 2026-04-13
updated: 2026-04-13
---

# Chat-to-document lineage and context threading

When a chat session produces a document (e.g. "create a letter at docs/letter.md"), that document loses its provenance — the reasoning that created it. This issue is about making that lineage explicit and usable.

The mental model: **the chat tree is the reasoning process, the documents are the fruits.** When reviewing a document, the chats that produced it should be available as context.

## The workflow

1. User starts chat-1 with AI
2. At some point, user asks chat-1 to create a document at a specific location (e.g. `docs/letter-to-founder.md`)
3. Document is created, link inserted into chat via tool call
4. User follows link to doc-1. Frontmatter records lineage: `source: chat-1`
5. In review mode on doc-1, the system sends chat-1's history as context, then addresses `㊷[]` markers with full understanding of why things were written that way

## Key design decisions

**Context scoping:** Follow the chat tree path-to-root. Only the lineage relevant to this document, not the whole tree.

**DAG, not tree:** A document can be touched by multiple chats. Chat-1 creates it, chat-2 refines tone, chat-3 adds nuance. The frontmatter becomes a provenance record:

```yaml
sources:
  - chat: chat-1
    role: initial draft, established thesis and structure
  - chat: chat-2
    role: voice adaptation
  - chat: chat-3
    role: added nuance on unsolved problems
```

**Context size:** Path-to-root from each source chat. May need summarization for long chat histories.

## Done when

- Documents created from chats automatically get lineage frontmatter
- Review mode on a document with lineage includes the source chat context
- Multiple source chats (DAG) are supported

## Plan

- [ ] Design frontmatter format for lineage
- [ ] Implement tool-call hook that records lineage when a document is created from chat
- [ ] Modify review flow to load source chat context
- [ ] Handle DAG case (multiple source chats)
- [ ] Consider summarization for large chat histories

## Log

### 2026-04-13

Issue created from brainstorming. Key insight: chat tree is the reasoning process, documents are the fruits. "Path to root" naturally scopes context. Multiple chats touching one document form a DAG — each source should explain its relationship to the document.
