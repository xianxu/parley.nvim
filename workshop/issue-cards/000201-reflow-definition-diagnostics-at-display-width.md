---
id: '000201'
status: done
started: 2026-08-18T17:17:25-07:00
created: 2026-08-18
updated: 2026-08-20
estimate_hours: 2.12
actual_hours: 2.18
---

# Reflow definition diagnostics at display width

## Problem

Definition diagnostics are hard-wrapped when they are created, using the
current editor window's width. The resulting newline characters become part of
the persisted diagnostic message. When the same message is later shown in the
centered diagnostic float, whose width differs from the editor window, those
stale breaks cannot reflow: short fragments and uneven line lengths remain even
though the float has more or less room. The managed footnote itself is one
logical Markdown line and soft-wraps correctly, so storage and popup presentation
currently have inconsistent width semantics.
