---
id: 000224
status: open
deps: []
github_issue:
created: 2026-09-08
updated: 2026-09-08
estimate_hours:
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
| used by | `<M-g>`, `gf`, navigation | **the ancestor chain** |

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

**Recommendation: drop it from the resolution path.** Resolution is a read;
mutating a file the user may not even have open, as a side effect of navigating,
is a surprise that only existed because the name was load-bearing. If tidy links
are still wanted, they belong in an explicit sweep, not in a resolver. Flagging
rather than deciding — it is a behaviour removal and the operator may want the
links kept current for grep-ability outside parley.

**Not in scope:** making the back-link correct at creation. The child is written
before the parent has a topic, and #214 BR-19 requires the reference to be
committed in the same action. Prefix identity is what makes that safe.

## Done when

- A child whose parent was renamed after the fork submits WITH the parent
  conversation as context — asserted on the message list, not on the absence of
  a warning.
- `branch_after` is correct when the CHILD was renamed.
- A slug-stale reference resolves by timestamp, with no repair required for
  correctness (whether repair is kept at all is the open question above).
- A same-timestamp collision picks deterministically and says so, rather than
  silently preferring the longest name.
- A guard fails if a module joins a chat-reference path outside the resolver.
- Seen red: reverting to the naive resolver drops the ancestor messages.

## Plan

- [ ] Failing test: parent renamed post-fork → ancestor messages are empty
- [ ] Make prefix matching the primary rule; delete the exact-match tier
- [ ] Route both `chat_respond` sites through it; remove the local joiner
- [ ] Test the renamed-child `branch_after` case
- [ ] Decide read-repair with the operator; test whichever way it lands
- [ ] Collision case: deterministic pick + warning
- [ ] Arch guard for the class; remove the local joiner

## Log

### 2026-09-08

Reported by the operator while using the fork feature heavily. They read it as a
possibly-spurious warning; it is a silent context loss, which is the more
important half and is why this is not just a log-level change.
