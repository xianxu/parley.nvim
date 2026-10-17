---
id: 000353
status: working
deps: [parley.nvim#332]
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours: 4.54
card_mirror: 'ff06dcb52eb216c52dd51840577e7e21d0e50bf2' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T09:59:46-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: full, provenance: operator}
---

# Breadcrumb winbar: the Alt+o / Alt+Shift+O file trail beside a fixed-width lock cell (one bar with #332's renderer)

## Problem

Moving through a tree of documents with Alt+o (into a link) and Alt+Shift+O (back up), the operator loses track of
where they are. Operator design, 2026-10-16 (ops QA `teams/devinfra/qa/xian-xu/2026-10-16-03-breadcrumb-winbar.md`):
show the trail in the winbar, combined with the Couch/parley lock bar. Part of ops project
universal-agent-input-interface.

## Spec

- **A per-window stack:** a file opened any way other than Alt+o is the root (the stack clears); Alt+o pushes the
  target; Alt+Shift+O pops. At the root, no breadcrumb.
- **One winbar, built by #332's shared renderer:** a fixed-width lock cell first (about 9 cells: `yours ●` with the
  dot meaning unsubmitted edits, `free`, `agent…`, `stale`), keeping the background colour for "needs submit"; then
  the breadcrumb: basenames without `.md` or a `YYYY-MM-DD-` prefix, joined by `›`; when too long, the middle
  collapses to `…`, keeping the root and the last two; same-named files gain their parent folder.
- Click-to-jump on a segment: out of scope (later).
- **Expose the per-file breadcrumb** (the trail at a moment) as a value other features can store and restore (the
  attention finder uses it).

## Done when

- Tests: push, pop, reset on non-Alt+o opens, per-window independence, truncation, same-name disambiguation, and
  lock-cell rendering for each state through the shared renderer; the operator's live check.

## Plan

Full-flow, single close boundary. Detailed design: [breadcrumb winbar plan](../plans/000353-breadcrumb-winbar-plan.md).

- [x] Add pure breadcrumb transitions and display projection, with direct sequence/width tests.
- [x] Record successful Alt+o destinations through the existing file history; expose snapshot/restore values and preserve native Back behavior.
- [x] Compose a nine-cell lock state, breadcrumb and feedback in document_band; keep its restoration ownership and both file kinds identical.
- [x] Exercise native keys, async resolution, split/window lifecycle and every lock/feedback state; update atlas/README/traceability.
- [x] Run the required suite and retain final-head verification evidence.

After code verification: close on SHIP and report green to TL. Do not stage; :0 holds a combined operator check. TL sequences the live check before any landing decision.

## Log

### 2026-10-16

- Planning follows landed #332 PR241, merge `3219cc0c705bd1a7c097bcf920135155892645b9` verified with git rev-parse; exact integrated-head suite passed, four CI checks green. Hub received the outcome (receipt 7d3db9df-927c-40ab-af86-588a7891a6e5 submitted).
- Existing `file_history` records every native file visit, not only Alt+o, and restores cursors/skips missing paths on Back. Breadcrumb is a value carried by those visits, not a replacement for this history (ARCH-DRY). `M.open_buf` may focus another editing window, so follow must commit against the actual destination window; async artifact/family resolution must carry the same explicit origin rather than leave a global pending flag.
- Staging lesson from #332: a later worker had replaced :0's stage with #257 at `d3909bd93e7cc6a0194fe255a1778099f489c5b7`; unconditional stage --clear removed that newer stage. Hub informed in the submitted landing report. Inspect the current stage identity before clearing; if another item's stage replaced ours, leave it to its owner.
- Design pending TL approval; no implementation started.

### Implementation evidence

