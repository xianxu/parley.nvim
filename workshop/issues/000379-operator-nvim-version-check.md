---
id: 000379
status: codecomplete
deps: []
github_issue:
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'bb08c7b0ca07290b32cb8f651ce55cb4e952415c' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-17T17:27:55-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "36ce31a4", done: "130b4f6d"}
actual_hours: 0.42
---

# Check operator Neovim compatibility

## Problem

The operator's PATH Neovim is 0.11.7, but scripts/test-nvim.sh selects 0.12.5 for its newer LuaJIT mcode fix. Our full suite can therefore pass while the installed operator editor is broken.

During #373's real-profile live check, all full-suite tests passed on 0.12.5, then a registered move failed immediately on PATH Neovim 0.11.7 with E976: Using a Blob as a String. document_move's journal-budget namespace contains a NUL; vim.fn.sha256 accepts its binary representation on 0.12 but refuses it on 0.11. The lease-boundary defect is fixed under #373; this issue owns preventing the wider version-coverage gap.

## Spec

Make the editor-version support contract explicit and enforce it. Either exercise the operator's Neovim version with the suite or a meaningful smoke subset in addition to the preferred test runtime, or declare and check a minimum version so an unsupported installed editor cannot silently start. Preserve the existing newer-LuaJIT test selection and its performance rationale unless the chosen policy supersedes it deliberately.

Any local-gate configuration change requires operator verification under local-gates-guard; do not apply that label as an agent.

## Done when

- Document the supported Neovim versions and how the operator's installed version is checked.
- Automated verification detects a version-specific compatibility regression such as the binary SHA-256 failure on 0.11; selecting 0.12 for performance cannot hide it.
- If 0.11 remains supported, run a meaningful suite or smoke subset on it. If it is unsupported, startup or installation gives a clear minimum-version diagnostic and the supported runtime is exercised.
- Keep the local-gate change and any required operator verification explicit.

## Plan

Measured first, on this branch's base 5ebffb3dd7d39dd168d19dc167ead22fb00c8dc0, with `PARLEY_TEST_NVIM=/opt/homebrew/opt/nvim-0.11/bin/nvim make -k test`:
- About 160 s of suite time once the machine slot was free. Of the 1550 s wall, 1389 s was the slot queue, not 0.11 itself.
- 460 spec files pass and 6 fail.
  - Five fail only on 0.11, all with E976 "Using a Blob as a String" (57 hits): agentic_document, agentic_document_lifetime, agentic_document_owned_move, document_band and document_move. This is the SHA-256 class that #373 fixes.
  - review_protocol_bundle fails because `tests/unit/review_protocol_export_test.py` hardcodes `dir='/tmp'`, which the sandbox refuses. It is not version-specific.

**Policy.** Neovim 0.11 or newer is supported, which is what `packaging/starter-config/README.md` already promises. The operator's editor is 0.11.7 (`/opt/homebrew/bin/nvim` is the pinned `nvim-0.11` keg). The tests keep preferring 0.12 for its LuaJIT mcode fix (#294).

**Changes.**
- [x] `scripts/test-nvim.sh --installed` prints the directory of the nvim the operator actually launches, the first `nvim` on PATH outside the test environment, and stays silent when there is none. The existing no-flag output (the preferred runtime) is unchanged (ARCH-DRY: one script owns runtime discovery).
- [x] `make test` gains a compat pass. After the preferred-runtime unit and integration runs, if the installed nvim reports a different `--version` line, it runs `test-unit` and `test-integration` again with `PARLEY_TEST_NVIM` set to that binary. The pass announces itself ("compat: also testing the installed NVIM v0.11.7"), and a failure there fails `make test`, so the recorded `sdlc-local/suite` covers both runtimes. If the installed version is below the supported minimum, `make test` fails with that diagnostic.
- [x] A pure `parley.version_support` module with `supported(version_table)` and a `MINIMUM = {0, 11, 0}` constant, plus a unit spec. `parley.setup()` on an older editor notifies "parley needs Neovim 0.11 or newer (this is X)" and returns before anything is installed. The compat pass reads the same constant by asking the installed nvim to evaluate it (ARCH-DRY).
- [x] Docs: `TOOLING.md` and `atlas/infra/test_harness.md` ("Which Neovim the tests run") describe the supported versions, the compat pass and its cost. The README's requirements line points to them.

**Detection proof.** On main today, the compat pass goes red on exactly the five E976 specs, so the 0.12 choice can no longer hide the class. After #373 lands, it goes green.

