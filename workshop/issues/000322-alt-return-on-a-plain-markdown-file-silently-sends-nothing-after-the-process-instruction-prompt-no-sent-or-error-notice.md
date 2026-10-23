---
id: 000322
status: codecomplete
deps: []
github_issue:
created: 2026-10-14
updated: 2026-10-23
estimate_hours:
card_mirror: 'd23dd52108997e5a0bbcce9896a0f4401e923233' # card fields mirrored from issue-cards; edit via sdlc
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "b73075b9", done: "d5ed7ad5"}
actual_hours: N/A
---

# Alt+Return on a plain markdown file silently sends nothing after the process-instruction prompt (no 'sent' or error notice)

## Problem

2026-10-14, the operator in ops:0's right pane: Alt+Return on `ops/teams/devinfra/qa/xian-xu/2026-10-14-01-following-operator-instructions.md` (plain markdown, no frontmatter) prompted for `process-instruction:`; the operator answered and nothing was sent. `:messages` shows only the file write ("… 25L, 1899B written"), no `review: sent to …` and no error. The file on disk had the operator's 🤖 comment but no `process-instruction:` line, so the flow stopped between `M.placement` (lua/parley/review_send.lua ~151–157) and `send_to_slot` (which saves first). Suspects: `couch.own_slot` returned `actors == nil` and fell into `run_via_invoke` (the outside-pair local review) silently, or its callback never fired; either way the operator got no signal.

## Spec

The operator's one-collaborative-mode pivot reopens this formerly superseded card. After #418 landed its narrow legacy-reader fix, #322 owns Alt+Return outside Couch: request the existing local review with no standing instruction or selected mode. It must never prompt for or insert process-instruction, including on a plain or partial-header file, and must visibly identify the local route. Preserve document bytes during submission preparation; ordinary review effects may still edit the document. Preserve review admission, lifecycle, cancellation and errors; Couch and legacy session-sync retain their existing submit owners.

Reuse review.run_via_invoke(buf, {}) (ARCH-DRY). Its existing marker admission decides whether to invoke, show pending questions, report nothing actionable, or refuse invalid legacy collaboration routing. A plain document without ready comments is a visible no-work outcome, not an implicit whole-document edit. A short local-route notice must describe a request, not claim generation completed. Ignore process-instruction for Alt+Return; preserve every legacy metadata byte. #419 separately owns the v4 bundle, retired-key notices/mapping, @@chat@@ policy and removal of obsolete completion. No new state owner, save path, cache, parser or transport.

Alternatives rejected: retaining the prompt violates the pivot; selecting free-form would retain an obsolete mode and force whole-document work; adding another submit/preparation state would duplicate the current owner. The thin adapter simply removes the asynchronous prompt branch. Existing review and skill_invoke retain in-flight/cancel/retry/source-edit ownership (ARCH-PURE, ARCH-STATE). It creates nothing durable; review's existing journal lifecycle remains unchanged (ARCH-FUNERAL). No persisted formats are rewritten (ARCH-EVOLVE).

The adapter adds constant work (one short notice and one owner call), removes a full-buffer read/expansion and holds no state between events; existing review scans retain their current bounds (ARCH-CONSTRAINTS). The named-buffer check and owned invocation keep source authority unchanged; no credentials or new trust boundary are introduced (ARCH-SECURE). Reuse the stateful fake Couch and native editor harness; provider lifecycle stays behind the existing dispatcher fixtures (ARCH-MOCK). New tests enumerate plain/partial/legacy input and marker/no-work/pending/chat/refusal outcomes, serving the original silent-submit purpose rather than merely deleting a prompt (ARCH-PURPOSE).

## Done when

- Outside Couch, Alt+Return on named plain/partial-header/legacy-instruction Markdown requests exactly one local review with empty args, no prompt, no Couch actor lookup/send, no submit-time metadata or body rewrite, and a visible local-route notice.
- Real local admission still invokes ready comments and visibly reports no actionable comments, pending-only documents, protected chat or malformed routing; unnamed buffers report save-first. Cancellation and provider failure remain owned and reported by existing review/skill_invoke.
- Pane and legacy session-sync dispatch retain their existing owners; pane save/register/delivery coverage stays green.
- Tests pass on both supported Neovim runtimes, native mapping/UI evidence proves the notice permits subsequent input, the recorded suite passes, and the binary-owned close review clears. Hub coordinates live acceptance before landing.

