---
id: 000423
status: done
deps: []
github_issue:
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
collaboration-mode: collaboration
card_mirror: '63166b247f0a0f6e816ee82ab51a8cde49f010ee' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-23T04:29:39-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "57bc0431", done: "48afe56c"}
actual_hours: 0.56
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
- [x] Guard: a root whose `/tmp` is exactly 189 bytes passes; 190 refuses with the length message and creates nothing.
- [x] Spec pins the constant against the running nvim: TMPDIR of 189 bytes is used, and 190 falls back. If Neovim changes its limit, the guard's constant fails visibly here rather than drifting. The suite's compat pass runs it on the second version.
- [x] The scratch_placement tempname()-under-$TMPDIR assertion.
- [x] Live: a long-root `make test-spec SPEC=infra/config TEST_ENV_ROOT=<long>` refuses up front; the normal checkout passes infra/test_harness and infra/config.
- [x] atlas/infra/test_harness.md: one line next to the #422 guard.

## Log

Filed from #422, at the TL's request (ops:0).

### 2026-10-23 — implemented (47a12d69)
- 2026-10-23: closed — R1 addressed: bytes count (non-ASCII case), marker walk before length (case), relative length-proof fixtures incl. lease test nested roots; infra/test_harness 235/0/0 clean at 185-byte root and on 0.12.5 + 0.11.7; lease 27 OK at default + long TMPDIR; counterfactual fails exactly bytes + marker-first cases; review verdict: SHIP

The TL approved the plan. The guard holds `TMPDIR_MAX=189` and refuses `ROOT/tmp` over it before any write. In scratch_placement_spec:
- in-process: tempname() lies under $TMPDIR;
- guard: 189 passes, 190 refuses and creates nothing;
- pin: the running nvim uses a 189-byte TMPDIR and falls back at 190.

Evidence:
- infra/test_harness 233/0/0 with a clean census on each of 0.12.5 and 0.11.7, selected via PARLEY_TEST_NVIM (the dry run confirms the PATH).
- Live `make test-spec SPEC=infra/config TEST_ENV_ROOT=<170-byte root>` exits 2 with the single test-placement length message and creates nothing.
- Counterfactual TMPDIR_MAX=190: the pin case fails with "Neovim refused a TMPDIR of the guard's limit, 190 bytes". Restored with git checkout of the committed file.


### 2026-10-23 — close review R1 REWORK, addressed (7364e799)

- **BR-1 (Critical, guard-fixture-length-budget):** fixed for the whole class. The guard's fixtures are relative to base (vim.system cwd), so they stay short at any accepted harness TMPDIR. The pin probe pads a relative "t" with "./" to an exact raw length: Neovim checks the raw string at 189 bytes and separately limits the absolute path at about 234 bytes, measured identically on 0.12.5 and 0.11.7 (cwd up to 232 with a relative "x"). The lease test's nested harness roots, the other member of the class, are now `../<name>-env`; under a 185-byte outer TMPDIR they had been refused (274- and 231-byte TMPDIRs). The length check now runs after the marker/checkout walk; new case "reports a marker before the TMPDIR length".
- **BR-2 (Important):** the length is counted in bytes (`LC_ALL=C wc -c`). New non-ASCII case: "é" at 190 bytes and 97 characters refuses.
- **Minor:** extracted an `is_under` helper for the three prefix checks.

Evidence:
- infra/test_harness 235/0/0 with a clean census at a 185-byte TEST_ENV_ROOT (the reviewer's repro), and on each of 0.12.5 and 0.11.7 at the default root.
- test_run_lease.py 27 OK at both the default and the 185-byte TMPDIR.
- Counterfactual (restore `${#tmp}` and length-first): exactly the bytes case and the marker-first case fail. Restored.
- Cancelled suite on 3f63c3b3 (not pass evidence); requeued on the fixed head.
