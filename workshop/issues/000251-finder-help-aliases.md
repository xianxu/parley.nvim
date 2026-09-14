---
id: 000251
status: working
deps: []
github_issue:
created: 2026-09-14
updated: 2026-09-14
estimate_hours:
started: 2026-09-14T10:53:58-07:00
---

# Align shortcut help with finder controls and aliases

## Problem

Help audit found stale branch wording, missing prompt navigation controls, and finder aliases advertised but not installed. A configured Chat Finder delete list `{ "<F8>", "<F9>" }` displays both but binds only F8.

## Spec

Update Alt+i wording to create/open a sub-chat. Include prompt navigation, selection, and cancellation in finder help. Keep configuration-aware registry output; consume all resolved aliases when installing picker mappings, including help bindings. Preserve primary-only display for compact titles. Disabled entries remain unbound; reserved confirmation/cancellation keys remain protected.

## Done when

- Help describes current branch behavior and includes finder prompt basics.
- Every configured picker alias is installed and dispatches its action; disabling hides and unbinds it.
- Default string mappings and reserved-key protection remain compatible.
- Focused regressions, exact starter override smoke, full tests and lint pass.

## Plan

- [ ] Implement the approved audit corrections following workshop/plans/000251-finder-help-aliases-plan.md.
- [ ] Verify configured/default mappings, update atlas, and close through fresh review.

## Log

### 2026-09-14

- User approved updates after audit. Native starter probe confirmed F8/F9 help versus F8-only mapping. No new product choice requires clarification; implementation follows the requested corrections.