## Plan

- [x] Add failing production-mapping regressions for outside-Couch plain/partial/legacy files, exact empty arguments, no prompt/write/send, and local-route/error outcomes; exercise actual review admission as well as the adapter seam.
- [x] Remove prompt/placement/standing-instruction expansion from review_send.submit; delete unused insertion helpers, keep completion until #419; retain existing coordinator dispatch and invoke the existing local owner with empty args and a short truthful notice.
- [x] Run focused review-send/review-invoke/native ownership tests on both runtimes, plus native UI notice/input verification and relevant architecture/lint checks; update atlas and checkpoint.
- [x] Push and retain the recorded suite; coordinate the approved stage and live acceptance with the hub.
- [x] Admit the tested candidate to binary-owned close review. Landing remains conditional on the recorded suite and live acceptance, then merge owns integration.

## Log

- 2026-10-15 — operator requested folding this into #332. Its feedback implementation passes18 production-door admission cases and64 native edit cases, including first-submit success and pre-attachment/attached error visibility. Close this duplicate as superseded by #332; remaining suite, review and operator acceptance stay on the parent.

### 2026-10-14

### 2026-10-23 — reopened for mode-free local submission
- 2026-10-23: closed — Both runtimes: submit25, review-admission39, invocation64, document-lifetime10, guards2+2 and native attached-UI8 pass; clean census, no prompt/submit rewrite/blocked input, lint and docs4 pass. Recorded suite lease-2691705198 and operator live acceptance pending; landing waits for both. Measured window includes parley.nvim#418 tail (11:18–14:30) because #322 was claimed on the same slot concurrently; clean #322 effort began 14:30; no typed hours. TL35643b0f explicitly directs --no-actual.; review verdict: SHIP

TL49bad7d4 assigned real mode-free outside-Couch work here, superseding the earlier acceptance-only/no-actual proposal and duplicate close; TL1341251d dispatches this item after #418 landed. start-plan created a fresh main-based branch and rebuilt slot tools during catch-up; seeded merge-check regeneration was correctly deferred, with no local-gates file mutation. Inspection confirms the existing local prompt returns silently on cancellation; the local review already owns no-marker/pending/provider outcomes. Keep that owner and remove only standing-instruction submission. Previous TTY unavailable; current source and authenticated dispatch are the evidence.


### 2026-10-23 — test-first mode-free adapter implemented

RED: outside-Couch plain/partial files still prompt, and an unknown retired instruction blocks invocation (21 prior cases pass,3 new failures). Native attached UI independently reproduces the prompt in all6 named Normal/Insert cases;2 unnamed error cases pass. GREEN after deleting the prompt/expansion path: submit25, real review-admission39, invocation/lifetime64, document-lifetime10 and two selected architecture guards2+2 pass on the preferred runtime. Native UI8 passes on both preferred and0.11.7, preserving real builtin notification behavior, live/disk bytes, changedtick, and subsequent typing. No native prompt/hit-enter issue remains. Changed Lua lint is0 warnings/errors. Compatibility owner checks are running; no full suite or live acceptance has been claimed. Existing completion stays for #419. Next: finish compatibility, commit/push, queue recorded suite, request hub staging/live acceptance, then binary close review.

### 2026-10-23 — both-runtime focused qualification green

The complete focused owner map passes on both Neovim0.12.5 and0.11.7: submit25, review-admission39, invocation64, document-lifetime10, arrival2 and admission-owner2, with clean terminal process censuses. Native UI8 passes on each runtime separately. No code changes beyond the thin adapter deletion and truthful local-request notice. Clarified that byte preservation is submit preparation, not a ban on later provider-owned edits. Atlas and traceability include the new native regression. No full suite or operator acceptance result yet. Next: commit/push this exact code, retain one recorded branch suite, and ask hub for staging/live acceptance before landing.

### 2026-10-23 — published candidate, retained suite and authorized stage

