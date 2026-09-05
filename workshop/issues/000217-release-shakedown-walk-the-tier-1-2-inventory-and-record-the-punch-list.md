---
id: 000217
status: open
deps: []
github_issue:
created: 2026-09-05
updated: 2026-09-05
estimate_hours:
---

# Release shakedown: walk the Tier 1/2 inventory and record the punch list

## Problem

`workshop/projects/parley-v1-release.md` has no shakedown item. The audit
(`workshop/plans/000206-shipping-surface-inventory.md`) is **static** — three
agents reading code plus a clean-clone repro. Nothing in the breakdown covers
sitting in the editor and using each feature, which is where usability defects
and "works but feels wrong" live.

This issue is the running punch list for that pass. Each row is **verified**,
**talking point** (announcement-worthy, works), or **gap** (fix before release).
Gaps large enough to plan get their own issue; this stays the index.

Note the audit's Tier 1 is a *triage* list, not a status surface — it says what
to lead with, not what currently works. This issue is the status surface.

## Spec

Walk Tier 1 (13 features) and Tier 2 (7 groups) from the audit. Record every
item. Do not silently drop a feature that turns out to be broken — a gap with no
owner is the thing this pass exists to surface.

### Punch list

| # | Item | Verdict | Notes |
|---|---|---|---|
| 1 | Markdown transcript as full state | **verified** | works well |
| 2 | cliproxyapi subscription auth | **talking point** | near-zero config for Codex/Claude subscribers. **Open Q:** does it work on the $20/mo tier or only $100+? Doc blocker, not a code one — #206 cannot describe who it works for until answered |
| 3 | Inline define (`<M-CR>` visual) | **verified** (was gap) | fixed via #215; still nondeterministic under `tool_choice: auto` — see #216 |
| 4 | Vendor neutrality | **verified** | agent recorded per exchange, e.g. `🤖:[gpt-5.6-luna*]` |
| 5 | Chat memory windowing | **verified** | `📝:` summary line present in transcript |
| 6 | `<M-i>` insert into agent pane | **expected** | fails when the agent pane wants a structured menu answer rather than free-form text. Not a defect |
| 7 | `<M-q>` quote mode | **talking point** | works on a selection *and* as a bare question after a paragraph. Good annotation flow, supplies the context the model needs. Currently **undocumented** (audit B-doc) |
| 8 | Memory system auto-grep | **gap** | see below |
| 9 | Repo mode without ariadne | **gap** | see below |
| 10 | Fence / malformed-output robustness | **gap** | filed as **#218** |
| 11 | Chat-action chord consistency | **gap (design)** | see below |
| 12 | `<M-q>` copies fence delimiters into the quote | **gap** | see below |

### Gap 8 — memory system auto-greps on startup

`memory_prefs.enable = true` with `max_age_days = 1`, fired from `setup()`
(`config.lua:493`, `init.lua:1199`). On a fresh install it shells `grep -r`
across every chat root, sends summaries of up to 100 files per tag to the model,
and writes generated `.md` back into `chat_dir`.

Operator's call: **stop the auto-grep; gate the feature and default it off**,
then design how it should actually be introduced.

This is audit **B4**, already owned by **#209** (safe-by-default posture). Recorded
here so the shakedown and the blocker list agree; the fix belongs to #209.

### Gap 9 — repo mode needs a story without ariadne

Repo mode is a reasonable generic idea, but the `workshop/` layout it imposes is
ariadne's, and it creates five directories on first activation
(`repo_artifacts.lua:3-9`).

Operator's framing, which is the shippable version: **parley as a chat-transcript
format for any repo.** Drop a `.parley` at the repo root, get a configurable
transcript path (default `workshop/parley`), and have the directory created when
missing. That is a feature a public user can want on its own terms, with no
issue tracker, no vision files, and no `sdlc`.

Overlaps **#212** (gate the ariadne surface) — #212 owns the *mechanism*
(context-filtered registration); this is the *product framing* of what survives
gating, and it needs #206 documentation.

### Gap 10 — fence handling is not robust across malformed model output

Reported: rendering degrades when the model returns unmatched ``` fences, and
damage escapes the exchange it originated in. Also `<M-q>` quoted text is
sometimes wrapped in a ``` fence incorrectly.

Operator's proposal, which is the right shape: **`💬:` and `🤖:` at line start
should be hard partitions.** Fence state resets at every boundary, so a
malformed answer can corrupt at most its own section. Plus a fixture suite of
deliberately malformed questions and answers asserting exactly that containment.

