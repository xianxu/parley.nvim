---
name: xx-pensive
description: "Use when the user wants to capture a train of thought, insight, or brainstorm into a pensive document. Invoked as /xx-pensive <topic-slug> or automatically when the user says 'let's capture this' or 'record this as pensive'."
---

# Pensive

Capture a train of thought into `docs/vision/` as a timestamped pensive document.

## Usage

```
/xx-pensive <topic-slug>
```

## Process

1. **Create the file** at `docs/vision/YYYY-MM-DD-NN-pensive-<topic-slug>.md` using today's date and a two-digit sequence number (NN). Check existing files for today's date to determine the next number (01, 02, 03, etc.).
2. **Write the pensive** with this format:
   - Title: `# Pensive: <Topic>`
   - Metadata: `**Date:** YYYY-MM-DD` and `**Status:** Thinking out loud`
   - Horizontal rule
   - The content from the current conversation, captured as coherent prose
3. **Write directly**, no approval needed. These are thinking-out-loud documents, not polished artifacts.

## Rules

- Capture the insight, not the conversation. Rephrase into coherent prose, don't transcribe chat back-and-forth.
- Keep the user's voice and framing. These are their thoughts, not summaries.
- Include open questions and unresolved tensions. Pensives are not conclusions.
- Link to related documents if they exist in the repo.
- Short is fine. A pensive can be 3 paragraphs.
