# Boundary Review — parley.nvim#308 (whole-issue close)

| field | value |
|-------|-------|
| issue | 308 — Issue finder folds in issue-tracker card fields |
| repo | parley.nvim |
| issue file | workshop/issues/000308-issue-finder-folds-in-issue-tracker-card-fields.md |
| boundary | whole-issue close |
| milestone | — |
| window | 8e3dfe3b3860a3a6c397e0b24a110b9622ac4f8c..874c100bec5e3c4cec782dff995ed8780ea459ec |
| command | sdlc close --issue 308 |
| reviewer | claude |
| timestamp | 2026-09-30T17:30:36-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

**Summary:** The work mostly delivers the Spec. The pure `issue_cards` core is clean and well tested. The `issue_tracker` IO shell is async, reads only by argv, caches blobs by OID and prunes them, and is tested against real git in throwaway repos. The finder overlays card values before sorting and keeps the selected row when it repaints. All six affected spec files pass when run here (`make test-spec SPEC=issues/issue-management`: issue_cards 13, finder_records 11, float_picker 82, tracker 7, finder_tracker 3, tracker_buffer 3, no failures).

One gap goes against the Spec: "if the ref moved, … refresh the open finder / issue buffers". A tip move is reported only to the caller whose `refresh` started the fetch. Inside the 60s throttle, an issue buffer's `BufEnter` also never re-reads the local ref. So open buffers can keep stale annotations after another view's fetch, or after a local `sdlc` verb, has moved the ref. The specs set `fetch_interval_s = 0`, which hides this. Nothing here blocks shipping; fix this one before the boundary if it's cheap.

1. **Strengths**
   - `lua/parley/issue_cards.lua` is a pure core with no IO. It covers parsing, the tree/batch decoding, remote selection, overlay and annotations. `parse_batch` walks frames by their declared byte size and stops cleanly on a truncated frame.
   - The card directory, branch and field list all come from the vocabulary (`discovery.cards/tracker`, `card.fields`). Nothing is hardcoded, so ARCH-DRY is honoured.
   - `issue_tracker.read` uses a generation guard plus a waiter list. Concurrent loads share one read, and a fetch-triggered read supersedes an older one instead of racing it (`issue_tracker.lua:93-110`).
   - ARCH-MOCK is met: specs drive real git against a bare remote with writer and reader clones (`tests/helpers/tracker_repo.lua`). Signing is off, a fixed identity is set, and nothing touches the user's repos. `fetch_enabled` is off under `PARLEY_TEST_MODE`.
   - The `float_picker` change is generic and safe: its own namespace, spans clipped to the line length, and it does nothing while a status line is showing (`float_picker.lua:972-988`).

2. **Critical:** none.

3. **Important**
   - **A tip move is not broadcast to open views** (`issue_tracker.lua:217-235`, `issue_tracker_buffer.lua:55-80`). `on_moved` reaches only the caller whose `refresh` won the throttle.
     - A finder-triggered fetch never repaints open issue buffers.
     - A buffer's `refresh` that lands while another fetch is running returns early through `st.fetching`, and never hears of the result.
     - Within 60s of the last fetch, `BufEnter` neither fetches nor re-reads the local ref, so a card that an `sdlc` verb moved in another slot stays stale in an open buffer.
     - **Fix sketch:** keep a per-root subscriber set. `issue_tracker_buffer.attach` subscribes (and unsubscribes on `BufWipeout`); the finder subscribes for as long as it is open. Have `read` notify subscribers whenever `st.tip` changes, whatever the trigger. Make `BufEnter` call `load` (local, cheap) as well as `refresh`. Add a spec with the real 60s interval: fetch from one view, assert the other repaints. (ARCH-PURPOSE, ARCH-ORDER)

