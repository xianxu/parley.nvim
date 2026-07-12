---
id: 000181
status: working
deps: []
github_issue:
created: 2026-07-10
updated: 2026-07-10
estimate_hours: 3.58
started: 2026-07-10T08:38:14-07:00
---

# repo-root read-wide completion for all markdown

## Problem

The #147 reference-neighborhood rule derives a **single** root per artifact and
uses it for *both* relative tool-path resolution and file-path completion. The
root is `repo_root` only for repo-backed Parley artifacts (files under
`repo_artifacts.dir_keys` → `workshop/parley|notes|issues|vision|history`);
every other file — including ordinary content under `data/`, `atlas/`,
`docs/`, or a data-file at repo top-level — falls through to `dirname(path)`,
its own folder.

Two consequences bite in a `.parley` repo:

1. **No repo-root escape hatch.** Editing `data/career/2026/xnurta-plan.md`, a
   reference/path resolves relative to `data/career/2026/` (`./`), and there is
   no way to reach a repo-root-relative path — even though the file is squarely
   inside the repo and repo-root-relative is how one naturally thinks
   (`data/career/2026/foo.md`, `atlas/index.md`).
2. **Completion is chat-only anyway.** `neighborhood.attach_completion` is
   called *only* from `prep_chat` (init.lua:1947). Non-chat markdown goes
   through `prep_md`, which never attaches it — so plain data/content markdown
   gets no neighborhood-aware completion at all (falls back to vim/cmp default,
   which isn't repo-anchored).

Design context + the option we picked (option 1, read-wide/write-narrow) is in
the parley chat `workshop/parley/` for 2026-07-10; option 2 (`.parley-neighborhood`
intermediate-scope marker) was considered and **deferred** — see Log.

## Spec

Adopt a **read-wide / write-narrow** split of the neighborhood root, and extend
completion to all markdown buffers in repo mode.

- **Write / primary root — unchanged.** `write_file` / `edit_file` and the
  dispatcher's `resolve_path_in_cwd` write-side enforcement keep using the
  current per-artifact neighborhood (`derive_for_path`). Writes stay confined —
  this is the rogue-agent boundary (`brain/atlas/threat-model-shared-brain.md`);
  do NOT widen it. Repo-root is NOT added to the write root.

- **Read + completion roots — widened to an ordered set.** When repo mode is active
  (`config.repo_root` set), fold `repo_root` into the set of roots used for (a)
  read-tool path resolution and (b) file-path completion candidates, *in
  addition to* the per-artifact neighborhood and the existing `tool_read_roots`.
  Repo-root-relative paths become resolvable and completable from any file in
  the repo. This mirrors the existing `tool_read_roots = {'../'}` mechanism —
  it's the same "reads may reach beyond the write root" philosophy, just always
  including `repo_root` in repo mode.

  The ordered read roots are: **artifact neighborhood first, then repo root,
  then configured `tool_read_roots`**, canonicalized and de-duplicated. For a
  relative read path, resolve against each root in that order and select the
  first existing candidate; this makes a collision deterministic (the local
  neighborhood wins). `.` and other default paths therefore keep their current
  local meaning. An absolute path is accepted only when its real path is within
  one of the ordered roots. A relative path with no existing candidate is an
  error for read tools; writes retain today's missing-leaf behavior against the
  single write root. Every accepted candidate and every containing root is
  symlink-canonicalized before the containment check, preserving the escape
  guard.

  This lookup applies uniformly in the dispatcher to every read-kind tool and
  every supported path shape: `read_file`, `ls`, `find`, `grep`, `ack`, custom
  read tools, `path`, `file_path`, `paths`, and injected `default_path`. Both
  chat `tool_loop` and `skill_invoke` derive and pass the same ordered roots;
  write-kind tools (`write_file`, `edit_file`, `propose_edits`) ignore the wider
  set and remain confined to the artifact neighborhood. Tools without path
  fields, such as `chat_history_search`, are unaffected.

- **Completion attaches to all markdown, not just chats.** Wire the neighborhood
  completion (`attach_completion` and a Parley-owned nvim-cmp source) into
  `prep_md`, so every markdown buffer in a repo-mode repo gets neighborhood +
  repo-root completion candidates. Chat buffers keep today's behavior (they
  already call it via `prep_chat`; avoid double-attach).

  Completion enumerates the same ordered read roots and presents root-relative
  candidates in that order. Duplicate display paths are collapsed first-wins,
  matching dispatcher collision precedence. Both Vim `completefunc` and one
  Parley-owned nvim-cmp source consume the same candidate merger; attachment is
  idempotent so `prep_chat -> prep_md` cannot register duplicate sources or
  autocmds. The existing single-root cmp-path adapter is replaced because
  nvim-cmp keys source options by source name: repeating `path` sources would
  silently reuse the first root's options and could not implement this contract.

