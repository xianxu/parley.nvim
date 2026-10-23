---
id: 000422
status: done
deps: []
github_issue:
created: 2026-10-22
updated: 2026-10-23
estimate_hours:
collaboration-mode: collaboration
card_mirror: '67fb2c170702ec70b8cc9a3e55c29c661fa99649' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-23T01:58:47-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "22a5882d", done: "87795ed6"}
actual_hours: 0.24
---

# Zero-config chat escapes scratch in review clones

## Problem

## Spec

The zero-config chat test must select its disposable scratch storage even in an SDLC review clone. During #405 M2 review it selected the clone's workshop/parley directory instead and created an untracked chat artifact, so the focused target failed despite passing endpoint tests. Determine which repository/config discovery input changes in a review clone and keep test state inside its owned scratch root.

## Done when

- Reproduce through the supported make target in a disposable review-style clone and ordinary checkout.
- A regression asserts chat output stays inside the harness-owned scratch root, with no checkout or operator-state artifact.
- Resolve the root discovery/isolation mismatch; keep real zero-config product behavior intact.

## Plan

Root cause (reproduced 2026-10-23): an SDLC inside-checkout review sets TMPDIR to `<clone>/.sdlc-review/tmp` (ariadne `cmd/sdlc/internal/reviewbox/confine.go`, by design: the reviewer never writes outside its checkout). The Makefile derives TEST_ENV_ROOT, HOME, XDG and TMPDIR from that, so all harness scratch sits under the clone, which carries a tracked `.parley`. The zero-config child clears PARLEY_REPO_MODE (on purpose: it tests real defaults), walks up from `scratch/work`, finds the clone's marker, and writes the new chat to `<clone>/workshop/parley`. This is the existing #202/#338 placement invariant (scratch outside the tree, no marked ancestor) broken by the environment. `tests/arch/scratch_placement_spec.lua` already detects it, but as one spec among many, after other specs have written into the tree. The product behavior is correct: a marked ancestor should select repo mode.

Two owners:
1. **parley (this issue): fail fast, once, before any spec writes.** PREP_TEST_ENV checks the placement invariant up front: if TEST_ENV_ROOT resolves inside $(CURDIR), or any ancestor of it carries the repo marker, the target refuses with one message naming the path, the marked root, and the fix (point TMPDIR or TEST_ENV_ROOT outside a marked tree). It is a shell helper next to test-env.sh, so it covers every target that calls PREP_TEST_ENV. scratch_placement_spec stays as the in-process guard; the new check is its pre-write twin, and the two state the same rule. This adds no product surface and changes no repo-mode behavior.
2. **ariadne (file there; TL routes it):** an inside-checkout reviewer's TMPDIR should be a sibling of the review checkout, inside the reviewer's write fence but outside the reviewed tree. That fixes this class for every repo (the #202 traversal flake and the #338 marker), and restores parley tests in review clones.

Tests:
- [x] Shell-level regression spec: a disposable marked tree with TEST_ENV_ROOT inside it → the guard refuses (nonzero, the message names the marked root) and creates nothing in the tree. An unmarked out-of-tree root passes. The guard catches a marker at the root itself, and inside $(CURDIR) even without a marker.
- [x] zero_config case 1 additionally asserts the precondition (no marked ancestor of its cwd) and that the chat path lies under the child's HOME scratch. A future placement break then fails with the reason rather than as "chat outside default dir", and asserts nothing about the checkout.
- [x] Repro: the short-path review-style clone (`TMPDIR=<clone>/.sdlc-review/tmp make test-spec SPEC=infra/config`) refuses up front with the guard message and leaves `git status` clean apart from `.sdlc-review/`. The ordinary checkout passes infra/config and infra/test_harness.
- [x] atlas/infra/test_harness.md: the pre-write placement check.

Side observation (not in scope): when $TMPDIR is long, nvim's tempname() silently falls back to /tmp/nvim.<user>, outside TEST_ENV_ROOT. My first repro under a long scratchpad path passed for that reason alone. If the TL wants it, I'll file it separately.

## Log

Observed independently in #405 M2 R1 and R2. R2 reviewed head4508683883564bbd676e42c2ee50d15935a95454 against replayed base d4f332353feca049bb17eb68643b40a66176d25d. Its preferred focused mapping had275PASS/1FAIL/0ERROR; zero-config alone at base had8PASS/1FAIL/0ERROR, proving it predates the M2 changes. All process censuses were clean. R1 reported a chat created under workshop/parley in its disposable checkout; R2 removed disposable artifacts. This is review-clone context evidence, not yet an ordinary-checkout reproduction or an established timing flake. See #405's M2 review sidecar for the retained result. No operator file was changed.

### 2026-10-23 — guard implemented; landing waits for ariadne#571
- 2026-10-23: closed — Minor fixed: guard uses -f -r (detect_root predicate), directory-marker case added; infra/test_harness 230/0/0 clean census (fixed-then-ship); review verdict: SHIP
- 2026-10-23: closed — review-style clone (TMPDIR=<clone>/.sdlc-review/tmp) make test-spec SPEC=infra/config refuses once with test-placement message, nothing created in clone; sibling TMPDIR layout 166/0/0 clean status; guard no-op -> zero_config fails on marked-project precondition before writing; ordinary infra/test_harness 229/0/0, infra/config 166/0/0, test_run_lease.py 27 OK; review verdict: SHIP

TL approved the refusal, plus the ariadne fix filed as ariadne#571 (owner ariadne:4). Sequencing: land this only after #571, so parley reviewers are not left unable to run tests in clones. The tempname() long-path fallback is filed separately as #423 (unclaimed).

Implementation 92bf8cbc:
- `scripts/test-placement.sh` is the opening step of PREP_TEST_ENV, with `REPO_MARKER := .parley`.
- Regressions in `tests/arch/scratch_placement_spec.lua`: a marked tree refuses and creates nothing; a root that carries the marker refuses; a root inside the checkout refuses without a marker; unmarked roots pass, existing or not; the guard is wired with the configured marker.
- zero_config case 1 asserts its no-marker precondition, and that the chat lies under the child's HOME.
- `tests/unit/test_run_lease.py` copies the script into its disposable checkouts. Before that, its real make runs hung at PREP and timed out (exit 124, 8 failures). After the fix: 27 OK.

Evidence:
- Ordinary checkout: infra/test_harness 229/0/0 and infra/config 166/0/0, each with a clean census.
- Short review-style clone of 92bf8cbc (`TMPDIR=<clone>/.sdlc-review/tmp make test-spec SPEC=infra/config`): exit 2, with the single `test-placement: ... is inside the checkout` refusal. No parley-test-env and no workshop artifact were created.
- Post-#571 sibling layout (`TMPDIR=<clone>.sdlc-review/tmp`): 166/0/0, clean census, clean git status.
- Guard replaced by a no-op in the disposable clone: zero_config fails on `scratch sits under a marked project` before any chat is written.

Sent ariadne:4 the capture /Volumes/TestScratch/tmp/r422-review.log, the probe target, and the reviewed heads (45086838, 09f68966).


Close review R1 returned SHIP with one Minor (guard-rule-diverges-from-product-predicate): the guard's `[ -e ]` also matched a `.parley` directory, which detect_root ignores. Fixed at the site and across its class: the guard now uses `-f` and `-r`, the product's readable-regular-file predicate, so the atlas and plan claim that both state the same rule is now true. Added a directory-marker case. infra/test_harness 230/0/0, clean census. Cancelled superseded suite on 50ed7eba (not pass evidence); requeued on the fixed head.
