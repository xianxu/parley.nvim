---
id: 000272
status: open
created: 2026-09-19
updated: 2026-09-19
estimate_hours:
github_issue:
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