- **Self-consistency invariant preserved.** #147's property — "what the model is
  told" == "what the dispatcher enforces" — must still hold *per side*: the read
  side advertises and enforces the same widened set; the write side advertises
  and enforces the same narrow root. A completed/suggested path must never be one
  the enforcing side then rejects.

  The model-facing context is derived from the same root-policy value passed to
  the dispatcher and says, in substance: relative reads search the ordered roots
  (listed in precedence order), while relative writes resolve only from the
  listed write root; the first existing read match wins. The formatter is a
  shared pure helper, not a separately maintained restatement in
  `chat_respond`.

Non-goals:
- No change to write confinement.
- No `.parley-neighborhood` marker (option 2 — deferred; see Log).
- No change outside repo mode (global chats / non-repo cwd keep own-folder
  behavior).

## Done when

- In a `.parley` repo, editing a non-chat markdown file (e.g. under `data/`)
  offers repo-root-relative path completion candidates (e.g. `atlas/index.md`,
  `data/career/2026/…`) alongside neighborhood-relative ones.
- A read-tool call (`read_file`) from such a buffer resolves a repo-root-relative
  path successfully; the same path used in a write-tool call is still rejected
  as outside the write root (write-narrow preserved).
- When the same relative read path exists under both the artifact neighborhood
  and repo root, the neighborhood copy wins; completion shows the relative path
  once.
- Chat buffers retain existing behavior (no regression, no double-attach).
- Outside repo mode, behavior is unchanged: global chats retain their existing
  own-folder completion, while ordinary non-chat Markdown receives no new
  Parley completion/source/autocmd attachment.
- Atlas `infra/repo_mode.md` "Reference neighborhood (#147)" section updated to
  document the read-wide/write-narrow split and the all-markdown completion attach.
- Unit tests cover: ordered read-set includes repo_root in repo mode; relative
  lookup across roots; collision precedence; missing reads; absolute paths and
  symlink escapes; `path`/`file_path`/`paths`/`default_path`; write root excludes
  repo root; completion de-duplicates in resolver order; completion attaches
  once on `prep_md`; chat and `skill_invoke` wiring; model guidance matches the
  shared policy; non-repo-mode unaffected.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.50 impl=0.60
item: lua-neovim design=0.50 impl=0.60
item: skill-or-dispatcher design=0.20 impl=0.20
item: cross-cutting-refactor design=0.20 impl=0.20
item: atlas-docs design=0.04 impl=0.08
item: milestone-review design=0.04 impl=0.20
design-buffer: 0.15
total: 3.58
```

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md`
against `baseline-v3.1.md`. Method A only. The spec and durable plan resolve the
lookup-order decisions, so the ×0.2 spec-quality discount and +15% design buffer
apply; implementation values use v3.1's 40% scaling. Calibration is currently
marked stale by `sdlc estimate-source`, so treat this as provisional evidence for
the next recalibration rather than a timeless constant.

## Plan

- [ ] Read-set: teach `neighborhood` to return the widened read/completion root
      set (per-artifact ∪ `repo_root`-in-repo-mode ∪ `tool_read_roots`), leaving
      `derive_for_path` (the write/primary root) intact.
- [ ] Dispatcher: ordered read-tool lookup consumes the widened read set for
      every supported path shape and read-kind tool;
      write tools keep the narrow root. Update the payload guidance line
      through a shared policy formatter to reflect lookup precedence and the
      read/write split.
