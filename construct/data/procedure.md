---
type: procedure
name: procedure
description: Use when the user wants to capture steps to follow for a repeatable or in-flight task — a multi-step setup, a recurring workflow, a one-off but complex sequence. Triggers on "save these steps", "capture this procedure", "remember how I did X".
---

# procedure

A sequence of steps to follow, written so a future self (or a different person) can replay them without rediscovering the order. Distinct from a `reference` (which is data) and an `event` (which has a deadline).

## Frontmatter shape

| Field | Required | Notes |
|---|---|---|
| `type` | yes | `procedure` |
| `goal` | yes | One sentence: what you achieve by following this. Used as title. |
| `prerequisites` | no | List of things that must be true before starting (access, credentials, tools installed). |
| `last-run` | no | ISO date of the most recent execution. Useful for procedures that touch external systems where things drift. |

## Body skeleton

1. `# <Goal>` — title.
2. **One-line summary** — restate the goal in plainer language.
3. **Prerequisites** (if any) — bulleted, each one independently checkable.
4. **Steps** — numbered list. Each step:
   - Imperative voice ("Run …", "Open …", "Click …").
   - Includes the command, URL, or specific UI path when applicable.
   - Calls out what success looks like when it's not obvious.
5. **Gotchas** — things that have bitten you before. One per bullet.
6. **Verification** — how to confirm the procedure worked end-to-end.

## Authoring instructions

When the dispatcher applies this prototype:

1. Reconstruct steps from the conversation if the user just walked through them. Number them in the order they were performed, not the order they were mentioned.
2. Surface placeholder values (account IDs, tokens, names) explicitly with `<…>` so the next reader can substitute.
3. **Gotchas:** lift directly from anything the user said went wrong, was surprising, or required backtracking.
4. **Default location:** under a `memory/` directory if one exists, grouped by what the procedure operates on (e.g., `memory/work/onboarding/`, `memory/life/finance/`). Run `find memory -type d` to discover existing structure.
5. Filename: kebab-case slug of the goal (e.g., `set-up-apple-developer-id.md`).

## Search recipes

```sh
# All procedures
rg -l "^type: procedure"

# Procedures mentioning a specific tool or system
rg -l "^type: procedure" | xargs rg -l -i "kubectl"
rg -l "^type: procedure" | xargs rg -l -i "apple developer"

# Procedures by goal phrase
rg -l "^type: procedure" | xargs rg -l "^goal:.*deploy"

# Procedures not run in 2026 (stale)
rg -l "^type: procedure" | xargs rg -L "^last-run: 2026"

# All gotchas across procedures (find what tends to go wrong)
rg -l "^type: procedure" | xargs rg -A 20 "^## Gotchas"
```