- Pure model RED and GREEN: /tmp/parley353-core-red.log, /tmp/parley353-core-red2.log, /tmp/parley353-core-green2.log (6 breadcrumb +12 history cases). Generated independent-window sequences protect immutability, trail/Back coherence and bounds.
- Navigation RED→GREEN captured missing APIs, redirected target rejection, unavailable-origin ordinary navigation and repeated-path overflow cursor provenance. Final /tmp/parley353-navigation-references-green.log has386 passing cases; file_history has44 passing cases. Existing security/native/async resolver paths remain green.
- Composition RED: /tmp/parley353-band-red.log, six assertion failures and zero errors for the absent model. GREEN: /tmp/parley353-band-green.log, all six cases pass. Native shared-renderer run /tmp/parley353-band-mapped.log passed new matching-trail and same-buffer/two-window/resize cases; two legacy whole-bar receipt assertions needed updated independent lock/feedback expectations, with corrected mapped rerun pending.
- Corrected focused run /tmp/parley353-render-green.log passes all17 window/ownership/parity cases and6 pure composition cases. The only remaining mapped-renderer failure was a test helper trimming a trailing literal newline-space from an error; raw receipt extraction now preserves exact literal feedback and the focused rerun passes. All prior session-sync native lock/undo cases passed the mapped run.
- Final keybinding mapping /tmp/parley353-keybindings-final.log passes, including architecture concept/symbol guards and plain native Alt+o/Back bar assertions. Context/file_references mapping passes386 cases. Changed-file lint and diff checks are clean.
- Collision regression /tmp/parley353-core-collision-red.log fails for irreducible stripped names; /tmp/parley353-core-collision-green.log passes7 breadcrumb and12 history-model cases after original-identity fallback.
- No staging: TL reserves :0 and will sequence the live check after green review.

- Final API contract adversary: a named file containing an unsupported control character returned nil without the promised reason. /tmp/parley353-snapshot-reason-red.log has44 passes/1 expected failure; the corrected cached projection preserves nil,reason and /tmp/parley353-snapshot-reason-green.log passes45 real-history cases. This is a production change after the first suite head, so final required-suite evidence will use the new head.

- First required suite passed448/448 spec files, lint749 clean, no survivors on `ed5af56cef2c8b6b917f0bd932eb18c1a36c0591`; retained log `/Users/xianxu/workspace/parley.nvim/.git/sdlc/local-checks/ed5af56cef2c8b6b917f0bd932eb18c1a36c0591/suite.log`, SHA256 `c5e72d52cd1a7d8a00a83c7b97d870b02ba3ca5487d318be7b83832bc1a11bea`.
- Final source-head suite on `f4239bccc3af35cd6fd0cbe65fafb1f128b45bb1` completed all tests:446 spec files passed, two independent cliproxy specs failed, lint749 clean, no survivors. Failures: catalog joins-routes case returned empty at cliproxy_catalog_spec.lua:75; expired-token recovery chose retry instead of give_up at cliproxy_auth_login_spec.lua:128. Immutable retained log `/Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/bd9f02e9a941c6a23073857764765ecb.log`, SHA256 `3c666a396002ea5ad421f2d8042d2bb452182ddea7f675de21a3b2607d7a470a`.
- Same-head focused replay of those two specs passes43 cases in `/tmp/parley353-cliproxy-repro.log`; no cliproxy source or fixture was edited. Filed separate unclaimed flake issues #360 (catalog) and #361 (auth), each with head, assertion, first-seen date, logs and deterministic-investigation Done when. Applying the approved issue-backed flake rule: one unchanged full-suite retry on f4239bcc, no waiver; if that fails, report the remaining blocker rather than blind retries.
- Real/fake sdlc resolver conformance passes all6 cases through production run_resolve/parse/dispatch using an isolated temporary Git repository (`/tmp/parley353-sdlc-conformance.log`).

- The one unchanged issue-backed retry passed448/448 spec files, lint749 clean, no survivors on f4239bccc3af35cd6fd0cbe65fafb1f128b45bb1; log /Users/xianxu/workspace/parley.nvim/.git/sdlc/local-checks/f4239bccc3af35cd6fd0cbe65fafb1f128b45bb1/suite.log, SHA256 4ed6914d565b6c50d3d49e8a592a82da850edb9d2c01071c069052a7c12ccf04. Both earlier failures remain linked to #360/#361. No waiver.
- A focused pre-close ownership probe then reproduced a real remaining #353 bug: pending-move fallback rendered unknown/WarningMsg over an attached operator lock. Durable RED /tmp/parley353-overlay-red.log reproduces both real pending recovery and refresh-overlay ordering; /tmp/parley353-overlay-knowledge-red.log proves fallback errors were also inventing free state from severity. Fixed the full class with explicit overlay inputs, underlying state ownership, stable overlay ordering, recomposition after either owner detaches, and plain/unknown fallback knowledge. /tmp/parley353-overlay-final-green.log passes18 real window cases +6 composition cases; changed-file lint clean. The final full suite will run on the new production head.

