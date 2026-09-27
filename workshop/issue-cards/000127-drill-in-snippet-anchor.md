---
id: '000127'
status: done
created: 2026-06-10
updated: 2026-06-10
estimate_hours: 2.5
actual_hours: 1.51
---

# Smart-snippet anchoring for unquoted drill-in comments

## Problem

When an unquoted marker `🤖[comment]` is gathered into the next user turn
(`drill_in.gather_and_strip`), the marker is stripped from the reply and the
comment floats into the new turn **with no anchor** — the next-turn agent reads
a free-floating comment with no idea which part of its prior reply it refers to.
Today only the *quoted* form `🤖<Q>[comment]` carries an anchor (the quoted
text is reproduced as `> Q`); the unquoted form loses position entirely
(`drill_in.lua:136`, `replacement = quoted_text or ""` → empty).

This is the flatten-vs-anchor coupling: moving the comment out of the reply
destroys the position it pointed at. The fix is to give the flattened comment a
recovered anchor.
