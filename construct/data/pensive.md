---
type: pensive
name: pensive
description: Use when the user wants to capture a train of thought, insight, brainstorm, or thinking-out-loud into a durable note. Triggers on "let's capture this", "record this as pensive", "save this thought", or `/xx-data pensive`.
---

# pensive

A timestamped record of thinking-out-loud — an insight, a half-formed idea, a tension worth holding onto. Distinct from `meeting-notes` (which records a sync) and `reference` (which is evergreen, not a moment of thought). Pensives are *the moment when the thought happened*, kept in the user's voice.

## Frontmatter shape

| Field | Required | Notes |
|---|---|---|
| `type` | yes | `pensive` |
| `date` | yes | ISO date (`YYYY-MM-DD`) the thought was captured. |
| `topic` | yes | Short phrase. Used in the title and as part of the filename slug. |
| `mode` | yes | One of: `ideas`, `eureka`, `thoughts`. `ideas` = exploratory; `eureka` = sudden insight; `thoughts` = reflective musing. |
| `description` | yes | One-line summary of what the pensive is about. Used by `rg` and by humans skimming a directory. |
| `references` | no | Inline list of related files: `[path/to/a.md, path/to/b.md]`. Empty if none. |

## Body skeleton

1. `# Pensive: <Topic>` — title.
2. The thought itself, captured as coherent prose. No fixed sub-section structure — pensives are narrative. If the thought has natural sub-parts, use sub-headings; otherwise plain paragraphs are fine.
3. **Open questions** (recommended) — unresolved tensions or follow-ups. Pensives are not conclusions; surface what's still unsettled.
4. **References** (optional) — bulleted list of related files or external links if there are more than fit in the frontmatter `references` field, or if each needs a sentence of context.

Three paragraphs is enough. Pensives are not essays.

## Authoring instructions

When the dispatcher applies this prototype:

1. **Capture the insight, not the conversation.** Rephrase into coherent prose. Don't transcribe chat back-and-forth.
2. **Keep the user's voice.** Pensives are the user's thoughts, not your summary of them. First person if the user spoke in first person.
3. **Pick `mode` from the conversation tone:**
   - `eureka` — the user just had a "oh!" moment, something clicked.
   - `ideas` — exploratory, listing possibilities.
   - `thoughts` — reflective, working through something.
   - When ambiguous, default to `thoughts`.
4. **Include open questions.** If the user voiced any tensions, uncertainties, or "I don't know yet" moments, surface them under **Open questions**.
5. **Link related documents.** Scan the conversation for file paths or document titles the user referenced; add them to frontmatter `references` (or the body References section if they need explanation).
6. **Default location:** no fixed home. Run `find <base> -type d` per the dispatcher; common candidates in order of preference: `docs/vision/` (if exists), `memory/thoughts/`, `memory/pensives/`, or the repo root. Ask the user if more than one fits.
7. **Filename:** `<date>-<NN>-pensive-<topic-slug>.md`, where `NN` is a two-digit sequence within the day (`01`, `02`, ...). Check existing files in the destination directory for that day's count and increment.
8. **Write directly.** Pensives are low-friction; do not ceremonially confirm content. Confirm only the *destination path* once if it's ambiguous, then write.

## Search recipes

```sh
# All pensives
rg -l "^type: pensive"

# Pensives on a specific date or month
rg -l "^type: pensive" | xargs rg -l "^date: 2026-04"

# Pensives by mode (eureka moments only)
rg -l "^type: pensive" | xargs rg -l "^mode: eureka"

# Pensives mentioning a term (matches topic, description, or body)
rg -l "^type: pensive" | xargs rg -l -i "agent substrate"

# Pensives that reference a specific file
rg -l "^type: pensive" | xargs rg -l "references:.*atlas/index.md"

# Pensives with unresolved open questions (find what's still open)
rg -l "^type: pensive" | xargs rg -A 20 "^## Open questions"
```

## Rules

- **Pensives are not conclusions.** Include unresolved tensions; don't sand them off into a tidy summary.
- **Keep the user's voice and framing.** These are their thoughts, not your distillation.
- **Short is fine.** Three paragraphs counts. Don't pad.
- **Be concise and precise.** No throat-clearing, no recap of context the reader already has.
- **Low-friction write.** Don't stop for content confirmation. Pensives lose their value if capture has overhead.
