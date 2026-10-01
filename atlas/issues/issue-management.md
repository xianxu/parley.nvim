# Issue Management

Optional repo-local issue tracking for development workflows, separate from
ordinary chats and the app tutorials. Existing issue files can be browsed without
installing the maintainer SDLC tool; `:ParleyIssueNew` requires `sdlc` and reports
setup advice when absent. The app does not install it.

The Ctrl+y shortcuts below are plugin defaults. The app disables that global
shortcut family; use the commands or configure explicit bindings. Finder-local
controls remain enabled. `:ParleyKeyBindings` reports effective configured keys.

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

The generated JSON ships with Parley and resolves from the plugin's own root,
never the launch directory. The loader validates category/lifecycle structure
and limits regular-file reads to 1 MiB. A ready or unavailable result is cached;
explicit `setup()` reloads it so a repaired installation recovers.

Missing or invalid data does not prevent chat startup. Raw issue records remain
readable and sort by ID (archive order still uses mtime), without fabricated
statuses or categories. Creation, decomposition, next-runnable selection, and
status cycling report the unavailable capability before changing files or
buffers. Finder status actions follow the same rule. The optional sdlc runner
supports PATH executables and interactive-shell functions/aliases; command
arguments remain literal, and missing tooling produces setup advice.

## Commands
- `:ParleyIssueNew` (`<C-y>c`): **delegates to `sdlc issue new`** (M3 #116) — the canonical creator (id allocation + the cue/sdlc-owned template + broadcast to origin/main per ariadne#82) — then opens the created file. The title prompt is prefixed with the destination repo — `[<repo>] Issue title: ` — where `<repo>` is the basename of the git root `issues_dir` resolves against (the editor's cwd root), so issues aren't created in the wrong repo (#142)
- `:ParleyIssueFinder` (`<C-y>f`): opens immediately with cancellable `scanning…`, then atomically installs asynchronously parsed issue metadata. `<Tab>` (natural key; `<C-a>` kept for back-compat) toggles between `issues` (all of `workshop/issues/`, done items visible — the default, vocabulary status/ID/path order) and `history` (archived items in `workshop/history/issues/`, mtime/ID/path order so the newest archive row sits closest to the bottom-anchored prompt) (#158, superseding the tri-state all/active/all+history from #152). Full payload reads occur only on canonical path-plus-mtime cache misses; parsing reuses `issues.parse_frontmatter`/`extract_title`. The complete prompt query is kept verbatim across repaint and later invocations; clearing persists the empty query (#177). In super-repo mode, a completely labelled root set with at least two distinct repositories adds `[ALL] [NONE]   [repo…]`; choices persist across views, newly discovered repos default on, temporarily absent choices are retained, and facet updates leave the live query untouched. Incomplete labels, one unique repo, and ordinary mode omit the bar. Persisted NONE still opens the empty picker so ALL remains reachable (#186, #189, #191).

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

## Tracker cards (ariadne#252, #308)
A repository with the cutover marker `workshop/issue-tracker.json` keeps
card-owned fields (status, dates, hours, GitHub link, title) on the
`issue-tracker` branch; a details file only carries a `card_mirror` snapshot.
Parley reads those cards read-only and shows them in two places:

- **Issue Finder:** rows overlay the card values before sorting, so status order
  follows the tracker. A field the mirror has wrong is painted amber
  (`ParleyIssueTracker`, default `#FFBF00`, overridable). Painting uses
  `float_picker` item `highlights` spans.
- **Issue buffers:** a details file in the repository's issue home gets amber
  end-of-line virtual text, `← tracker: <value>`, beside each stale card-owned
  line and the H1. File bytes are never changed.
- **Card-only issues (#309):** a card with no details file in this checkout
  (the details may sit on another branch) still gets a finder row. Cards join
  details by repository and id across the issues *and* history dirs, so an
  archived issue is never card-only. A card-only row is amber end to end and
  carries 🔒 right after its id (the issue lives only on the tracker branch,
  so it cannot be picked up in this checkout). A details file whose fields went
  stale keeps per-field amber and no lock. The row sorts by card status and
  lands in the history view when its status is terminal. Selecting it opens a read-only
  scratch buffer (`parley-card://<root>#<id>`, nomodifiable, wiped when hidden)
  with the provenance label, the source ref and tip, a freshness line, the
  card's top-level fields (not sdlc's `tracker:` envelope) and its body, the
  Problem included. No details file is created and no Spec or Plan is
  invented. The finder's delete and status-cycle keys, `:ParleyIssueStatus` and
  `:ParleyIssueDecompose` refuse these with
  `#<id> is a tracker card without local details (read only)`. Code:
  `lua/parley/issue_card_view.lua`, plus `card_only_records`/`view_lines`/
  `freshness` in `issue_cards.lua`.

Cards come from `refs/remotes/<remote>/issue-tracker`. The remote is the
current branch's upstream remote, else the only one carrying that ref, and every linked
worktree shares it. Reads are async: `ls-tree`, then one `cat-file --batch` for
blobs not yet cached by OID. A throttled background fetch of that branch (at
most once per 60s per repository, 15s timeout, skipped under the test harness
unless a spec opts in) runs with an explicit refspec, so single-branch clones
work. A checkout that never fetched the tracker resolves the remote the same way
and fetches it first (#309). The fetch outcome is kept apart from the throttle
stamp: `issue_tracker.status(root)` reports the ref, tip, last success and last
failure, and the card view says `cached · last fetch failed …` rather than
claiming freshness. Every open finder and issue buffer subscribes per
repository. Any read that finds a new tip (that fetch, another view's read, or
an issue buffer re-reading the local ref on BufEnter after sdlc in another slot
fetched) repaints them all. A failed re-read keeps the last good cards. The card
directory, branch and field list come from the vocabulary's `discovery` and
`card` blocks. Without the marker, the ref or the vocabulary, behaviour is
unchanged. Code: pure `lua/parley/issue_cards.lua`; IO in
`lua/parley/issue_tracker.lua` and `lua/parley/issue_tracker_buffer.lua`.

Known gap: the finder's status-cycle key and `:ParleyIssueStatus` still write
`status:` into the mirror, which sdlc refuses in a tracked repository; they
should go through `sdlc issue set-status`.

## Parent/Child Links
- `deps` is the canonical machine-readable representation of parent→child (an issue's `deps` lists the IDs of its children).
- Cross-issue references inserted by parley use **standard markdown links** (`[issue NNNNNN](./NNNNNN-slug.md)`, path relative to the file containing the link), so they render correctly in any markdown viewer and are followable by `:ParleyIssueGoto`.
- Child→parent navigation is derived from `deps` at scan time, not from the body backlink, so issues decomposed before this feature was added still navigate correctly.

## Archival
Done issues move to `workshop/history/issues/` at the SDLC publish gate. GitHub
issues are closed through the publish flow. History is low-signal — agents
should avoid reading it unless directed.

## Workflow integration and checks

Maintainers create/import internal issues with `sdlc issue new`, then use the
lifecycle gates described in [the optional workflow](../infra/workflow.md).
Do not infer that creating a chat requires an issue or publishes anything.

Implementation: `lua/parley/issues.lua`, `issue_finder.lua`,
`issue_finder_records.lua` and `issue_vocabulary.lua`. Tests:
`tests/unit/issues_spec.lua`, `tests/unit/issue_finder_spec.lua`,
`tests/unit/issue_unavailable_spec.lua` and
`tests/integration/issue_command_spec.lua`.
