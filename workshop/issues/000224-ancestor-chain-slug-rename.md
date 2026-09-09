---
id: 000224
status: working
deps: []
github_issue:
created: 2026-09-08
updated: 2026-09-08
estimate_hours:
started: 2026-09-08T15:04:07-07:00
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

| | `resolve_chat_path` (`init.lua:3200`) | `resolve_path` (`chat_respond.lua:176`) |
|---|---|---|
| searches every chat root | yes | no |
| timestamp glob for slug variants | yes | no |
| read-repairs the stale reference | yes | no |
| used by | `<M-o>`, `gf`, navigation | **the ancestor chain** |

`collect_ancestor_chain` (`chat_respond.lua:201`) uses the naive one, bails, and
returns `{}` — so `collect_ancestor_messages` → `build_ancestor_messages`
contributes nothing. For a fork, the parent conversation IS the context the fork
exists to carry.

**Second site, same cause.** `chat_respond.lua:221` matches a parent branch back
to the current file with the same naive resolver. A renamed CHILD therefore
fails that comparison, leaving `branch_after = 0` — so even when the parent
resolves, its exchanges are truncated at the wrong point.

### The class

`resolve_chat_path` was built for exactly this (it even schedules
`_read_repair_reference` to rewrite the stale link) and is already exported at
`init.lua:3252`. `chat_respond` grew its own path-joiner instead. Any code
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
- **Both `chat_respond` sites use it** — the parent lookup (`:201`) and the
  branch-match that sets `branch_after` (`:221`). Its local `resolve_path` goes
  away; the exporter already delegates (`exporter.lua:32`), so after this there
  is exactly one resolver.
- **An arch guard for the class:** no module outside the resolver joins a
  chat-reference path itself. Same shape as #214's "no module outside the
  registry reads `config.<key>.shortcut`", which caught the class rather than
  the site.

### Consequence: read-repair becomes optional

`resolve_chat_path` currently schedules `_read_repair_reference` to rewrite a
stale link on the way past (`init.lua:3241`). Under prefix identity a
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
| `resolve_chat_path` | `lua/parley/init.lua` | modified | filesystem glob |
| `resolve_path` | `lua/parley/chat_respond.lua` | deleted | — |
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

- **`resolve_chat_path`** — prefix identity becomes the primary rule, not a
  fallback tier, and it stops scheduling repair. Resolution becomes a pure read
  (ARCH-PURE: the glob is the only IO, and the ordering decision moves out to
  `resolve_candidates`).

**Operating envelope (ARCH-CONSTRAINTS).** `CursorHold` is an idle event, not a
keystroke path — that is why it is the trigger rather than `CursorMoved`, which
would glob across every chat root on every motion. Budget: one `glob` per idle
pause, and only when the cursor line matches the reference pattern (a cheap
string test gates the glob). No work at all in insert mode. The ancestor walk
keeps its existing depth cap.

**Trust (ARCH-SECURE).** The reference is transcript text, so resolution goes
through the `helper.safe_glob` / `expand_path` guards #225 installed; the arch
guard added there already covers any new sink this introduces.

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
- Navigation performs no writes at all — asserted by spying the file-write seam
  across `<M-o>`, `gf` and the ancestor walk.
- A same-timestamp collision picks deterministically and says so, rather than
  silently preferring the longest name.
- A guard fails if a module joins a chat-reference path outside the resolver.
- Seen red: reverting to the naive resolver drops the ancestor messages.

## Plan

- [ ] Failing test: parent renamed post-fork → ancestor messages are empty.
      Assert on the MESSAGE LIST, not on the absence of a warning — the warning
      is the symptom the operator saw, the missing context is the defect
- [ ] Make prefix matching the primary rule in `resolve_chat_path`; delete the
      exact-match tier rather than reordering it (it is the case where the glob
      returns the name already used)
- [ ] Collision: prefer an exact basename match when the reference has one, else
      lexicographically first + a warning. Replaces the current sort-by-length,
      which encodes "the one with a slug" and stops being right the moment two
      slugged variants exist
- [ ] Route both `chat_respond` sites through it — the parent lookup (`:201`)
      and the branch-match that sets `branch_after` (`:221`) — and delete the
      local `resolve_path`
- [ ] Test the renamed-CHILD `branch_after` case (the second site, same cause:
      a renamed child fails the parent-branch comparison and truncates at 0)
- [ ] Remove `_read_repair_reference` from the resolution path; resolution
      becomes a pure read
- [ ] Add the cursor-entry trigger: `CursorHold` in a chat buffer, reference on
      the cursor line, name actually changed, not in insert mode → rewrite the
      line as a BUFFER edit. Test the no-op case leaves `modified` untouched
- [ ] Arch guard for the class: no module outside the resolver joins a
      chat-reference path itself (same shape as #214's registry guard). Seen red
      by re-adding a local joiner

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
