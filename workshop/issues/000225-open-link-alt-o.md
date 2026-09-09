---
id: 000225
status: codecomplete
deps: []
github_issue:
created: 2026-09-08
updated: 2026-09-08
estimate_hours: 1.79
started: 2026-09-08T16:45:24-07:00
actual_hours: 3.92
---

# Open a link with <M-o>, falling back to gf

## Problem

Following a link is the most-used navigation in a forked transcript, and it is
on the hardest key. #214 moved it from `<C-g>o` to `<M-g>` to join the alt
family; the operator, using forks heavily, reports `<M-g>` is awkward to press.

Two things are wrong beyond the reach:

1. **`<M-o>` is the obvious key and is taken.** It opens the skill picker
   (`review_menu`, `scope = markdown`, chosen by the operator in #133 —
   "alt+o = skill selector"). `<M-o>` is therefore free in a chat buffer and
   taken in a markdown one, which is exactly the per-buffer-type divergence
   #214 spent sixteen rounds removing.
2. **Open dead-ends instead of falling through.** With the cursor on anything
   that is not a `🌿:` line, an inline `[🌿:…](file)` or an `@@ref@@`,
   `OpenFileUnderCursor` logs *"No file reference (@@ syntax) found on current
   line"* and stops. Meanwhile `gf` (`resolve_ref_gf`) already does the sensible
   thing for everything else: resolve an ariadne artifact ref, else native `gf`.
   One key should cover "go to the thing under my cursor."

## Spec

**Operator decision, 2026-09-08:**

| key | does | scope |
|---|---|---|
| `<M-o>` | open the link under the cursor | chat **and** markdown |
| `<M-s>` | skill picker (moved from `<M-o>`) | markdown |
| `<M-CR>` | review menu | unchanged |

`o` = open and `s` = skills both resolve as mnemonics, which the previous
assignment did not.

**Fallback chain for `<M-o>`**, in order:

1. `🌿:` reference line → open that chat
2. inline `[🌿:anchor](file)` under the cursor → open it
3. `src:` link / `@@path@@` reference → open it
4. **otherwise → `ResolveRefOrGotoFile`**: an ariadne artifact ref resolves and
   jumps; anything else gets native `gf`

### Step 4 is an extraction, and it needs a three-valued contract (PQ-1, PQ-2)

`OpenFileUnderCursor` has **two** chains:

```lua
if M.is_markdown(buf, file_name) then
    M.open_chat_reference(current_line, cursor_col, in_insert_mode, current_line)
    return                       -- UNCONDITIONAL. markdown never reaches below.
end
if M.not_chat(buf, file_name) then … return end
if open_branch_ref(...) then return end            -- the chat chain
if try_open_inline_branch_link(...) then return end
… @@ handling …
```

Appending step 4 would fire in chat and never in markdown — the per-buffer
divergence this issue exists to remove, reintroduced by its own fix. Appending
to both is two copies. So it is an **extraction**: one predicate for both types,
one fall-through at the caller. **The two chains are NOT duplicates, and saying so was the #214 M1 mistake
repeated** (PQ-8). I cited `branch_inserters` as the precedent for the
extraction and then made the error that precedent exists to prevent —
*"consolidating implementations ≠ erasing situational differences"*
(`lessons.md`). Measured, four divergences, each with a verdict:

| # | difference | today | verdict |
|---|---|---|---|
| 1 | `src:` links (`init.lua:4307`) | markdown only | **keep, extend to chat.** A `src:` link is a reference like any other; its absence in chat is an omission, not a policy. |
| 2 | `@@path: topic` form (`init.lua:4328`) | markdown only | **keep, extend to chat.** Same parser, strictly more forms accepted. Low risk: the chat path already handles bare `@@ref@@`. |
| 3 | bare-name `resolve_chat_path` (`init.lua:4352`) | markdown only | **keep, extend to chat** — and it is the timestamp-prefix resolver #224 is about, so chat gains slug-tolerance it should already have had. |
| 4 | directory `Explore` + split-aware edit (`init.lua:4463-4492`) | **chat only** | **keep, chat only.** This is the one that must NOT be flattened: it opens a directory reference in netrw, preferring the other window in a two-split layout. Deleting the "second copy" as originally written would have silently dropped it. Whether markdown should gain it is a separate question, deliberately not answered here. |
| 5 | `@@` extraction greediness (`init.lua`) | chat greedy, markdown `[^@]+` | **keep chat's, for a line that is wholly one reference.** Found in review round 2: adopting markdown's `[^@]+` wholesale silently broke `@@/tmp/a@b/c.md@@`. A whole-line reference is now taken greedily, guarded so a line carrying two references is not swallowed. |
| 6 | landing mode after a reference (`init.lua`) | chat restored insert, markdown returned first | **unify on chat's.** Found in review round 3. Markdown's early return meant `<M-o>` from insert in a markdown doc landed in normal; the Spec's own landing-mode policy says a reference is somewhere you went to *write*, so restoring insert is the correct resolution — but it was silently resolved rather than tabulated. The landing tests are now parameterised over both buffer types so the next one is a red test, not a review round. |