- Final production-head required suite passed448/448 spec files, lint749 clean, no surviving test processes on `bf196623e36642c1368ccdbc33be4ca135d0f166` (2m35s). Retained log `/Users/xianxu/workspace/parley.nvim/.git/sdlc/local-checks/bf196623e36642c1368ccdbc33be4ca135d0f166/suite.log`, SHA256 `c39a78cc28c7f39bc0c4298fde6716a4326d7b1fc5397c523d916606fcdbceb1`. Final overlay focused evidence passes18 native window/ownership/parity cases +6 pure composition cases;45 real-history and6 real/fake resolver conformance cases also pass. Prior failed attempts and issue-backed retry remain retained against #360/#361. Close review follows; no staging per TL.

- Close initially refused before review because main had new code; merged origin/main without conflicts. Integrated production head `5ac7cd3548c3cdc11ec5d0812e6c042e2352c9e6` then passed the required full suite on its first attempt: 454/454 spec files, Total: 0 warnings / 0 errors in 760 files, no surviving processes (3m8s). Log `/Users/xianxu/workspace/parley.nvim/.git/sdlc/local-checks/5ac7cd3548c3cdc11ec5d0812e6c042e2352c9e6/suite.log`, SHA256 `435f2e463b87d493b2b7c130c6188b9d3ddc0f204cc5e4f2363a5ed8d0cc3403`. Main supplied reload cursor preservation and review/provider changes; shared session_sync merge retains both view restoration and lock/feedback projection. This integrated pass supersedes the earlier pre-merge suite for final close evidence.

- Close review round1 returned REWORK: BR-1 renderer-ownership-state, BR-2 window-option-ownership, BR-3 protected-breadcrumb-segments. Adapter RED `/tmp/parley353-br12-red.log` reproduced the plain-root crash and all six independent option-override cases (18pass/7fail); GREEN `/tmp/parley353-br12-green.log` passes25 native cases after one per-option installation helper handles initial paint, refresh, layer handoff and cleanup. A prepared record has no installation proof and retires safely; a user override relinquishes only that option for the record's lifetime. Pure RED `/tmp/parley353-br3-red.log` and `/tmp/parley353-br3-leaf-red.log` cover missing parent and oversized-leaf bypass; `/tmp/parley353-br3-final-green.log` passes10 cases including Unicode/combining widths, duplicate context and generated budgets0–120. Changed four-file lint and whitespace checks pass. Source changed, so required suite and close review will be rerun.

- Post-review-fix required suite on `aa8a3408fd3338402eb949a7c275335bd9c9966f` ran all454 spec files:453pass and only cliproxy_lifecycle_spec failed (two credential-restart cases, timeout and unexpected killed-port probe),760 lint clean, no survivors. Retained log `/Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/1faa0580088008736845350a044e2a30.log`, SHA256 `433c84052df7d9a2abef784e9e0ba7b353e338ec0172f8112c66ea7dec0c42a5`. Same-head focused `/tmp/parley353-lifecycle-repro.log` passes63/63 without source/fixture/assertion/timeout changes; lifecycle module/spec/helper have no branch diff against main. Filed unclaimed #363 with exact cases/head/log/first-seen and deterministic-investigation Done when. Applying the issue-backed flake rule: one unchanged full-suite retry on the same `aa8a3408fd3338402eb949a7c275335bd9c9966f`; no waiver, no further blind retries.

