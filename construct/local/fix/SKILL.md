---
name: xx-fix
description: Use when 🤖{} or 🤖[] or 🤖~~ markers appear in markdown documents
---

# Inline Review

Process 🤖 inline markers in a file, following the review convention
documented in the ariadne workshop target `review-convention.md`. That target
is the canonical grammar; this skill is the agentic side of it.

## Usage

```
/fix <path-to-file>
```

## Marker Format

```
marker     ::= 🤖 reference? section*
reference  ::= "<" TEXT ">" | "~" TEXT "~"     -- optional, at most one, first slot only
section    ::= "[" TEXT "]" | "{" TEXT "}"
```

Two **reference** enclosures (anchor to prior text):

- `<X>` — text quoted from the prior edition; preserved on resolve.
- `~X~` — text marked for deletion; markdown strikethrough renders the preview.

Two **commentary** enclosures (alternate freely):

- `[]` = **always human** (comments, corrections, instructions, replacements).
- `{}` = **always agent** (findings, suggestions, questions, responses).

After the optional reference, any chain of `[]`/`{}` sections in any order:

```
🤖{agent finding}[human response]{agent follow-up}[human reply]...
🤖[human comment]{agent response}[human reply]{agent response}...
🤖<quoted text>[human instruction about that text]
🤖~old text~                       -- robot proposes deletion
🤖~old text~{new text}             -- robot proposes replacement
🤖~old text~[new text]             -- human-authored replacement
```

### Examples

| Marker | Meaning |
|--------|---------|
| `🤖{needs citation}` | Agent flagged an issue, awaiting human |
| `🤖{needs citation}[added ref to Smith 2024]` | Human responded — **actionable** |
| `🤖{needs citation}[]` | Human says "go ahead" — **actionable** |
| `🤖[fix this typo]` | Human comment — **actionable** |
| `🤖<foo_bar>[rename to foo_baz]` | Human scopes instruction to the quoted text — **actionable** |
| `🤖~old phrase~[new phrase]` | Human-authored replacement — **actionable** (apply per §5) |
| `🤖~old phrase~` | Robot proposed a deletion, awaiting human — skip |
| `🤖~old phrase~{better phrase}` | Robot proposed a replacement, awaiting human — skip |
| `🤖[fix this typo]{did you mean "their" → "there"?}` | Agent asked for clarification, awaiting human |
| `🤖[]` | Bare empty marker with no prior context — skip |
| `🤖{}` | Empty agent marker — skip |

### Determining if a marker is actionable

One rule: **if the last section is `[]`, act. Otherwise, skip.**

References (`<X>`, `~X~`) are not sections — `🤖<Q>` alone or `🤖<Q>{A}` is not
actionable; a bare `🤖~D~` (or `🤖~D~{N}`) is a robot-authored edit proposal
awaiting the operator's Alt+a / Alt+r in parley.nvim, so /xx-fix skips it.

An empty `[]` means "go ahead" — the human approves the agent's prior
suggestion without additional instructions, or asks the agent to do its best.

Markers inside fenced code blocks are ignored.

## Process

1. **Read the file** from the supplied path.
2. **Check for YAML frontmatter** at the top of the file. If `sources` and
   `source_precedence` are present, load them — use these to guide re-research
   when a marker flags a factual correction. Prefer sources in the stated
   precedence order (typically: codebase > Jira > doc text). If no frontmatter,
   proceed without re-research guidance.
3. **Parse all 🤖 markers** (and `㊷` aliases), checking the rightmost section
   to decide actionability. Skip non-actionable markers.
4. **For each actionable marker** (last section is non-empty `[]`), read the
   full chain, then:
   - **Replacement form** `🤖~D~[N]` (no robot reply after): the operator
     authored a literal replacement — substitute `D` with `N` in the surrounding
     text and remove the marker. This is the §5 accept path.
   - **Instruction form** `🤖[H]` or `🤖<X>[H]`: interpret `H` as a directive.
     If `H` is a factual correction, consult frontmatter sources before
     rewriting — do not just rephrase. Apply the change and remove the marker.
   - **Reply-after-robot form** `🤖{R}[H]`, `🤖<X>{R}[H]`, `🤖~D~{R}[H]`,
     etc.: `H` is the operator's response to the robot's prior `{R}`. Read both;
     `H` may be "yes apply R" (→ apply R and remove the marker) or a new
     instruction overriding R (→ apply H, remove the marker).
   - **Disagreement**: if you disagree with the operator's instruction, leave
     the surrounding text unchanged, append a concise `{agent feedback}` to the
     marker (so it ends in `{}` — non-actionable until the human responds), and
     send the verbose reasoning in the coding-session reply.
   - **Need clarification** (genuinely ambiguous, not disagreement): add
     `{your question here}` to the marker.
   - **Acknowledged, no doc change needed**: remove the marker entirely.
5. **Write the modified file** back to the same path.
6. **Report** in the session what changed, what you disagreed with (with
   verbose reasoning), and what markers remain pending.

A feedback session is **complete when no marker ending in `[]` remains** in
the document. Remaining markers ending in `{}` (or bare edit proposals like
`🤖~D~`, `🤖~D~{N}`) are awaiting the human's next gesture.

## Operator-initiated bulk resolution (review-convention §6)

When the operator says something like *"we're aligned, please resolve the
outstanding markers"*, you are explicitly authorized to walk every remaining
chain and apply the §5 accept/reject table from the review convention. For
each chain, read the *last* commentary block — typically the trailing `[H]` —
and interpret it as accept or reject. Do **not** resolve markers the operator
has not acknowledged; resolution is always operator-initiated. §5 summary:

| Marker | Accept to | Reject to |
|---|---|---|
| `🤖[H]` | empty | same |
| `🤖<X>[H]` | `X` | same |
| `🤖{R}` | `R` | empty |
| `🤖[H]{R}` / `🤖{R}[H]` | empty | same |
| `🤖~D~` | empty (deletion applied) | `D` |
| `🤖~D~{N}` | `N` | `D` |
| `🤖~D~[N]` | `N` | `D` |
| longer `[]{}` chains | empty (chain discarded, surrounding text untouched) | same |

## Rules

### Scope: let the human's instruction guide you

- **If a `<quoted text>` reference is present**: the instruction targets exactly
  that text. Use it as the scope.
- **If a `~deleted text~` reference is present**: the instruction targets
  exactly that text — substitution or deletion per §5.
- **Otherwise default**: a marker targets the text **before** it (preceding
  paragraph, bullet, or sentence) — people comment at the end of what they
  just read.
- **But follow the instruction**: if `[instruction]` references something else —
  a different section, a module name, the overall tone, the whole document —
  apply it to that scope instead.
- Examples:
  - `🤖[fix this typo]` → fix the preceding text
  - `🤖<foo_bar>[rename to foo_baz]` → rename that exact identifier
  - `🤖~deprecated paragraph~[new paragraph text]` → substitute paragraph
  - `🤖[no, module_x doesn't call module_y]` → find and correct that factual claim wherever it appears
  - `🤖[the overall tone is too cheeky, we should be more serious]` → adjust tone across the document

### General

- When removing a marker, leave the corrected text in place with no trace of the marker.
- When adding an agent question, append `{question}` to the marker.
- Respect existing voice and style in the surrounding document.
- Do not rewrite sections that have no markers and are not referenced by any marker's instruction.
