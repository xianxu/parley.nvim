# Boundary Review — parley.nvim#309 (whole-issue close)

| field | value |
|-------|-------|
| issue | 309 — Show tracker-only cards in issue finder and viewer |
| repo | parley.nvim |
| issue file | workshop/issues/000309-tracker-only-issue-views.md |
| boundary | whole-issue close |
| milestone | — |
| window | c1b2173ea7fbb3e3d6a5b851d500be082b2bd09d..cb7c928409fb9488ffe4c2963fa9c19896f1ade4 |
| command | sdlc close --issue 309 |
| reviewer | claude |
| timestamp | 2026-09-30T22:47:59-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: medium
```

The branch delivers what #309 asks for. Tracker cards with no local details now appear in the finder with the amber `card only · read only` label and normal search, filter and sort. Opening one gives a read-only, nonmodifiable scratch buffer. That buffer shows the source ref, the tip, a freshness line that cannot claim freshness after a failed fetch, and the card body including its Problem. Delete, status-cycle, `:ParleyIssueStatus` and `:ParleyIssueDecompose` all refuse these entries. A checkout that has never fetched the tracker resolves a remote and fetches it first, and a refresh that arrives during a fetch now waits for that fetch to finish. I ran `make test-spec SPEC=issues/issue-management` and every spec file passed with 0 failures and 0 errors. One cheap fix is left. The finder finds which issues have local details using its own directory-resolution rule instead of the one it already uses for scanning. Any difference between the two rules would make every card look card-only and duplicate every local issue.

**1. Strengths**
- `lua/parley/issue_cards.lua:233-322`: the card-only records, freshness text and view text are pure functions, unit-tested without IO. The finder and the view are thin callers around them (ARCH-PURE).
- The fetch outcome (`fetch_ok_at` / `fetch_failed_at` / `fetch_error`) is kept apart from the throttle stamp. `freshness()` never reports cached content as freshly fetched. Specs cover failure, recovery and "never fetched".
- `issue_tracker.refresh` handles a refresh that arrives during a fetch: it settles only after that fetch's read lands. Tests cover a second caller arriving mid-fetch and the throttle case.
- Cards are matched to local details in both the issues and history dirs, so an archived issue is never card-only. Card-only records carry a finder identity, so the existing materialize, filter and sort run on them unchanged (ARCH-DRY).
- The view writes through `buffer_edit.replace_all` instead of widening the arch allow-list. It clears `readonly` only during the render, which fixes the W10 warning, and the buffer wipes when hidden so its subscription ends with it (ARCH-FUNERAL).

**2. Critical findings**
None.

**3. Important findings**
- **`lua/parley/issue_finder.lua:347-375` (ARCH-DRY):** `configured_dir` / `local_ids` re-resolve `issues_dir` and `history_dir` as "git root + relative value". Scanning already resolves those dirs in `discovery_roots` / `absolute_configured_dir`, which go through `super_repo.expand_roots` or `get_issues_dir`/`get_history_dir` → `project_root()`, and also expand `~`.
  - **Failure:** if the two rules disagree (a `~/…` config, or a `project_root()` that differs from the git root), `local_ids` scans a missing directory. Every card then becomes card-only and every local issue appears twice, which breaks the "one row per repository/ID" Done-when.
  - **Fix:** build the per-git-root details dirs from `discovery_roots(0)` and `discovery_roots(1)`, mapping each `root.path` through `issue_tracker.repo_root`. Add a spec where `issues_dir` resolves through the fallback path.

**4. Minor findings**
- `issue_tracker.status()` returns nil until a remote is known or a fetch has failed. During a first fetch the view therefore shows neither the ref nor "refreshing…". This is mostly unreachable, because card-only rows need cards that were already loaded.
- `view_lines(nil, …)` prints "Card #id is no longer on <ref>" whenever a load returns nil. That also happens when the remote ref disappears, or the repository stops being tracked, which is a different claim.
- ARCH-ORDER: the fetch state is a set of separate flags (`fetching`, `fetched_at`, `fetch_ok_at`, `fetch_failed_at`, `fetch_error`, `joiners`, `loading`). Success clears the failure fields, so the `>=` timestamp comparison in `freshness()` is redundant. A tagged outcome (`never | ok(at) | failed(at, err)`) would make the legal states readable from the code.
- `refresh`: a caller that joins during a fetch gets a follow-up refresh that is throttled, so a change published after the fetch began is not fetched until the next interval. This is documented in a comment and acceptable.

**5. Test coverage notes**
The Done-when list is covered:
- card-only discovery, including details that exist only on another branch (the `tracker_repo` helper's worktree push)
- sorting, the repo facet, archived matching and the untracked no-op
- opening a row, the refusals in both the finder and the buffer commands
- fetch success and failure, first-fetch bootstrap, the explicit-refspec single-branch clone
- a refresh joining a fetch in flight, the throttle

Missing: a spec for the directory-resolution mismatch in the Important finding.

**6. Architectural notes**

| Principle | Result | Note |
|---|---|---|
| ARCH-DRY | **flag** | Directory resolution (above); otherwise reuses #308's reader, subscription and overlay. |
| ARCH-PURE | pass | |
| ARCH-PURPOSE | pass | Every Done-when item is delivered and checked. |
| ARCH-MOCK | pass | Tests use real local git remotes behind the same `git()` seam; a failing remote is modeled with `missing.git`. |
| ARCH-CONSTRAINTS | pass | Two synchronous directory scans per delivery on a UI path is acceptable for issue-dir sizes. Fetch is throttled and has a timeout. |
| ARCH-SECURE | pass | Card ids are validated as digits. Git runs from argv arrays, never a shell. Remote content is shown only in a nonmodifiable buffer. |
| ARCH-ORDER | pass, with the Minor note | Waiting-for-fetch behavior is tested across event sequences. |
| ARCH-FUNERAL | pass | The blob cache now also holds card bodies but is still bounded by card count; buffers wipe when hidden; subscribers are dropped once their view closes. |

**7. Plan revision recommendations**
None needed if the Important finding is fixed in code. If it is accepted as is instead, add a `## Revisions` entry recording that `local_ids` assumes relative config under the git root.