- The sole allowed unchanged full-suite retry also completed all454 files: 452pass, catalog and auth failed,760 lint clean,no survivors (4m16s after55s queue). Log `/Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/220afa677e351fcb53a792c7553029a5.log`, SHA256 `7576e666c8badab1fffee47cacf5369530e3f793b097b1133091f37837de37c6`. Lifecycle #363 passed on this attempt. Catalog matches #360 (joins-routes returns empty at line75). Auth is an additional variant in the #361 spec: oauth-model-alias Claude login prompt missing at line149, rather than the earlier expired-token retry case; shared cause is not asserted. This is a second unrelated flake on the same head, so no further retry or close finalization. Report the verification blocker to TL for disposition/flake dispatch; retain unstaged branch and all three review fixes.

- 2026-10-16 22:24 PDT: TL explicitly authorized one additional unchanged full-suite run, issue-backed by #360/#361/#363 (submitted receipt f3fdd54b-5146-40b6-b8d1-d177d5dd26ab). If green, re-close and continue; if another filed flake fails, stop and tell TL, who is dispatching the flake work. Restart audit found no existing sdlc/make runner in this checkout; the previous two runs had completed before Couch's22:22 restart, so this is the authorized additional attempt, not recovery of a killed run. Production source stays aa8a3408fd3338402eb949a7c275335bd9c9966f.

- The TL-authorized additional run passed on `833370703bf6c0d1a29e17e0f12dfc570b2fe210`: 454/454 spec files, Total: 0 warnings / 0 errors in 760 files, no surviving processes. Retained log `/Users/xianxu/workspace/parley.nvim/.git/sdlc/local-checks/833370703bf6c0d1a29e17e0f12dfc570b2fe210/suite.log`, SHA256 `ad74c70b20c3a16db5d3f0155618faca6a77223a0b65c508e0f0d898036c1679`; runner reported1m58s execution. Production source/tests match aa8a3408; only issue Log differs. Earlier failures remain retained against #360/#361/#363; no waiver. TL's wrapper handoff request now takes priority before the next long wait: report this green suite and pause for same-conversation relaunch, then re-close against the three fixed review families. Unstaged pending TL's live sequencing.

## Revisions

### 2026-10-16 — #354 persisted-trail coordination

Agreed with parley.nvim:3: retain snapshot(win)/restore(win,value), with an opaque JSON-safe value. Finder owns opening the selected file; restore owns removing missing ancestors and installing the surviving trail/Back stack without opening files. It returns false plus a reason for invalid values, uncertain ancestor checks or final-file mismatch; finder keeps the opened file as a root on refusal. Detailed contract and regression cases are appended to the durable plan. Awaiting TL approval before implementation.

- TL approved the design and contract Revision (receipt 5d93a58a-2467-42dd-bac4-6b468bbf15d1, submitted). Full-flow change-code next. Live-check override: report green without staging; :0 is reserved for a combined check and TL will sequence this one.

### 2026-10-16 — Plan gate refinements

Plan gate round1 identified PQ-1 (destination history must match a cross-window trail) and PQ-2 (name risky functions and generated adversarial strategies). Appended one install_trail transition for all follows/restores, with destination-history overlap/cursor rules and generated sequence/width/validation invariants. No implementation before the rerun admits the plan.

## Estimate

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A only. Calibration source is tagged stale by estimate-source, so rates remain provisional. Three focused Lua primitives cover pure trail/history, native/async navigation and shared renderer wiring. One TUI projection covers width/state composition; docs, cross-file integration and one close review are separate. Existing history, renderer and text measurement APIs remove novel-stack discovery; no external library is needed. Thorough approved plan gives design ×0.2 (Lua midpoint2h→0.4h each; TUI midpoint1.25h→0.25h) and15% design buffer; implementation values are40% of the upper v2 ranges. Familiar territory uses1.0. Sum design1.62×1.15 + impl2.68 =4.543, rounded4.54h.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.4 impl=0.6
item: lua-neovim design=0.4 impl=0.6
item: lua-neovim design=0.4 impl=0.6
item: tui-screen design=0.25 impl=0.4
item: cross-cutting-refactor design=0.12 impl=0.2
item: atlas-docs design=0.03 impl=0.08
item: milestone-review design=0.02 impl=0.2
design-buffer: 0.15
total: 4.54
```
