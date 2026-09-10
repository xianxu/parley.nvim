---
id: 000224
status: codecomplete
deps: []
github_issue:
created: 2026-09-08
updated: 2026-09-09
estimate_hours: 6.46
started: 2026-09-08T15:04:07-07:00
actual_hours: 4.46
---

# Forked chat loses its parent context after a slug rename

## Problem

Operator, forking extensively after #214 shipped:

```
Parley.nvim: collect_ancestor_chain: parent file not readable:
  …/workshop/parley/2026-09-08.13-37-05.361.md
```

*"the file is there, I can navigate to it. this seems maybe erogenous warning?"*

It is not spurious, and the warning understates it. **The forked chat is
submitted with no parent context at all.**

### What happens

1. `<M-i>` creates the parent's child and writes the child's back-link
   immediately — it must, or a crash orphans the child (#214 BR-19).
2. The parent then earns its topic and the `ParleySlug` `BufWritePost` autocmd
   renames it: `2026-09-08.13-37-05.361.md` →
   `…361_light-lag-simultaneity.md`.
3. The child's back-link still names the pre-slug file. Verified on disk:

   ```
   workshop/parley/…13-41-59.745_astronomers-….md:6:
     🌿: 2026-09-08.13-37-05.361.md: Light lag and simultaneity
   ls: 2026-09-08.13-37-05.361_light-lag-simultaneity.md
   ```

### Why navigation works but the submission does not

Two independent resolvers, and only one knows about renames:

| | `resolve_chat_path` (`init.lua:3215`) | `resolve_relative_path` (`helper.lua`, via `chat_respond.lua:176`, `outline.lua:208`) |
|---|---|---|
| searches every chat root | yes | no |
| timestamp glob for slug variants | yes | no |
| read-repairs the stale reference | yes | no |
| used by | `<M-o>`, `gf`, navigation | **the ancestor chain** |

`collect_ancestor_chain` (`chat_respond.lua:195`) uses the naive one, bails, and
returns `{}` — so `collect_ancestor_messages` → `build_ancestor_messages`
contributes nothing. For a fork, the parent conversation IS the context the fork
exists to carry.

**Second site, same cause.** `chat_respond.lua:215` matches a parent branch back
to the current file with the same naive resolver. A renamed CHILD therefore
fails that comparison, leaving `branch_after = 0` — so even when the parent
resolves, its exchanges are truncated at the wrong point.

### The class

`resolve_chat_path` was built for exactly this (it even schedules
`_read_repair_reference` to rewrite the stale link) and is already exported at
`init.lua:3269`. `chat_respond` grew its own path-joiner instead. Any code
resolving a chat reference must go through the one resolver — a second one is
guaranteed to be the one that has not learned about renames.

## Spec

**The timestamp prefix is the identity of a chat file. The trailing slug exists
for human inspection and carries no meaning to resolution** (operator,
2026-09-08). `YYYY-MM-DD.HH-MM-SS.mmm` is unique in practice — two chats created
in the same millisecond is the only collision, and it is handled below rather
than assumed away.

That makes resolution one rule instead of a rule plus a fallback:

```
reference → parse_filename() → timestamp → glob "<ts>*.md" across the chat roots
```

`chat_slug` already provides both halves (`parse_filename` at `:74`,
`glob_pattern` at `:103`). Today they sit behind an exact-name tier as a *fuzzy
fallback* (`init.lua:3208`, comment: "Fuzzy fallback"). Nothing about it is
fuzzy — it is the identity — and demoting it to a fallback is what let a second
resolver be written that only does exact matching.

- **Exact match stops being a tier.** It is just the case where the glob returns
  the name the reference already used. Delete the two-tier structure rather than
  reordering it.
- **Collision, handled not assumed:** if the glob returns more than one file,
  prefer an exact basename match when the reference has one; otherwise take the
  lexicographically first and log at warning. Today the code sorts by *length*
  and silently prefers the longest, which encodes "the one with a slug" — a
  guess that stops being right the moment two slugged variants exist.
- **All FIVE consumer sites use it**, not two. Measured, after the plan-quality
  gate caught the plan claiming "exactly one resolver" while a third consumer
  sat outside it:

  | site | what breaks today |
  |---|---|
  | `chat_respond.lua:195` — parent lookup | the fork submits with no parent context |
  | `chat_respond.lua:215` — branch-match | `branch_after = 0`, parent truncated at the wrong point |
  | `outline.lua:230` — `find_tree_root` | **verified**: a renamed parent makes the tree root the CHILD; `<M-t>` never reaches the parent |
  | `outline.lua:273` — branch topic | a renamed child shows no topic |
  | `outline.lua:277` — picker `child_path` | a renamed child stores an unreadable navigation target |

  A **third** `resolve_path` definition turned up in `highlighter.lua` while the
  other two were being removed. That one was already a correct delegate and
  never had the bug — but the shared NAME is what made the broken pair look like
  the working one, so it goes too. After this there is no `local resolve_path`
  anywhere in `lua/`.

  *(Counting note, close review round 3: the table above lists five consumer
  CALL SITES; the definitions were three — `chat_respond`, `outline`,
  `highlighter`. Round 1's commit message and the atlas both said "six", which
  read call sites as definitions and double-counted the pair #225 had merged.)*

  The exporter (`exporter.lua:32`) and highlighter (`highlighter.lua:66`)
  already delegate to `resolve_chat_path`, so after this there is exactly one
  resolver *and* one set of consumers.

- **#225's consolidation unified the bug rather than fixing it** — worth stating,
  because it is the reason the third site is easy to miss. `chat_respond` and
  `outline` each had a byte-identical private `resolve_path`; #225 merged them
  into `helper.resolve_relative_path` (ARCH-DRY, correctly) — but merged them
  onto the **naive** resolver. One implementation of the wrong thing is still
  the wrong thing, now uniformly. A DRY consolidation must pick the
  more-correct implementation as the survivor, not the more common one.
- **An arch guard, over RESOLUTION rather than joining.** The obvious phrasing —
  "no module joins a chat-reference path itself" — greps clean over a tree that
  still has the bug, because after #225 nothing joins: `chat_respond.lua:176`
  and `outline.lua:208` both *delegate* to `helper.resolve_relative_path`. A
  guard over the wrong term is the #225 round-3 failure exactly (the rule was
  over `expand` while `glob` was the live sink).

  The rule: **`helper.resolve_relative_path` may be reached with a
  transcript-derived chat reference only from `resolve_chat_path`.** Enforced in
  the shape of `tests/arch/untrusted_path_spec.lua`'s ALLOW — every call site
  listed with a stated reason, so a new one fails until it is justified. After
  this change the allowlist has exactly one entry (`init.lua`'s
  `_resolve_chat_path_candidates`), which is the assertion worth making.

  **Seen red by re-adding a local RESOLVER, not a local joiner** — the mutation
  has to be the mistake the guard exists to catch.

### Consequence: read-repair becomes optional

`resolve_chat_path` currently schedules `_read_repair_reference` to rewrite a
stale link on the way past (`init.lua:3258`). Under prefix identity a
slug-stale link is not stale — it resolves correctly forever — so repair stops
being load-bearing and becomes cosmetic.

**Decided (operator, 2026-09-08): drop it from the resolution path, and give it
one explicit trigger — the cursor entering the link.**

> *"it's not broken but not desirable to be out of sync, that's all. I think we
> can trigger the read repair operation to be cursor entering that link, you put
> your cursor there, we do a refresh in case slug changes. that's the only
> read-repair trigger, by user action, seems safe?"*

It is safe, and it is better than both alternatives. Keeping repair in the
resolver means navigating mutates files you may not have open; dropping it
entirely leaves links that are correct-but-stale to anything reading the
transcripts outside parley (grep, the exporter, a human). Cursor-entry is a user
action, is scoped to the one reference you are looking at, and happens in a
buffer that is by definition already open.

Four consequences, each a design commitment rather than an implementation
detail:

- **Buffer edit, not file write.** Repair rewrites the line in the buffer, so it
  is undoable, visible in the diff the user is looking at, and never touches a
  file behind their back. `_read_repair_reference`'s current file-write shape
  goes away with the resolver call that motivated it.
- **`CursorHold`, not `CursorMoved`** (ARCH-CONSTRAINTS). Cursor movement is a
  keystroke path; a glob across chat roots per motion is exactly the "repeated
  expensive work on a critical UI path" the envelope forbids. `CursorHold` fires
  after `updatetime` idle, so the cost is one glob per pause, and only when the
  cursor line actually carries a reference.
- **Only when the name actually changed.** Resolution answers with a path; if
  its basename equals the one in the line, there is nothing to repair and no
  edit is made. A no-op must leave `modified` untouched.
- **Never on a line the user is editing.** Repair is skipped in insert mode, so
  it cannot fight a half-typed reference.
- **Never while the buffer is busy.** A response streaming into the buffer is a
  concurrent writer, and `chat_lease` anchors on a buffer line and invalidates
  on concurrent mutation (`chat_respond.lua:1575-1582`). Both existing writers
  already defer on this — `_read_repair_reference` on `tasker.is_busy`
  (`init.lua:3107`), `_slug_rename_chat` refuses outright (`init.lua:3029`) — and
  omitting it here would make the new writer the only one that does not.
  **It IGNORES, it does not queue or cancel:** repair is cosmetic and
  idempotent, there is no state to cancel, and the next `CursorHold` retries for
  free. Queuing would land the write at the least predictable moment.

`CursorHold` **reads** `updatetime` and does not set it — this is the plugin's
first cursor autocmd, and silently changing a global option to tune a cosmetic
feature would be exactly the kind of surprise `default_keymaps` exists to
prevent. Users who want faster repair set `updatetime` themselves.

The read-repair trigger is therefore the *only* writer, and prefix identity is
what makes it optional — correctness never depends on it firing.

**Not in scope:** making the back-link correct at creation. The child is written
before the parent has a topic, and #214 BR-19 requires the reference to be
committed in the same action. Prefix identity is what makes that safe.

## Core concepts

The work is one consolidation plus one relocation. The consolidation is
`resolve_chat_path` becoming the single resolver; the relocation is read-repair
moving off it onto a user action.

### Pure entities

| Name | Lives in | Status |
|---|---|---|
| `rewrite_reference` | `lua/parley/chat_slug.lua` | new |
| `resolve_candidates` | `lua/parley/chat_slug.lua` | new |

- **`rewrite_reference(line, old_basename, new_basename)`** — the line with the
  reference renamed, or `nil` when it does not appear. This is the one part of
  today's `_read_repair_reference` worth keeping, and it carries a real trap:
  the replacement must be `%`-escaped or Lua's `gsub` reads `%` as a capture
  reference. That bug class already cost a round in #214.
  - **DRY rationale:** first occurrence of "rename a reference inside a line",
    which the exporter and any future sweep would otherwise each re-derive.
  - **Future extensions:** an explicit repair-the-whole-file sweep calls it per
    line; that is the natural growth axis and needs no signature change.

- **`resolve_candidates(reference, names)`** — given a reference basename and
  the candidate names a glob returned, the ordered picks. Owns the collision
  policy (exact basename wins; else lexicographically first) with no IO, so the
  policy is testable without a filesystem. Today that decision is a
  `table.sort` by *length* buried inside the resolver.

### Integration points

| Name | Lives in | Status | Wraps |
|---|---|---|---|
| `repair_reference_at_cursor` | `lua/parley/init.lua` | new | buffer read/write |
| `_collect_ancestor_messages` | `lua/parley/chat_respond.lua` | new | test seam over the ancestor walk |
| `_collect_ancestor_chain` | `lua/parley/chat_respond.lua` | new | test seam over the ancestor walk |
| `_find_tree_root` | `lua/parley/outline.lua` | new | test seam over the upward tree walk |
| `resolve_chat_path` | `lua/parley/init.lua` | modified | filesystem glob |
| `resolve_path` | `lua/parley/chat_respond.lua` | deleted | — |
| `resolve_path` | `lua/parley/outline.lua` | deleted | — |
| `resolve_path` | `lua/parley/highlighter.lua` | deleted | — |
| `_read_repair_reference` | `lua/parley/init.lua` | deleted | — |

- **`repair_reference_at_cursor(buf, lnum)`** — resolves the reference on one
  line and applies `rewrite_reference` as a buffer edit. Wired to `CursorHold`
  in a chat buffer.
  - **Injected into:** nothing; it is the leaf. The autocmd is its only caller,
    so "repair happens on exactly one trigger" is checkable by grep.
  - **Scope, deliberately:** the line under the cursor, not the file. A
    transcript with three stale references needs three visits. That follows
    from the operator's framing ("you put your cursor there") and is the
    property that makes it unsurprising; a whole-file rewrite triggered by
    resting a cursor would be the behaviour the old design was criticised for,
    moved rather than removed.

- **`_find_tree_root`** — the UPWARD half of the outline walk.
  `_build_tree_outline_items` builds *downward* from whatever path it is handed,
  so a test driving it can never observe a broken parent lookup — which is
  exactly how the `<M-t>` coverage claim shipped unbacked (close review BR-2).
  Same shape as the ancestor seam below: the defect lives in the IO half.

- **`_collect_ancestor_messages` / `_collect_ancestor_chain`** — the repo's
  `M._x = local_fn` seam idiom. The walk is IO (it reads parent files off disk
  and resolves their references), so the defect it carries is unreachable
  through `build_ancestor_messages`, which is only the pure half — and that is
  why a passing `ancestor_messages_spec` never saw this bug.

- **`resolve_chat_path(path, base_dir)`** — prefix identity becomes the primary
  rule, not a fallback tier, and it stops scheduling repair. Resolution becomes
  a pure read (ARCH-PURE: the glob is the only IO, and the ordering decision
  moves out to `resolve_candidates`).
  - **Signature change:** the third parameter `referring_file` goes away, since
    its only purpose was scheduling repair. Six consumers pass or re-export it:
    `init.lua:3302`, `:3337`, `:3358`, `:4248` pass it; `exporter.lua:32` and
    `highlighter.lua:66` re-export the 2-arg form and are unaffected. Dropping a
    parameter is source-compatible in Lua (extra args are ignored), which is
    precisely why it must be swept rather than left — a forgotten caller would
    keep compiling and silently pass a now-meaningless argument.

**Operating envelope (ARCH-CONSTRAINTS).** `CursorHold` is an idle event, not a
keystroke path — that is why it is the trigger rather than `CursorMoved`, which
would glob across every chat root on every motion. Budget: one `glob` per idle
pause, and only when the cursor line matches the reference pattern (a cheap
string test gates the glob). No work at all in insert mode. The ancestor walk
keeps its existing depth cap.

**Trust (ARCH-SECURE).** The reference is transcript text, so resolution goes
through the `helper.safe_glob` / `expand_path` guards #225 installed; the arch
guard added there already covers any new sink this introduces.

## Revisions

### 2026-09-09 — close review round 1 (REWORK, 1 Critical + 2 Important)

- **BR-1 (Critical) — making the glob primary introduced a silently WRONG
  answer.** `search_dirs` was `{base_dir} ∪ chat_roots`, so a reference whose
  own directory is neither — an absolute path, `~/…`, `../archive/…` — globbed
  everywhere *except* where it pointed. `resolve_candidates` never saw the exact
  basename, an unrelated same-timestamp file in a chat root won, and the
  existence loop below was unreachable because the glob had already answered.
  Reproduced: an archived chat referenced by absolute path resolved to a
  different chat entirely.
  That is this issue's own failure mode from the opposite cause, and it is worse
  than the bug being fixed: not-found is loud, wrong-file is silent. The fix
  adds the reference's own directory to the glob set, so the exact hit wins
  *through* `resolve_candidates` — the one-rule design intact, no tier restored.

- **BR-2 (Important) — three claims of coverage with no test behind them.** All
  three verified by the reviewer's mutations, and all three are mine:
  the `<M-t>` Plan row was ticked with only the arch guard behind it; the
  `branch_after` test wrote the parent's branch line as the child's ACTUAL
  on-disk name, so the naive resolver handled it and the test passed with the
  fix reverted; and the atlas claimed "five guards, each with its own test"
  while the insert-mode guard had none.
  The `<M-t>` one has a second lesson in it: I drove
  `_build_tree_outline_items`, which builds *downward* from the path it is
  handed and therefore can never observe a broken parent lookup. The defect
  lives in the upward walk, which is now exposed as `_find_tree_root`. Testing
  the reachable seam instead of the defective one is how a claim ships unbacked.

- **BR-3 (Important) — the new writer bypassed `buffer_edit`.** `init.lua` is on
  `buffer_mutation_spec`'s *shrinking* allowlist (#90: "after Phase 3, ONLY
  buffer_edit.lua remains"), and a new direct `nvim_buf_set_lines` moves that
  list the wrong way. `replace_line_at` is exactly this operation.

- Minor: `<M-t>` resolved the same branch reference twice per untopiced branch.
  Under prefix identity each resolve is a glob per chat root, so that is double
  cost on a keystroke path.

Each fix is mutation-verified by name with lint clean — twice this round an
`exit 2` came from lint (an unused variable the mutation created) rather than
from the guard, and once a `head -2` on the output hid the failure I was looking
for. Red for the wrong reason is the same as green, and so is red you did not
read.

### 2026-09-09 — close review round 2 (FIX-THEN-SHIP, 3 Important)

- **BR-14 — my BR-1 fix was the instance, not the class.** BR-1 named absolute
  and `~/` references, and I added `candidates[1]`'s directory. The class is
  *every* directory the candidate list can point into: a `sub/<ts>.md`
  reference resolving under a second chat root still lost. The glob set is now
  derived from `candidates`, so it cannot go stale when
  `_resolve_chat_path_candidates` gains a source.
  Two further things fell out of building a test that could actually tell the
  two fixes apart:
  - **Search ORDER is the tie-break**, and candidate directories have to come
    first. `base_dir` is where the reference was *written from*, not where it
    points; leading with it resolved a renamed `sub/` target to whatever sat at
    the root. `resolve_candidates` no longer sorts — the caller supplies search
    order and sorts within each directory, so filesystem order still cannot
    leak in.
  - **The obvious fixture could not discriminate.** With the target present
    under its referenced name, BR-15's exact-hit short-circuit answers first and
    the test passes against both the instance fix and the class fix. The
    discriminating case is a `sub/` reference whose target was *renamed*: no
    candidate exists, so the glob must find it. Two versions of this test
    passed either way before the third one bit.

- **BR-15 — deleting the exact-hit short-circuit changed the cost class of
  every existing consumer.** Measured here, not taken on faith: one root of
  2000 files, exact-name hit, **0.031 ms → 2.434 ms** (the review measured
  0.033 → 2.486). That is the *common* case — every reference whose parent has
  not been renamed — and `<M-t>` pays it once per branch on a keystroke path.
  The short-circuit is back, and it is **not** the tier the Spec deletes: a tier
  changes the answer, and this cannot, because `resolve_candidates` already
  prefers an exact basename over every other same-timestamp match and (after
  BR-14) an existing exact target is always among the glob's matches. Removing
  it leaves the suite green — which is the equivalence claim, as evidence.

- **BR-16 — nothing drove the `CursorHold` autocmd**, the feature's only
  production entry point. Nine arms called `repair_reference_at_cursor`
  directly, so the event, the `*.md` pattern and the `ev.buf` /
  `nvim_win_get_cursor(0)` pairing were pinned by nothing. Two arms now fire
  the real event, and breaking the pattern reddens them.
  This is the same family as BR-2's `<M-t>` finding, stated one level up: **a
  test must enter through the path production enters through — the trigger, not
  just the function behind it.**

**Commit hygiene, second occurrence.** The round-1 commit swept 14 of the
operator's chat transcripts (~1,500 lines) into the diff. #225 recorded the
lesson as "stage by path, never `-A`" and I then wrote
`git add -A -- lua tests atlas workshop` — which *is* by path, and `workshop`
contains `workshop/parley/`. The rule was true and not specific enough. The
branch was unpushed; the commit was amended and the transcripts are untracked
again.

## Estimate

Derived against the calibration ledger's parley rows (`sdlc estimate-source`
flags the v3.1 doc `[stale]`; the ledger is the newer artifact):

