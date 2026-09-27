---
id: '000181'
status: done
started: 2026-07-10T08:38:14-07:00
created: 2026-07-10
updated: 2026-07-11
estimate_hours: 3.58
actual_hours: N/A
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
