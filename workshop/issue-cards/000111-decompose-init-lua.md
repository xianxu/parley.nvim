---
id: '000111'
status: done
created: 2026-04-22
updated: 2026-04-22
actual_hours: N/A
---

# Decompose init.lua

## Problem

init.lua was 4736 lines with ~20 logical sections. Goal: extract self-contained
sections to reduce init.lua size and improve cohesion.