| row | est | design | impl | actual | ratio |
|---|---|---|---|---|---|
| #215 | 2.23 | 1.25 | 0.60 | 1.67 | 1.34 |
| #218 | 1.86 | 0.70 | 1.05 | 2.13 | 0.87 |
| #202 | 1.64 | 0.65 | 0.89 | 1.89 | 0.87 |
| #225 | 1.79 | 0.60 | 1.10 | 3.92 | **0.46** |
| #214 | 3.83 | 1.00 | 2.68 | 17.14 | **0.22** |

**The pattern in my own rows is the useful signal, and it is not "everything
overruns".** The four that landed near 1.0 (#201 0.97, #202 0.87, #215 1.34,
#218 0.87) were single-concern changes that closed in one review round. The ones
that missed badly (#225 0.46, #203 0.40, #205 0.30, #214 0.22) all took three or
more close-review rounds. The overrun is not in the implementation line — it is
in a `milestone-review` item budgeted for **one** round when the work reliably
takes several.

#224 is #225-shaped and slightly larger: five consumer sites rather than two, a
resolver rewrite, and a genuinely new surface (the plugin's first cursor
autocmd, with a concurrency guard). #225 actualled 3.92. So the review line is
budgeted at 0.6 — two to three rounds — rather than the 0.2 that made #225's
estimate wrong.

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only. (`sdlc estimate-source` flags that doc
`[stale]`, so the per-primitive hours were cross-checked against the newer
calibration ledger rows above; the method and vocabulary are unchanged.)

Three of the first draft's slugs (`pure-entity-tests`, `arch-guard`,
`signature-sweep`) were invented; the vocabulary is closed.

