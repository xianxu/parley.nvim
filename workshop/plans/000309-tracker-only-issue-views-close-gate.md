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

## Open findings

- **BR-5** [Minor] `parallel-path-resolution` local_ids re-parses issue ids from filenames instead of reusing the scan's parser
