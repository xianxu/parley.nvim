---
id: 000362
status: working
deps: [parley.nvim#319]
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: '35486bcfe2e859798f929c26a758c60996822909' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T16:04:39-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "b8e85993", done: "dec7e7ee"}
---

# Review-protocol sync accepts S2's collaboration-modes export member

## Problem

S2 M1 (ops `universal-agent-input-interface/design.side/01-s2-section-modes.md`, db130ac0) adds a member to ariadne's universal-review `export.json`, still version 1: role `collaboration-modes`, path `collaboration-modes.md`. #319's `scripts/sync-review-protocol.py` is strict and refuses any role outside {round, grammar, adapter, mode} ("invalid member role"). So the next sync after ariadne:2 lands M1 fails until parley accepts the role.

## Spec

- `validate` accepts the role `collaboration-modes`, exactly one when present, still at version 1. Any other unknown role keeps refusing.
- The member goes into the package snapshot like round and grammar, with its byte count and SHA256 checked. The generated `SKILL.md` composes it after the round and the grammar and before the Parley-owned `local-adapter.md`.
- `examples/` is not exported and not synced.

## Done when

- `tests/unit/review_protocol_export_test.py` covers: an export with the role syncs and composes it in that order; a duplicate refuses; a still-unknown role refuses.
- The sync against ariadne's M1 export updates `lua/parley/skills/review/` and `--check` is clean.
- Older version-1 exports without collaboration modes successfully sync and
  pass `--check`, with each command reporting that the synced prompt has no
  collaboration modes.

- Local discussion/default and collaboration answer in place; chat sections stay
  byte-for-byte untouched, with deterministic pre-generation notices saying the
  hub agent answers chat, including all-chat/no-marker rounds.
- Unknown collaboration modes and conflicting normalized heading assignments
  refuse without generation or writes. Scalar, flow/block mapping and heading
  inheritance follow the canonical collaboration contract.

## Plan

Approved local-adapter correction: see [implementation plan](../plans/000362-local-collaboration-plan.md).

- [ ] Implement pure collaboration frontmatter/section resolution and protected chat ranges.
- [ ] Add local admission/notices and a proposal guard; test default questions, explicit collaboration/chat, invalid routing and resubmission.
- [ ] Update the local adapter/docs and re-run full verification and close review.

- [x] Extend pure validation/rendering for an optional singleton at the fixed
  collaboration-modes.md path; compose round, grammar, collaboration modes.
  Keep old version-1 exports and strict rejection of unknown roles.
- [x] Extend owned-output preflight and add Python pure/real-CLI regressions
  for ordering, corruption, duplicate/unknown roles, stale/unsafe output and
  examples exclusion. Verify the existing local source orders its adapter last.
- [x] Coordinate with ariadne:2 and snapshot the landed S2 M1 export; verify
  --check and standalone packaged composition. Update atlas and README.
- [ ] Run focused/mapped tests and a recorded full suite, close-review, land
  on SHIP and report to the hub.

## Log

- Filed by parley.nvim:4 as S2's design owner, from ariadne:2's question on the export member. It depends on #319 landing (the sync lives there) and on ariadne's M1 export.

### 2026-10-16 — initial plan

Dispatched by ops:0 in delivery 44a5640b-6633-4b68-8a4b-dee8c13e7a32.
Quick plan posted to the hub (70229a8f-43ec-4ee3-80ff-8af4ef1b884f,
submitted); proceeding unless objected. Producer coordination is queued to
ariadne:2, asking for its landed export pin. Build from fresh main after #334.

ARCH-DRY/PURE: reuse validate_manifest/render_snapshot (pure) and existing CLI
preflight (IO); no parallel prompt builder or runtime peer lookup. ARCH-PURPOSE:
consumer chain is export -> snapshot SKILL.md -> review.skill.source -> selected
mode context -> local adapter. Fixed output ownership must include the new file
so --check sees drift and preflight refuses symlinks before any write. The
optional member preserves prior version-1 packages; other unknown roles refuse.
One fixed package file is replaced by each sync, not an accumulating artifact
(ARCH-FUNERAL). Source digests/path validation remain the trust boundary
(ARCH-SECURE). This build-time batch adds no process or state between events
(ARCH-ORDER); input sizes remain the finite manifest/package (ARCH-CONSTRAINTS).
Real scratch source/output trees exercise IO without external services or mocks
(ARCH-MOCK). Do not snapshot an unlanded producer branch.

### 2026-10-16 — consumer implementation verified

The new acceptance tests failed against the old validator (invalid member role);
the minimal validator/renderer/preflight change makes all fifteen Python
contract tests pass. The real CLI cases cover new-member digest corruption,
--check drift without writes, repairs, preserved local adapters, explicit stale
member refusal when syncing an older export, output symlink safety and excluded
examples. Pure composition reverses manifest order and still checks exactly
once after round and grammar. Duplicate, unknown role and wrong path refuse.
The mapped modes/review suite passed with clean process census.

Producer coordination 175d76ec-d041-4afe-ac38-aedffddd563a is submitted to
ariadne:2. Own refreshed Ariadne main still exports the old version-1 shape;
its --check passes unchanged, proving backward compatibility. Await the landed
S2 M1 pin before refreshing the snapshot and final recorded full suite/close.
Couch discovery in a login shell temporarily failed; the same bare command in
a non-login shell resolves the installed binary normally. No resend needed.

