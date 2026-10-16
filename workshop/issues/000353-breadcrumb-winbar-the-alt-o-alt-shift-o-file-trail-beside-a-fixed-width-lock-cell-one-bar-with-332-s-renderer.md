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
- [ ] Run the required suite, close on SHIP, stage with the hub's coordination and perform the operator's live check before landing.

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