```findings
findings:
  - id: new
    severity: Important
    family: parallel-path-resolution
    title: |
      issue_finder local_ids re-resolves issues/history dirs instead of reusing discovery_roots
    detail: |
      configured_dir joins git root and the config value, while the scan resolves dirs via expand_roots or get_issues_dir/get_history_dir (project_root, ~ expansion). If the two disagree, every card becomes card-only and duplicates local rows. Derive the per-root dirs from discovery_roots(0)/(1) and add a spec.
  - id: new
    severity: Minor
    family: freshness-reporting
    title: |
      issue_tracker.status returns nil during a first-fetch bootstrap, hiding ref and refreshing state
  - id: new
    severity: Minor
    family: freshness-reporting
    title: |
      view_lines says the card is no longer on the ref whenever a load returns nil, including a lost remote ref or untracked repo
  - id: new
    severity: Minor
    family: flag-constellation-state
    title: |
      fetch state is a set of independent flags; a tagged outcome would make legal states explicit
```

---

## Re-review — 2026-09-30T23:00:28-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 309 — Show tracker-only cards in issue finder and viewer |
| repo | parley.nvim |
| issue file | workshop/issues/000309-tracker-only-issue-views.md |
| boundary | whole-issue close |
| milestone | — |
| window | c1b2173ea7fbb3e3d6a5b851d500be082b2bd09d..18a6643866522d4bbe8c8464ced4f3c0343d3634 |
| command | sdlc close --issue 309 |
| reviewer | claude |
| timestamp | 2026-09-30T23:00:28-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The issue is delivered. Card-only rows show up in the finder with a text-plus-amber `card only · read only` label. Selecting one opens a nonmodifiable `parley-card://` scratch view with the source ref, tip and a freshness line, and nothing is made up. Delete, status-cycle, `:ParleyIssueStatus` and `:ParleyIssueDecompose` all refuse. Fetching now works in a checkout that has no tracker ref yet, uses an explicit refspec, and records success and failure separately. The round-1 fix for BR-1 is correct: `discovery_roots()` now resolves both views once, and the card join uses exactly the dirs the scan used. All 14 spec files mapped to `issues/issue-management` pass at HEAD (issue_card_view 6, issue_finder_tracker 12, issue_tracker 18, issue_cards 24, and the rest). The only remaining item is Minor.