**Two corrections after the estimate-quality pass, both worth recording because
the first one was the same mistake the block itself was written to avoid:**

- The first remap parked the arch guard inside `cross-cutting-refactor` at
  `impl=0.45` — **2.3× that slug's ceiling**, which is the tell that a number is
  being stretched to make a slug fit. The guard is a Lua test with a seen-red
  mutation; it belongs under `lua-neovim`. `cross-cutting-refactor` now carries
  only what it names: the six-consumer signature sweep.
- **The design line was badly under-budgeted, and I can now measure it.**
  `sdlc actual --issue 224` reports **2.60h already spent** — claim, spec,
  Core concepts, the read-repair write-up and two plan-gate rounds. Against a
  4.01h total that left 1.4h for the whole implementation plus the two-to-three
  review rounds this block itself names as the dominant term. The block argued
  the right thing and then wrote a number that contradicted it.

  This is a revision of the per-item hours with new evidence, not a back-fit:
  the total moved *because* the items did, not the other way round.

**A third correction, and it is arithmetic rather than judgment.** The 6.00
block still landed its design line *under* the measurement it had just cited:
2.60h measured + 3.70h itemized impl is 6.30 before a line of code. Design is
now 2.4 (→ 2.76 buffered), which covers the 2.60 already spent plus the
estimate rounds that are themselves design time and are not free.

