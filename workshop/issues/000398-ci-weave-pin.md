---
id: 000398
status: open
deps: [ariadne#459]
github_issue:
created: 2026-10-19
updated: 2026-10-19
estimate_hours:
collaboration-mode: collaboration
card_mirror: '82bd18df93d35e9305848ece829437c6a674c262' # card fields mirrored from issue-cards; edit via sdlc
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

Leave unclaimed for the hub to dispatch to a repository slot after ariadne#459
lands. Read its approved guard/template and verified consumer inventory before
planning the bounded migration. No downstream workflow edits or PR are made by
this filing operation.

## Log

Filed under explicit hub authorization from this repository's primary :0
checkout, unclaimed, depending on ariadne#459. Source class C; inventory:
[verified active GitHub consumers](https://github.com/xianxu/ariadne/blob/000459-weave-release-downstream-ci-still-runs-weave-0-1-0-pre-422-vocabulary-changes-break-every-downstream-merge-check/workshop/plans/000459-downstream-compiler-inventory.md).
The upstream owner files the hand-off; this repository's assigned slot and the
operator own implementation and acceptance.
