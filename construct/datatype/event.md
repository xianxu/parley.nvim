---
type: event
name: event
description: Use when the user wants to capture a time-bound plan — a launch, a conference, a deadline-driven prep effort. Triggers on "track this launch", "capture conference prep", "plan for the deadline".
---

# event

A plan tied to a specific moment in time. Has a clear before/during/after shape. Distinct from a `procedure` (replayable, not time-bound) and a `travel-plan` (specialized for trips).

## Frontmatter shape

| Field | Required | Notes |
|---|---|---|
| `type` | yes | `event` |
| `name` | yes | Short identifier — what is this event. |
| `date` | yes | ISO date of the event itself, or the deadline. For multi-day events, use the start date. |
| `end` | no | ISO end date for multi-day events. |
| `status` | yes | `planning`, `imminent`, `in-progress`, `done`, `cancelled`. |

## Body skeleton

1. `# <Name> — <date>` — title.
2. **One-line summary** — what's the event and what's the user's role.
3. **Before** — preparation tasks. Bulleted, each in the form `- [ ] <task> — by <date>`.
4. **During** — what happens on the day; key contacts, schedule, things to bring. Skip if irrelevant.
5. **After** — follow-ups, debrief notes, lessons. Mostly empty until the event happens.
6. **Open questions** — unresolved items.

## Authoring instructions

When the dispatcher applies this prototype:

1. **Date** is the anchoring field — confirm it before anything else. If only a fuzzy time was given, ask for concrete date.
2. **Status** defaults to `planning`. Suggest bumping to `imminent` if the date is within a week of today.
3. Pull preparation tasks from the conversation; surface unknown owners/dates explicitly rather than guessing.
4. **Default location:** under a `memory/` directory if one exists, categorized by event type (`memory/work/launches/`, `memory/life/conferences/`). Run `find memory -type d` to discover structure.
5. Filename: `<date>-<name-slug>.md`.
6. Don't pad `Before/During/After` sections with empty bullets. Empty sections are fine while planning is light.

## Search recipes

```sh
# All events
rg -l "^type: event"

# Upcoming events (still in planning or imminent)
rg -l "^type: event" | xargs rg -l "^status: planning|^status: imminent"

# Events in a year or month
rg -l "^type: event" | xargs rg -l "^date: 2026"
rg -l "^type: event" | xargs rg -l "^date: 2026-06"

# Events by name fragment
rg -l "^type: event" | xargs rg -l -i "^name:.*launch"

# Open prep tasks across all events
rg -l "^type: event" | xargs rg "^- \[ \]"
```
