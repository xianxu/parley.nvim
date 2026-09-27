---
id: '000224'
status: done
started: 2026-09-08T15:04:07-07:00
created: 2026-09-08
updated: 2026-09-09
estimate_hours: 6.46
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
