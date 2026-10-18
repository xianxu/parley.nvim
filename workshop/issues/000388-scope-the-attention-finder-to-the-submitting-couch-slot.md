---
id: 000388
status: open
deps: []
github_issue:
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'a38911ce3a838b66182a09e74704822403bd005c' # card fields mirrored from issue-cards; edit via sdlc
---

# Scope the attention finder to the submitting Couch slot

## Problem

Every editor shares attention.json, so a Couch pane currently lists submits made from other slots.

## Spec

Record the submitting pane's Couch slot on each attention entry. Default the finder to the current slot, with one key toggling all slots. Keep one store file and shared seen/side-doc tracking. Legacy entries without a slot remain visible everywhere; outside Couch show all. Operator design: ops/teams/devinfra/qa/xian-xu/2026-10-18-11-attention-per-slot.md.

## Done when

- Successful submits carry the originating pane slot, including when routed to a different owner.
- Current-slot view excludes other slots, includes legacy entries, and toggles to all and back without losing updates.
- Outside Couch shows all; side docs inherit their parent's submitting slot.
- Store round-trip and submission/finder regressions pass; shared tracking remains intact.

## Plan

- [ ]

## Log

### 2026-10-18
