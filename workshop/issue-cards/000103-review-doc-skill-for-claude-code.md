---
id: '000103'
status: done
created: 2026-04-13
updated: 2026-05-05
actual_hours: N/A
---

# Review-doc skill for Claude Code

## Problem

The `㊷[comment]` review marker system in `parley/review.lua` is powerful but currently Parley-only. The system prompt and edit protocol are tool-agnostic — they should be portable to Claude Code as a skill (e.g. `/review-doc`).

The idea: user annotates any markdown file with `㊷[fix this transition]` markers, runs the skill, and Claude Code addresses each marker using its native `Edit` tool. Same light/heavy edit distinction. Same alternating `[user]{agent}` conversation within markers.

What we lose vs Parley: diagnostics, color-coded markers, quickfix navigation. But the core flow — annotate, run, get edits — works immediately. The system prompt is the valuable part, and it's portable.