### 2026-10-16 — landed snapshot and compatibility notice verified

Snapshot generated from an isolated git archive of the landed producer pin,
including its canonical grammar symlink. The new packaged member is 20746
bytes with SHA256 2ccd78b5c8834f42d9551c78b66c5aba9f2d83847a40436a373345f6a7ae64f3;
the manifest hash matches the producer handoff. No examples were copied.
The notice and shipped-member assertions first failed for their missing
behavior, then all sixteen Python contract tests passed. The mapped
make test-spec SPEC=modes/review run passed, including standalone copied-package
composition round -> grammar -> collaboration modes -> selected review modes ->
local adapter, with clean process census. Exact pinned-source --check and
git diff --check passed. Next: recorded full suite and the SDLC close review.

### 2026-10-16 — recorded full suite green

The pushed code head 56270d7110ca6ec36f34c23fa5f4337337460256 passed its first
recorded full suite in 2m6s, with all files passing, 759 Lua files lint-clean
and no surviving test processes. Log: .git/sdlc/local-checks/
56270d7110ca6ec36f34c23fa5f4337337460256/suite.log, SHA256 prefix 0d949f63ee13.
No retry or waiver. The sync/prompt snapshot adds no editor control or new
runtime transport; standalone packaged composition is the acceptance check.
Request the binary-owned close review and land on SHIP.

### 2026-10-16 — close review REWORK, adapter decision pending

Round 1 independently passed the Python contracts, mapped review tests and
pinned-source check, but raised BR-1 (Critical, prompt-adapter-capability-contract)
and BR-2 (Important, acceptance-contract-coverage). Verified BR-1 against
skill_invoke's artifact-bound propose_edits and local-adapter's single-file,
no-baseline contract: the canonical default discussion and explicit chat flows
need side docs, cross-file folds, discovery and previous-read changes that the
local adapter cannot provide. Do not ship dangling links or promise these
operations. Hub decision requested in 232ecfeb-a078-4eec-8a92-239117b594f6;
proposed in-place-only local support plus an explicit unsupported-routing
refusal, versus a larger multi-file adapter. Await approval before introducing
that policy. BR-2's Done-when clause now explicitly covers old-v1 success plus
the notice for both normal sync and --check; its existing regression passes.

### 2026-10-16 — design-owner proposal, not yet approved

Submitted peer replies f872b978-b47b-4d29-b9da-fd480f671585 and
5386b2ab-299e-4b50-8e11-faabffb91e0a propose local in-place answers for
non-chat sections, untouched chat sections, and deterministic vim.notify
notices computed before generation, including all-chat/no-marker rounds.
Unknown mode names or conflicting heading assignments would retain canonical
refusal. The notices cannot be model replies: propose_edits has per-edit
explanations only, and an empty batch offers no round-summary channel.
This needs section/frontmatter resolution and pre-generation admission, beyond
mere snapshot composition. The design owner explicitly says to wait for the
TL's policy decision. No implementation of this proposal has begun.

## Revisions

### 2026-10-16 — priority interruption

Hub delivery c322a428-5e9c-4da8-981f-e6cbccada6c2 prioritizes the shared
cliproxy lifecycle flakes (#363/#364) before this issue. Consumer changes are
committed and targeted green; preserve this branch while investigating from
fresh main, then return here for the landed producer export and final gates.

### 2026-10-16 — resume on the landed producer

After #363 landed, merge fresh main and pin ariadne #412's landed export at
1db0ec0ed0b6e2affb426c2a311bebf5c24c70a2. Independently verified main ancestry,
manifest SHA256 f8301e9c4fbd89d453b8999aa400147440b19e5c4c2aac0a2e09d56da0135c3c,
and the 20746-byte member digest from the producer's submitted handoff
b3009571-8c11-4e64-8af2-dec6abc03632. Parley:4 confirmed in submitted delivery
3fc24d3f-ebfa-4627-83bb-8944347c3c94 that singleton means at most one when
present; older v1 exports remain valid. Add a one-line CLI notice when an old
export omits collaboration modes; require the new member in shipped-package
and standalone composition tests. This additive visibility change stays inside
the original optional-v1 contract; no runtime parser or alternate builder.

### 2026-10-16 — acceptance coverage correction (BR-2)

Append the old-v1 success/notice requirement to Done when, matching the
already-recorded compatibility revision and existing real-CLI regression.
BR-1's local adapter capability mismatch remains pending the hub's scope
decision; no runtime policy has changed.

### 2026-10-16 — approved local adapter scope (BR-1)

TL approval 48f954d0-eae8-4c8b-a091-94086c6551a0 folds the narrowed local policy
into #362: discussion (including the default) and collaboration answer in place;
chat sections are left untouched and a deterministic notice says the hub agent
answers chat. Unknown modes and conflicting headings refuse. Chat answer docs,
side-doc creation, multi-file IO and previous-read baselines stay with the
agent-side skill. Parley resolves frontmatter/sections before generation and
protects chat bytes at its tool-execution seam; no model-authored notice or
new reply channel. The durable plan records this approved implementation.
