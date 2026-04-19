---
name: fix
description: "Use proactively — without being asked — in two situations: (1) when performing a document review, write findings as 🤖[] markers inline in the file rather than a separate report; (2) when a file contains ㊷[] or 🤖[] inline markers to process, apply them. Invoked as /fix <path-to-file> for processing markers."
---

# Inline Review

Process ㊷[] inline feedback markers in a file, following parley.nvim's review protocol.

## Usage

```
/xx-review <path-to-file>
```

## Marker Format

Two marker types with opposite initiators:

### ㊷ — Human-initiated

```
㊷[user comment]{agent response}[user reply]{agent response}...
```

- `[]` brackets = user turns (comments, corrections, requests)
- `{}` braces = agent turns (questions, acknowledgments, explanations)
- **Odd section count** (1, 3, 5) = human last spoke = **ready for agent to process**
- **Even section count** (2, 4) = agent last spoke = awaits user response (skip it)

### 🤖 — Agent-initiated

```
🤖[agent finding]{human response}[agent follow-up]{human response}...
```

- `[]` brackets = agent turns (findings, questions, flagged issues)
- `{}` braces = user turns (corrections, instructions, confirmations)
- **Odd section count** (1, 3, 5) = agent last spoke = awaiting human response (**skip it**)
- **Even section count** (2, 4) = human last spoke = **ready for agent to process**

Markers inside fenced code blocks are ignored.

## Process

1. **Read the file** from the supplied path
2. **Check for YAML frontmatter** at the top of the file. If `sources` and `source_precedence` are present, load them — use these to guide re-research when a marker flags a factual correction. Prefer sources in the stated precedence order (typically: codebase > Jira > doc text). If no frontmatter, proceed without re-research guidance.
3. **Parse all ㊷ markers**, identifying:
   - Ready markers (odd section count): process these
   - Pending markers (even section count): leave these untouched
4. **For each ready marker**, read the comment/conversation history, then:

   **For ㊷ markers (human-initiated, odd count = ready):**
   - If the comment is a factual correction: consult the frontmatter sources (if present) to verify and re-research before rewriting — do not just rephrase the existing text
   - If the comment is a correction or rewrite request: apply the change to the surrounding text and remove the marker
   - If the comment needs clarification: add an agent question `{your question here}` to the marker (making it even/pending)
   - If the comment is acknowledged and done: remove the marker entirely

   **For 🤖 markers (agent-initiated, even count = ready):**
   - Read the human's `{response}` — it is the instruction to act on
   - Apply the human's instruction to the text the marker refers to, then remove the marker
   - If the human's response is unclear: append `[clarifying question]` to the marker and leave it in place
4. **Write the modified file** back to the same path
5. **Report** what was changed and what markers remain pending

## Responding to AI Critiques

When a `🤖->` critique line is followed by a `㊷[]` marker, this is the human responding to the AI's critique with instructions:

```
Some text the author wrote.

🤖-> This claim needs grounding. Your experience with Y would be the evidence.
㊷[good point, weave in my example from last week's tool system build]
```

In this case:
1. Read the `🤖->` critique to understand the problem
2. Read the `㊷[]` to understand the human's instruction for resolving it
3. Apply the human's instruction to the text **before** the `🤖->` line
4. Remove both the `🤖->` line and the `㊷[]` marker
5. If the human's instruction is unclear, add `{question}` to the ㊷ marker and leave both lines in place

## Rules

- Preserve all text outside of markers exactly as-is
- Preserve `🤖->` lines that do NOT have a `㊷[]` marker after them (unresolved critiques the human hasn't addressed yet)
- A marker refers to the text **before** it, up to the previous natural boundary (paragraph, bullet, section). In a typical reading flow, you read and comment at the end of what you just read
- Only modify text that a marker refers to (the preceding paragraph, bullet, or section)
- **Exception**: if the marker explicitly mentions a bigger or different scope (e.g. "this whole article", "the next section about XXX", "all the bullet points above"), follow what the marker says instead of defaulting to the preceding block
- When removing a marker, leave the corrected text in place with no trace of the marker
- When adding an agent question, append `{question}` inside the existing marker
- Respect the user's voice and style in the surrounding document
- Do not rewrite sections that have no markers
