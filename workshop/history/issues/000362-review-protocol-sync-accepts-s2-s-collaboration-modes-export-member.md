---
id: 000362
status: done
deps: [parley.nvim#319]
github_issue:
created: 2026-10-16
updated: 2026-10-17
estimate_hours:
card_mirror: '5b9946b7abea27ac2d9acbbd81d911fd9836f465' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T16:04:39-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: full, provenance: inferred}
actual_hours: 6.98
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

Approved local-adapter correction: see [implementation plan](../plans/000362-review-protocol-sync-accepts-s2-s-collaboration-modes-export-member-plan.md).

- [x] Implement pure collaboration frontmatter/section resolution and protected chat ranges.
- [x] Add local admission/notices and a proposal guard; test default questions, explicit collaboration/chat, invalid routing and resubmission.
- [x] Update the local adapter/docs and re-run full verification and close review.

- [x] Extend pure validation/rendering for an optional singleton at the fixed
  collaboration-modes.md path; compose round, grammar, collaboration modes.
  Keep old version-1 exports and strict rejection of unknown roles.
- [x] Extend owned-output preflight and add Python pure/real-CLI regressions
  for ordering, corruption, duplicate/unknown roles, stale/unsafe output and
  examples exclusion. Verify the existing local source orders its adapter last.
- [x] Coordinate with ariadne:2 and snapshot the landed S2 M1 export; verify
  --check and standalone packaged composition. Update atlas and README.
- [x] Run focused/mapped tests and a recorded full suite, close-review, land
  on SHIP and report to the hub.

## Log

- Filed by parley.nvim:4 as S2's design owner, from ariadne:2's question on the export member. It depends on #319 landing (the sync lives there) and on ariadne's M1 export.

### 2026-10-16 — initial plan
- 2026-10-16: closed — BR-3 complete resolve-path sweep: parser, flat reader, name trim/normalization, balanced annotations, fences, ATX/closing hashes. Resolver scaling regressions red to green; 20 KB heading 3.755 s to 0.000097 s; 30 pure cases, 16 Python contracts, mapped review and 64 real invocation cases passed; pinned-source --check, lint and diff clean. Integrated recorded suite 95639f28: 461 files passed, 773 lint-clean, exit 0 in 2m24s, log sha256 0f301da12b61. Prior exact staged partial accepted by TL 855c7c6f: all-chat/refusal live passed; mixed notices correct, edit blocked by logged-out providers and runner timeout; mixed live edit checked in operator normal use. Stage cleared. No finding-cap waiver used. (done-when: contract moved since change-code; judged by the close review); review verdict: SHIP
- 2026-10-16: flow upgraded quick → full — 537 added lines in code files (limit 100); an earlier round of this close already ran the full review

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

### 2026-10-16 — approved local correction implemented

BR-1: added pure collaboration value/section resolution, pre-generation notices
and chat-aware admission/resubmission. Default discussion and explicit
collaboration answer in place. All-chat rounds skip generation even with a
selected review mode. Unknown/conflicting routing refuses before prompting or
writing, and invalid review+routing values report both errors. Chat headings,
content and boundary newlines plus frontmatter are protected by an
invocation-owned proposal validator before tool effects; generated canonical
files remain unchanged. No new IO/baseline/side-doc resources.

Red evidence: /tmp/parley-362-admission-red.log has three admission failures;
/tmp/parley-362-guard-red.log has both forbidden-chat proposals changing disk.
Green: mapped modes/review passes, including 12 value-parser tests, five resolver
tests and 24 local-driver cases; real asynchronous tool integration passes all
48 cases in /tmp/parley-362-guard-final.log, including chat-only, crossing and
newline-deletion rejection with an allowed ordinary edit control. All changed
Lua files lint clean and pinned export --check/git diff --check pass.

ARCH-PURE/DRY/PURPOSE: one routing result supplies notices, eligibility and
permission; parser handles only this frontmatter field, using the existing
quoted scalar/boundary helpers. No external YAML process/dependency. Readable
canonical forms are supported; unsupported YAML shapes refuse explicitly.
Plan uses the canonical issue-slug filename named by change-code.

### 2026-10-16 — close the proposal permission class

