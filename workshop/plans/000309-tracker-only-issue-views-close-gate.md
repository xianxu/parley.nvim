---
gate: boundary-review
issue: 309
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-30T22:48:00-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Important
          title: issue_finder local_ids re-resolves issues/history dirs instead of reusing discovery_roots
          detail: configured_dir joins git root and the config value, while the scan resolves dirs via expand_roots or get_issues_dir/get_history_dir (project_root, ~ expansion). If the two disagree, every card becomes card-only and duplicates local rows. Derive the per-root dirs from discovery_roots(0)/(1) and add a spec.
          family: parallel-path-resolution
          round: 1
        - id: BR-2
          severity: Minor
          title: issue_tracker.status returns nil during a first-fetch bootstrap, hiding ref and refreshing state
          family: freshness-reporting
          round: 1
        - id: BR-3
          severity: Minor
          title: view_lines says the card is no longer on the ref whenever a load returns nil, including a lost remote ref or untracked repo
          family: freshness-reporting
          round: 1
        - id: BR-4
          severity: Minor
          title: fetch state is a set of independent flags; a tagged outcome would make legal states explicit
          family: flag-constellation-state
          round: 1
      recipe: milestone-review
      blocked: true
    - "n": 2
      timestamp: "2026-09-30T23:00:29-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: discovery_roots() now returns both modes from one expansion; the join uses roots_by_mode; regression spec relocates history via super_repo and asserts one non-card-only 000009 row.
          round: 2
        - id: BR-2
          disposition: addressed
          note: status() returns a table with ref=nil and fetching=true during bootstrap; pinned by "reports a first-fetch bootstrap while it runs".
          round: 2
        - id: BR-3
          disposition: addressed
          note: view_lines takes `readable` and says no tracker cards are readable; unit spec covers both branches.
          round: 2
        - id: BR-4
          disposition: withdrawn
          note: 'freshness() fixes the flags'' precedence and is unit-tested; reshaping #308''s tracker state into a tagged outcome is a separate refactor.'
          round: 2
      findings:
        - id: BR-5
          severity: Minor
          title: local_ids re-parses issue ids from filenames instead of reusing the scan's parser
          detail: '2nd in family. Rule: the card join derives every fact (dirs AND filename-to-id) from the scan''s own resolution. issue_finder.lua local_ids uses ^(%d+)%-.*%.md$ while issue_finder_records.lua:47 uses ^(%d+)%-(.+)%.md$, so a name like 000123-.md is "local" to the join but has no scan row and vanishes. Expose the records parser and call it from local_ids. One remaining instance.'
          family: parallel-path-resolution
          round: 2
      recipe: milestone-review
      blocked: false
    - "n": 3
      timestamp: "2026-09-30T23:03:14-07:00"
      agent: claude
      dispose:
        - id: BR-5
          disposition: addressed
          note: local_ids now calls issue_records.parse_name (issue_finder.lua:365), the same parser adapt uses; spec "counts only the files the scan turns into rows" pins the empty-slug case, which the old .* pattern would have counted as local.
          round: 3
      recipe: milestone-review
      blocked: false
    - "n": 4
      timestamp: "2026-10-01T08:58:49-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: Disposed in an earlier round; no regression in the latest delta.
          round: 4
      findings:
        - id: BR-6
          severity: Minor
          title: Durable plan still specifies the card-only text label and search token removed by 408843e3
          detail: Plan lines 74-76, 230-236 and 396-402 describe the card-only text label and the search token. The issue's Revisions records the change, but the plan has no Revisions entry.
          family: plan-revision-lag
          round: 4
        - id: BR-7
          severity: Minor
          title: Card-only rows no longer carry a searchable provenance token in search_text
          detail: issue_finder_records.lua:165 dropped the card-only search token and did not add the lock. Users can no longer narrow the finder to card-only issues by typing; adding a token such as 'card-only' back to search_text would restore it.
          family: search-affordance-regression
          round: 4
      recipe: milestone-review
      blocked: false
---

# Gate ledger — parley.nvim#309 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-30T22:48:00-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `parallel-path-resolution` issue_finder local_ids re-resolves issues/history dirs instead of reusing discovery_roots
  configured_dir joins git root and the config value, while the scan resolves dirs via expand_roots or get_issues_dir/get_history_dir (project_root, ~ expansion). If the two disagree, every card becomes card-only and duplicates local rows. Derive the per-root dirs from discovery_roots(0)/(1) and add a spec.
- **BR-2** [Minor] `freshness-reporting` issue_tracker.status returns nil during a first-fetch bootstrap, hiding ref and refreshing state
- **BR-3** [Minor] `freshness-reporting` view_lines says the card is no longer on the ref whenever a load returns nil, including a lost remote ref or untracked repo
- **BR-4** [Minor] `flag-constellation-state` fetch state is a set of independent flags; a tagged outcome would make legal states explicit

## Round 2 — 2026-09-30T23:00:29-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — discovery_roots() now returns both modes from one expansion; the join uses roots_by_mode; regression spec relocates history via super_repo and asserts one non-card-only 000009 row.
- BR-2 — addressed — status() returns a table with ref=nil and fetching=true during bootstrap; pinned by "reports a first-fetch bootstrap while it runs".
- BR-3 — addressed — view_lines takes `readable` and says no tracker cards are readable; unit spec covers both branches.
- BR-4 — withdrawn — freshness() fixes the flags' precedence and is unit-tested; reshaping #308's tracker state into a tagged outcome is a separate refactor.

### Raised

- **BR-5** [Minor] `parallel-path-resolution` local_ids re-parses issue ids from filenames instead of reusing the scan's parser
  2nd in family. Rule: the card join derives every fact (dirs AND filename-to-id) from the scan's own resolution. issue_finder.lua local_ids uses ^(%d+)%-.*%.md$ while issue_finder_records.lua:47 uses ^(%d+)%-(.+)%.md$, so a name like 000123-.md is "local" to the join but has no scan row and vanishes. Expose the records parser and call it from local_ids. One remaining instance.

## Round 3 — 2026-09-30T23:03:14-07:00 (claude) — passed

### Disposed

- BR-5 — addressed — local_ids now calls issue_records.parse_name (issue_finder.lua:365), the same parser adapt uses; spec "counts only the files the scan turns into rows" pins the empty-slug case, which the old .* pattern would have counted as local.

## Round 4 — 2026-10-01T08:58:49-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — Disposed in an earlier round; no regression in the latest delta.

### Raised

- **BR-6** [Minor] `plan-revision-lag` Durable plan still specifies the card-only text label and search token removed by 408843e3
  Plan lines 74-76, 230-236 and 396-402 describe the card-only text label and the search token. The issue's Revisions records the change, but the plan has no Revisions entry.
- **BR-7** [Minor] `search-affordance-regression` Card-only rows no longer carry a searchable provenance token in search_text
  issue_finder_records.lua:165 dropped the card-only search token and did not add the lock. Users can no longer narrow the finder to card-only issues by typing; adding a token such as 'card-only' back to search_text would restore it.

## Open findings

- **BR-6** [Minor] `plan-revision-lag` Durable plan still specifies the card-only text label and search token removed by 408843e3
- **BR-7** [Minor] `search-affordance-regression` Card-only rows no longer carry a searchable provenance token in search_text