Rows 5 and 6 were not in the original measurement. That is the finding: the
divergence set was hand-written, and a hand-written set is complete only by
luck. Wherever practical the specs now run the same case over
`{chat, markdown}` so a difference shows up red.

So the extraction takes the union for 1-3 and preserves 4 as a chat-only arm —
one function with one explicit branch, not one function that quietly loses a
feature. That branch is the `owns_file`-shaped parameter M1 ended up with, for
the same reason.

**A boolean is not enough.** Making markdown fall through promotes three
currently-discarded exits to load-bearing, and they do not mean the same thing:

| exit | today | means | on fall-through |
|---|---|---|---|
| `init.lua:4337` | `nil` + warning *"No chat reference (@@ syntax) found"* | there is no reference here | **fall through to `gf`**; drop the warning |
| `init.lua:4344` | `nil` + warning *"Could not extract chat path"* | same | **fall through**; drop the warning |
| `init.lua:4394` | `false` + warning *"Chat file not found: <path>"* | a reference we understood, whose file is missing | **terminal — report, do NOT fall through** |

Falling through on the third would hand `gf` a path we already know is absent,
losing the diagnostic and letting `gf` fail or open something unrelated. So:

```lua
--- @return "opened" | "none" | "failed"
local function open_reference_under_cursor(buf, line, col, in_insert) … end
```

`"none"` is the only value that falls through. `"failed"` keeps its message.

### Landing mode (PQ-3, PQ-7)

Every existing success exit restores insert when it started there
(`init.lua:4511, 4587, 4602`). That is not an oversight to normalise away — it
is a coherent policy once stated:

> **The landing mode follows the destination, not the origin.**
> A chat reference is somewhere you went to *write*, so insert is restored.
> A `gf` destination is source you went to *read*, so it lands in normal.

So the fall-through does `stopinsert`, the reference exits keep `startinsert`,
and the difference is intended rather than an artifact of which branch ran.

## Core concepts

The work is one extraction, so the table is short. `open_reference_under_cursor`
is the entity; the three helpers below it change *contract* (boolean → status)
without changing shape, which is what makes the extraction's fall-through
possible at all.

### Pure entities

| Name | Lives in | Status |
|---|---|---|
| `glob_base` | `lua/parley/helper.lua` | new |
| `would_execute` | `lua/parley/helper.lua` | new |

Reference opening is *mostly* an integration — it reads the filesystem, creates
buffers and moves windows — and the first version of this table said "none",
which the close review correctly called out as hiding a pure fragment.

- **`glob_base`** — the directory part of a glob-ish reference
  (`a/b/**/*.md` → `a/b`). It had two near-copies stripping different shapes;
  neither wrong, but a pair that could drift. Its spec runs with no IO, which
  is the test that the purity claim is real.

- **`would_execute`** — a string predicate: would handing this to a
  command-executing vim function run a shell command? One predicate behind all
  three guards, so a new guard cannot adopt a narrower notion of "dangerous"
  than the existing ones — which is exactly how `glob` stayed open for a round
  after `expand` was closed.

The second version of this table also listed `expand_path` here, which was
wrong: `vim.fn.expand` reads the environment, globs the filesystem and — the
entire point of the guard — can spawn a process. It is an integration point and
is tabled as one below.

The other pure parts it leans on (`_parse_at_reference`, `_parse_branch_ref`,
`extract_inline_branch_links`) already exist and are unchanged.

### Integration points

