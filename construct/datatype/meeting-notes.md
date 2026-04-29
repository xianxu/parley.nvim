---
type: meeting-notes
name: meeting-notes
description: Use when the user wants to capture notes from a meeting, sync, or call — agenda discussed, decisions reached, action items.
---

# meeting-notes

A record of a synchronous conversation: who attended, what was discussed, what was decided, what's owed and by whom. Distinct from raw transcript — meeting-notes are distilled, not verbatim.

## Frontmatter shape

| Field | Required | Notes |
|---|---|---|
| `type` | yes | `meeting-notes` |
| `date` | yes | ISO date of the meeting (`YYYY-MM-DD`). |
| `attendees` | yes | Inline list of names: `[alice, bob, carla]`. Agent infers from context if possible, asks otherwise. |
| `topic` | yes | One short phrase. Used as the title and (kebab-cased) as a filename hint. |
| `next` | no | Date of the follow-up meeting if one is planned. |

## Body skeleton

1. `# <Topic>` — title.
2. **One-line summary** — what was the meeting about and what came out of it. Read this and skip the rest if you're skimming.
3. **Decisions** — bulleted, each one a single sentence. If there were no decisions, omit the section (don't pad with "(none)").
4. **Action items** — bulleted, each in the form `- [ ] <action> — <owner>, by <date>`. Owner and date are required; if unknown, surface that explicitly (`owner: TBD`).
5. **Discussion** — short narrative or bullets covering the substance. Don't transcribe — distill. Cut anything that doesn't inform the decisions or action items.
6. **Open questions** — things raised but not resolved. Useful for the next meeting's agenda.

## Authoring instructions

When the dispatcher applies this prototype:

1. Try to fill **date**, **attendees**, **topic** from conversation context before asking. If the chat references a calendar event or names participants, use those.
2. For **action items**, scan the conversation for verbs of commitment ("I'll send", "we'll review", "she's going to") and surface them as candidates with owner and rough deadline. Confirm before writing.
3. **Decisions** should be terse and unambiguous. If the conversation was directional but didn't actually decide, capture under **Open questions** instead.
4. Default location: `memory/work/meeting-notes/` if a `memory/` directory exists with a work-flavored subtree; otherwise propose 1–2 candidate locations from `find . -type d` output.
5. Filename: `<date>-<topic-slug>.md` (e.g., `2026-04-28-q2-roadmap.md`).

## Search recipes

Find with `rg`; no index needed.

```sh
# All meeting-notes
rg -l "^type: meeting-notes"

# Meetings on a specific date or month
rg -l "^type: meeting-notes" | xargs rg -l "^date: 2026-04-28"
rg -l "^type: meeting-notes" | xargs rg -l "^date: 2026-04"

# Meetings with a specific person (relies on inline attendee list)
rg -l "^type: meeting-notes" | xargs rg -l "attendees:.*\balice\b"

# Meetings about a topic
rg -l "^type: meeting-notes" | xargs rg -l -i "q2 roadmap"

# All open action items across every meeting
rg -l "^type: meeting-notes" | xargs rg "^- \[ \]"

# Action items owned by Alice
rg -l "^type: meeting-notes" | xargs rg "^- \[ \].*— alice"
```
