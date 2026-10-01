---
gate: boundary-review
issue: 308
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-30T17:30:36-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Important
          title: A tracker tip move repaints only the caller that triggered the fetch, so open issue buffers and other views miss it
          detail: 'The Spec says a moved ref refreshes the open finder and issue buffers. In fact on_moved goes only to the refresh caller that won the throttle. A refresh that arrives during an in-flight fetch returns early, and BufEnter inside the 60s throttle never re-reads the local ref, so moves made by sdlc in other slots are missed too. Fix: a per-root subscriber set notified from read() whenever the tip changes; BufEnter also calls load. Add a spec that keeps the real throttle.'
          family: change-notification-reaches-all-views
          round: 1
        - id: BR-2
          severity: Minor
          title: overlay copies a blank card title or github_issue over the details value, hiding a stale field that should show amber
          family: blank-overlay-masks-stale-field
          round: 1
        - id: BR-3
          severity: Minor
          title: A failed tracker re-read sets st.cards to nil, so one transient git error throws away a good card cache
          family: transient-failure-discards-cache
          round: 1
        - id: BR-4
          severity: Minor
          title: Remote selection uses the current branch's upstream, but the Spec says the default branch's upstream
          family: spec-code-wording-drift
          round: 1
      recipe: milestone-review
      blocked: true
---

# Gate ledger — parley.nvim#308 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-30T17:30:36-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `change-notification-reaches-all-views` A tracker tip move repaints only the caller that triggered the fetch, so open issue buffers and other views miss it
  The Spec says a moved ref refreshes the open finder and issue buffers. In fact on_moved goes only to the refresh caller that won the throttle. A refresh that arrives during an in-flight fetch returns early, and BufEnter inside the 60s throttle never re-reads the local ref, so moves made by sdlc in other slots are missed too. Fix: a per-root subscriber set notified from read() whenever the tip changes; BufEnter also calls load. Add a spec that keeps the real throttle.
- **BR-2** [Minor] `blank-overlay-masks-stale-field` overlay copies a blank card title or github_issue over the details value, hiding a stale field that should show amber
- **BR-3** [Minor] `transient-failure-discards-cache` A failed tracker re-read sets st.cards to nil, so one transient git error throws away a good card cache
- **BR-4** [Minor] `spec-code-wording-drift` Remote selection uses the current branch's upstream, but the Spec says the default branch's upstream

## Open findings

- **BR-1** [Important] `change-notification-reaches-all-views` A tracker tip move repaints only the caller that triggered the fetch, so open issue buffers and other views miss it
- **BR-2** [Minor] `blank-overlay-masks-stale-field` overlay copies a blank card title or github_issue over the details value, hiding a stale field that should show amber
- **BR-3** [Minor] `transient-failure-discards-cache` A failed tracker re-read sets st.cards to nil, so one transient git error throws away a good card cache
- **BR-4** [Minor] `spec-code-wording-drift` Remote selection uses the current branch's upstream, but the Spec says the default branch's upstream