**Why the design hours sit above `lua-neovim`'s discounted ceiling.** Step 3 of
the model discounts design ×0.2 for a spec that pre-resolves its decisions, and
this spec does. The discount assumes design was paid *outside* the measured
window — but claim-early (AGENTS.md §2) anchors `sdlc actual` at the **claim
commit**, so on this repo the design sits inside the window and has to stay in
the estimate. Applying the discount here would estimate a cost the measurement
will still charge. That is the reconciliation; without it the 0.9s look like a
split difference between the discounted ceiling and the undiscounted floor.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim              design=0.9 impl=0.9
item: lua-neovim              design=0.9 impl=0.8
item: lua-neovim              design=0.3 impl=0.4
item: cross-cutting-refactor  design=0.3 impl=0.2
item: atlas-docs              design=0.0 impl=0.2
item: milestone-review        design=0.0 impl=1.2
design-buffer: 0.15
total: 6.46
```

`design-buffer: 0.15` (not the 0.30 default) because the plan is thorough: two
plan-gate rounds, the five consumer sites measured rather than recalled, the
guard's rule restated after the gate showed it was over the wrong term, and the
repair trigger's five guards enumerated with a stated disposition each.

Recomputed: (0.9+0.9+0.3+0.3) × 1.15 + (0.9+0.8+0.4+0.2+0.2+1.2) × 1.0
= 2.40 × 1.15 + 3.70 = 2.76 + 3.70 = **6.46**.

Against #225 (est 1.79, actual 3.92) for comparable-but-smaller scope, and with
2.60h already measured on this one, 6.46 is arithmetic rather than a hedge.

## Done when

- A child whose parent was renamed after the fork submits WITH the parent
  conversation as context — asserted on the message list, not on the absence of
  a warning.
- `branch_after` is correct when the CHILD was renamed.
- A slug-stale reference resolves by timestamp, and **correctness never depends
  on repair having fired** — asserted by resolving with repair disabled.
- Resting the cursor on a stale reference rewrites that line in the BUFFER
  (undoable, `modified` set); resting it on a current one changes nothing and
  leaves `modified` untouched.
- Navigation performs no writes at all. Evidence as shipped: `read_repair_spec`
  compares the referring file's bytes before and after a `resolve_chat_path`
  call. That covers all three entry points because they go through the one
  resolver and `_read_repair_reference` is deleted — but it is a content
  compare on one call, not the per-entry-point write-seam spy this line
  originally promised (close review round 3).
- A same-timestamp collision picks deterministically and says so, rather than
  silently preferring the longest name.
- A guard fails if a module joins a chat-reference path outside the resolver.
- Seen red: reverting to the naive resolver drops the ancestor messages.

## Plan

- [x] Failing test: parent renamed post-fork → ancestor messages are empty.
      Assert on the MESSAGE LIST, not on the absence of a warning — the warning
      is the symptom the operator saw, the missing context is the defect
- [x] Make prefix matching the primary rule in `resolve_chat_path`; delete the
      exact-match tier rather than reordering it (it is the case where the glob
      returns the name already used)
- [x] Collision: prefer an exact basename match when the reference has one, else
      lexicographically first + a warning. Replaces the current sort-by-length,
      which encodes "the one with a slug" and stops being right the moment two
      slugged variants exist
- [x] Route ALL FIVE consumer sites through it — `chat_respond.lua:195` and
      `:215`, `outline.lua:230`, `:273` and `:277` — and delete both local
      `resolve_path` delegates. Five, not two: the plan-quality gate caught the
      plan claiming "exactly one resolver" while `outline` sat outside it
- [x] Test the renamed-CHILD `branch_after` case (the second site, same cause:
      a renamed child fails the parent-branch comparison and truncates at 0)
- [x] Test the `<M-t>` tree: a renamed parent must not make the CHILD the tree
      root. Verified failing today via `_build_tree_outline_items` — the outline
      shows `📋 Child` and never reaches the parent
- [x] Remove `_read_repair_reference` from the resolution path; resolution
      becomes a pure read
- [x] Drop `referring_file` from `resolve_chat_path`'s signature and sweep the
      four call sites that pass it
- [x] Add the cursor-entry trigger: `CursorHold` in a chat buffer, reference on
      the cursor line, name actually changed, not insert mode, not busy →
      rewrite the line as a BUFFER edit. Test: the no-op case leaves `modified`
      untouched; a busy buffer is skipped and retried on the next hold
- [x] Arch guard over RESOLUTION: `helper.resolve_relative_path` reached with a
      chat reference only from `resolve_chat_path`, allowlisted per site with a
      stated reason (shape of `untrusted_path_spec.lua`'s ALLOW). Seen red by
      re-adding a local RESOLVER — a guard over "joining" greps clean over the
      buggy tree, which is what the gate caught

## Revisions

### 2026-09-09 — read-repair decided

The Spec recommended **dropping** read-repair outright and flagged it as the
operator's call. The operator chose a third option the Spec had not offered:
keep it, but give it exactly one trigger — the cursor entering the link.

The recommendation was reasoned from "resolution is a read, so it must not
mutate", which is right about the *resolver* and overshoots to the *feature*.
Moving the trigger to a user action keeps the property that motivated the
recommendation (navigation never writes) without losing the property the
operator wanted (links that stay grep-able outside parley). Spec section
updated in place; Plan row 5 replaced by the two rows that implement it.

## Log


- 2026-09-09: closed — Round 3 after FIX-THEN-SHIP-with-open-findings. make test exit=0 (208 spec files), make lint 0 warnings / 0 errors in 364 files — verified AFTER the commit, by exit code. BR-14 fixed at the CLASS: the glob set derives from candidates rather than naming candidates[1], and search order is the tie-break with candidate directories first (base_dir is where a reference was written from, not where it points). Mutation-verified by name with lint clean, on a fixture that actually discriminates — two earlier fixtures passed against BOTH the instance fix and the class fix, one because a single root made candidates[1] already right, the other because BR-15 short-circuit answered before the glob ran; the discriminating case is a sub/ reference whose target was RENAMED. resolve_candidates no longer sorts (the caller supplies search order and sorts within each directory, so filesystem order still cannot leak), and its unit spec was rewritten to the new contract. BR-15 fixed and MEASURED BY ME rather than cited: one root of 2000 files, exact-name hit, 0.031 ms with the short-circuit vs 2.434 ms without, matching the review 0.033/2.486. The short-circuit is not the deleted tier — it cannot change the answer, because resolve_candidates prefers an exact basename and after BR-14 an existing exact target is always among the glob matches; removing it leaves the suite green, which is that equivalence as evidence. BR-16 fixed: two arms now fire the real CursorHold event, and breaking the *.md pattern reddens them by name. Commit hygiene second occurrence recorded and corrected: the round-1 commit swept 14 operator transcripts because "stage by path, never -A" was satisfied by `git add -A -- lua tests atlas workshop` and workshop contains workshop/parley; branch was unpushed, commit amended, transcripts untracked again, and the sharpened rule immediately caught an unrelated config.lua edit staged into round 2.; review verdict: FIX-THEN-SHIP
### 2026-09-08

Reported by the operator while using the fork feature heavily. They read it as a
possibly-spurious warning; it is a silent context loss, which is the more
important half and is why this is not just a log-level change.

**The bug was masked, which is why it read as a warning rather than a defect.**
The operator noticed that the model in a forked chat started emitting
`chat_history_search` — *"it's almost like organic life finding ways when
there's bug."* That is exactly what happened: deprived of the parent
conversation by this defect, and handed every builtin tool by #221's `@all`, the
model went and fetched the context itself.

Two things follow:

- **It is behavioural evidence for this issue, stronger than the log line.** A
  model that already has the parent conversation in its context has no reason to
  search for it. The tool calls are the symptom the warning only hints at.
- **It is not an argument against `chat_history_search`.** Unlike
  `emit_definition` that tool is a legitimate general capability and should stay
  discoverable under #221. The problem is that its availability *compensated*
  for a missing input, at the cost of extra round-trips and a retrieval that may
  well find the wrong chats — a plausible answer built from a search instead of
  the actual parent thread.

Worth remembering as a review heuristic: a model reaching for a tool to obtain
something the harness was supposed to hand it is a signal that the harness
stopped handing it over.