4. **Minor**
   - `overlay` copies a blank card value over the details value:
     - A card with no H1 sets `title = ""`, and the row falls back to the slug with no amber.
     - A card whose `github_issue` is blank while the details mirror has one drops the `(#N)` segment, so the stale field can't be seen.
     - Fix: skip a blank card title; for `github_issue`, show something visible when the stale value has been dropped.
   - A failed re-read (`fail` → `finish(nil)`) sets `st.cards = nil`, so one transient git error throws away a good cache. Keeping the previous cards on failure is more robust.
   - `select_remote` is fed the upstream of the current branch (`@{u}`, usually the issue branch), whereas the Spec says "upstream remote of the default branch". The two match in practice, but the doc or the code should change so they agree.
   - The `loading` / `fetching` / `cards` / `tip` / `gen` fields form a small set of independent flags. That's fine at this size, but if it grows, collapse it into an explicit state enum.
   - The finder test "repaints when a background fetch moves the tracker" actually opens the finder a second time. It does not check that an already-open picker repaints from its own refresh.

5. **Test coverage notes**
   - Unit coverage of the parser, overlay, annotations and `select_remote` is good, and the integration specs run real git.
   - Every integration spec sets `fetch_interval_s = 0`, so the interaction between throttling and repainting, which is where the Important finding sits, is never exercised.
   - The Done-when item "Untracked repos and missing refs behave exactly as before" is covered: there are specs for a missing marker and a missing ref, and the finder-records spec pins today's row format.

6. **Architectural notes for upcoming work**
   - The follow-up for the status-cycle key and `:ParleyIssueStatus` (route them through `sdlc issue set-status`) should reuse the tracker subscriber channel suggested above, so a write repaints every view.
   - Principle by principle:
     - **ARCH-DRY:** pass.
     - **ARCH-PURE:** pass.
     - **ARCH-PURPOSE:** flag (the Important finding).
     - **ARCH-MOCK:** pass (real git behind the same seam). There is no live conformance check against ariadne's real card format; the #296 card fixture in the unit spec partly stands in for one.
     - **ARCH-CONSTRAINTS:** pass. All git calls are async, there are timeouts, the fetch is throttled, and reads after the first only fetch the blobs not yet cached.
     - **ARCH-SECURE:** pass. Commands are argv only, the id is checked against `^%d+$`, card text is only ever displayed, and the env sets `GIT_TERMINAL_PROMPT=0`.
     - **ARCH-ORDER:** flag, minor part. The generation guard and the closed-picker guard are good; the issue is the per-caller move notification.
     - **ARCH-FUNERAL:** pass. Everything lives in memory, the blob cache is pruned to the current tree, extmarks are cleared before each repaint, and the buffer's augroup is deleted on wipeout.

7. **Plan revision recommendations**
   - Add a `## Revisions` entry once the move notification becomes a per-root subscription. Also make the remote-selection wording ("upstream of default branch" vs the current branch's `@{u}`) match the code.

```findings
findings:
  - id: new
    severity: Important
    family: change-notification-reaches-all-views
    title: |
      A tracker tip move repaints only the caller that triggered the fetch, so open issue buffers and other views miss it
    detail: |
      The Spec says a moved ref refreshes the open finder and issue buffers. In fact on_moved goes only to the refresh caller that won the throttle. A refresh that arrives during an in-flight fetch returns early, and BufEnter inside the 60s throttle never re-reads the local ref, so moves made by sdlc in other slots are missed too. Fix: a per-root subscriber set notified from read() whenever the tip changes; BufEnter also calls load. Add a spec that keeps the real throttle.
  - id: new
    severity: Minor
    family: blank-overlay-masks-stale-field
    title: |
      overlay copies a blank card title or github_issue over the details value, hiding a stale field that should show amber
  - id: new
    severity: Minor
    family: transient-failure-discards-cache
    title: |
      A failed tracker re-read sets st.cards to nil, so one transient git error throws away a good card cache
  - id: new
    severity: Minor
    family: spec-code-wording-drift
    title: |
      Remote selection uses the current branch's upstream, but the Spec says the default branch's upstream
```
