---
id: 000272
status: open
deps: []
github_issue:
created: 2026-09-19
updated: 2026-09-19
estimate_hours:
---

# Define refuses with 'overlapping patches' when the buffer ends in two or more blank lines

## Problem

Operator, 2026-09-19: defining a phrase fails with

```
Parley.nvim: Define: edit cancelled: overlapping patches
```

The refusal is real and the definition is silently lost — the lookup ran, the
model answered, and `render_definition` (`lua/parley/init.lua:1987`) reports the
refused apply and returns. The trigger is **not the phrase**: it is the shape of
the buffer's tail.

**Mechanism.** `apply_definition_footnote` appends the managed footer by first
stripping every trailing blank line and then emitting `"" / "---" / "" /
[^id]: …` (`lua/parley/define.lua`, `replace_or_append_footnote`). When the
buffer already ends in **two or more** blank lines, `vim.diff` aligns the
appended block's own blank line against one of them and splits the append into
**two** insertion hunks instead of one:

```
before:                                   after:
  3 "the deterministic shell matters"       3 "the deterministic shell[^…] matters"
  4 ""                                      4 ""
  5 ""                                      5 "---"
                                            6 ""
                                            7 "[^deterministic-shell]: A shell."

hunk {3,1,3,1} -> region (2,0)..(3,0)     the reference insertion
hunk {4,0,5,1} -> region (4,0)..(4,0)     "---"          <-- zero-width, at EOF
hunk {5,0,7,1} -> region (4,0)..(4,0)     the footnote   <-- zero-width, at EOF
```

`buffer_edit.apply_user_line_hunks` maps both of those hunks onto the **same
zero-width position**: the second gets `{row=first, col=0}` because `hunk[2]==0`,
the third takes the `first == #before` branch and becomes
`{row=#before-1, col=#before[#before]}` — the same byte. `user_edits.compile`
then refuses, correctly, because it cannot order two patches that start at the
same byte:

```lua
if e.last.byte>lower or e.first.byte==lower then return nil,'overlapping patches' end
```
`lua/parley/document/user_edits.lua:170`

**The defect is in the hunk → region mapping, not in the guard.** The guard is
the proof layer doing its job; `apply_user_line_hunks` handed it two patches it
had collapsed onto one point. `apply_user_line_hunks` is shared
(`chat_respond.lua:1905`, `:1957`, `init.lua:2496`), so any caller whose `after`
appends at a buffer with ≥2 trailing blank lines is exposed to the same
refusal — Define is just the caller that hits it every time.

**Measured tail matrix** (selection on line 5, footer appended, same phrase):

| buffer tail | hunks | result |
|---|---|---|
| no trailing blank | 1 | ok |
| 1 trailing blank | 2 | ok |
| **2 trailing blanks** | **3** | **refused** |
| **3 trailing blanks** | **3** | **refused** |
| `---` + 1 blank | 2 | ok |
| **`---` + 2 blanks** | **3** | **refused** |
| existing footer (+0/1/2 blanks) | 2 | ok |

An existing managed footer is immune because `replace_or_append_footnote` then
appends only the single `[^id]:` line — no blank line for the differ to align
against.

**Word count is a red herring.** A single-word selection fails identically under
the same tail, and every multi-word/multi-line selection passes under a tail that
has 0 or 1 trailing blank. If the operator saw this only while defining phrases,
the buffer tail — not the selection — is what to record next time.

Also worth noting: the passing cases pass *by one byte*. The reference hunk's
region ends exactly where the append region begins, so `e.last.byte > lower` is
false only on equality. This is a tight boundary, not a comfortable margin.

## Spec

Define must store its footnote whatever the buffer's trailing whitespace is, and
the fix belongs where the collapse happens, not in the caller.

- **`apply_user_line_hunks` must not emit two patches at the same position.**
  Two zero-width insertions anchored at end-of-buffer are one insertion; the
  mapping should merge hunks that resolve to the same point (concatenating their
  text in buffer order) before asking the document layer to apply them.
- **Leave `user_edits.compile`'s guard alone.** Refusing two patches that share a
  start byte is correct — it is the only thing that caught this. Do not relax it
  to "allow zero-width insertions at the same byte"; that moves an ordering
  ambiguity into the proof layer, which is the layer that exists to not have one.
- **A caller-side tweak is not the fix.** Making `replace_or_append_footnote`
  preserve trailing blanks (so the differ yields one hunk) would make Define's
  symptom go away and leave the shared mapping broken for the other three call
  sites. It may still be worth doing for the artifact's sake — the footer edit
  currently rewrites whitespace the user did not ask it to touch — but as a
  separate decision, not as this bug's remedy.
- The refusal path itself is fine: `render_definition` reports and leaves no
  partial edit. Nothing about error handling needs to change here (cf. #265).

## Done when

- Defining a phrase in a buffer whose last two lines are blank stores the
  footnote and renders the diagnostic — no `overlapping patches` refusal.
- A unit test drives `apply_user_line_hunks`'s hunk→region mapping over the tail
  matrix above (0, 1, 2, 3 trailing blanks; `---` + blanks; existing footer) and
  asserts one patch per distinct position.
- A test pins the `user_edits.compile` guard as unchanged: two patches that
  genuinely share a start byte are still refused.
- The existing define specs still pass (`tests/unit/define_spec.lua`).

## Plan

- [ ] Confirm an implementation plan against the Spec and Done when before starting work.

## Log

### 2026-09-19

Filed from an operator report. Reproduced outside Neovim's plugin runtime with a
standalone script: it requires the pure `parley.define`, replays
`apply_user_line_hunks`'s region math and `user_edits.compile`'s overlap rule,
and drives `vim.diff` under `nvim --headless -l`. That is what produced the tail
matrix above; the same harness is the natural seed for the unit test.

```lua
-- nvim --headless -l repro.lua
package.path = "<repo>/lua/?.lua;<repo>/lua/?/init.lua;" .. package.path
local define = require("parley.define")
local before = { "# t", "", "the deterministic shell matters", "", "" }
local e = define.apply_definition_footnote(before, 3, 4, 3, 22, "deterministic shell", "A shell.")
for _, h in ipairs(vim.diff(table.concat(before,"\n").."\n",
                            table.concat(e.lines,"\n").."\n", {result_type="indices"})) do
  local first = h[2] == 0 and h[1] or h[1] - 1
  print(("hunk {%d,%d,%d,%d} -> first=%d"):format(h[1], h[2], h[3], h[4], first))
end
-- hunks 2 and 3 both resolve to the same zero-width position at EOF
```

Ruled out by measurement, so nobody re-walks them: the selection's word count,
whether the selection spans two lines, the model's `term` differing from the
phrase, and an already-present footnote footer. All four behave identically; only
the count of trailing blank lines moves the outcome.

## Revisions

### 2026-09-22 — publish conformance

Replaced the empty Plan checkbox with an explicit pending planning task to satisfy
the publish validator. No implementation design, scope, or status change.