Further concrete validation found that overlapping replacements can shift bytes
past their old spans and several proposal calls can reuse newly created text.
The local guard now requires unique snapshot matches, disjoint replacement
spans and one proposal batch per invocation before any proposal effect. The
multiple-call regression failed against the earlier driver and passes now;
a disposable earlier guard accepts overlapping spans, while the corrected guard
rejects overlap/non-snapshot cases. Mapped tests pass with six resolver cases;
the real invocation suite passes all 49 cases, process census clean.

The recorded run on d38fa68feae91fb320ff6d742989594c9c76b0f4 was cancelled
while queued (no suite tests had started) to add these corrections. This is a
new code head requiring fresh verification, not an unchanged flake retry.

### 2026-10-16 — corrected code head full suite passed

fce152dc891b3c7679f001aabd2e9acbd9e39aac passed the first full suite that
actually ran on this corrected head in 2m12s after 1456s queue. All files pass,
lint and process census clean; no retry/waiver. Recorded log:
.git/sdlc/local-checks/fce152dc891b3c7679f001aabd2e9acbd9e39aac/suite.log,
SHA256 prefix 8a72baa22663. BR-1's compatibility policy and runtime permissions
are implemented and regression-tested; BR-2's old-export success/notice family
is explicit in Done when and tested for sync plus --check. Shared generic
edit-engine overlap handling is filed unclaimed as #369, outside this local
adapter correction. Request full boundary review on the enlarged patch.

### 2026-10-16 — BR-1 declaration family corrected and verified

The full reviewer validated the original compatibility/guard corrections and
marked BR-2 addressed, but BR-1 stayed open for permissive declaration misses.
Root block recognition now decodes indentation and escaped/quoted keys, rejects
unsupported root shapes, merge keys and unclosed frontmatter, and preserves
true absence plus unrelated nested metadata/literal text. Root flow scanning is
linear; no external decoder or general YAML runtime dependency was added.

The shared 15-case declaration matrix runs through admission and real tool IO.
A disposable spec loading the pinned earlier parser after the test harness reset
reproduces nine forbidden writes (/tmp/parley-362-declaration-actual-red.log).
The first comparison attempt loaded the current module and was not red evidence.
Corrected real invocation tests pass all 64 cases; 17 pure value-parser cases
pass (Lua and LuaJIT), including a red/green literal quoted-text control.
Final mapped modes/review, lint, pinned-source --check and diff checks pass,
with clean process census. Submit the corrected code head to fresh full-suite
verification, then ask the binary's next boundary review to dispose BR-1.

### 2026-10-16 — declaration-corrected full suite green

3ed96ac1829348e5eda1ae2246c625273d39abec passed its first recorded full run
in 2m9s after 2743s queue. All 456 files pass, lint and process census clean,
no retry or waiver. Log .git/sdlc/local-checks/
3ed96ac1829348e5eda1ae2246c625273d39abec/suite.log, SHA256 prefix c182dab6c553.
The full run includes the 64 invocation cases and declaration admission matrix.
Request the full boundary review to dispose the remaining BR-1 family.

### 2026-10-16 — BR-3 synchronous scan work

Round 3 addressed BR-1/BR-2 and found no Critical defects, but measured quadratic
comment scanning (5/10/20 KB: 0.277/1.127/4.441 CPU seconds reproduced). The class
sweep also found repeated quoted-tail copies, multiline list concatenation,
and whitespace-pattern backtracking in the shared flat reader and trim.
Incremental previous-character state, offset-based quoted spans, one join per
list, and anchored edge scans remove those repeated prefixes/tails. The same
20 KB metadata parses in 0.001220 s; interior whitespace drops from 3.651 s to
0.001038 s. No canonical generated file or routing policy changes.

Regression evidence: both deterministic copied-byte bounds failed before the
fix (/tmp/parley-362-scan-red.log); the whitespace/multiline CPU budget also
failed (/tmp/parley-362-whitespace-red.log). All 20 pure parser tests pass after
the fix. The copied-byte bounds cover 5/10/20 KB scalar metadata and 100/200/400
quoted list members; the CPU check covers 20 KB interior whitespace and 4,001
multiline members with a generous 1-second CPU ceiling. Shared quoting tests
cover offset escapes and whitespace/comment preservation.

