# Issue Management

Repo-local issue tracking with single-file-per-issue markdown format, designed for agentic coding workflows.

## File Format
Each issue is `{issues_dir}/NNNNNN-slug.md` with YAML frontmatter (`id`, `status`, `deps`, `github_issue`, `created`, `updated`) and markdown sections (title, done-when, plan checklist, log).

IDs are sequential integers (e.g., `000066`, `000067`). Sub-ticket IDs must NOT use letter suffixes (e.g., `000065a` is wrong). Always allocate the next available integer ID.

Status values, categories, and lifecycle transitions are loaded at runtime from
`construct/generated/vocabulary/issue.json`, which is generated from ariadne's
`construct/vocabulary/issue.cue`. Parley uses that model for status completion,
picker active filtering, status sorting, and status cycling — and (M2 #116) for
the issue **home**: `config.issues_dir` is seeded at setup from the cue
`discovery.home` (precedence: explicit user override > cue home > built-in
default), so every reader derives from the one cue source.

## Commands
- `:ParleyIssueNew` (`<C-y>c`): **delegates to `sdlc issue new`** (M3 #116) — the canonical creator (id allocation + the cue/sdlc-owned template + broadcast to origin/main per ariadne#82) — then opens the created file. The title prompt is prefixed with the destination repo — `[<repo>] Issue title: ` — where `<repo>` is the basename of the git root `issues_dir` resolves against (the editor's cwd root), so issues aren't created in the wrong repo (#142)
- `:ParleyIssueFinder` (`<C-y>f`): float picker with status badges and 2-state view cycling — `<Tab>` (natural key; `<C-a>` kept for back-compat) toggles between `issues` (all of `workshop/issues/`, done items visible — the default, sorted by the existing status/ID order) and `history` (archived items in `workshop/history/`, sorted by file modification time ascending so the newest archive row sits closest to the bottom-anchored prompt) (#158, superseding the tri-state all/active/all+history from #152). The complete prompt query is kept verbatim across that repaint and later Issue Finder invocations; clearing the prompt persists the empty query (#177). In super-repo mode, a completely labelled root set with at least two distinct repositories adds Chat Finder's existing `[ALL] [NONE]   [repo…]` facet bar. Repo choices share one persistent state across both views and invocations, and facet updates repaint in place without touching the query; newly discovered repos default on while temporarily absent choices are retained. Incomplete labels, a single unique repo, and ordinary single-root mode omit the bar and leave rows unfiltered. Persisted NONE still opens the empty picker so ALL remains reachable (#186).

Facet discovery, persistent-state merging, immutable transitions, OR filtering,
picker-tag projection, and complete-labelled-root eligibility live in the pure
`lua/parley/finder_facets.lua` model. Chat, Issue, and Markdown Finders supply
their item-specific facet keys and own their session/UI adapters; Issue and
Markdown also use the shared eligibility policy for contextual repository bars.
Markdown's directory-versus-repository choice remains a picker concern rather
than broadening issue-management policy (`ARCH-DRY`, `ARCH-PURE`).
- `:ParleyIssueNext` (`<C-y>x`): open next runnable issue (oldest open with all deps done)
- `:ParleyIssueStatus` (`<C-y>s`): cycle frontmatter status using the first lifecycle transition for the current status in generated vocabulary order
- `:ParleyIssueDecompose` (`<C-y>i`): create child issue from plan line, add to parent deps, and write a markdown link `[issue NNNNNN](./NNNNNN-slug.md)` into the parent's plan line; the new child file gets a `Parent: [issue PPPPPP](./PPPPPP-...md)` backlink under its title. (M3 #116: decompose **retains** parley's `render_issue_template` — its semantics, parent.deps += child + the parent plan-line link + the backlink, are incompatible with `sdlc issue new`'s shape, so unlike `:ParleyIssueNew` it is not delegated.)
- `:ParleyIssueGoto` (`<C-y>g`): follow a markdown link `[...](./NNNNNN-*.md)` under the cursor to the linked issue; if there is no link under the cursor, jump to the current issue's parent (derived from `deps`). Use `<C-o>` to return.

## Parent/Child Links
- `deps` is the canonical machine-readable representation of parent→child (an issue's `deps` lists the IDs of its children).
- Cross-issue references inserted by parley use **standard markdown links** (`[issue NNNNNN](./NNNNNN-slug.md)`, path relative to the file containing the link), so they render correctly in any markdown viewer and are followable by `:ParleyIssueGoto`.
- Child→parent navigation is derived from `deps` at scan time, not from the body backlink, so issues decomposed before this feature was added still navigate correctly.

## Archival
Done issues moved to `workshop/history/` by `make push` or `make merge`. GitHub issues auto-closed. History is low-signal — agents should avoid reading it unless directed.

## Makefile Integration
- `make fetch N` / `make issue N`: create local issue from GitHub issue
- `make push` / `make merge`: archive done issues, close GitHub issues
- `make pull-request`: gathers issue references for PR body
