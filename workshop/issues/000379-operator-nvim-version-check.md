---
id: 000379
status: working
deps: []
github_issue:
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
collaboration-mode: collaboration
card_mirror: '4f7f59aa76d6d2a36310a0fd8664a2d7f4926871' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-17T17:27:55-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
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

Measured first, on main 9b0c5d75+ (this branch's base), with `PARLEY_TEST_NVIM=/opt/homebrew/opt/nvim-0.11/bin/nvim make -k test`:
- About 160 s of suite time once the machine slot was free. Of the 1550 s wall, 1389 s was the slot queue, not 0.11 itself.
- 460 spec files pass and 6 fail.
  - Five fail only on 0.11, all with E976 "Using a Blob as a String" (57 hits): agentic_document, agentic_document_lifetime, agentic_document_owned_move, document_band and document_move. This is the SHA-256 class that #373 fixes.
  - review_protocol_bundle fails because `tests/unit/review_protocol_export_test.py` hardcodes `dir='/tmp'`, which the sandbox refuses. It is not version-specific.

**Policy.** Neovim 0.11 or newer is supported, which is what `packaging/starter-config/README.md` already promises. The operator's editor is 0.11.7 (`/opt/homebrew/bin/nvim` is the pinned `nvim-0.11` keg). The tests keep preferring 0.12 for its LuaJIT mcode fix (#294).

**Changes.**
- [ ] `scripts/test-nvim.sh --installed` prints the directory of the nvim the operator actually launches, the first `nvim` on PATH outside the test environment, and stays silent when there is none. The existing no-flag output (the preferred runtime) is unchanged (ARCH-DRY: one script owns runtime discovery).
- [ ] `make test` gains a compat pass. After the preferred-runtime unit and integration runs, if the installed nvim reports a different `--version` line, it runs `test-unit` and `test-integration` again with `PARLEY_TEST_NVIM` set to that binary. The pass announces itself ("compat: also testing the installed NVIM v0.11.7"), and a failure there fails `make test`, so the recorded `sdlc-local/suite` covers both runtimes. If the installed version is below the supported minimum, `make test` fails with that diagnostic.
- [ ] A pure `parley.version_support` module with `supported(version_table)` and a `MINIMUM = {0, 11, 0}` constant, plus a unit spec. `parley.setup()` on an older editor notifies "parley needs Neovim 0.11 or newer (this is X)" and returns before anything is installed. The compat pass reads the same constant by asking the installed nvim to evaluate it (ARCH-DRY).
- [ ] Docs: `TOOLING.md` and `atlas/infra/test_harness.md` ("Which Neovim the tests run") describe the supported versions, the compat pass and its cost. The README's requirements line points to them.

**Detection proof.** On main today, the compat pass goes red on exactly the five E976 specs, so the 0.12 choice can no longer hide the class. After #373 lands, it goes green.

**ARCH notes.**
- ARCH-CONSTRAINTS: the compat pass costs about 160 s on top of about 140 s, measured. It holds the same machine suite slot, adds no parallel fan-out, and is skipped when the installed version matches the preferred one (as in CI, or a 0.12-only machine).
- ARCH-FUNERAL: nothing durable; it reuses the per-target logs and the existing test env.
- Local gates: `Makefile.parley`, `scripts/test-nvim.sh`, `lua/` and the docs are not on local-gates-guard's protected list, and CI runs only the merge checks. So no local-gate config changes and no label is needed. If that changes during the work, I stop at operator verification.

**Sequencing.** The compat pass is red until #373 lands, so landing #379 first would block every landing. I propose landing #379 right after #373, with my final suite rerun on a main that includes it.

**Separate.** The hardcoded `/tmp` in `review_protocol_export_test.py` breaks the #342 TMPDIR rule. I will file it as its own issue, since it is not version coverage.

## Log

### 2026-10-17

Filed unclaimed on TL instruction (receipt 4b20a07a-3975-44a4-8087-b941a0d31569). Evidence: PATH /opt/homebrew/bin/nvim reports NVIM v0.11.7; the selected suite runtime /opt/homebrew/opt/neovim/bin/nvim is 0.12.5. Recorded #373 suite eea1accf42a3e8bb2066abb9742ce90a3b5d2c0f passed, exit 0 in 2m20s, log SHA256 prefix b0d48b081b89. Real profile /Users/xianxu/.config/parley with staged runtime failed at document_lease.lua:106 hashing the NUL-delimited budget namespace. Stage cleared, disposable registry entry forgotten, scratch removed. No credential changes or real-document edits.
