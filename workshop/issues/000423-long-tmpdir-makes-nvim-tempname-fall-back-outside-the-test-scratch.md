---
id: 000423
status: working
deps: []
github_issue:
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'd2852a024afb8289749a48d4bfb866d4af9942bc' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-23T04:29:39-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "57bc0431", done: "48afe56c"}
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

Measured 2026-10-23 on both supported versions (Homebrew 0.12.5 and 0.11.7, same result). Neovim uses `$TMPDIR` only while the raw string is at most 189 bytes; at 190 or more, a trailing slash included, tempname() silently returns /tmp/nvim.<user>/…. This matches Neovim's fixed temp-path buffer (TEMP_FILE_PATH_MAXLEN 256, minus room for its own suffix). The harness sets TMPDIR to `TEST_ENV_ROOT/tmp`, and TEST_ENV_ROOT = `<inherited TMPDIR>/parley-test-env/<checkout basename>-<cksum>`. A long inherited TMPDIR or a long checkout name therefore pushes every spec's scratch out to /tmp. That escapes TEST_ENV_ROOT (and the census/cleanup that assume it), escapes #422's marker check, and fails confusingly where a sandbox denies /tmp.

Two checks, the same split as #422:
1. **Pre-write (scripts/test-placement.sh):** it already receives TEST_ENV_ROOT. Also refuse when `ROOT/tmp` is longer than 189 bytes. The message names the length, the limit and the fix: a shorter TMPDIR or TEST_ENV_ROOT, or a shorter checkout name.
2. **In-process (tests/arch/scratch_placement_spec.lua):** assert that vim.fn.tempname() lies under $TMPDIR. This asserts the produced path rather than a constant, so it also catches any other fallback cause and any change in Neovim's limit.

Tests:
- [ ] Guard: a root whose `/tmp` is exactly 189 bytes passes; 190 refuses with the length message and creates nothing.
- [ ] Spec pins the constant against the running nvim: TMPDIR of 189 bytes is used, and 190 falls back. If Neovim changes its limit, the guard's constant fails visibly here rather than drifting. The suite's compat pass runs it on the second version.
- [ ] The scratch_placement tempname()-under-$TMPDIR assertion.
- [ ] Live: a long-root `make test-spec SPEC=infra/config TEST_ENV_ROOT=<long>` refuses up front; the normal checkout passes infra/test_harness and infra/config.
- [ ] atlas/infra/test_harness.md: one line next to the #422 guard.

## Log

Filed from #422, at the TL's request (ops:0).