1. **Strengths**
   - `lua/parley/issue_finder.lua:173-209`: a single `discovery_roots()` expansion feeds both the scan (`by_mode[view_mode]`) and the join (`roots_by_mode[0/1]`). This removes the parallel resolution class from BR-1, not just the one call site.
   - `issue_tracker.refresh` joiners (`issue_tracker.lua` settle/joiners): a refresh that arrives while a fetch is running settles only after that fetch lands, then gets a throttled follow-up. Two specs pin this: "settles … only when that fetch settles" and "does not refetch for a joiner inside the throttle interval".
   - `issue_cards.freshness`: a failure after the last success always reports `cached · last fetch failed`, so cached content never reads as fresh. This is a unit-tested pure function.
   - Card-only records carry a proper `identity`, so the finder's existing dedupe/filter/sort and the `archived` view filter (`issue_finder.lua:42-49`) work on them unchanged.
   - The card view renders through a new `buffer_edit.replace_all` instead of widening the arch allow list, and it drops the readonly flag only during rendering to avoid W10. A spec pins that.

2. **Critical findings:** none.

3. **Important findings:** none.

4. **Minor findings**
   - `issue_finder.lua` `local_ids`: it parses the issue id from filenames with its own pattern `^(%d+)%-.*%.md$`. The scan's parser at `issue_finder_records.lua:47` uses `^(%d+)%-(.+)%.md$`. The two disagree on `000123-.md`: the join counts it as local, but the scan skips it, so that issue gets no row at all (ARCH-DRY, family `parallel-path-resolution`).
   - `issue_cards.lua` `epoch()` is yet another date-to-epoch helper (`note_finder_records`, `chat_finder_records` each have one). Low cost.

5. **Test coverage**
   - The done-when items are covered: card-only discovery, open, refusals (finder and buffer commands), fetch success/failure, first-fetch bootstrap (tracker and finder level), dedup against active and history details, the repo facet, and untracked repos.
   - BR-1 has a regression spec ("joins against the dirs the finder scans…"). It moves history to a dir the config value does not name. Under the old `configured_dir` code that would produce a second, card-only 000009 row, so the spec discriminates.
   - BR-2 is pinned by "reports a first-fetch bootstrap while it runs", and BR-3 by the `view_lines` "no tracker could be read" unit test.

6. **Architecture**
   - **ARCH-DRY:** passes, except the Minor filename-parser restatement above.
   - **ARCH-PURE:** passes. The card model, records, freshness and view text are pure in `issue_cards`. The view and finder are thin glue, and `is_terminal` is injected.
   - **ARCH-PURPOSE:** passes. Every done-when item is delivered, and the finder and card view both derive from one `card_ref`.
   - **ARCH-MOCK:** passes. It reuses #308's real-git fixture repos behind the same `git()` seam; failure is simulated with a dead remote URL.
   - **ARCH-CONSTRAINTS:** passes. `local_ids` lists directories synchronously, but only when the scan settles or the tip moves (bounded). Fetches stay throttled and timed out, and the bootstrap path is throttled too.
   - **ARCH-SECURE:** passes. Card text comes from the remote branch and is shown read-only, split on newlines. The first line of git stderr appears in a local buffer only.
   - **ARCH-ORDER:** passes, with BR-4 withdrawn. The joiner and in-flight ordering is explicit and tested, and `freshness()` fixes the precedence between flags.
   - **ARCH-FUNERAL:** passes. The scratch buffer is `bufhidden=wipe`, its subscription drops via `alive`, joiners are cleared on settle, and the fetched ref is git-managed and superseded by later fetches.

7. **Plan revisions:** none. The Core concepts table matches the code.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      discovery_roots() now returns both modes from one expansion; the join uses roots_by_mode; regression spec relocates history via super_repo and asserts one non-card-only 000009 row.
  - id: BR-2
    disposition: addressed
    note: |
      status() returns a table with ref=nil and fetching=true during bootstrap; pinned by "reports a first-fetch bootstrap while it runs".
  - id: BR-3
    disposition: addressed
    note: |
      view_lines takes `readable` and says no tracker cards are readable; unit spec covers both branches.
  - id: BR-4
    disposition: withdrawn
    note: |
      freshness() fixes the flags' precedence and is unit-tested; reshaping #308's tracker state into a tagged outcome is a separate refactor.
findings:
  - id: new
    severity: Minor
    family: parallel-path-resolution
    title: |
      local_ids re-parses issue ids from filenames instead of reusing the scan's parser
    detail: |
      2nd in family. Rule: the card join derives every fact (dirs AND filename-to-id) from the scan's own resolution. issue_finder.lua local_ids uses ^(%d+)%-.*%.md$ while issue_finder_records.lua:47 uses ^(%d+)%-(.+)%.md$, so a name like 000123-.md is "local" to the join but has no scan row and vanishes. Expose the records parser and call it from local_ids. One remaining instance.
