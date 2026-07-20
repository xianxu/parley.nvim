---
id: 000196
status: codecomplete
deps: []
github_issue:
created: 2026-07-19
updated: 2026-07-19
estimate_hours: 0.85
started: 2026-07-19T18:07:05-07:00
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

## Spec

Completion must read the **live** neighborhood derivation, the same one
execution uses — never a policy frozen at attach time. Concretely, stop serving
a cached `vim.b[buf].parley_root_policy` from the completion path; recompute (or
invalidate-then-recompute) so that completion and `chat_respond`'s
`policy_for_buf(buf)` return the identical `write_root`/`read_roots` for a given
buffer state. Recompute cost is negligible next to the per-keystroke `glob`
completion already does.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec    design=0.2  impl=0.02
item: lua-neovim    design=0.1  impl=0.35
item: milestone-review design=0.0 impl=0.15
design-buffer: 0.10
total: 0.85
```

Small, well-understood bugfix: the diagnosis is done (issue-spec), the code
change is a few lines removing a stale cache read/write plus one new regression
test and one existing-test update (a single focused `lua-neovim` item), and the
single-pass close review (milestone-review overhead). `familiarity: 1.0` — the
neighborhood/completion path was just traced end to end.

## Done when

- For a chat whose repo is recognized only after buffer attach, typeahead offers
  the same `../sibling/` candidates that submission would resolve — no stale
  fallback root.
- Completion and `neighborhood.policy_for_buf(buf)` yield the same `write_root`
  for the same buffer at the same time (no attach-time freeze).
- A regression test drives the production completion entry point across an
  attach-before-recognition → recognized transition and asserts the candidate
  set tracks the live root.
- Existing neighborhood/completion tests stay green.

## Plan

- [x] Reproduce in a test: completion returns stale candidates when the derived
      root changes after attach (drives `completefunc`/cmp source, not just the
      helper).
- [x] Make the completion path read the live policy (remove/bypass the frozen
      `vim.b[buf].parley_root_policy` for candidate derivation; keep cmp
      re-assert behavior intact).
- [x] Verify the new test passes and the full neighborhood/completion suite is
      green; capture evidence.

## Log

### 2026-07-19
- 2026-07-19: closed — neighborhood_completion_spec 10/10 + neighborhood_spec 12/12 green; #196 transition regression is RED pre-fix (frozen cache still returns {} after repo recognized) and GREEN post-fix (production completefunc re-derives live root ../nbr2/); luacheck clean. Completion derives its neighborhood live via policy_for_buf — no attach-time freeze.; review verdict: SHIP

- Diagnosed from a live report (cwd brain, chat under `brain/workshop/parley`,
  `../ar` typeahead empty while submission resolved `../ariadne`). Traced to the
  attach-time policy cache in `neighborhood.lua`; confirmed the `..` glob and the
  fresh execution derivation both behave correctly. `ARCH-DRY`: one derivation,
  evaluated consistently — not two owners.
- Confirmed there is only one execution regime for local file tools: cliproxyapi
  is a model gateway (`atlas/providers/cliproxyapi.md`), tools run client-side
  via `tool_loop → dispatcher.execute_call` against `root_policy.write_root`. So
  completion and execution only had to share the derivation *evaluation*, not
  reconcile two path-resolution owners.
- Fix: `policy_for_completion` now always returns `M.policy_for_buf(buf)` (live);
  removed the `vim.b[buf].parley_root_policy` cache write in `attach_completion`.
  Grep confirmed the cache had no other consumer (read `:175` + write `:294`
  only), so removal strictly consolidates onto the live source (ARCH-DRY). The
  `parley_completion_attached` one-shot + cmp BufEnter/InsertEnter re-assert are
  untouched.
- TDD: added a `neighborhood_completion_spec.lua` regression that drives the
  real Done-when transition — a second repo whose chat attaches while
  unrecognized (fallback root → `completefunc "../nbr2"` = `{}`), then flips
  `config.repo_root` to recognize it and asserts `completefunc` re-derives live
  (`../nbr2/`). RED against pre-fix code (the frozen cache still returns `{}`
  after recognition), GREEN after the fix. This guards the *behavior*
  (completion tracks the live root), so it survives a freeze re-added under any
  var name — stronger than an earlier planted-var proxy, per the close review's
  Minor finding. Also replaced the now-vacuous `parley_root_policy` idempotency
  assertion (plan-quality INFO) with a meaningful re-`prep_md` completefunc check.
- Evidence: `neighborhood_completion_spec` 10/10, `neighborhood_spec` 12/12,
  `luacheck neighborhood.lua` clean. Two full-suite failures are NOT from this
  change: `markdown_finder_async_spec` fails 1 identically on clean `main`
  (pre-existing git-in-sandbox), `git_markdown_source_spec` passes 9/9 in
  isolation (parallel-run flake). Atlas `repo_mode.md` updated to record the
  live-derivation invariant.
