---
gate: boundary-review
issue: 317
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-10-11T11:47:27-07:00"
      dispatched: "2026-10-11T11:39:58-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Important
          title: disk_changed treats a failed or eventless :checktime as the operator's own write and advances s.loaded
          detail: 'session_sync.lua:271 ignores the pcall result. If :checktime errors (likely E11 from a watch tick while the cmdline window is open) or FileChangedShell is suppressed (eventignore), s.foreign is never set and s.loaded = now accepts a foreign write. The only instance in the window is line 271. Fix: on pcall failure return true or leave s.loaded alone, and add a spec that stubs :checktime to error.'
          family: checktime-verdict-fails-open
          round: 1
        - id: BR-2
          severity: Minor
          title: The first-edit mtime snapshot repeats disk_changed's baseline guard
          detail: session_sync.lua:515 repeats the check at :265-266. Extract a mtime_moved(buf) helper and call it from both places (ARCH-DRY).
          family: arch-dry-duplicated-guard
          round: 1
        - id: BR-3
          severity: Minor
          title: A spec comment and a Log line misstate what the code and tests do
          detail: In the :checktime cases (POLL_MS=60000) the spec comment says "several watch ticks", but the watch is off. The Log says "all 4 auto-save cases fail" against base, but the ":checktime reload + auto-save" case passes on base; the fourth failure is "the same write noticed by :checktime does not reload".
          family: claim-not-matching-code
          round: 1
        - id: BR-4
          severity: Minor
          title: The ":checktime reload + auto-save" spec passes on base because the watch is off
          detail: With POLL_MS=60000, the stale baseline is never read, so that case cannot catch the reported bug. Allow watch ticks in that case or document that it only guards the :checktime path.
          family: test-does-not-exercise-bug-path
          round: 1
      recipe: small-diff-review
      isolation: checkout
      blocked: true
    - "n": 2
      timestamp: "2026-10-11T11:53:24-07:00"
      dispatched: "2026-10-11T11:51:04-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: Baseline advances only when ok; eventignore guard added; reverting either guard fails its own spec (verified by mutation on the pinned head).
          round: 2
        - id: BR-2
          disposition: addressed
          note: mtime_moved helper at session_sync.lua:266 used by disk_changed (:273) and the first-edit snapshot (:530).
          round: 2
        - id: BR-3
          disposition: addressed
          note: Spec comment now says "watch ticks (when on)"; Log names the :checktime-no-reload case as the fourth base failure and notes the checktime-reload case passed on base.
          round: 2
        - id: BR-4
          disposition: addressed
          note: The case now ends with a submit that reads the baseline; verified it fails against base session_sync.lua.
          round: 2
      findings:
        - id: BR-5
          severity: Minor
          title: disk_changed's doc comment now sits on mtime_moved after the BR-2 extraction
          detail: 'session_sync.lua:257-265 describes disk_changed (checktime, "never call from inside an autocmd") but is attached to mtime_moved, which the first-edit autocmd calls legitimately; disk_changed (:271) has no comment. 2nd finding in this family. Rule: a comment must describe the code it is attached to, so an extracted or moved function takes its doc comment with it. Swept every comment in the window; this is the only instance. Fix: one-line comment on mtime_moved, move the block down to disk_changed.'
          family: claim-not-matching-code
          round: 2
      recipe: small-diff-review
      isolation: checkout
      reviewed: d4051e8f9ec793d6506a770a8160be15bcd8b2a8
      blocked: false
---

# Gate ledger — parley.nvim#317 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-11T11:47:27-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `checktime-verdict-fails-open` disk_changed treats a failed or eventless :checktime as the operator's own write and advances s.loaded
  session_sync.lua:271 ignores the pcall result. If :checktime errors (likely E11 from a watch tick while the cmdline window is open) or FileChangedShell is suppressed (eventignore), s.foreign is never set and s.loaded = now accepts a foreign write. The only instance in the window is line 271. Fix: on pcall failure return true or leave s.loaded alone, and add a spec that stubs :checktime to error.
- **BR-2** [Minor] `arch-dry-duplicated-guard` The first-edit mtime snapshot repeats disk_changed's baseline guard
  session_sync.lua:515 repeats the check at :265-266. Extract a mtime_moved(buf) helper and call it from both places (ARCH-DRY).
- **BR-3** [Minor] `claim-not-matching-code` A spec comment and a Log line misstate what the code and tests do
  In the :checktime cases (POLL_MS=60000) the spec comment says "several watch ticks", but the watch is off. The Log says "all 4 auto-save cases fail" against base, but the ":checktime reload + auto-save" case passes on base; the fourth failure is "the same write noticed by :checktime does not reload".
- **BR-4** [Minor] `test-does-not-exercise-bug-path` The ":checktime reload + auto-save" spec passes on base because the watch is off
  With POLL_MS=60000, the stale baseline is never read, so that case cannot catch the reported bug. Allow watch ticks in that case or document that it only guards the :checktime path.

## Round 2 — 2026-10-11T11:53:24-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — Baseline advances only when ok; eventignore guard added; reverting either guard fails its own spec (verified by mutation on the pinned head).
- BR-2 — addressed — mtime_moved helper at session_sync.lua:266 used by disk_changed (:273) and the first-edit snapshot (:530).
- BR-3 — addressed — Spec comment now says "watch ticks (when on)"; Log names the :checktime-no-reload case as the fourth base failure and notes the checktime-reload case passed on base.
- BR-4 — addressed — The case now ends with a submit that reads the baseline; verified it fails against base session_sync.lua.

### Raised

- **BR-5** [Minor] `claim-not-matching-code` disk_changed's doc comment now sits on mtime_moved after the BR-2 extraction
  session_sync.lua:257-265 describes disk_changed (checktime, "never call from inside an autocmd") but is attached to mtime_moved, which the first-edit autocmd calls legitimately; disk_changed (:271) has no comment. 2nd finding in this family. Rule: a comment must describe the code it is attached to, so an extracted or moved function takes its doc comment with it. Swept every comment in the window; this is the only instance. Fix: one-line comment on mtime_moved, move the block down to disk_changed.

## Open findings

- **BR-5** [Minor] `claim-not-matching-code` disk_changed's doc comment now sits on mtime_moved after the BR-2 extraction
