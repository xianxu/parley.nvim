---
id: 000423
status: open
deps: []
github_issue:
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
collaboration-mode: collaboration
card_mirror: '13d05fea5ffefd5ef851c61fc8c13754861598cc' # card fields mirrored from issue-cards; edit via sdlc
---

# Long TMPDIR makes nvim tempname() fall back outside the test scratch

## Problem

When $TMPDIR is long, Neovim's tempname() does not use it. It silently falls back to /tmp/nvim.<user>/…, which is outside the harness's TEST_ENV_ROOT. Observed 2026-10-23 during #422. A disposable clone under a long Claude scratchpad path set TMPDIR=<clone>/.sdlc-review/tmp/parley-test-env/<key>/tmp. The zero-config probe child's tempname() resolved to /private/tmp/nvim.xianxu/tUFOR9/0/… (instrumented PROBE line). Its scratch therefore escaped TEST_ENV_ROOT, and also escaped the marker check, so the run passed for the wrong reason. A short clone path (/Volumes/TestScratch/tmp/r422) used TMPDIR as expected.

## Spec

Find Neovim's TMPDIR acceptance rule (a length limit or a usability check) and make the harness detect a fallback rather than inherit it silently. For example, the placement guard or minimal_init could assert that tempname() lies under $TMPDIR, refusing with the reason, or the Makefile could pick a short TEST_ENV_ROOT. Under a sandbox that denies /tmp, the fallback also fails in confusing ways.

## Done when

- The fallback threshold or cause is measured on the supported nvim versions (0.11.7 and 0.12.5).
- A harness run whose tempname() leaves TEST_ENV_ROOT fails once with the reason, and a regression covers it.

## Plan

- [ ]

## Log

Filed from #422, at the TL's request (ops:0).