```

---

## Re-review — 2026-09-30T23:03:14-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 309 — Show tracker-only cards in issue finder and viewer |
| repo | parley.nvim |
| issue file | workshop/issues/000309-tracker-only-issue-views.md |
| boundary | whole-issue close |
| milestone | — |
| window | c1b2173ea7fbb3e3d6a5b851d500be082b2bd09d..051770cc4335f0baefbcb416111086a55448fd5a |
| command | sdlc close --issue 309 |
| reviewer | claude |
| timestamp | 2026-09-30T23:03:14-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

BR-5 is fixed. `issue_finder_records.parse_name` (`lua/parley/issue_finder_records.lua:44`) is now the only filename-to-id parser. `adapt` and the card join's `local_ids` (`lua/parley/issue_finder.lua:365`) both call it, so the join counts exactly the files the scan turns into rows. This closes the last instance of the `parallel-path-resolution` family. BR-1 already made the join reuse the dirs the scan resolves, and the id is the only other fact `local_ids` derives.

The new spec writes `000005-.md` next to a card-only `000005`. The old pattern `^(%d+)%-.*%.md$` matches an empty slug, so it would mark `000005` as local and hide the card. The spec waits for the card row, so it would time out on the old code. I did not run that revert, because the review is read-only; this follows from the pattern itself.

I ran `make test-spec SPEC=issues/issue-management` and it passed: 0 failures across 14 spec files, including `issue_finder_tracker` 13/13, `issue_card_view` 6/6, `issue_tracker` 18/18, `issue_cards` 24/24 and `issue_finder_records` 13/13. Nothing new blocks shipping.

1. **Strengths**
   - There is one parser for filename → id/slug, and a comment states why it exists (`issue_finder_records.lua:42-46`).
   - `details_dirs` is built from `roots_by_mode`, the same resolution the scan uses, so the join cannot look in a different directory (`issue_finder.lua:420-430`).
   - The regression spec targets the exact divergence (an empty slug) rather than a generic case.
   - `freshness` / `view_lines` (`issue_cards.lua`) are pure and unit-tested. The view module is a thin IO shell around them.

2. **Critical:** none.

3. **Important:** none.

4. **Minor:** none new. There is a residual edge in the same rule: a details file whose frontmatter fails to parse becomes a scan failure but still counts as "local", so its card is hidden. A parse failure is shown to the user anyway, so this is not worth a finding.

5. **Test coverage**
   - BR-5 has a behavioural regression spec that would fail without the fix.
   - Earlier rounds' fixes (BR-1/2/3) keep their specs, and they are green in this run.

6. **Architecture**
   - ARCH-DRY: pass. The duplicated parser is gone.
   - ARCH-PURE: pass. Card model and view text are pure; finder and view are the shell.
   - ARCH-PURPOSE: pass. Done-when items are delivered and tested.
   - ARCH-MOCK: pass. Tracker repo fixtures use real local git remotes.
   - ARCH-CONSTRAINTS: pass. There is one directory listing per dir per delivery, and the finder caches repo-root lookups.
   - ARCH-SECURE: pass. Card text is shown read-only and never written to disk.
   - ARCH-ORDER: pass. BR-4 was withdrawn, and joined refresh plus fetch settling are covered by specs.
   - ARCH-FUNERAL: pass. The view buffer has `bufhidden=wipe`, and its subscription is dropped when the buffer dies (`alive`).

7. **Plan revisions:** add one line under Revisions for round 2: "BR-5: `local_ids` uses `issue_finder_records.parse_name`; regression spec with an empty-slug file."

```findings
dispose:
  - id: BR-5
    disposition: addressed
    note: |
      local_ids now calls issue_records.parse_name (issue_finder.lua:365), the same parser adapt uses; spec "counts only the files the scan turns into rows" pins the empty-slug case, which the old .* pattern would have counted as local.
