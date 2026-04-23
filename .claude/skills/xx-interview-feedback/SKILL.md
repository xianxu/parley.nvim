---
name: xx-interview-feedback
description: "Use when processing interview notes taken in parley.nvim interview mode into structured hiring feedback. Invoked as /xx-interview-feedback <path-to-notes>."
---

# Interview Feedback Generator

Transform raw interview notes (taken in parley.nvim interview mode) into structured hiring feedback written in Xian's voice.

## Usage

```
/xx-interview-feedback <path-to-notes.md>
```

## Input Format

The input file uses parley.nvim's interview mode conventions:

```
:00min what the candidate told me about [my own question to TC] {and my thinking of their responses}
All other text are prefilled question or other reminders.
```

- **`:NNmin` lines** — What the candidate told the interviewer, timestamped by elapsed minutes
- **`[square bracket text]`** — Interviewer's questions to TC or factual notes
- **`{curly brace text}`** — Interviewer's thinking, reactions, and assessments of TC's responses
- **All other text** — Prefilled template questions or reminders (ignore for feedback generation)
- **Level information** — Mentioned in the document (e.g., L5, L6, Senior, Staff)

## Process

1. **Read the interview notes file** from the supplied path
2. **Check for existing feedback file** at the `-feedback` suffix path. If it exists, read it and treat the user's prior edits as authoritative. Preserve their changes (e.g., adjusted conclusions, added commentary) and use the existing feedback as a starting point rather than generating from scratch.
3. **Read the voice guide** from `~/.personal/xian-writing-style.md`
3. **Analyze the notes** — extract:
   - Topics discussed and key exchanges
   - Level signals (both positive and concerning)
   - Concrete examples of strength and weakness from the conversation
   - Your bracket comments as primary assessment signals
4. **Generate feedback** in the output format below, written in Xian's voice per the style guide
5. **Present the feedback** and **write the feedback file** in one step — write directly to the same directory as the notes with `-feedback` suffix. For input `path/to/foo-bar.md`, write to `path/to/foo-bar-feedback.md`. Do not wait for approval before writing.

## Output Format

Write in Xian's voice — direct, concrete, example-driven. No throat-clearing. Lead with the conclusion.

```
## Conclusion

Overall [strong/mixed/weak] hire at [level], [signal at adjacent level if any],
main concern at [higher level] is [specific concern].

## What We Talked About

[2-3 sentence summary of the interview topics and flow]

## Strengths

- [Strength area]: [concrete example from conversation]
- ...

## Weaknesses

- [Weakness area]: [concrete example from conversation]
- ...
```

### Interview-Type-Specific Sections

Detect the interview type from the document title/headers and add relevant sections:

**Tech Deepdive (TDD)** — add after Weaknesses:

```
## Scope

[Assess the project scope TC demonstrated. How large was the system? How many
teams/services involved? Was it greenfield or brownfield? Does the scope match
the level they're interviewing for?]

## Cross-Functional Complexity

[Assess xfn complexity. Did the project require alignment across teams, orgs,
or functions (PM, legal, ops, data science)? How did TC navigate competing
requirements? Was there evidence of driving alignment vs. just executing?]
```

### Writing Rules

- **Lead with the verdict** — the first sentence is your hiring recommendation
- **Every point needs a concrete example** — pull directly from the `:NNmin` lines
- **Use bracket comments as anchors** — your `[in-the-moment reactions]` are the most honest signal, build around them
- **Be direct about concerns** — no hedging, no "might benefit from"
- **Keep it short** — hiring committees skim; a few strong examples beat many weak ones
- **Match Xian's voice** — short sentences, concrete over abstract, first person, no corporate speak
- **Use TC, not the candidate's name** — refer to the candidate as "TC" (The Candidate) throughout, never by name
- **Rephrase, don't copy** — raw notes are typed during the interview and full of typos; always rephrase into clean prose, never copy verbatim from the notes
- **No timestamp references** — the raw notes are not submitted with the feedback, so `:NNmin` references are meaningless to readers; describe the context instead
- **No em dashes** — do not use `—` (em dash) in the output; use commas, periods, parentheses, or colons instead
- **Use level codes** — use L5 for Senior Engineer, L6 for Staff Engineer, L7 for Senior Staff, etc. Prefer "L5" over "Senior" and "L6" over "Staff" in the feedback
- **Support ㊷[] inline feedback** — if the existing feedback file contains ㊷[] markers (parley.nvim review format), process them: each marker refers to the text **before** it (the preceding paragraph, bullet, or section). Apply the user's corrections, answer their questions, and remove resolved markers. See `/xx-review` for the full marker protocol
