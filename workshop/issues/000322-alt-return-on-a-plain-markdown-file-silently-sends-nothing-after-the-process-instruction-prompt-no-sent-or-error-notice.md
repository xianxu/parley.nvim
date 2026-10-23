---
id: 000322
status: working
deps: []
github_issue:
created: 2026-10-14
updated: 2026-10-23
estimate_hours:
card_mirror: '06bec2a32000bebe13d7746d9360479a6e7912f3' # card fields mirrored from issue-cards; edit via sdlc
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# Alt+Return on a plain markdown file silently sends nothing after the process-instruction prompt (no 'sent' or error notice)

## Problem

2026-10-14, the operator in ops:0's right pane: Alt+Return on `ops/teams/devinfra/qa/xian-xu/2026-10-14-01-following-operator-instructions.md` (plain markdown, no frontmatter) prompted for `process-instruction:`; the operator answered and nothing was sent. `:messages` shows only the file write ("… 25L, 1899B written"), no `review: sent to …` and no error. The file on disk had the operator's 🤖 comment but no `process-instruction:` line, so the flow stopped between `M.placement` (lua/parley/review_send.lua ~151–157) and `send_to_slot` (which saves first). Suspects: `couch.own_slot` returned `actors == nil` and fell into `run_via_invoke` (the outside-pair local review) silently, or its callback never fired; either way the operator got no signal.

## Spec

The operator's one-collaborative-mode pivot reopens this formerly superseded card. After #418 landed its narrow legacy-reader fix, #322 owns Alt+Return outside Couch: request the existing local review with no standing instruction or selected mode. It must never prompt for or insert process-instruction, including on a plain or partial-header file, and must visibly identify the local route. Preserve document bytes, ordinary review admission, lifecycle, cancellation and errors; Couch and legacy session-sync retain their existing submit owners.

Reuse review.run_via_invoke(buf, {}) (ARCH-DRY). Its existing marker admission decides whether to invoke, show pending questions, report nothing actionable, or refuse invalid legacy collaboration routing. A plain document without ready comments is a visible no-work outcome, not an implicit whole-document edit. A short local-route notice must describe a request, not claim generation completed. Ignore process-instruction for Alt+Return; preserve every legacy metadata byte. #419 separately owns the v4 bundle, retired-key notices/mapping, @@chat@@ policy and removal of obsolete completion. No new state owner, save path, cache, parser or transport.

Alternatives rejected: retaining the prompt violates the pivot; selecting free-form would retain an obsolete mode and force whole-document work; adding another submit/preparation state would duplicate the current owner. The thin adapter simply removes the asynchronous prompt branch. Existing review and skill_invoke retain in-flight/cancel/retry/source-edit ownership (ARCH-PURE, ARCH-STATE). It creates nothing durable; review's existing journal lifecycle remains unchanged (ARCH-FUNERAL). No persisted formats are rewritten (ARCH-EVOLVE).

## Done when

- Outside Couch, Alt+Return on named plain/partial-header/legacy-instruction Markdown requests exactly one local review with empty args, no prompt, no Couch actor lookup/send, no metadata or body rewrite, and a visible local-route notice.
- Real local admission still invokes ready comments and visibly reports no actionable comments, pending-only documents, protected chat or malformed routing; unnamed buffers report save-first. Cancellation and provider failure remain owned and reported by existing review/skill_invoke.
- Pane and legacy session-sync dispatch retain their existing owners; pane save/register/delivery coverage stays green.
- Tests pass on both supported Neovim runtimes, native mapping/UI evidence proves the notice permits subsequent input, the recorded suite passes, and the binary-owned close review clears. Hub coordinates live acceptance before landing.

## Plan

- [ ] Add failing production-mapping regressions for outside-Couch plain/partial/legacy files, exact empty arguments, no prompt/write/send, and local-route/error outcomes; exercise actual review admission as well as the adapter seam.
- [ ] Remove prompt/placement/standing-instruction expansion from review_send.submit; delete unused insertion helpers, keep completion until #419; retain existing coordinator dispatch and invoke the existing local owner with empty args and a short truthful notice.
- [ ] Run focused review-send/review-invoke/native ownership tests on both runtimes, plus native UI notice/input verification and relevant architecture/lint checks; update atlas and checkpoint.
- [ ] Push, queue recorded suite, coordinate live acceptance with the hub, close via SDLC and let merge own integration.

## Log

- 2026-10-15 — operator requested folding this into #332. Its feedback implementation passes18 production-door admission cases and64 native edit cases, including first-submit success and pre-attachment/attached error visibility. Close this duplicate as superseded by #332; remaining suite, review and operator acceptance stay on the parent.

### 2026-10-14

### 2026-10-23 — reopened for mode-free local submission

TL49bad7d4 assigned real mode-free outside-Couch work here, superseding the earlier acceptance-only/no-actual proposal and duplicate close; TL1341251d dispatches this item after #418 landed. start-plan created a fresh main-based branch and rebuilt slot tools during catch-up; seeded merge-check regeneration was correctly deferred, with no local-gates file mutation. Inspection confirms the existing local prompt returns silently on cancellation; the local review already owns no-marker/pending/provider outcomes. Keep that owner and remove only standing-instruction submission. Previous TTY unavailable; current source and authenticated dispatch are the evidence.


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