```

---

## Re-review — 2026-10-01T08:58:49-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 309 — Show tracker-only cards in issue finder and viewer |
| repo | parley.nvim |
| issue file | workshop/issues/000309-tracker-only-issue-views.md |
| boundary | whole-issue close |
| milestone | — |
| window | c1b2173ea7fbb3e3d6a5b851d500be082b2bd09d..408843e3b4773a0d666f1caab9cf8e434f54eb49 |
| command | sdlc close --issue 309 |
| reviewer | claude |
| timestamp | 2026-10-01T08:58:49-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

**VERDICT: SHIP**

The three earlier rounds closed every finding, BR-1 through BR-5. The only code change since the last close is 408843e3. It came from the operator's smoke test and changes how card-only rows render: the `card only · read only` text is gone, the whole row is amber, and a 🔒 sits right after the id. The issue records this as a Revision and restates its Done-when to match. The code fits the picker's contract. `float_picker.lua:57-58` says highlight spans are 0-based, end-exclusive byte offsets. `render` sets `{0, #display}`, which counts the 4-byte 🔒 in bytes, and the painter clamps to `#line`. The lock still gives a cue that doesn't depend on colour, which the Spec requires (`Amber and a textual provenance label … without relying on color alone`). That requirement is now met by a glyph, and the Revision says so. Nothing blocks the ship. Two Minor items remain: the durable plan was not revised for this change, and you can no longer search for card-only rows.

1. **Strengths**
   - `issue_finder_records.lua:159-162`: one span covering the whole row for card-only issues. Stale details files keep their separate per-field spans, so the two cases look clearly different.
   - The new unit test `issue_finder_records_spec.lua` "keeps per-field amber and no lock for a stale details file" checks the contrast from the other side too: no 🔒, and the span covers exactly `[wontfix]`. The card-only test adds `tracker_stale = { status = true }`, which shows the whole-row span takes precedence over per-field spans.
   - The integration test checks both `000005🔒 Remote only` and the exact highlight list, so a byte-offset regression would fail it.
   - The atlas entry `atlas/issues/issue-management.md` was updated in the same commit.
   - At HEAD, `make test-spec SPEC=issues/issue-management` passes every mapped spec, 0 failures: issue_finder_records 14, issue_finder_tracker 13, issue_cards 24, issue_card_view 6, issue_tracker 18, issue_finder 31, float_picker 82, and the rest.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - `workshop/plans/000309-tracker-only-issue-views-plan.md:74-76, 230-236, 396-402` still says rows show `card only · read only` and that `search_text` includes `card only`. The plan has no `## Revisions` section for the smoke-test change.
   - `issue_finder_records.lua:165`: `search_text` no longer has any card-only token. Before, typing `card only` filtered to these rows; now nothing does, and 🔒 isn't searchable either.

5. **Test coverage notes:** The kind of bug this change could ship is a wrong byte span with a multibyte glyph, or losing per-field amber on stale details files. Unit and integration tests cover both. Nothing tests the search-affordance change, because it was removed on purpose.

6. **Architecture**
   - **ARCH-DRY: pass.** `render` still builds the row through one `append` path. The card-only override is a single assignment.
   - **ARCH-PURE: pass.** `render` stays pure and has direct unit tests.
   - **ARCH-PURPOSE: pass.** The Done-when as restated is delivered. The 🔒 still meets the Spec's "not colour alone" rule.
   - **ARCH-MOCK: pass.** The delta adds no new external calls. The tracker fixtures from earlier rounds are unchanged.
   - **ARCH-CONSTRAINTS: pass.** One string concat per row, no change on the hot path.
   - **ARCH-SECURE: pass.** No untrusted input or secrets are added. The display contains card text, as it did before.
   - **ARCH-ORDER: pass.** The delta holds no state between events because `render` is a pure function of one issue record.
   - **ARCH-FUNERAL: pass.** The delta creates nothing durable, because it only changes how an in-memory display string is built.

7. **Plan revision recommendations**
   - Add a `## Revisions` entry to the durable plan, dated 2026-10-01, with the reason "operator smoke test". Delta: the T2 render produces `<id>🔒` with one full-row `ParleyIssueTracker` span and no text label, and `search_text` no longer includes `card only`. The card view's label line (`issue_cards.lua:305`) is unchanged.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Disposed in an earlier round; no regression in the latest delta.
findings:
  - id: new
    severity: Minor
    family: plan-revision-lag
    title: |
      Durable plan still specifies the card-only text label and search token removed by 408843e3
    detail: |
      Plan lines 74-76, 230-236 and 396-402 describe the card-only text label and the search token. The issue's Revisions records the change, but the plan has no Revisions entry.
  - id: new
    severity: Minor
    family: search-affordance-regression
    title: |
      Card-only rows no longer carry a searchable provenance token in search_text
    detail: |
      issue_finder_records.lua:165 dropped the card-only search token and did not add the lock. Users can no longer narrow the finder to card-only issues by typing; adding a token such as 'card-only' back to search_text would restore it.
```
