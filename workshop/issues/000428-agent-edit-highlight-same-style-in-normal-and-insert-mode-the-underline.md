---
id: 000428
status: working
deps: []
github_issue:
created: 2026-10-23
updated: 2026-10-24
estimate_hours:
collaboration-mode: collaboration
card_mirror: '6061234d03858dd7adbdb63e5b48437d296d49ae' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-24T07:36:07-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "06db3071", done: "cc0eabff"}
---

# Agent-edit highlight: same style in normal and insert mode (the underline disappears in insert)

## Problem

## Spec

**The agent-edit highlight changes style between normal and insert mode (operator, 10-23).** In a collaborative
document, the highlight of the agent's last edit shows with an underline over the whole edited text in normal mode;
on entering insert mode the underline disappears (only link-like references such as `pair#844` stay underlined).
Screenshots: ops `assets/session/2026-10-23.12-29-46.680.png` (normal) and `2026-10-23.12-30-25.815.jpg` (insert).
The operator wants **one consistent style** unless there's a reason to differ.

First find why it differs (an intentional insert-mode style, a highlight group linked to something mode-dependent
such as CursorLine or Visual, a conceal or extmark priority interaction, or the colorscheme), and report the cause
before changing anything. Then make the edit highlight render the same in every mode (the reference underlines are
separate and stay).

## Done when

- The cause is stated in the Log.
- The agent-edit highlight's attributes are identical in normal and insert mode (test reading the effective
  highlight at a position in both modes).

## Plan

- [x] Configure underline=false once at the owned edit-explanation diagnostic namespace, retaining tint highlights and all diagnostic data (ARCH-DRY).
- [x] Add red-first native effective-cell comparisons across modes/refreshes, round/skill/footnote writers, tint kinds and custom styles; keep independent reference/foreign-diagnostic controls.
- [x] Update README/atlas and verify existing render/round/diagnostic display tests. Recorded pre-close and boundary review remain workflow gates.

## Log


- 2026-10-24: closed — Cause captured before code: native probe shows stable ParleyEditChange bg plus DiagnosticUnderlineInfo in Normal, only bg after Insert-mode round rederive; InsertLeave restores diagnostic layer. Red effective-cell matrix0/6/0 before fix; namespace-only underline=false makes style consistent without changing global/update timing or payloads. Final focused67/0/0 across render, round/hooks, diagnostic display, highlight groups and arrival guards; installed-runtime native matrix7/0/0. Actual composed cells compared in Normal/Insert/Replace/Visual/Visual-line with add/change, round/skill/footnote, custom tint and explicit custom underline; references and foreign diagnostics keep their styles, semantic messages/sign marks and pre-existing global/foreign settings retained. Logs /Volumes/TestScratch/parley428.qkdGOp; lint858 clean, diff-check clean. README/atlas updated. Recorded --pre-close suite PENDING on pushed e6e2a208d14027b4eb52c5056d2b916a5228a27c; must pass before merge. Live check awaits hub sequence, no stage touched.; review verdict: SHIP
### 2026-10-23


### Cause confirmed before production code

Native probe /Volumes/TestScratch/parley428.qkdGOp/probe.log on unchanged code passes1/0/0 with clean census and inspects actual composed cell attributes through nvim__inspect_cell. ParleyEditChange itself remains background1977405 in every mode. Normal effective cell additionally has underline=true and special9238775 from DiagnosticUnderlineInfo. Mere InsertEnter leaves that layer; calling the existing round rederive while in Insert removes the diagnostic underline mark (1 to0) and the effective cell becomes background-only. InsertLeave redraw restores the mark and underline (0 to1). No colorscheme/group mutation occurs. The operator screenshots likewise show a stable tint and stable explicit-reference underline.

Owner chain: edit_round's on_lines schedules skill_render.rederive_round; set_round_diagnostics replaces INFO records in parley_skill; Neovim diagnostic.show calls hide before checking update_in_insert (default false), then defers its handlers until InsertLeave. This is an incidental diagnostic overlay, not an intentional Insert-mode edit style. Cause and fix plan reported to hub before code.

The intended edited-span style is already the background-only ParleyEditAdd/ParleyEditChange tint (#386/#387). Disable diagnostic underline in that owned namespace rather than enabling all diagnostic refresh work in Insert or adding mode callbacks. The same namespace owns round, review-skill and footnote explanations, so enumerate all three writers. Do not change the global diagnostic options, semantic records, gutter/display handlers, or explicit reference groups. User highlight overrides remain supported and mode-independent. This adds no state a user acts on, no per-keystroke work, no timer, and no durable artifact. One namespace-local configuration at lazy namespace creation; the native matrix reads composed UI cell attributes, not merely named group definitions.


### Implementation and targeted verification

Hub approved93e9445b-7fbe-4420-99f6-191c12326a63: namespace-local underline=false only, retaining tint, messages, signs, independent reference underlines and foreign settings, with README discoverability. Added that one configuration at lazy skill_render namespace creation; no global setting, mode hook, update-in-insert policy, per-keystroke work or diagnostic payload changes.

Native red.log on unchanged production code:0/6/0, all six composed-cell tests fail at the Normal/Insert refresh comparison. Green.log after the local configuration:6/0/0, clean census. Expanded to7 cases including explicit user underline styling. The new test reads actual composed UI attributes with nvim__inspect_cell at a buffer position, enters Normal/Insert/Replace/Visual/Visual-line through native input, and re-publishes each diagnostic kind. Add/change/round/skill/footnote/custom styles remain stable; reference and foreign diagnostic underlines survive, messages and sign marks remain. An initial strengthened global-config control counted the pre-existing custom handler registration as a setting mutation; corrected it to compare every pre-existing global option and the foreign namespace's full options. No production adjustment was needed for that fixture correction.

Final focused-final.log: exits0,67/0/0 across skill_render, skill_render_round, edit_round, edit_round_hooks, review_diag_display, highlight_groups, native effective-cell matrix and arrival architecture guards. operator-native.log on installed /opt/homebrew/bin/nvim: exits0,7/0/0; clean process censuses on both. Final lint and diff check pending. Logs and initial cause probe retained under /Volumes/TestScratch/parley428.qkdGOp. README explains that skill and agent-edit explanations now show without diagnostic underlines; atlas maps the namespace-local rule. No operator stage touched. Next: pushed-head pre-close, close review, then hub-sequenced live check or landing instruction.

Final lint-final.log exits0,858 files/0warnings/errors; git diff-check clean. All implementation and targeted verification is checkpointed before the recorded pre-close check.
