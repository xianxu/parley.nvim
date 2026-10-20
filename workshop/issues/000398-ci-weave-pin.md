---
id: 000398
status: working
deps: [ariadne#459]
github_issue:
created: 2026-10-19
updated: 2026-10-19
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'e8acc83e0b178a8616a9cb9ebfda70dfcf0c2db6' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-19T21:32:47-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "6386f544", done: "a4d38aa0"}
---

# CI: build weave from a pinned ariadne commit

## Problem

ariadne#459 reproduced the cold generated-vocabulary failure in published weave
0.1.0, before ariadne#422's shipped-output sidecar ownership. This repository's
active GitHub main merge-check installs the published formula without an exact
source pin. Verified 2026-10-19 against [the exact workflow blob](https://api.github.com/repos/xianxu/parley.nvim/git/blobs/91cfc2012e8f61ff8cfac85b2e7159e0c085711e).

## Spec

Repository-owned migration after ariadne#459's upstream compatibility guard
lands. Build weave from approved full Ariadne commit
63d6bfd86509d97649e10d7a5dd1e9a06db17d21 before bootstrap, using an authored
.sdlc/weave-compiler-ref outside weave's managed manifest. Follow the reviewed
upstream merge-check template. Install Go from that pinned source's go.mod;
verify fetched HEAD and binary vcs.revision/modified metadata, and prepend its
private output directory to PATH. No floating HEAD/formula or old PATH fallback
on pin acquisition/build failure. Preserve bootstrap, setup and check ordering.

## Done when

- The committed workflow builds the exact selected supported full SHA and uses
  that executable before bootstrap; tests reject malformed pins and fetch/build
  failure and prevent an older PATH weave from winning.
- A cold CI checkout with tracked old generated vocabulary and matching sidecars
  regenerates changed exports and sidecars without authored-replacement refusal;
  an authored/tampered output still refuses without losing its bytes.
- The consumer-authored pin survives compile and is not manifest-managed.
- Operator verifies the local-gates PR and applies local-gates-verified. Agents
  never apply that label. Future pin bumps require the same verification.
- The owner reports the PR, compiler identity and real CI acceptance to the hub.

## Plan

- [ ] Regenerate the two workflow files with weave refresh on this clean issue branch; add the exact approved compiler pin outside the manifest (ARCH-DRY, ARCH-SECURE).
- [ ] Verify generated workflow equality with the reviewed upstream template, pin grammar/fetch/build/provenance failure propagation and PATH precedence using upstream actual-block conformance; build the exact pin and run cold ownership/tamper conformance. Confirm compile retains the authored pin.
- [ ] Run the required suite and close review; report the PR, exact compiler identity and CI result to the hub for operator-held local-gates verification. Normal landing follows the operator label and green gates.

Actions: review/bump pin, rerun CI, operator labels verified PR. Pin acquisition/build/identity failures stop CI before bootstrap; recover by correcting the pin/source and rerunning, with no fallback to PATH or formula. A successful build uses its private PATH directory before bootstrap/setup/checks. No new product state or hot-path work; one bounded compiler checkout/build per CI job. Existing upstream conformance owns malformed/failure cases rather than a second hand-maintained workflow implementation.

## Log

Filed under explicit hub authorization from this repository's primary :0
checkout, unclaimed, depending on ariadne#459. Source class C; inventory:
[verified active GitHub consumers](https://github.com/xianxu/ariadne/blob/000459-weave-release-downstream-ci-still-runs-weave-0-1-0-pre-422-vocabulary-changes-break-every-downstream-merge-check/workshop/plans/000459-downstream-compiler-inventory.md).
The upstream owner files the hand-off; this repository's assigned slot and the
operator own implementation and acceptance.

## Revisions

### 2026-10-19 — Assigned consumer migration

Replaces the filing-time dispatch placeholder: Leave unclaimed for the hub to dispatch to a repository slot after ariadne#459 lands. Read its approved guard/template and verified consumer inventory before planning the bounded migration. No downstream workflow edits or PR are made by this filing operation. The hub assigned parley.nvim:2 after upstream ariadne#459 landed and the operator selected option B. start-plan ran before regeneration on a clean tree. This issue imports the reviewed generated workflows and authors only the compiler pin; operator owns the local-gates label.
