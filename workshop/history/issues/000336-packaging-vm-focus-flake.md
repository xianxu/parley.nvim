---
id: 000336
status: done
deps: []
github_issue:
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
card_mirror: 'edde71906a9286af5b7c615f6b9a9b6e3a33ba52' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-15T15:41:39-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "d26adc12", done: "2979c40b"}
actual_hours: 0.39
---

# Flake: packaging VM guest chat confinement follows transient focus

## Problem

Flake first seen 2026-10-15 during #332 verification: tests/integration/packaging_vm_spec.lua, case exercises guest fake first use, login prompt and real chat dispatch in an isolated profile, failed its guest current-buffer confinement assertion. An unchanged focused rerun passed all17cases. Per test-economy rule, retain this as a tracked flake rather than treating rerun success as disposal.

## Spec

Investigate and eliminate the guest probe timing/focus dependence without weakening profile confinement, first-use login or real chat dispatch assertions. Reproduce under parallel integration load and distinguish the created chat document from transient UI focus.

## Done when

- A deterministic regression (a focus change before the guest assertions) reproduces the failure on the old assertion.
- The root cause is fixed: the probe settles the login flow's reopened picker before chat dispatch, and confinement is asserted on the created chat file, never on the current buffer.
- Focused and full parallel integration runs pass with profile confinement, first-use login and real chat dispatch assertions intact.

## Core concepts

| Entity | Kind | Status | Location | Responsibility |
| --- | --- | --- | --- | --- |
| `vm_chat` | INTEGRATION | modified | `tests/packaging/vm_chat.lua` | Guest probe settles the login's reopened picker; ask() reports the chat file it created. |
| `is_connecting` | PURE | new | `lua/parley/starter_onboarding.lua` | Reports whether a connection flow is still open (its returned picker unresolved). |
| `packaging_vm_spec` | INTEGRATION | modified | `tests/integration/packaging_vm_spec.lua` | Guest confinement asserted on the created chat after a deliberate focus change. |

## Plan

Root cause (traced): `agent_picker`'s login row runs `run_login`, whose success
callback schedules `M.agent_picker(plugin, opts)` — the reopened model-choice
picker (a floating prompt in insert mode; the failure log shows `-- (insert) --`
twice, once per picker). The fake probe in `tests/packaging/vm_chat.lua` treats
the credential FILE as login completion (lessons: file existence is not
readiness), so the reopen races `ask()`. Credential health → settle → schedule
lands either before `ask()` (then `nvim_set_current_buf` swaps the chat into the
picker float and the run passes by accident) or during the response wait (then
window 0 is the picker's unnamed prompt, and `resolve('')` fails the
`guest chat file escaped` assertion). Confinement itself was never violated.

- [x] Probe: after the credential appears, wait for the login flow's own
      completion signal, the reopened picker float, and dismiss it through its
      cancel path, as an operator would, before `ask()`.
- [x] Probe: `ask()` returns the captured chat buffer's resolved file
      (`chat_file`); the guest script asserts confinement on that file, never
      on buffer 0.
- [x] Regression (packaging_vm_spec guest script): after `run("fake")`, assert
      that no floating window remains (the login UI settled inside the probe),
      then move focus to an unnamed scratch buffer (`enew`) before the
      confinement assertions, so they are provably focus-independent. Show that
      the old assertion fails deterministically under that focus change.
- [x] Verify: focused spec runs repeated, then the full parallel integration suite.

## Log


- 2026-10-15: closed — Red: focus-change regression failed old buffer-0 assertion 16/1; mutation deleting the picker-settle block failed 16/1 x2 (chat dispatch began while account connection was still open). Green: probe settles reopened picker, ask() refuses dispatch while is_connecting, confinement asserted on chat_file; focused 17/0 x3, starter_onboarding unit 7/0; full make -k test exit 0 on 01ebf088, lint clean, packaging_vm_spec PASS in parallel run.; review verdict: SHIP
First-seen head: b6c67239f20e820d85bf4144671f5c7cb8f98152. Command: make -k test-integration, after the required suite stopped at unit failures. Log: /tmp/parley332-full-remainder.log, packaging_vm_spec section, test line167, generated fake-chat.lua line10: guest chat file escaped isolated profile. Observed16pass/1fail, exit1. Unchanged command make -k test-spec SPEC=scratch MAP_FILE=/tmp/parley332-vm-map.yaml passed17/0; log /tmp/parley332-packaging-vm-repro.log. The failed combined remainder has four other named #332 failure classes, independently fixed; this flake had no packaging source changes.

- 2026-10-15 — reproduced in a second complete required suite, now on e9a1622d2102e71e66dc44d3a0dacb70e9921f92. Same packaging_vm_spec.lua:167 / generated fake-chat.lua:10 assertion,16pass/1fail. All other test files passed; lint745files clean. Durable log: /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/894c995da011381b869a9bd450c9545b.log. This blocks #332 close/staging; no rerun waiver. Cause remains unproven.

- 2026-10-15 (:3): root cause traced to the reopened model picker (see Plan); TL approved plan f3a52c2e. Red: with only the regression (no-float assertion, `enew`, old buffer-0 assertion) the focused spec failed 16/1 with `guest chat file escaped isolated profile`, deterministically. Green: probe settles the reopened picker via its own `<Esc>` cancel mapping; `ask()` returns `chat_file`; the guest script asserts confinement on it. Focused spec 17/0 on three consecutive runs. Fix commit 6ab04a67.
- Full suite (make -k test) on 6ab04a67: lint clean (732 files), packaging_vm_spec PASS (14s) under the parallel integration run; the only failure was the arch guard's absent Core concepts table, now added (arch spec 25/0).
- Close review round 1 (BR-1, Important): deleting the settle block left the spec green, so that half of the fix had no failing regression. Fix: `starter_onboarding.is_connecting` exposes the existing open-connection state (cleared only when the returned picker resolves). `ask()` asserts it is closed before dispatch, and the settle wait now waits for the picker to close and the connection to settle. Mutation check: with the settle block deleted (temporary file copy, no stash), the focused spec failed 16/1 on two runs with `chat dispatch began while account connection was still open`. Restored: 17/0 ×3, unit starter_onboarding 7/0 (new open-until-resolved case), lint clean. Minor: maparg callbacks are now checked via `press()`; the float check uses one `is_float` helper.
- Review observation (pre-existing, out of scope): with TMPDIR inside a git checkout, the starter's project discovery puts the guest chat root in that project (fails at the first `confined()`, before the probe runs). Reported to the TL for a separate issue.

## Revisions

- 2026-10-15: BR-1 changed the regression. The no-float check after `run()` cannot see a picker reopen still queued, so the deterministic oracle for the settle step is now `is_connecting` asserted in `ask()`. This adds a 6-line product query in `starter_onboarding` (it was test-and-probe only); the atlas starter entry documents it.