**ARCH notes.**
- ARCH-CONSTRAINTS: the compat pass costs about 160 s on top of about 140 s, measured. It holds the same machine suite slot, adds no parallel fan-out, and is skipped when the installed version matches the preferred one (as in CI, or a 0.12-only machine).
- ARCH-FUNERAL: nothing durable; it reuses the per-target logs and the existing test env.
- Local gates: `Makefile.parley`, `scripts/test-nvim.sh`, `lua/` and the docs are not on local-gates-guard's protected list, and CI runs only the merge checks. So no local-gate config changes and no label is needed. If that changes during the work, I stop at operator verification.

**Sequencing.** The compat pass is red until #373 lands, so landing #379 first would block every landing. I propose landing #379 right after #373, with my final suite rerun on a main that includes it.

**Separate.** The hardcoded `/tmp` in `review_protocol_export_test.py` breaks the #342 TMPDIR rule. I will file it as its own issue, since it is not version coverage.

## Log

### 2026-10-17
- 2026-10-17: closed — Review Minors fixed: --supported fails closed (only an exact yes verdict passes; missing nvim and an erroring check exit 1, verified by mutation; MINIMUM raised to 0.12 still refuses 0.11.7 with the message); help-parley lists test-compat; version_support_spec restores _setup_called (5/5). (fixed-then-ship); review verdict: SHIP
- 2026-10-17: closed — Supported Neovim 0.11+ (version_support.MINIMUM, one owner); setup() on 0.10.4 refuses with one message, nothing installed (unit). make test ends with test-compat: recorded suite on 3f6ec814 printed "compat: also testing the installed NVIM v0.11.7", 940 PASS (both runtimes), 0 FAIL, 5m14s. Detection proven: before #373 landed, the same 0.11 pass was red on exactly the 5 E976 specs (base 5ebffb3d); after integrating #373 they pass. --supported refuses 0.11.7 when MINIMUM is raised to 0.12 (mutation). Skip paths verified (versions match; no nvim on PATH). Docs: README, TOOLING, atlas config + test_harness. No local-gate paths touched.; review verdict: SHIP

Filed unclaimed on TL instruction (receipt 4b20a07a-3975-44a4-8087-b941a0d31569). Evidence: PATH /opt/homebrew/bin/nvim reports NVIM v0.11.7; the selected suite runtime /opt/homebrew/opt/neovim/bin/nvim is 0.12.5. Recorded #373 suite eea1accf42a3e8bb2066abb9742ce90a3b5d2c0f passed, exit 0 in 2m20s, log SHA256 prefix b0d48b081b89. Real profile /Users/xianxu/.config/parley with staged runtime failed at document_lease.lua:106 hashing the NUL-delimited budget namespace. Stage cleared, disposable registry entry forgotten, scratch removed. No credential changes or real-document edits.
- The TL approved the plan and the sequencing: build now, and run the recorded suite only after #373 has landed and been integrated.
- Built.
  - `lua/parley/version_support.lua` holds the MINIMUM 0.11.0 constant, `supported` and `refusal`. Its unit spec has 5 cases, including setup() refusing on 0.10.4 with nothing installed.
  - `scripts/test-nvim.sh` gained `--installed` and `--supported DIR`. Checked by mutation: with MINIMUM raised to 0.12, `--supported` refuses 0.11.7 with "parley needs Neovim 0.12.0 or newer (this is 0.11.7)" and exits 1.
  - `make test` ends with `test-compat`. It skips when the preferred runtime is the installed one, or when there is no nvim on PATH; both paths were checked.
  - Docs: README, TOOLING.md, atlas/infra/config.md and test_harness.md. traceability.yaml maps the new module and spec.
- Running `make test-compat` alone skips the machine suite lock, which is taken only for the `test` goal. The real check therefore goes through `make test`, and TOOLING.md says so.
- Filed #381 (unclaimed) for the hardcoded `/tmp` in review_protocol_export_test.py.
- Recorded suite on 3f6ec814, after integrating #373 (merge 4bd385dd): it printed "compat: also testing the installed NVIM v0.11.7", logged 940 PASS lines covering both runtimes and 0 FAIL, in 5m14s. Close review: SHIP, with three Minors, all fixed:
  - probe-fail-open: nvim exits 0 after a `-c` Lua error, so an erroring `--supported` check passed. It now fails closed, printing a verdict that is accepted only as an exact `yes`, like `has_mcode_fix`. Checked: 0.11.7 passes; a missing nvim and a check that throws (mutation) each exit 1; raising MINIMUM to 0.12 prints the refusal and exits 1.
  - `help-parley` now lists `make test-compat`.
  - version_support_spec restores `parley._setup_called`.
