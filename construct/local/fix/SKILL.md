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

A single marker type `🤖` with alternating sections:

- `[]` = **always human** (comments, corrections, instructions)
- `{}` = **always agent** (findings, questions, responses)

Sections alternate between human and agent. Either side can start:

```
🤖{agent finding}[human response]{agent follow-up}[human reply]...
🤖[human comment]{agent response}[human reply]{agent response}...
```
### Examples

| Marker | Meaning |
|--------|---------|
| `🤖{needs citation}` | Agent flagged an issue, awaiting human |
| `🤖{needs citation}[added ref to Smith 2024]` | Human responded — **actionable** |
| `🤖{needs citation}[]` | Human says "go ahead" — **actionable** |
| `🤖[fix this typo]` | Human comment — **actionable** |
| `🤖[fix this typo]{did you mean "their" → "there"?}` | Agent asked for clarification, awaiting human |
| `🤖[]` | Bare empty marker with no prior context — skip |
| `🤖{}` | Empty agent marker — skip |

### Determining if a marker is actionable

One rule: **if the last section is `[]`, act. Otherwise, skip.**

An empty `[]` means "go ahead" — the human approves the agent's prior suggestion without additional instructions; or asking agent to do its best.

Markers inside fenced code blocks are ignored.

## Process

1. **Read the file** from the supplied path
2. **Check for YAML frontmatter** at the top of the file. If `sources` and `source_precedence` are present, load them — use these to guide re-research when a marker flags a factual correction. Prefer sources in the stated precedence order (typically: codebase > Jira > doc text). If no frontmatter, proceed without re-research guidance.
3. **Parse all 🤖 markers** (and `㊷` aliases), checking the rightmost section to determine if each is actionable. Skip non-actionable markers.
4. **For each actionable marker** (last section is non-empty `[]`), read the full conversation history, then:
   - If the human's `[comment]` is a factual correction: consult the frontmatter sources (if present) to verify and re-research before rewriting — do not just rephrase the existing text
   - If the comment is a correction or rewrite request: apply the change to the surrounding text and remove the marker
   - If the comment needs clarification: add an agent question `{your question here}` to the marker (making `{}` the last section — now non-actionable until human replies)
   - If the comment is acknowledged and done: remove the marker entirely
5. **Write the modified file** back to the same path
6. **Report** what was changed and what markers remain pending

## Rules

### Scope: let the human's instruction guide you

- **Default**: a marker targets the text **before** it (preceding paragraph, bullet, or sentence) — people comment at the end of what they just read
- **But follow the instruction**: if `[instruction]` references something else — a different section, a module name, the overall tone, the whole document — apply it to that scope instead
- Examples:
  - `🤖[fix this typo]` → fix the preceding text
  - `🤖[no, module_x doesn't call module_y]` → find and correct that factual claim wherever it appears
  - `🤖[the overall tone is too cheeky, we should be more serious]` → adjust tone across the document

### General

- When removing a marker, leave the corrected text in place with no trace of the marker
- When adding an agent question, append `{question}` to the marker
- Respect existing voice and style in the surrounding document
- Do not rewrite sections that have no markers and are not referenced by any marker's instruction. 
