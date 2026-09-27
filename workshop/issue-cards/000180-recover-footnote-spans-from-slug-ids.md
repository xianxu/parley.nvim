---
id: '000180'
status: done
started: 2026-07-09T11:16:32-07:00
created: 2026-07-09
updated: 2026-07-09
estimate_hours: 0.20
actual_hours: 0.06
---

# recover footnote spans from slug ids

## Problem

After reopening a chat, persisted definition footnotes only recover multi-word
highlight spans when the footer starts with a structured quoted/backquoted term.
Existing generated footnotes often do not have that structured prefix; for
`serverless functions[^serverless-functions]`, reload falls back to the last
token and highlights only `functions[^serverless-functions]`.