Two design notes for whoever plans this:

- **The zero-width-space idea should be resisted.** Inserting an invisible
  character after `💬:` to make the marker more unique costs the property that
  Tier 1 leads with — the transcript is plain markdown the user can freely edit.
  A hand-typed `💬:` would lack the ZWSP, so the parser must accept both anyway,
  which spends the format's editability for no uniqueness gain. Treating
  line-start `💬:`/`🤖:` as a hard boundary achieves the containment on its own.
- **`\`\`\`` legitimately appears inside questions** (asking *about* fences), which is
  exactly why containment must be positional (section boundaries) rather than
  fence-matching. The `<M-q>` mis-fencing is likely the same root cause.

`exchange_model` already claims to be "the single source of truth for buffer
layout — everything is a block", so the boundary may exist in the model and be
lost at the render seam. Worth confirming before designing.

**Filed as #218.** Reading the code confirmed the operator's diagnosis and found
a second defect: `highlight_structure.lua` resets `in_question`/`in_reasoning` at
every partition but never `in_code`, so one unmatched fence flips the flag for
the rest of the file — and it is the one fence consumer #200 left behind, still
matching `^%s*\`\`\`` loosely instead of deriving from `parley.fence`.

### Gap 11 — chat-action chords are split between `<C-g>` and alt

The chat actions have drifted across two chord families. Operator proposes
consolidating the transcript-mutating actions onto alt.

Current vs proposed:

| action | today | proposed |
|---|---|---|
| quote for next question | `<M-q>` | unchanged |
| define (visual) / respond (n,i) | `<M-CR>` | unchanged |
| insert branch + new transcript | `<C-g>i` | **`<M-i>`** |
| prune rest of transcript into a side chain | `<C-g>b` | **`<M-p>`** |

Verified for this issue:

- **`<M-i>` and `<M-p>` are both free.** The only alt keys bound today are
  `<M-q>`, `<M-a>`, `<M-r>`, `<M-CR>`, `<M-o>`, `<M-t>`.
- **The alt family already means "act on this transcript"** — quote, accept
  marker, reject marker, respond/define, skill picker, outline. Insert and prune
  belong to it; `<C-g>` is the odd one out for these two.
- **There is a migration precedent in-tree:** `chat_drill_in` carries
  `default_key = { "<C-g>q", "<M-q>" }`. The registry accepts a key list, so
  `<C-g>i`/`<C-g>b` can stay as aliases rather than breaking muscle memory.
- **No new keyspace claim.** Both are `scope = "chat"`/`parley_buffer` and
  buffer-local, so this does not worsen audit **B9**.

Operator also wants an ergonomic fix on the insert path: **open the newly minted
sub-transcript directly** rather than only writing the link.

Open design question the operator raised and did not settle: branching currently
costs **one file per side question**, which feels heavy. The keystroke
consolidation is orthogonal to that and can land first.

Intended workflow this is meant to serve, recorded because it explains the
design: chat normally → `<M-q>` on things you do not understand → once the first
answer is fully understood, **prune** those side threads out, leaving the main
thread clean. One section per point.

#### Resolved proposal (2026-09-04)

**Bind both `<M-S-CR>` and `<M-i>` to the same action**, keeping `<C-g>i` as a
legacy alias. Same for prune: `<M-p>` with `<C-g>b` retained.

```lua
default_key = { "<M-S-CR>", "<M-i>", "<C-g>i" }   -- branch here
default_key = { "<M-p>", "<C-g>b" }               -- prune
```

*Why both, not one.* `<M-S-CR>` carries the better mnemonic — shift as "same
action, redirected destination", the shift-click convention — and makes the alt
family read as: `<M-q>` gather, `<M-CR>` submit here, `<M-S-CR>` submit into a
new branch, `<M-p>` prune. But **most terminals cannot distinguish Shift+Enter
from Enter**: without the kitty keyboard protocol, CSI-u or `modifyOtherKeys`,
both send identical bytes and Neovim never sees `<S-CR>`. It works on
kitty/wezterm/ghostty and silently does nothing on Terminal.app, plain xterm and
older tmux. That is an author's-terminal-vs-public-audience trap, which is
precisely what #214 exists to catch.

