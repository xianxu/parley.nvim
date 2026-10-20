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
flow: {kind: full, provenance: inferred}
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

- [x] Regenerate the two workflow files with weave refresh on this clean issue branch; add the exact approved compiler pin outside the manifest (ARCH-DRY, ARCH-SECURE).
- [x] Verify generated workflow equality with the reviewed upstream template, pin grammar/fetch/build/provenance failure propagation and PATH precedence using upstream actual-block conformance; build the exact pin and run cold ownership/tamper conformance. Confirm compile retains the authored pin.
- [x] Record the required suite result.

Close review follows verification. Report the PR, compiler identity and real CI result to the hub for operator-held local-gates verification; normal landing follows the label and green gates.

Actions: review/bump pin, rerun CI, operator labels verified PR. Pin acquisition/build/identity failures stop CI before bootstrap; recover by correcting the pin/source and rerunning, with no fallback to PATH or formula. A successful build uses its private PATH directory before bootstrap/setup/checks. No new product state or hot-path work; one bounded compiler checkout/build per CI job. Existing upstream conformance owns malformed/failure cases rather than a second hand-maintained workflow implementation.

## Log



- 2026-10-19: closed — BR-1 fixed with README contributor guidance and indexed repository-owned atlas compiler map; checked pin ownership, format, update/recovery, ordering and operator approval against workflow. git diff --check clean. Executable content unchanged since recorded suite success on46a1132c (attempt0293e2d95ffdc19d1ec8cc6989c23d4d); actual-block and real compiler conformance passed. Hosted merge-check39370460605 passed with Go1.26.3 and exact clean compiler63d6bfd86509d97649e10d7a5dd1e9a06db17d21. Operator local-gates-verified label confirmed onPR323. (done-when: contract moved since change-code; judged by the close review); review verdict: SHIP
- 2026-10-19: flow upgraded quick → full — 139 added lines in code files (limit 100); an earlier round of this close already ran the full review
Filed under explicit hub authorization from this repository's primary :0
checkout, unclaimed, depending on ariadne#459. Source class C; inventory:
[verified active GitHub consumers](https://github.com/xianxu/ariadne/blob/000459-weave-release-downstream-ci-still-runs-weave-0-1-0-pre-422-vocabulary-changes-break-every-downstream-merge-check/workshop/plans/000459-downstream-compiler-inventory.md).
The upstream owner files the hand-off; this repository's assigned slot and the
operator own implementation and acceptance.

- Started from a clean issue branch. Plain weave refresh refused the local issue commits without changing refs; used its documented issue-branch mode, weave refresh --substrate, preserving this branch/HEAD. It regenerated exactly .github/workflows/merge-check.yml and local-gates-guard.yml. Both match the reviewed upstream templates byte-for-byte; no handwritten workflow variant. Added the Spec's exact pin plus newline, absent from construct/base.manifest. A subsequent weave compile passed and preserved both workflows and the authored pin.
- make -k conformance `/tmp/parley398-conformance.log` passed: upstream portable-ci actual Bash blocks reject malformed pins, fetch/build/source/metadata/dirty failures and an older PATH weave, preserve bootstrap/setup/check ordering; the workflow bytes here equal the tested template. Isolated clean clone at approved63d6bfd86509d97649e10d7a5dd1e9a06db17d21 built successfully (local Go1.27.1; real CI selects Go from pinned go.mod1.26.3). go version -m reports vcs.revision=63d6bfd86509d97649e10d7a5dd1e9a06db17d21 and vcs.modified=false. Real pinned compiler conformance passes changed-cold and no-drift cold consumers across6 noun exports, plus tampered/missing/malformed/symlink/undeclared refusal controls without losing bytes. Fixture also preserves its authored pin. Log SHA256 f485f0a83b5301dab0ec63a3b8bbb2166fee20b77bc6c71050b136534966cbdb. Scratch `/Volumes/TestScratch/tmp/parley.nvim-slot2/parley398.CMM4Ii`; binary lives outside its clean source clone. Whitespace checks clean. Required consumer suite and real GitHub CI remain pending; operator alone applies the local-gates-verified label.

- Recorded suite passed on 46a1132cf7c1fd7c82c004b0ba9c98336c433eca, attempt 0293e2d95ffdc19d1ec8cc6989c23d4d, exit0 in304.50s; SHA256 4d7b805c3c0827c41d4fddf4f347ccee04568e5c0017ddfb234bd96c3794a2b8. GitHub merge-check run39370460605 passed: actual log confirms Go1.26.3 linux/amd64, binary vcs.revision=63d6bfd86509d97649e10d7a5dd1e9a06db17d21 and vcs.modified=false before bootstrap, followed by setup and both merge checks passing. PR https://github.com/xianxu/parley.nvim/pull/323 reported to the hub with compiler identity and conformance evidence. Operator local-gates-verified label requested through the hub; its guard remains correctly blocked pending approval. The first close found that inherited workflow documentation does not replace repository-owned README and indexed atlas guidance; corrected as recorded below.

## Revisions

### 2026-10-19 — Assigned consumer migration

Replaces the filing-time dispatch placeholder: Leave unclaimed for the hub to dispatch to a repository slot after ariadne#459 lands. Read its approved guard/template and verified consumer inventory before planning the bounded migration. No downstream workflow edits or PR are made by this filing operation. The hub assigned parley.nvim:2 after upstream ariadne#459 landed and the operator selected option B. start-plan ran before regeneration on a clean tree. This issue imports the reviewed generated workflows and authors only the compiler pin; operator owns the local-gates label.

### 2026-10-19 — Close BR-1: document authored compiler configuration

Added contributor guidance and indexed atlas/infra/ci_compiler.md covering the
pin format and ownership, acquisition/build ordering, update and recovery path,
and operator-held label. This supplements the inherited shared workflow map;
it changes no executable behavior. Operator label is now confirmed on PR323.