PR344 contains code b9135976daa17a4a2986cb1fd1b8e02fd4708e9d. Recorded suite terminal81302, lease-2691705198, checkout /Volumes/TestScratch/local-checks/sdlc-local-2867989229, inflight log .git/sdlc/test-stats/inflight/2f462d85c36ec3d495801235b68a6e90/run.log; last seen FIFO6, not yet admitted. Preserve that runner and do not restart/requeue for these documentation-only descendants. No full-suite result yet.

Authenticated TL7f03823a approves staging; stage --build completed on parley.nvim:0 at the exact candidate b9135976daa17a4a2986cb1fd1b8e02fd4708e9d. This Lua plugin has no Go entrypoints/binaries, so no Go build was needed. Hub received three operator steps (plain no-work; ready comment; unnamed save-first) and a fresh-plugin-load caution; receipt1c6f1f7a is submitted. Operator acceptance remains pending. Clear stage after acceptance or landing through the existing SDLC lease, without touching editor processes.

A documentation sweep corrected standing-instruction descriptions and links to the renamed Alt+Return atlas section; documentation_spec4 passes with clean census. Exact next step: read retained terminal81302 to completion, receive live result, then binary-owned close review/merge. No new full run is authorized merely by queue delay; classify any failure and retain all attempts. #419 remains separate, waiting for the landed #576 fixture revision.

### 2026-10-23 — close review overlaps retained suite

TL-worker explicitly permits the binary-owned close review alongside a queued recorded suite, provided a final-code pass precedes landing and any review code fix requeues verification. Enter close on the complete tested candidate; suite lease-2691705198 and operator acceptance are still pending. Plan ticks record review admission and completed stage coordination, not those pending landing conditions. This issue has its own new implementation interval under the revised dispatch, so use measured actual adoption; the historical acceptance-only no-actual proposal was superseded by TL49bad7d4. Never infer a full-suite pass or live result from codecomplete.

### 2026-10-23 — contaminated actual rejected before finalization

The first close proposed4.59h and a dominant203.5m interval11:18–14:42; this includes #418's post-close classification/verification/landing tail through14:30 under the concurrent #322 claim. Authenticated TL35643b0f explicitly says do not adopt it: close with --no-actual and cite the contamination, no typed hours; file the classifier defect unclaimed in Ariadne. Interrupted only the in-flight close review through its terminal; it returned context-cancelled with no verdict or completion. Fresh issue observation confirms working, no completion, no actual adopted. Suite terminal81302/lease-2691705198 remains retained and unchanged. Re-enter close with the precise --no-actual waiver and required reason; no measurement-source repair.

## Revisions

### 2026-10-15 — Superseded by #332 at operator request

The requested Couch-pane workflow now uses save→register→submit rather than the original process-instruction prompt→placement→resubmit route. #332 owns visible owner/time success and visible errors, plus the remaining combined live check. Preserve the original report and acceptance text as evidence; close this card as a superseded duplicate, not as a claim that its original prompt route or outside-pane flow was newly implemented.

### Historical duplicate contract retained for provenance

#### Historical Spec

Covered by #332: Couch-pane Alt+Return saves, registers and submits named Markdown without prompting for process instructions; it shows completed submission owner/time or an explicit visible error. No separate implementation remains on this duplicate card.

Every Alt+Return ends with exactly one visible outcome: `review: sent to <slot>`, a named error (cannot resolve this slot; couch unavailable; save failed), or, outside pair, an explicit "no slot: running the review here". Find the actual path on the operator's setup (ops:0's right pane, Couch with several hubs since pair#546) and fix the resolution if it's wrong there.

#### Historical Done when

The parent #332 owns implementation, verification, review, staging/live acceptance and landing. This duplicate is closed as superseded; it does not claim the parent has landed.

- Reproduced with a test of the prompt → placement → resubmit path; each branch of `own_slot` notifies.
- In ops:0's right pane, Alt+Return on a plain markdown file reaches ops:0 (`review: sent to ops:0`).

#### Historical Plan

- [ ]


### 2026-10-23 — active local-submit contract replaces superseded duplicate

The historical #332 duplicate closure and #418 acceptance-only proposal no longer describe remaining work. #418 delivered only the legacy parser correction. This issue now delivers mode-free local Alt+Return and its visible route, without frontmatter insertion. #419 follows with v4 fixtures and the tag/legacy policy. Plan is quick-flow sized: deletion of the old prompt/expansion path, no new state or transport, under 100 added runtime lines.