Supporting evidence: the tree has **no shift chords** except `<S-Tab>` (which is
universally supported), and the multi-key registry precedent already exists
(`chat_drill_in` = `{ "<C-g>q", "<M-q>" }`). Document `<M-S-CR>` as primary and
`<M-i>` as the fallback for terminals that swallow Shift+Enter.

*All three invocations are ONE action — "branch at this location".* An earlier
draft of this proposal argued for cutting the no-selection case on the grounds
that nothing is being submitted, so it did not belong on a submission chord.
**That was wrong**, and the operator corrected it: n/i and visual both create a
branch at this point in the chat tree. What differs is an **inconsistency**, not
a design —

| invocation | link written | child chat created? |
|---|---|---|
| visual (`chat_insert_inline_branch_ref`) | `[🌿:text](file.md)` inline | **yes** — calls `create_child_chat` |
| n/i (`chat_insert_branch_ref`) | `🌿: file.md: ` on its own line | **no** — reference only |

That gap is what makes the no-selection case feel unintuitive. Closing it, plus
the operator's ergonomic ask, makes all three uniform:

- create the child chat in **every** path, not just the visual one
- **open the newly minted sub-transcript** so the chord lands you where you type
- with pending `<M-q>` quotes, those become the child's opening question

Then the no-selection case is not an exception: it is a submission whose content
you have not written yet. Press, land in the child, type.

Relates to **#214** (audit the default keybinding surface), which owns policy;
this is a concrete proposal for it.

### Gap 12 — `<M-q>` pulls ``` lines into the quoted snippet

Quoting a span that sits next to a fenced block copies the ```` ``` ```` lines
into the quote. Operator's rule of thumb: **strip fences at the beginning and
end of a quote — that is never what was wanted.**

Diagnosed to `lua/parley/drill_in.lua`, and it is **not** the render bug (#218):
`paragraph_top` walks backwards through the enclosing prose block, stopping only
on `is_blank` or `is_boundary_line` (a configured turn prefix). A fence line is
neither, so the scan passes through it and the delimiters land in the snippet.

Two candidate fixes, preferring the first:

- **treat a fence line as a scan boundary** in `paragraph_top`/`is_boundary_line`
  — prevents inclusion rather than repairing it, and matches how turn prefixes
  are already handled
- **strip leading/trailing fence lines from the snippet** — matches the
  operator's phrasing and is the needed safety net for an explicit *visual*
  selection that deliberately spans a fence

There is precedent for the second shape in the same file: `strip_markers`
already removes 🤖-markers whose raw bytes fall inside a snippet window because
"they are not prose". Fence delimiters are the same category.

### Operator steer on write-time sanitization (2026-09-04)

Recorded because it constrains #218's sibling issue: **prefer not to rewrite
what the user typed.** Not forbidden — the balance is overall formatting
consistency against intrusive rewriting — but the default is hands-off, and any
touch-up should be a discrete, visible, undoable event at submit rather than an
as-you-type transform.

## Done when

- every Tier 1 and Tier 2 item carries a verdict
- each gap is either fixed, or filed as its own issue and linked here
- gaps that duplicate an existing blocker (#209, #212, #214) say so rather than
  forking a second owner
- the project file references this issue

## Plan

- [ ] Walk remaining Tier 1: chat tree branching, chat finder (`<C-g>f`),
      `@@path@@` file context, local tools, server-side web search, tree export
- [ ] Walk Tier 2: notes + note finder, outline/follow-cursor/tool folds,
      exchange cut/paste + ChatMove + ChatReview, interview mode, raw-mode
      logging, lualine, copy helpers, markdown finder, system prompts, spell
      typeahead
- [x] File the fence-robustness issue (gap 10) with the containment fixture suite — **#218**
- [ ] Fold the resolved chord proposal (gap 11) into #214 — includes the
      create-the-child + open-the-file consistency fix, which is what makes the
      no-selection case intuitive
- [ ] File the `<M-q>` fence-stripping fix (gap 12) — small, `drill_in.lua`
- [ ] Answer the cliproxyapi plan-tier question (gap 2) for #206
- [ ] Link this issue from `workshop/projects/parley-v1-release.md`

## Log

### 2026-09-04

Opened mid-shakedown; items 1-7 were already walked in session before this file
existed, and are recorded above from that pass rather than re-tested.

Verified for gap 11 rather than assumed: alt-key availability, the existing alt
family's meaning, the multi-key registry precedent (`chat_drill_in`), and that
`<C-g>b` is `chat_prune` (`config.lua:349`, `keybinding_registry.lua:586`).
