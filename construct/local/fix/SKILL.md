---
name: xx-fix
description: Use when 🤖{} or 🤖[] line appear in markdown documents
---

# Inline Review

Process 🤖 inline feedback markers in a file, following parley.nvim's review protocol.

## Usage

```
/fix <path-to-file>
```

## Marker Format

```
marker  ::= 🤖 quoted? section*
quoted  ::= "<" TEXT ">"        -- optional, at most one, first slot only
section ::= "[" TEXT "]" | "{" TEXT "}"
```

- `<>` = **quoted body** — the specific text the marker refers to (e.g. selected via drill-in). Optional; if present, scopes the instruction to that text.
- `[]` = **always human** (comments, corrections, instructions)
- `{}` = **always agent** (findings, questions, responses)

After the optional `<>`, any number of `[]` and `{}` sections in any order:

```
🤖{agent finding}[human response]{agent follow-up}[human reply]...
🤖[human comment]{agent response}[human reply]{agent response}...
🤖<quoted text>[human instruction about that text]
```
### Examples

| Marker | Meaning |
|--------|---------|
| `🤖{needs citation}` | Agent flagged an issue, awaiting human |
| `🤖{needs citation}[added ref to Smith 2024]` | Human responded — **actionable** |
| `🤖{needs citation}[]` | Human says "go ahead" — **actionable** |
| `🤖[fix this typo]` | Human comment — **actionable** |
| `🤖<foo_bar>[rename to foo_baz]` | Human scopes instruction to the quoted text — **actionable** |
| `🤖[fix this typo]{did you mean "their" → "there"?}` | Agent asked for clarification, awaiting human |
| `🤖[]` | Bare empty marker with no prior context — skip |
| `🤖{}` | Empty agent marker — skip |

### Determining if a marker is actionable

One rule: **if the last section is `[]`, act. Otherwise, skip.**

`<>` is not a section — `🤖<Q>` alone or `🤖<Q>{A}` is not actionable.

An empty `[]` means "go ahead" — the human approves the agent's prior suggestion without additional instructions; or asking agent to do its best.

Markers inside fenced code blocks are ignored.

## Process

1. **Read the file** from the supplied path
2. **Check for YAML frontmatter** at the top of the file. If `sources` and `source_precedence` are present, load them — use these to guide re-research when a marker flags a factual correction. Prefer sources in the stated precedence order (typically: codebase > Jira > doc text). If no frontmatter, proceed without re-research guidance.
3. **Parse all 🤖 markers** (and `㊷` aliases), checking the rightmost section to determine if each is actionable. Skip non-actionable markers.
4. **For each actionable marker** (last section is non-empty `[]`), read the full conversation history, then:
   - If the human's `[comment]` is a factual correction: consult the frontmatter sources (if present) to verify and re-research before rewriting — do not just rephrase the existing text
   - If you accept the instruction: apply the change to the surrounding text and remove the marker entirely
   - If you disagree with the instruction: leave the surrounding text unchanged, append a concise `{agent feedback}` to the marker (so it becomes `🤖[user input]{concise reason}` or `🤖<Q>[user input]{concise reason}`), and send the verbose reasoning in the coding session reply. The marker now ends in `{}` — non-actionable until the human responds
   - If the comment needs clarification (genuinely ambiguous, not disagreement): add `{your question here}` to the marker
   - If the comment is acknowledged and done with no doc change needed: remove the marker entirely
5. **Write the modified file** back to the same path
6. **Report** in the session what was changed, what was disagreed with (with verbose reasoning), and what markers remain pending

A feedback session is **complete when no marker ending in `[]` remains** in the document. Remaining markers ending in `{}` are awaiting the human's next reply.

## Rules

### Scope: let the human's instruction guide you

- **If `<quoted text>` is present**: the instruction targets exactly that text. Use it as the scope.
- **Otherwise default**: a marker targets the text **before** it (preceding paragraph, bullet, or sentence) — people comment at the end of what they just read
- **But follow the instruction**: if `[instruction]` references something else — a different section, a module name, the overall tone, the whole document — apply it to that scope instead
- Examples:
  - `🤖[fix this typo]` → fix the preceding text
  - `🤖<foo_bar>[rename to foo_baz]` → rename that exact identifier
  - `🤖[no, module_x doesn't call module_y]` → find and correct that factual claim wherever it appears
  - `🤖[the overall tone is too cheeky, we should be more serious]` → adjust tone across the document

### General

- When removing a marker, leave the corrected text in place with no trace of the marker
- When adding an agent question, append `{question}` to the marker
- Respect existing voice and style in the surrounding document
- Do not rewrite sections that have no markers and are not referenced by any marker's instruction. 
