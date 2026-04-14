---
id: 000103
status: open
deps: []
created: 2026-04-13
updated: 2026-04-13
---

# Review-doc skill for Claude Code

The `㊷[comment]` review marker system in `parley/review.lua` is powerful but currently Parley-only. The system prompt and edit protocol are tool-agnostic — they should be portable to Claude Code as a skill (e.g. `/review-doc`).

The idea: user annotates any markdown file with `㊷[fix this transition]` markers, runs the skill, and Claude Code addresses each marker using its native `Edit` tool. Same light/heavy edit distinction. Same alternating `[user]{agent}` conversation within markers.

What we lose vs Parley: diagnostics, color-coded markers, quickfix navigation. But the core flow — annotate, run, get edits — works immediately. The system prompt is the valuable part, and it's portable.

## Done when

- A Claude Code skill exists that reads a file, finds `㊷[]` markers, and addresses them via edits
- Both light edit and heavy revision modes work
- The skill reuses the same system prompt logic from `review.lua`

## Plan

- [ ] Extract system prompt from `review.lua` into a portable format
- [ ] Create Claude Code skill definition
- [ ] Test on a real document with multiple markers

## Log

### 2026-04-13

Issue created from brainstorming session about cross-pollination between Parley and Claude Code.
