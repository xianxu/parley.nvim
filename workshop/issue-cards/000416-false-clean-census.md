---
id: 000416
status: open
created: 2026-10-22
updated: 2026-10-22
estimate_hours:
github_issue:
---

# Test census reports clean while an orphaned embedded Neovim survives

## Problem

A completed targeted #405 native test run reported `clean: no surviving test processes` while an embedded Neovim from that exact run remained alive for about six hours, orphaned under PID 1. A clean census is currently capable of giving false assurance.

Related: #409, the test-lease and orphan-reaper work that protects active targeted runs. This is the complementary false-negative case: a completed run's survivor must be detected without touching a live or foreign run.
