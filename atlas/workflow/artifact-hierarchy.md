# Artifact Hierarchy

## Principle

Work artifacts live close to the issue, then graduate to permanent locations or get archived.

## Locations

| Path | Purpose | Lifecycle |
|------|---------|-----------|
| `workshop/issues/` | Active issue files | Archived to history when done |
| `workshop/plans/` | Detailed designs for complex issues | Archived with issue |
| `workshop/history/` | Completed issue files | Permanent archive, low-signal |
| `workshop/staging/` | Work-in-progress scratch | Temporary |
| `docs/vision/` | Pensive docs, brainstorms | Permanent thinking artifacts |
| `atlas/` | Sketch-level documentation | Permanent, updated with code |

## Rules

- **Simple case**: everything lives in the single issue file
- **Complex case**: issue file + detailed plan in `workshop/plans/` (same filename with `-plan` suffix)
- **When done**: issue + plan move to `workshop/history/`
- **Atlas**: updated during pre-merge checks to reflect what was built; never exhaustive
- **History**: avoid reading unless explicitly asked — it's archive, not reference