| Name | Lives in | Status | Wraps |
|---|---|---|---|
| `_open_reference_under_cursor` | `lua/parley/init.lua` | new | filesystem + buffer/window opening |
| `expand_path` | `lua/parley/helper.lua` | new | `vim.fn.expand` |
| `abs_path` | `lua/parley/helper.lua` | new | `vim.fn.expand` + `vim.fn.resolve` |
| `safe_glob` | `lua/parley/helper.lua` | new | `vim.fn.glob` |
| `resolve_relative_path` | `lua/parley/helper.lua` | new | path resolution against a base dir |
| `focus_other_split` | `lua/parley/init.lua` | new | window layout |
| `open_buf` | `lua/parley/init.lua` | modified | — |
| `open_branch_ref` | `lua/parley/init.lua` | modified | — |
| `try_open_src_link` | `lua/parley/init.lua` | modified | — |
| `try_open_inline_branch_link` | `lua/parley/init.lua` | modified | — |
| `OpenFileUnderCursor` | `lua/parley/init.lua` | modified | — |
| `open_chat_reference` | `lua/parley/init.lua` | deleted | — |

- **`_open_reference_under_cursor`** — the single chain, exported under `M._`
  purely as a test seam (the repo's existing idiom for a file-local function).
  - **Injected into:** nothing; it is the leaf. `OpenFileUnderCursor` is its
    only caller and owns the `"none"` → `gf` fall-through, so the fall-through
    exists in exactly one place and cannot be re-duplicated per buffer type.
  - **DRY rationale:** collapses two chains that had drifted apart in four
    measured ways. Three of the four were omissions **in chat** — the released
    surface — so the union is the fix, not a nicety.
  - **Future extensions:** `is_chat` is the one deliberate divergence axis. If
    markdown should ever gain directory `Explore`, the parameter disappears; no
    other caller shape changes.

- **`focus_other_split`** — the two-split preference, which had **three**
  copies: one in `open_buf` and two hand-inlined in `OpenFileUnderCursor`.
  Netrw is why a second *call site* is needed (a directory reference does not
  go through `open_buf`); it was never a reason for a second *implementation*,
  and the first version of this change stopped at two of three.

- **`open_branch_ref` / `try_open_src_link` / `try_open_inline_branch_link`** —
  each returned `true` for both "opened it" and "recognised it and failed".
  That conflation was harmless while every non-`false` answer meant "stop"; it
  is not harmless once `"none"` falls through to `gf`. Each now returns
  `"opened" | "failed" | nil`.

- **`open_chat_reference`** — deleted. It was the markdown-only chain; its one
  production caller and its one test now go through the unified function.

- **`safe_glob`** — the second sink. `vim.fn.glob` executes backticks exactly
  as `expand` does, which the arch spec now establishes by probe rather than by
  memory. It refuses like `expand_path` (returns `nil`), because a glob has no
  sensible "degrade to the literal" answer.

- **`expand_path` / `abs_path`** — the provenance boundary. `expand_path`
  refuses (returns `nil`) so a caller can *report* the refusal; `abs_path` is
  **total**, degrading to the unexpanded literal so a caller's existing
  "file not readable" branch handles it without a nil check. That split is not
  taste: making the resolution path return `nil` crashed two callers that index
  the result (close review C2). `abs_path` is also the single copy of
  `vim.fn.resolve(vim.fn.expand(x))`, which had fifteen.
  - **Injected into:** nothing — they are leaves, and `tests/arch/untrusted_path_spec.lua`
    is what keeps them the only expansion sites, by allowlisting every
    `vim.fn.expand(<variable>)` in `lua/` with a stated reason.

- **`resolve_relative_path`** — the ~/absolute/relative triage, which existed in
  **five** copies, two of them byte-identical. The round that guarded one of the
  identical pair missed the other, leaving a live sink in `outline.lua`; the
  arch guard then found a fifth in `init.lua` while the other four were being
  merged. That sequence is the argument for the guard over another sweep.

**Test surface.** `tests/integration/open_reference_spec.lua` — integration
rather than unit because the behaviour under test *is* the IO: real files, real
buffers, real window layout, with `vim.cmd` / `open_buf` / `logger.warning`
spied at the boundary. Each of the four one-chain capabilities was
mutation-checked before the extraction landed.

## Revisions

### 2026-09-08 — close review round 1 (FIX-THEN-SHIP, 4 Important)

All four Importants **fixed** rather than argued down, so the Done-when bullets
they contradicted are now true as written.

- **BR-4 (`vim.fn.expand` executes backticks).** The serious one, and it is a
  security bug, not a hygiene nit: chat buffers hold **model output**, so a
  model can write `@@`cmd`@@` into a transcript and the operator's most-pressed
  key runs it. Reproduced end-to-end before the fix, and the guard verified by
  reverting it (all six arms of `untrusted_path_spec` go red).
  Fixed as a **class**, not the two named sites: `helper.expand_path` is now
  the only expansion a transcript-derived path may go through, and the sinks
  routed to it are `read_file_content`, `is_directory`, `find_files`,
  `prepare_dir`, `_resolve_chat_path_candidates`, `find_tree_root_file`,
  `collect_tree_files`, `chat_respond.resolve_path` and both `@@` sites. The
  review's enumeration named three; the sweep found ten. Config-derived paths
  (`chat_dir`, `root.dir`, `src_root`) keep plain `vim.fn.expand` — the
  distinction is provenance, not syntax.
- **BR-5 (the divergence was unpinned).** True and embarrassing: D4 is the arm
  the Spec calls "the one that must NOT be flattened", and deleting `is_chat`
  left all tests green. The negative half is now asserted and mutation-checked.
  The positive-only characterisation was the gap — every D4 test drove a chat
  buffer, so nothing said what markdown must *not* do.
- **BR-6 (two of three copies).** `focus_other_split` swept the two instances
  the issue named and left `open_buf`'s. Instance, not class. `open_buf` calls
  it now.
- **BR-3 (the seam was unreachable).** `goto_ref_at_cursor` gained
  `opts.runner`, so `run_resolve`'s documented seam is reachable from a caller
  and `artifact_ref_spec` no longer replaces the module function. The `<M-o>`
  test fakes `vim.system` instead — the OS boundary, so argv construction, the
  default runner, JSON decode and dispatch all execute for real.

Minors landed: the `deleted`-row sweep now **inverts** (asserts the symbol is
gone) rather than skipping, `<M-o>` joined the markdown binding assertions, and
`glob_base` retired the duplicated glob→directory derivation.

Two deliberately **not** folded in:

- **The `sdlc resolve` spawn has no in-flight guard.** Two `<M-o>` presses
  before the first returns start two subprocesses. Pre-existing on `gf`, but
  `<M-o>` is pressed far more often, so it matters more now. Cancellation and a
  dedup key are a design question, not a keybinding fix → filed.
- **Chat's chain order flipped** — inline `[🌿:…](file)` links are now tried
  before `open_branch_ref` (markdown's order won). Observable only on a `🌿:`
  line that also contains an inline link with the cursor inside it, where the
  inline link is the more specific match and the better answer. Recorded here
  rather than left implicit.

Commit hygiene: `bb7050a` had swept twelve unrelated `workshop/parley`
transcripts (~1,300 lines) into the implementation commit via `git add -A`.
The branch was unpushed, so it was rebuilt without them; the transcripts are
back to untracked and byte-identical, and the only diff between the old and
rebuilt branches is those 1,314 lines.

### 2026-09-08 — close review round 2 (REWORK, 3 Critical + 2 Important)

Round 1's fixes introduced two of the three Criticals. Recorded plainly because
the pattern matters more than the individual defects.

- **C1 — I reported a clean suite that was red.** `make test` failed at HEAD:
  the two new spec files were unrouted in `atlas/traceability.yaml`. I had
  grepped the log for `^FAIL: `, a pattern that does not appear in this
  runner's output, instead of checking the exit code. The verification claim in
  the round-1 close was therefore false, not merely optimistic. Fixed by
  routing both specs; the lesson is that **the oracle for "tests pass" is the
  exit status**.
- **C2 — the BR-4 guard crashed instead of degrading.** Making
  `_resolve_chat_path_candidates` return `{}` made `resolve_chat_path` return
  `nil`, and two callers index that result: both the `🌿:` arm and the
  inline-link arm raised `attempt to index local 'expanded'`. The security
  property held (nothing executed) and the failure mode did not.
  Fixed by making the resolution path **total**: `helper.abs_path` returns the
  unexpanded literal on refusal, so `filereadable` says no and every caller
  keeps its existing not-found branch. No caller changed.
  **Why it shipped is the oracle**: my spec wrapped each call in a bare `pcall`
  and asserted only that the marker file was absent. That cannot distinguish
  "refused cleanly" from "the interpreter blew up" — an absent side effect is
  evidence that *something* stopped, not that the right thing happened. Every
  arm now asserts `ok == true` and the reported diagnostic, and the strengthened
  oracle was mutation-checked against the exact C2 regression (four arms red).
- **C3 — the sweep stopped at the module boundary, not the provenance
  boundary.** `outline.lua` held a **byte-identical copy** of the resolver I had
  just guarded in `chat_respond.lua`, still executing backticks from a `🌿:`
  path and reachable from `<M-t>`. Round 1 named 3 sites, my sweep found 10,
  and 4 remained.
  Enumeration was the wrong instrument, so this round replaces it with a rule:
  `tests/arch/untrusted_path_spec.lua` allowlists every
  `vim.fn.expand(<variable>)` in `lua/` with a stated reason why the argument is
  operator-derived, and fails on anything new. It found a **fifth** copy of the
  resolver in `init.lua` while the other four were being merged — which is the
  argument for the guard, made by the guard.
- **I1** — the table called `expand_path` PURE. It expands the environment,
  globs the filesystem and can spawn a process. Moved to Integration points.
- **I2** — `prepare_dir` returned the unusable input on refusal while every
  sibling returned `nil`. Now `nil`, with the two assigning call sites keeping
  their original value.

Minors landed: the greedy `@@` form restored (adopting markdown's `[^@]+`
wholesale had silently broken `@@/tmp/a@b/c.md@@` — a **fifth** divergence,
resolved the wrong way and never tabulated), `open_buf`'s two-split preference
pinned (BR-6 moved the logic but left its call site unasserted), and the atlas
corrected to name the per-arm diagnostic wording.

Noted, not fixed: `review_menu` (`<M-s>`, markdown) and `skill_picker`
(`<C-g>s`, global) are two registry ids and two config keys for one action, and
the rename made them exactly the alt/`<C-g>` pair `open_file` models as one
entry. Merging them retires a public `config_key`, which is a release-notes
change rather than a review fix — it belongs with the keybinding surface work,
not here.

### 2026-09-08 — close review round 3 (REWORK, 3 Critical)

Round 2's fixes produced round 3's Criticals, the same way round 1's produced
round 2's. Three rounds, one pattern: **I keep declaring a class closed on the
strength of a sweep.**

- **C1 — the red suite, again, one commit later, by the identical mechanism.**
  Round 2 fixed the two unrouted specs BR-13 named and did not ask why they were
  unrouted; the arch spec it added was then unrouted itself. My `make test` said
  exit 0 — truthfully — because the new spec was still **untracked**, and the
  routing guard uses `git diff --diff-filter=A`, which cannot see untracked
  files. So the guard fires one commit after the mistake, every time.
  Fixed at the mechanism: the guard now also reads `git ls-files --others`, so
  it flags a new spec while it is being written. Its sibling guard in the same
  file already carried this exact lesson ("comparing against the working tree
  flags it while it is still being written") and it had not been applied here.
  The process rule stands too: run `make test` **after committing**, read the
  exit status.
- **C2 — the rule was over one sink.** `vim.fn.glob` executes backticks as
  surely as `vim.fn.expand`, and `find_files` concatenates a transcript-derived
  *pattern* into its glob — a path `glob_base` never touches, so the round-2
  guard passed it straight through. Reproduced: `@@<dir>/**/`cmd`.md@@` created
  the marker.
  The deliverable is not "also guard glob". It is that the **sink set is now
  probed**: the arch spec runs `expand`, `glob`, `globpath`, `expandcmd`,
  `resolve`, `filereadable`, `isdirectory`, `simplify`, `fnamemodify` against a
  live payload and fails if the declared set differs in either direction. One
  shared predicate (`helper.would_execute`) backs all three guards so a new one
  cannot disagree with the old ones. Mutation-checked: a raw `vim.fn.glob` in
  `find_files` reddens the arch guard; `SINKS = { "expand" }` reddens the probe.
- **C3 — the test certifying round 2's C3 fix could not fail.** It passed a
  buffer number where `_build_tree_outline_items` wants `root_path`, and put the
  `🌿:` line before the first exchange so `parsed.branches` was empty anyway.
  The reviewer reverted `outline.lua` to its vulnerable resolver and the spec
  stayed 10/10 green.
  **My own probe had the same bug**: I called it with the same wrong signature,
  saw `MARKER: false`, and recorded that as confirmation. It was false because
  nothing ran. The arm now asserts the walk actually reached the branch before
  asserting it was refused, and was verified by the revert — it goes red.

Minors: the third `prepare_dir` call site (`root_dirs.lua`) now handles `nil`,
with an arch check that enumerates the consuming call sites mechanically —
that sweep came up one short twice. The `open_buf` LuaLS annotations are back
adjacent to `open_buf`, `focus_other_split` logs its target again, and the atlas
claims that round 2 could not support are corrected: "every arm goes red" was
false (C3), and "fifteen copies → one" was false (six config-side copies
remain, now stated).

### 2026-09-08 — close review round 4 (FIX-THEN-SHIP)

Gate passed: no open blocking findings. Three Importants were demoted past the
round cap and are fixed here anyway, because all three are about the *guards*
the previous rounds installed — the mechanisms meant to end this pattern still
had the pattern in them.

- **I1 — the sink matcher saw one argument shape, and the allowlist keyed on a
  file rather than a site.** Round 3 established the sink *set* by executable
  probe and left the matcher's *coverage* established by memory: it captured
  only a leading identifier, so `vim.fn.glob("/tmp/" .. ref_path)` was invisible
  — and one such call was already in the tree
  (`skills/voice_apply/init.lua:43`), exempt by accident rather than by
  allowlist. Its self-test drove the single shape it already handled, which is
  round 3's "my probe shared my misconception" one layer up.
  The matcher now extracts the full first-argument expression with balanced
  parens/quotes, skips only bare string literals, and keys `ALLOW` on
  `<file>:<enclosing function>:<expression>` — so an entry cannot pre-approve a
  call written later. Its self-test drives nine argument shapes and three
  literals. Both holes the reviewer demonstrated now fail by name.
  `voice_apply`'s `slug` is routed through `expand_path`: a skill argument can
  be emitted by the model, so it carries transcript provenance.
- **I2 — the code→table sweep was blind to `helper.lua`'s export idiom.** It
  matched `M.` literally; `helper.lua` exports through `_H.`, so its entire
  surface was exempt — and five of this issue's new entities live there. The
  guard was inert exactly where the work was. It now derives the alias from the
  module's own `return <X>`. De-blinded, it immediately named `safe_glob` and
  `would_execute` as untabled, which they were.
- **I3 — the inline-link arm was the one member of the tri-state conversion with
  no test through the chain.** The bug it hid is specific: had the success arm
  returned `nil`, the chain would keep walking, answer `"none"`, and run
  `ResolveRefOrGotoFile` on top of a navigation that already happened — two
  navigations per keypress, with a green suite. Tests added in both buffer
  types plus the missing-target case, mutation-checked against exactly that
  `nil`. The rule: an arch check now enumerates every producer of the tri-state
  and requires each to be dispositioned by name with the test that
  distinguishes its values. This was the fourth sweep on this issue to come up
  one member short.

**Three of my own verification steps were themselves buggy this round**, which
is the honest summary of the whole issue: a mutation check that reported `exit
2` from *lint* rather than from the guard; a mutation that inserted its probe
into the middle of a function (matching a `return _H` substring) so it proved
nothing; and, in round 3, a probe that shared its test's wrong signature. Each
was caught only by looking at *why* the result came back the way it did. A
green or red exit code is a starting point for that question, not an answer to
it.

## Estimate

Derived against the calibration ledger's comparable parley rows rather than a
remembered table (`sdlc estimate-source` flags the v3.1 doc `[stale]`; the
ledger is the newer artifact):

| row | est | design | impl | actual | ratio |
|---|---|---|---|---|---|
| #215 | 2.23 | 1.25 | 0.60 | 1.67 | 1.34 |
| #218 | 1.86 | 0.70 | 1.05 | 2.13 | 0.87 |
| #214 | 3.83 | 1.00 | 2.68 | 17.14 | **0.22** |

#218 is the closest shape — a focused Lua behaviour change with real edge cases
— and it bracketed 1.0 from the low side. #225 is a little more than that: an
extraction with four measured divergences, a three-valued contract, and 13
literal hits across 7 files.

**#214's 0.22 is the loud one, and it is not evidence to inflate this.** That
overrun was sixteen boundary rounds on a milestone carrying eight plan rows
across four subsystems. #225 is single-pass, one concern, and its design is
largely already spent — four plan-gate rounds have happened, which is why the
design line is not larger.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim              design=0.5 impl=0.5
item: ux-rename-iteration     design=0.1 impl=0.25
item: atlas-docs              design=0.0 impl=0.15
item: milestone-review        design=0.0 impl=0.2
design-buffer: 0.15
total: 1.79
```

`design-buffer: 0.15` (not the 0.30 default) because there is a thorough plan:
four gate rounds, the divergences enumerated with verdicts, the exit contract
tabulated. `milestone-review ×1` because the Plan is plain checkboxes — one
boundary, one `sdlc close`, no `Mx` tags.

Recomputed: (0.5+0.1) × 1.15 + (0.5+0.25+0.15+0.2) × 1.0 = 0.69 + 1.10 = **1.79**.

## Done when

- `<M-o>` opens a `🌿:` line, an inline link, a `src:` link, an `@@ref@@` and an
  `@@path: topic` in **both** chat and markdown buffers; `<C-g>o` does the same.
- A directory reference still opens in `Explore`, split-aware, **in chat
  buffers** — the one divergence kept rather than flattened.
- On a plain word `<M-o>` reaches the `gf` path **in both buffer types** —
  asserted by spying the delegation, not by hoping a real file exists.
- A `🌿:` reference whose file is missing still reports and does **not** reach
  `gf` — the `"failed"` case, asserted separately from `"none"`.
- On an ariadne artifact ref it resolves, exercised through
  `artifact_ref.run_resolve`'s existing injected-runner seam
  (`artifact_ref.lua:112-134`) rather than spawning `sdlc`.
- From insert mode: a reference lands in insert (unchanged), the `gf`
  fall-through lands in normal — both asserted, since the split is the policy.
- `<M-s>` opens the skill picker; `<M-o>` does not, in any buffer type.
- **No alt key resolves to more than one entry** — generalised from #214's
  `<M-g>`-specific check, which would not have caught this collision (PQ-4).
- One fall-through call site, asserted, so it cannot be re-duplicated per branch.
- No "no file reference" warning on the fall-through path.

## Plan

- [x] Generalise the collision guard: no alt key has two owners (fails today
      only if a collision exists; seen red by binding `<M-o>` twice)
- [x] Extract `open_reference_under_cursor(buf, line, col, is_chat)` — landed
      without the `in_insert` parameter: the landing mode is the *caller's*
      decision (it depends on which of the three outcomes came back), so
      passing it in would have been a parameter the function never reads
      taking the UNION of differences 1-3 and keeping 4 behind `is_chat`;
      characterisation tests for all four BEFORE the extraction, so a dropped
      arm fails rather than passing silently
- [x] Three-valued return; only `"none"` falls through. `"failed"` keeps its
      diagnostic; the two `"none"` warnings are deleted
- [x] One fall-through to `ResolveRefOrGotoFile`, `stopinsert` first when in
      insert mode
- [x] Move `review_menu` to `<M-s>`. **Grep-derived hit list** (13 across 7
      files — the first version of this row was recalled and named 2):
      `keybinding_registry.lua:750` (`default_key`), `config.lua:458,462`,
      `skills/review/init.lua:742,765`, `init.lua`, `atlas/modes/review.md:55,199`,
      `tests/integration/review_menu_spec.lua:93,110`,
      `tests/integration/keybinding_agreement_spec.lua:326,370,397,407` — where
      two hardcoded `{ "<C-g>ve", "<M-o>", "<M-CR>" }` lists need editing and
      `:407` (journal sidecar asserts `is_nil` for `<M-o>`) fails outright
- [x] `<M-g>` also lives in `README.md:189` and `atlas/ui/keybindings.md:65`
- [x] Rebind `open_file` to `{ "<M-o>", "<C-g>o" }` — full list in `config.lua`,
      since M2's superset guard requires it
- [x] Tests, named: `OpenFileUnderCursor` reaches each of the four steps in both
      buffer types; the gf arm via a `vim.cmd` spy; the resolve arm via the
      injected runner
- [x] README + `atlas/ui/keybindings.md` alt-family list + `atlas/modes/review.md`

## Log

### 2026-09-08 — implementation
- 2026-09-08: closed — Round 4 after REWORK. Verified AFTER the commit (5394d88), by exit code: make test exit=0, make lint 0 warnings / 0 errors in 359 files — that ordering IS round 3s C1, since the routing guard reads git state and answers differently across the commit boundary. C1 fixed at the mechanism, not the instance: the guard unioned git ls-files --others so an untracked new spec is flagged while it is being written rather than one commit later; proven by touching a stray spec and watching it go red. The arch spec is also routed. C2 fixed at the rule, not the sink: vim.fn.glob executes backticks and reached a transcript-derived pattern through find_files pattern half (reproduced, marker created; now refused). The sink set is PROBED — the arch spec runs a live payload through nine candidate vim functions and fails if the declared set differs either way; four execute (expand, glob, globpath, expandcmd). One shared predicate helper.would_execute backs expand_path, safe_glob and abs_path. Mutation-checked: a raw vim.fn.glob in find_files reddens the arch guard, and SINKS={expand} reddens the probe. C3 fixed: the outline arm passed a buffer number where root_path was wanted and put the branch line before the first exchange, so it asserted nothing — my own standalone probe had the identical bug and I had read its MARKER:false as confirmation. The arm now asserts the walk actually rendered the child branch before asserting refusal, and was verified by reverting outline.lua to its vulnerable resolver and watching it go red. Minors: third prepare_dir consumer handles nil with an arch check that enumerates consumers mechanically; landing-mode specs parameterised over {chat, markdown} so divergence seven is a red test not a review round; atlas corrected on two claims round 2 could not support (every arm goes red — false; fifteen copies to one — false, six config-side remain). Divergence table extended to six rows with verdicts. side-quest: chat_respond_footnote_spec made hermetic after one intermittent failure during this rounds verification; three consecutive full runs green afterwards.; review verdict: FIX-THEN-SHIP

**The bare-name gap was not just an omission.** D3 was tabled as "markdown
resolves bare filenames against the chat roots, chat does not." What chat
actually did was fall past `filereadable`, match the timestamp pattern, and
**create a second empty chat** beside the one being referenced. So `@@<bare
name>@@` in a chat buffer silently forked the transcript. The union fixes it;
`open_reference_spec` asserts the file count, not just which path was opened.

**Chat is the release surface** (operator, mid-implementation): markdown is
experimental ariadne-stack polish. That reinforces rather than redirects the
extraction — all three omissions were on the chat side. It does settle the
question the Spec deliberately left open: whether markdown should gain
directory `Explore` is not worth answering now.

**The unified file-open goes through `open_buf`.** The chat chain hand-rolled
its own split-aware `vim.cmd("edit")`, a strictly worse copy of what `open_buf`
already did: no existing-window reuse, no `file_tracker` access record. Chat
gains both. `focus_other_split` exists only because netrw does not go through
`open_buf`.

**Read-repair was deliberately NOT extended.** `resolve_chat_path` takes an
optional `referring_file` that schedules a slug rewrite in the referring
document. The `🌿:` paths pass it; the `@@` path does not, and this change kept
it that way — widening read-repair to `@@` references is #224's call, not a
side effect of a keybinding move.

**Two guards were wrong, not the code.**
- The plan-table sweep demanded a definition for rows marked `deleted` — a
  status its own legend defines. Fixed in `single_source_sweeps_spec`.
- The journal-sidecar assertion listed `<M-o>` among "review keys that must not
  leak". `<M-o>` is now `open_file`, `parley_buffer` scope, which *belongs* on a
  sidecar. It checks `<M-s>` instead: the key changed, but so did the rule the
  line was expressing.

**`<M-CR>` means two things and that is fine.** `chat_define` (chat) and
`review_next` (markdown) are siblings under `parley_buffer`, so no buffer is
ever both — the collision guard permits it by design. `<M-o>` was the opposite
case: `open_file` is an *ancestor* scope of `markdown`, so both bindings would
have been live in one buffer with the later registration silently winning. That
is why the skill picker had to move rather than coexist.

### 2026-09-08

Requested during the #224 investigation, after the operator had been using forks
heavily. Taken ahead of #224 because it is small and it is the key they press
most; #224 is the larger fix and follows.

`<M-g>` lasted a few hours — worth recording as evidence that a chord's cost is
not knowable from the registry. It was chosen because it was free and in the
right family, which is necessary and not sufficient.
