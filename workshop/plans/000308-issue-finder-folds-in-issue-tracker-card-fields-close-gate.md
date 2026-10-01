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
    - "n": 2
      timestamp: "2026-09-30T17:47:57-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: per-root subscribe fan-out from read() plus BufEnter re-read; hidden-buffer real-throttle and cross-view specs fail without it
          round: 2
        - id: BR-2
          disposition: addressed
          note: blank card title ignored (issue_cards.lua overlay); dropped github link flagged stale and rendered as (#-), unit-tested
          round: 2
        - id: BR-3
          disposition: addressed
          note: fail() finishes with st.cards; "keeps the last good cards when a re-read fails" spec corrupts the ref and asserts the old card
          round: 2
        - id: BR-4
          disposition: addressed
          note: Spec revised in Revisions to the current branch's upstream remote, matching issue_tracker.lua read()
          round: 2
      findings:
        - id: BR-5
          severity: Minor
          title: 'Buffer subscription guarded by a sticky b: flag that outlives both the subscription and the attach closure'
          detail: '2nd in family. b: vars survive :bunload, so a subscriber pruned while unloaded is never re-registered on reload, and a re-attach (:e) leaves the old show closure subscribed while BufWritePost repaints the new, possibly older, card. Rule: key each subscription by view identity and replace it on attach, so liveness and subscription derive from one fact.'
          family: change-notification-reaches-all-views
          round: 2
      recipe: milestone-review
      blocked: false
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

## Round 2 — 2026-09-30T17:47:57-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — per-root subscribe fan-out from read() plus BufEnter re-read; hidden-buffer real-throttle and cross-view specs fail without it
- BR-2 — addressed — blank card title ignored (issue_cards.lua overlay); dropped github link flagged stale and rendered as (#-), unit-tested
- BR-3 — addressed — fail() finishes with st.cards; "keeps the last good cards when a re-read fails" spec corrupts the ref and asserts the old card
- BR-4 — addressed — Spec revised in Revisions to the current branch's upstream remote, matching issue_tracker.lua read()

### Raised

- **BR-5** [Minor] `change-notification-reaches-all-views` Buffer subscription guarded by a sticky b: flag that outlives both the subscription and the attach closure
  2nd in family. b: vars survive :bunload, so a subscriber pruned while unloaded is never re-registered on reload, and a re-attach (:e) leaves the old show closure subscribed while BufWritePost repaints the new, possibly older, card. Rule: key each subscription by view identity and replace it on attach, so liveness and subscription derive from one fact.

## Open findings

- **BR-5** [Minor] `change-notification-reaches-all-views` Buffer subscription guarded by a sticky b: flag that outlives both the subscription and the attach closure