Focused verification note: the first post-sweep mapped and invocation commands
were accidentally overlapped in one checkout; the mapped cleanup correctly
reaped the other run as a leak (logs /tmp/parley-362-scan-final-mapped.log and
/tmp/parley-362-scan-invoke.log). This is a harness scheduling error, not a
passing test result or a product flake. Re-run those commands serially.

### 2026-10-16 — BR-3 final verification and staged live check

Serial verification passed: mapped modes/review (including 20 parser scale cases
and shared frontmatter cases), 64 real invocation/tool cases, 16 Python export
contracts, pinned-source --check, changed-file lint and git diff --check. The
serial logs are /tmp/parley-362-scan-serial-mapped.log and
/tmp/parley-362-scan-serial-invoke.log; the earlier overlapping attempts above
remain retained as scheduling failures, not product flakes.

Recorded full suite on 665ad29c90aa2ca769351a572e51f9a81e88afec: exit 0,
456/456 files, 764 files lint-clean, no surviving test processes. Queued 3951 s,
ran 2m9s, first full attempt on this code head; log SHA256 prefix 110eed3af072.
Log: /Users/xianxu/workspace/parley.nvim/.git/sdlc/local-checks/665ad29c90aa2ca769351a572e51f9a81e88afec/suite.log.

TL authorized staging in delivery b66293d4-85fd-4053-bdca-0d9d3d608153.
sdlc stage --build put that exact head on parley.nvim:0 (Lua plugin; no Go
binaries to build). A fresh interactive Neovim used the operator's actual
/Users/xianxu/.config/nvim config and the staged plugin, outside Couch, via the
actual Alt+Return mapping and temporary files. All-chat passed live: skipped
notice, zero provider queries and unchanged bytes. Unknown mode passed live:
visible refusal, zero queries and unchanged bytes. Mixed discussion/chat
showed both correct notices, then the real managed model picker listed Claude
and Codex logged out; its edit round could not run. Cancelled that picker and
exited the temporary Neovim. No credential change. Cleared the stage immediately;
:0 is back on main. Evidence: /var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/parley-362-live.GCLFlK/evidence.txt;
partial result and picker were observed directly in the interactive terminal.

Report 6973183b-df43-438d-bbcf-43a44cee72d2 is submitted. TL accepted this exact
partial live result in delivery 855c7c6f-26c4-4325-be62-983c1309da68: the mixed
edit is covered by real-tool invocation cases and gets its live check through
operator normal use; the TL tells the operator. Proceed to close and land.
This does not claim a live mixed edit pass.

Runner detail correcting the cancellation shorthand above: Escape was attempted
at the picker; the smoke runner ultimately recorded its 180-second mixed-round
timeout before exiting with status 1. The retained evidence file contains that
explicit timeout. The stage had already been cleared; the two live passes and
the observed logged-out provider blocker are unchanged.

### 2026-10-16 — BR-3 complete routing admission sweep

Round 4 disposed BR-1/BR-2, found no Critical or new defects, but kept BR-3
unaddressed: the parser was bounded while semantic routing still backtracked.
Reproduced document heading costs at 5/10/20 KB: 0.244/0.938/3.755 CPU seconds.
Two resolver-level scale cases failed before correction
(/tmp/parley-362-resolver-red.log). This is an incomplete class disposition,
not a new product-policy decision. The gate's round-cap demotion is not used
to ship the unresolved defect; close returned REWORK and remains unfinished.

The complete resolve-path enumeration is now: value-parser comment/quote/flow
scans and collection joins; flat-reader value/comment scans; heading-name trim,
whitespace collapse and one balanced suffix removal; fence recognition/closing;
ATX prefix/title extraction and closing-hash removal; per-row mode/protected
spans; deterministic missing-name warnings. Replace unanchored edge and heading
patterns with bounded scans, scan parenthesized suffixes backward, and normalize
each assignment once. Missing-name sorting keeps its existing deterministic
ordering; no routing/refusal/state/IO policy changes.

