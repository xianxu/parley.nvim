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

- `collect_ancestor_chain` resolves the parent through `resolve_chat_path`,
  passing the referring file so the read-repair fires and the stale link is
  rewritten rather than merely tolerated.
- The branch-match at `:221` resolves through it too, so `branch_after` is right
  for a renamed child.
- `chat_respond`'s local `resolve_path` goes away if nothing else needs it; if
  something does, it is not used for chat references.
- An arch guard: no module outside the resolver joins a chat-reference path
  itself. Same shape as #214's "no module outside the registry reads
  `config.<key>.shortcut`", which caught the class rather than the site.

**Not in scope:** making the back-link correct at creation time. The child is
written before the parent has a topic, and #214 BR-19 establishes the reference
must be committed in the same action. Resolution-side repair is the design, not
a workaround — the rename is legitimate and the resolver already handles it.

## Done when

- A child whose parent was renamed after the fork submits WITH the parent
  conversation as context — asserted on the message list, not on the absence of
  a warning.
- `branch_after` is correct when the CHILD was renamed.
- The stale back-link is read-repaired.
- A guard fails if a module joins a chat-reference path outside the resolver.
- Seen red: reverting to the naive resolver drops the ancestor messages.

## Plan

- [ ] Failing test: parent renamed post-fork → ancestor messages are empty
- [ ] Route both `chat_respond` sites through `resolve_chat_path`
- [ ] Test the renamed-child `branch_after` case
- [ ] Assert the read-repair rewrites the link
- [ ] Arch guard for the class; remove the local joiner

## Log

### 2026-09-08

Reported by the operator while using the fork feature heavily. They read it as a
possibly-spurious warning; it is a silent context loss, which is the more
important half and is why this is not just a log-level change.
