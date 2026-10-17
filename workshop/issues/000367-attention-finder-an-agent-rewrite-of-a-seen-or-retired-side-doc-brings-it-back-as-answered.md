---
id: 000367
status: codecomplete
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: '2399ed8d1e9b4c24a17f2a23cee09c277bcda846' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T19:46:30-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: full, provenance: inferred}
actual_hours: 0.27
---

# Attention finder: an agent rewrite of a seen or retired side doc brings it back as answered

## Problem

#354's attention finder lists side docs the agent wrote as "answered, not yet seen" until the operator looks. Once seen, or once swept and retired, a side doc stays gone even when the agent writes to it again. Operator decision (TL, on #354): an agent write to a side doc after the operator last saw it brings it back as answered, the same as any other entry the agent answers. The operator's own edits do not. A retired entry stays retired only until the next agent write.

## Spec

- Tell an agent write apart from the operator's own save. For example, record the mtime of each save the operator makes in this editor (BufWritePost) and count only a newer mtime that this editor did not write. Finding the agent's write signal is part of the design.
- A seen side doc whose agent-write time is later than its `seen_at` goes back to answered. This is a pure model event in `attention_model`, alongside `viewed`.
- A retired side doc with a newer agent write is rediscovered, and leaves `retired`.
- `attention.discover` today skips existing entries and retired paths. It, or a sibling, would emit the new event.

## Done when

- Model specs: an agent rewrite after seen makes the entry answered; an operator save does not; a rewrite before seen changes nothing; a retired doc with a newer agent write comes back.
- An integration spec through `attention.open` covers one rewrite.
- atlas/ui/attention_finder.md describes the rule.

## Plan

**The agent-write signal (what was measured).** Couch's ledger can't tell the two writers apart for side docs. `LastWrite` is set only by `couch --session-sync write`. The review skill (`xx-universal-review`, adapters/file-edit.md) creates a new side doc directly on disk, and rewrites one directly too unless the side doc is registered with Couch; side docs usually aren't. Session-sync's FileChangedShell sees only open `type: session-sync` buffers. So the seam is the writer we do own: the operator edits in Neovim, and every save Neovim makes fires BufWritePost. **An agent write is a disk mtime that this editor did not write.**

- The store keeps a `saved` map `{[path] = "sec.nsec"}`: the mtime of the operator's last save of a side doc. A BufWritePost in the existing `ParleyAttentionViews` augroup records it for any `*.md` directly inside a `*.side/` folder, and for any path that is an entry or retired. It is recorded through the one `apply`, as the pure event `saved{path, mtime}`. The map is pruned on every write to paths that are entries, retired, or under an entry's `.side/` folder, and capped at LIMIT; this follows the ARCH-FUNERAL rule.
- Why not a lock or lease, which the invariant rule asks about: the agent writes untracked side docs with no lease, and requiring one is a change to the review skill and Couch in another repo. This one-step check needs only the editor.

**The rule (pure, in `attention_model`).** A new `M.scan(state, files)` takes the stat of each `.side/` file the glue found, `{path, parent, mtime_sec, mtime_id}`, and returns the events. A file is agent-written when `mtime_id ~= state.saved[path]`.
- **New** (neither an entry nor retired): agent-written and `mtime_sec > since`, which is the current rule. The result is `discovered`. The current rule also lists a side doc the operator creates and saves themselves as answered; this check removes that gap too.
- **Retired:** agent-written and `mtime_sec > retired_at`. The result is `discovered`, and `handlers.discovered` now un-retires the path instead of ignoring it. It becomes an answered entry again, with `answered_at = mtime_sec`.
- **Seen side entry:** agent-written and `mtime_sec > seen_at`. The result is `rewritten{path, at = mtime_sec}`, which sets `answered_at = at`, so `state_of` reads answered again. A rewrite of a waiting or answered entry, or one at or before `seen_at`, changes nothing.
- `attention.discover` keeps only the IO: scan, stat and the frontmatter head read. It hands the files to `Model.scan`.

**Boundaries, as stated in the atlas.**
- An edit made outside this editor, or in an editor without parley, counts as an agent write.
- mtimes are compared at whole seconds against `seen_at`, so an agent write in the same second as the operator's view is missed, as with the current `discovered` rule.
- Only the `.side/` folders of current entries are scanned. A side doc whose parent entry has also left comes back on the parent's next submit.

**Steps** (quick flow, single pass):
- [x] Model: the `saved` and `rewritten` events, `discovered` un-retiring, and `scan`, with unit specs for the Done-when cases. Those are: rewrite after seen gives answered; operator save gives nothing; rewrite at or before seen gives nothing; retired with a newer agent write comes back; retired with an operator save stays retired; an operator-created side doc is not listed.
- [x] Store: parse and type `saved` with one warning per read, and prune it.
- [x] Glue: BufWritePost records `saved`, and `discover` goes through `Model.scan`.
- [x] Integration spec through `attention.open`:
  - the agent rewrites a seen side doc and it is listed as answered;
  - the operator `:w`s it and it is not;
  - a retired one comes back.
- [x] Atlas: update `attention_finder.md`'s side-docs section and traceability.

## Log

### 2026-10-16
- 2026-10-16: closed — Attention specs green: model 40, store 17, rows 6, record 12, finder 26, plus 38; lint clean. Model specs cover: an agent rewrite after seen is answered; the operator save is not (same second, different nsec, is the agent); writes at or before seen, or to waiting or answered entries, change nothing; a retired doc comes back on a later agent write, not an operator save; an operator-created side doc is not listed; saved is pruned and capped. A store spec with two module instances shows one editor save read as the operators in another (TL check). An integration spec through attention.open covers a real :w (seen stays), an agent rewrite (answered), retire, then rewrite (answered, un-retired). Mutations: not recording saves, ignoring saved, and never un-retiring each fail their specs. Folded-in fix of the #354 repaint spec flake (the qzx query matched via the temp dir; root cause shown with _fuzzy_score), six clean runs after. The full suite runs as sdlc-local/suite on 108f5a7f.; review verdict: SHIP
- 2026-10-16: flow upgraded quick → full — 135 added lines in code files (limit 100)
- 2026-10-16: TL approved the plan. TL check: the operator runs more than one parley Neovim. `saved` lives in the shared store file, so one editor's save reads as the operator's in another; a store spec covers this with two module instances.
- 2026-10-16: `discover` first read every side doc's head on each open. Now `Model.scan` picks candidates from stat data, and only those have their frontmatter read, the pre-#367 bound.
- 2026-10-16: folded-in flake fix (#354's spec, on main). "keeps the typed filter and the selected row across a live repaint" failed about one run in nine: "typeahead did not filter to the two qzx rows". Printing on timeout showed the prompt "> qzx" with all three rows. A query of three characters or fewer matches the whole search text, which includes the random temp directory, so `beta.md` matched. The spec now uses `q+` (no temp path holds `+`). Shown deterministically: `_fuzzy_score("qzx", "beta.md /tmp/nvim.u/aqbzcx/0")` = 21, `"q+"` = nil. Six clean runs after the fix.
- 2026-10-16: mutation checks. Not recording saves fails the integration spec. Ignoring `saved` in scan fails 3 model specs and the integration spec. Never un-retiring fails 2 model specs and the integration spec.