- [ ] Completion: attach the policy-backed Parley completion source in
      `prep_md` for repo-mode markdown; preserve the existing `prep_chat`
      attachment for global chats; guard against double-attach.
- [ ] Tests: read-set includes/excludes repo_root correctly; write-narrow
      rejection holds; `prep_md` attaches; non-repo-mode unchanged.
- [ ] Atlas: update `infra/repo_mode.md` #147 section + `providers/tool_use.md`
      cwd-scope note for the read-wide/write-narrow split.

## Log

### 2026-07-10

Created from a brain-side design chat. Decision: **option 1
(read-wide/write-narrow)**, scoped to **all markdown files in repo mode** (not
just repo-backed artifact dirs).

- The self-consistency subtlety that shaped the design: #147 fuses completion +
  tool resolution under one root; a completion-only escape hatch would break that
  (suggest a path the enforcer rejects). Fix is to split the root into a **read
  set** (wide) and a **write root** (narrow) and keep each side self-consistent.
- **Option 2 deferred** (`.parley-neighborhood` marker for an explicit
  intermediate scope between repo-root and file-dir): a different axis — it picks
  a different *single primary* root for a subtree, not a read-set widening.
  Reach for it only if repo-root completion proves too noisy and own-folder too
  narrow for some subtree. YAGNI until a concrete case appears; the two layer
  cleanly and don't conflict.
- Motivating artifact: `brain/data/career/2026/xnurta-plan.md` had
  `Reference: ./` resolving to its own folder with no repo-root path reachable.

## Revisions

### 2026-07-10 — specify ordered multi-root resolution

Reason: fresh-context spec review found that authorizing `repo_root` as an
allowed root would not by itself make a bare repo-relative path resolve there;
the existing dispatcher joins relative inputs only to `cwd`.

Delta: defined neighborhood-first ordered lookup, collision and missing-path
behavior, symlink enforcement, completion ordering/de-duplication, exact path
shapes and dispatcher entry points in scope, and shared model-guidance derivation
(`ARCH-PURPOSE`, `ARCH-PURE`, `ARCH-DRY`).

### 2026-07-10 — reconcile the implementation plan and estimate

Reason: the approved spec is now decomposed into a durable TDD plan, and
`start-plan` requires the estimate to use the current calibrated method before
`change-code`.

Delta: added `workshop/plans/000181-repo-root-read-wide-completion-for-all-markdown-plan.md`
and replaced the provisional v2 estimate with the itemized v3.1 derivation.

### 2026-07-10 — replace cmp-path with one policy-backed cmp source

Reason: plan review verified that nvim-cmp retrieves source configuration by
source name, so multiple `path` entries cannot carry different `get_cwd` roots;
cmp-path also does not enforce the required first-root-wins de-duplication.

Delta: completion still derives entirely from the ordered read roots, but both
Vim and nvim-cmp now consume one shared Parley candidate merger. This preserves
the approved behavior while making the adapter feasible (`ARCH-DRY`,
`ARCH-PURPOSE`).

### 2026-07-11 — repair estimate vocabulary and buffer unit

Reason: `sdlc change-code` correctly rejected two non-canonical primitive slugs;
review also found `design-buffer` had been written as hours rather than the
fraction required by the reconciliation grammar.

Delta: renamed the items to canonical `lua-neovim` / `milestone-review` and set
the planned 15% buffer as `0.15`; the itemized total remains 1.58 hours.

### 2026-07-11 — preserve non-repo markdown and re-estimate visible scope

Reason: the `change-code` plan-quality review found that unconditional
`prep_md` attachment would change ordinary non-repo Markdown, and that the
initial estimate treated the dispatcher/security work and completion adapter as
one small feature despite their separate integration/test surfaces.

Delta: repo-mode `prep_md` attaches completion, global `prep_chat` retains its
existing own-folder attachment, and ordinary non-repo Markdown stays untouched
(`ARCH-PURPOSE`). The estimate now itemizes two Lua/Neovim features plus the
dispatcher and cross-cutting wiring, totaling 3.58 calibrated hours.
