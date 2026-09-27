---
id: '000196'
status: done
started: 2026-07-19T18:07:05-07:00
created: 2026-07-19
updated: 2026-07-28
estimate_hours: 0.85
actual_hours: 0.23
---

# Path typeahead caches stale neighborhood; diverges from live tool-exec cwd

## Problem

Path typeahead (the `<Tab>`/cmp completion that offers filesystem paths inside a
chat) can offer a **different neighborhood root** than the one parley actually
uses when it executes the tool call — so a path that completion refuses to
suggest still resolves fine on submission.

Concrete repro: cwd `~/workspace/brain`, editing a chat at
`~/workspace/brain/workshop/parley/<file>.md`. Typing `../ar` did NOT pop up
`../ariadne/`, yet the submitted tool call resolved `../ariadne` correctly.

Root cause — a **stale cached policy**, not two different code paths. Both sides
already derive the root through the same `neighborhood.derive_for_path` /
`policy_for_buf`:

- **Execution** recomputes `policy_for_buf(buf)` *fresh* on every submit
  (`chat_respond.lua:1402`), so once the repo is recognized it uses
  `write_root = …/brain`.
- **Completion** computes the policy *once* at attach time and freezes it in
  `vim.b[buf].parley_root_policy`; `attach_completion` early-returns on
  re-entry (`neighborhood.lua:292`) and `policy_for_completion` returns the
  cached value first (`neighborhood.lua:174-175`), so it never refreshes. If the
  buffer attached before `config.repo_root` / `chat_dirs.get_chat_roots()`
  recognized brain, completion keeps the dirname fallback
  `write_root = …/workshop/parley`.

With `write_root = …/workshop/parley`, `../ar` globs `…/workshop/ar*` → nothing.
With `write_root = …/brain`, `../ar` globs `…/ariadne` → the expected hit.
(Verified via headless reproduction of `completion_candidates`; the `..` glob
itself works — only the root was wrong.)

There is no second execution regime: cliproxyapi is a model gateway, not a
tool-executor (`atlas/providers/cliproxyapi.md`), so parley executes every local
file tool client-side against `root_policy.write_root` regardless of provider.
The agent's local cwd is always parley's neighborhood — so completion and
execution only need to evaluate that one derivation *at the same time*.
