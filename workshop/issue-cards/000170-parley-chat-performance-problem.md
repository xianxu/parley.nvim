---
id: '000170'
status: done
started: 2026-07-11T21:57:07-07:00
created: 2026-07-08
updated: 2026-07-12
estimate_hours: 14.15
actual_hours: N/A
---

# parley chat performance problem

## Problem

Long Parley chats become noticeably less responsive to ordinary editing around
1,000 lines. `:MarkdownPreview` amplifies the symptom and is likely the dominant
cost when enabled, but it is external to Parley and therefore outside this
issue's optimization scope.

Parley's viewport decoration provider renders only the visible region plus a
small margin, but its redraw path still reads the complete buffer to locate the
managed footnote footer and may scan backward line-by-line for structural
highlight state. Separately, every `TextChangedI` event rebuilds timezone and
managed-footnote diagnostics from the full buffer. These costs scale with total
document length even when the edit and viewport are local.

The exchange model is not rebuilt per keystroke: the authoritative chat parse
happens when submitting/resubmitting, and a live model is maintained during
streaming/tool recursion. A continuously maintained incremental exchange parser
would therefore add complexity without addressing the current typing path.
