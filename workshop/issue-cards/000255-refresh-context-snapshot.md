---
id: '000255'
status: done
started: 2026-09-19T17:46:24-07:00
created: 2026-09-15
updated: 2026-09-26
actual_hours: 1.79
---

# Use previous completed answers in context during refresh

## Problem

Follow-up to #254 (chat ownership and concurrency).

Refreshing Q1 removes its previous answer from the live transcript while the
replacement streams. If the user then refreshes Q2, its current context snapshot
contains an absent or partial Q1 answer even though Q1's previous completed
answer is retained for recovery. Context quality therefore depends on timing.