Post-fix 20 KB heading resolution is 0.000097 CPU seconds. All 10 resolver tests
and 20 value-parser tests pass; both new scale failures are green under Lua and
LuaJIT. Coverage includes 5/10/20 KB headings and assigned names, closing hashes,
20 KB interior whitespace, nested/unmatched annotations, long fence tails,
indented/overlong rejected headings, and existing functional routing cases.
Disposable differential checks agree for 10,000 deterministic name strings and
1,000 routing snapshots against the prior implementation
(/tmp/parley-362-resolver-compare.lua). Re-run mapped/real-tool tests and the
recorded full suite before close. Prior partial live acceptance remains exact.

### 2026-10-16 — integrate landed main before final recorded suite

Mapped review and all 64 invocation cases passed after the complete-resolver
fix. The recorded f6a03793 attempt (run 873031a21c660c1b5b06238df5b82d85)
was cancelled while queued at position 10, before any tests began, so final
verification can include the already-landed main required at publish. This is
not a test failure or flake retry. Merge of origin/main completed automatically
without conflicts, including README, traceability and lessons. Preserve the
queue-only log and run a fresh recorded full suite on the integrated head;
keep that head fixed through the run.

### 2026-10-16 — final complete-resolver integrated verification

On integrated head 95639f28b67bb97776d3a8b04bcc5786be2b651a, mapped review and
64 real invocation/tool cases passed serially (logs
/tmp/parley-362-integrated-mapped.log and /tmp/parley-362-integrated-invoke.log).
All 30 pure parser/resolver cases, 16 Python contracts, pinned-source --check,
lint and whitespace checks passed. No generated canonical source changed.

Recorded full suite: exit 0 in 2m24s after 4037 s queued; 461/461 files,
773 files lint-clean, no surviving test processes. First full attempt on this
integrated code head, no test failures or flake retries. The queued runner
survived the 22:22 Couch restart; its slot-holder and acquire process remained
alive, so it kept its place. Log SHA256 prefix 0f301da12b61:
/Users/xianxu/workspace/parley.nvim/.git/sdlc/local-checks/95639f28b67bb97776d3a8b04bcc5786be2b651a/suite.log.

The staged live evidence remains the exact partial result on 665ad29c above,
accepted by the TL in 855c7c6f. The complete-resolver correction changes scan
work while preserving routing semantics (direct and differential controls).
Re-close normally; BR-3 must be addressed by evidence, not its round-cap status.

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

### 2026-10-16 — BR-1 declaration recognition completion

The full reviewer independently verified local policy/permission regressions
and disposed BR-2, but reproduced root declaration forms silently becoming
absent routing. Refine the existing unsupported-input rule: only a genuinely
absent collaboration-mode in a recognizable root block mapping defaults to
discussion. Decode uniform root indentation and quoted/escaped root keys;
visibly refuse unsupported root flow maps, sequences, explicit/complex keys,
root tags/aliases/anchors and merge keys, including multiline forms. Nested
collaboration-mode under an unrelated field is not root routing. Keep all
canonical scalar/block/flow field values. Cover the declaration matrix in
pure parsing, local admission and real tool effects. This fixes the existing
chat-protection invariant, adding no routing mode, IO or baseline.

### 2026-10-16 — bound synchronous frontmatter work (BR-3)

ARCH-CONSTRAINTS: frontmatter admission must scan and copy in proportion to
input size. Track quote context incrementally, scan quotes by offset, join
multiline values once, and trim only at the edges. Pin 5/10/20 KB metadata,
long whitespace runs and many quoted/multiline members with deterministic
copy bounds plus a broad CPU stall check. Inspect all sibling parser scanners
and shared flat-reader patterns; re-run focused/full verification and close.
No change to the approved single-artifact policy or canonical export.

### 2026-10-16 — complete synchronous routing admission (BR-3)

Extend the bounded-work rule through the full resolve path, beyond YAML parsing:
heading extraction, closing-hash removal, name edge scans, whitespace collapse,
and one balanced trailing annotation. Enumerate fence handling, per-row routing
and warning assembly too. Require resolver-level scaling and semantic controls,
then fresh focused/full evidence and close review. This completes the same
performance class without changing the approved product policy.
