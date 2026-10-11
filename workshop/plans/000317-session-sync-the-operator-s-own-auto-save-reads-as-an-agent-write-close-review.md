# Boundary Review — parley.nvim#317 (whole-issue close)

| field | value |
|-------|-------|
| issue | 317 — session-sync: the operator's own auto-save reads as an agent write |
| repo | parley.nvim |
| issue file | workshop/issues/000317-session-sync-the-operator-s-own-auto-save-reads-as-an-agent-write.md |
| boundary | whole-issue close |
| milestone | — |
| window | cb4af8d281e073c150960dcb08dbd8b2401f9b4e..40bf7c0f457a6f89c2c18ab6d746a7fcbde33644 |
| command | sdlc close --issue 317 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-11T11:47:27-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Diff and issue read; now checking a suspected side effect (`:checktime` updating Neovim's stored mtime, which disarms its own overwrite warning) and running the specs.

All 34 pass. Now probing the suspected regression: after an unkept violation, does a plain `:w` still meet Neovim's overwrite warning?

```verdict
verdict: FIX-THEN-SHIP
confidence: medium
```

The fix works and the tests back it up. `disk_changed` now treats `s.loaded` as a cache and asks Neovim through `:checktime <buf>` whether a moved mtime came from this buffer. Because every caller (the watch, submit, `violation`, the first-edit race) goes through that one function, they all pick up the new behaviour. I ran the spec at head and it passes 34/34. I swapped in the base `session_sync.lua` and 4 of the new specs fail. I set `autoread` back to true and 3 specs fail, which confirms the mutation claim in the Log. I also checked a suspected regression: does running `:checktime` with `fcs_choice=""` disarm Neovim's own "file changed since reading" warning on `:w`? It does not; the warning still fired at head in an unkept-copy probe. One thing should be fixed before shipping, and it is cheap. The `pcall` around `:checktime` fails open: if the command errors, `disk_changed` decides the write was the operator's own and moves the baseline forward, so a foreign write is silently accepted.

1. **Strengths**
   - `lua/parley/session_sync.lua:263-279`: the fix sits in the one function every detector calls, so the watch, submit, `violation` and the first-edit race all get it in one change (ARCH-PURPOSE shadow-sweep passes).
   - `s.foreign` keeps `:checktime` from being run again for the same foreign write. That matters because Neovim stores the new mtime and won't raise `FileChangedShell` twice for it.
   - Turning `autoread` off (`:496-499`) fixes the second hazard found during repro. The mutation result above shows the tests pin it.
   - The first-edit race now notes the mtime move inside the autocmd and runs `:checktime` from the scheduled callback (`:515-522`), which respects the rule that `:checktime` prompts if run inside an autocmd.
   - The tests reproduce the real config (an auto-save from a non-nested `TextChanged`) and the TL's exact sequences.

2. **Critical findings:** none.

3. **Important findings**
   - **`lua/parley/session_sync.lua:271` fails open when `:checktime` errors.** It runs as `pcall(vim.cmd, "checktime " .. buf)` and ignores the result. If `:checktime` errors, or never raises `FileChangedShell`, `s.foreign` stays unset and `s.loaded = now` takes in the foreign write as the operator's own. Two ways this can happen: a watch tick fires while the command-line window (`q:`) is open, where `:checktime` is likely E11; or `eventignore` covers `FileChangedShell`. The code before this change could not lose a foreign write this way.
     - Fix sketch: `local ok = pcall(...)`, and when it fails return `true` (treat the write as foreign) or leave `s.loaded` alone. Add a spec that stubs `:checktime` to error.
     - Every instance of this pattern in the window: line 271 is the only `pcall` around the decision.

4. **Minor findings**
   - **ARCH-DRY:** `:515` (`s.loaded ~= nil and disk_mtime(buf) ~= s.loaded`) repeats the first guard of `disk_changed` (`:265-266`). Pull it into a `mtime_moved(buf)` helper and call it from both places.
   - **Spec comment:** in the `:checktime` reload cases, `ss.POLL_MS = 60000` turns the watch off, but the comment says `vim.wait(300) -- several watch ticks`. That comment is wrong for those cases.
   - **Log claim:** the Log says "all 4 auto-save cases fail" against base. Against base, the ":checktime reload + auto-save" case passes. The 4 that fail are: own auto-save, watch reload + auto-save, Alt+Return auto-save, and "the same write noticed by :checktime does not reload".

5. **Test coverage notes**
   - Done-when row 1 (an auto-save raises no violation): covered, and it fails before the fix. Row 2 (an agent write under the lock over a clean buffer is still a violation): covered through both the watch and `:checktime`.
   - The ":checktime reload, auto-save" case with `POLL_MS=60000` doesn't test the bug: with no watch ticks, the stale baseline is never read, so it passes on base. Either allow watch ticks in that case or say it only guards the `:checktime` path.
   - Nothing tests the fail-open path in the Important finding.

6. **Architectural notes**
   - ARCH-DRY: flagged (the Minor helper finding above).
   - ARCH-PURE: pass. `disk_changed` was IO already (`fs_stat`). The new decision logic is three comparisons, too small to justify pulling out a pure function.
   - ARCH-PURPOSE: pass. All consumers go through `disk_changed`, and the `FileChangedShell` handler records `s.foreign` before branching, so detection has one source of truth.
   - Docs: the atlas is updated (`atlas/modes/session_sync.md:33-38`). This change adds no new user surface (no flags or keys), so README doesn't need updating.

7. **Plan revision recommendations**
   - None needed for the Core concepts table: both rows match the code at the stated path.
   - Optionally correct the Log line "all 4 auto-save cases fail" so it names the 4 cases that actually fail.

```findings
findings:
  - id: new
    severity: Important
    family: checktime-verdict-fails-open
    title: |
      disk_changed treats a failed or eventless :checktime as the operator's own write and advances s.loaded
    detail: |
      session_sync.lua:271 ignores the pcall result. If :checktime errors (likely E11 from a watch tick while the cmdline window is open) or FileChangedShell is suppressed (eventignore), s.foreign is never set and s.loaded = now accepts a foreign write. The only instance in the window is line 271. Fix: on pcall failure return true or leave s.loaded alone, and add a spec that stubs :checktime to error.
  - id: new
    severity: Minor
    family: arch-dry-duplicated-guard
    title: |
      The first-edit mtime snapshot repeats disk_changed's baseline guard
    detail: |
      session_sync.lua:515 repeats the check at :265-266. Extract a mtime_moved(buf) helper and call it from both places (ARCH-DRY).
  - id: new
    severity: Minor
    family: claim-not-matching-code
    title: |
      A spec comment and a Log line misstate what the code and tests do
    detail: |
      In the :checktime cases (POLL_MS=60000) the spec comment says "several watch ticks", but the watch is off. The Log says "all 4 auto-save cases fail" against base, but the ":checktime reload + auto-save" case passes on base; the fourth failure is "the same write noticed by :checktime does not reload".
  - id: new
    severity: Minor
    family: test-does-not-exercise-bug-path
    title: |
      The ":checktime reload + auto-save" spec passes on base because the watch is off
    detail: |
      With POLL_MS=60000, the stale baseline is never read, so that case cannot catch the reported bug. Allow watch ticks in that case or document that it only guards the :checktime path.
```

---

## Re-review — 2026-10-11T11:53:23-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 317 — session-sync: the operator's own auto-save reads as an agent write |
| repo | parley.nvim |
| issue file | workshop/issues/000317-session-sync-the-operator-s-own-auto-save-reads-as-an-agent-write.md |
| boundary | whole-issue close |
| milestone | — |
| window | cb4af8d281e073c150960dcb08dbd8b2401f9b4e..d4051e8f9ec793d6506a770a8160be15bcd8b2a8 |
| command | sdlc close --issue 317 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-11T11:53:23-07:00 |
| verdict | SHIP |

## Review

Checking the callers of `disk_changed` and the reload/submit paths, then running the specs.

Getting the spec suite to run headless; the first attempt printed nothing, so checking raw output.

All 36 pass. Now mutation checks: reverting the BR-1 guards, and running the head specs against base `session_sync.lua` (BR-4).

```verdict
verdict: SHIP
confidence: high
```

The fix works. `disk_changed` now treats `s.loaded` as a cache and asks Neovim with `:checktime` whose write it was. `FileChangedShell` records the foreign mtime, `autoread` is off, and the first-edit race check now runs in the scheduled callback, outside the autocmd. All four prior findings are addressed, and I checked each one by running tests, not by reading commit messages. On the head commit, `tests/integration/session_sync_spec.lua` passes 36/36. With the head specs run against base `session_sync.lua`, 7 of the new specs fail: the 5 tests for the reported bug (including the `:checktime` reload + auto-save case, BR-4) and the 2 BR-1 cases. Removing each BR-1 guard on its own fails exactly its own spec. One new Minor: when the `mtime_moved` helper was extracted, `disk_changed`'s doc comment ended up above `mtime_moved` instead. Nothing blocks shipping.

1. **Strengths**
   - `lua/parley/session_sync.lua:271-295`: only Neovim's answer moves the baseline. If `:checktime` errors or `eventignore` hides the event, the write stays undecided and is asked again; it is never adopted as the operator's own (fixes BR-1 for the whole class).
   - `s.foreign` caches Neovim's answer. This matters because a second `:checktime` would not raise `FileChangedShell` again for the same write, so the cache is what makes the result stick.
   - `session_sync.lua:530-538`: the mtime move is captured inside the autocmd, and the `:checktime` question is asked in the scheduled callback. This respects the rule "never `:checktime` inside an autocmd".
   - The specs reproduce the real trigger: an auto-save from a non-nested `TextChanged` autocmd, which fires no `BufWritePost`. They also cover the team lead's exact sequences, with both auto-save and `:w`, and with the watch on and off.
   - Turning `autoread` off is justified, explained in a comment, and covered by a test (the ":checktime does not reload over the operator's text" spec).

2. **Critical findings:** none.

3. **Important findings:** none.

4. **Minor findings**
   - `session_sync.lua:257-265`: the doc comment ("Whether the file on disk changed… Never call it from inside an autocmd") describes `disk_changed`, but since the BR-2 extraction it sits above `mtime_moved`. `disk_changed` at :271 has no comment. Its "never call from inside an autocmd" warning now appears to apply to `mtime_moved`, which the first-edit autocmd calls legitimately. Fix: give `mtime_moved` a one-line comment and move the block down to `disk_changed`.
     - This is the 2nd finding in family `claim-not-matching-code`. The rule: a comment must describe the code it is attached to, so when a refactor extracts or moves a function, its doc comment has to move with it.
     - Swept every comment in the window for this rule. The other places are correct: the state-field comment at :41-42, the attach comments at :511-514, :528-529 and :544-547, the atlas paragraph, the lessons entry, and the spec comments. This is the only instance.

5. **Test coverage notes**
   - Mutation results, all on the pinned head:
     - Making `s.loaded = now` unconditional fails "checktime errors".
     - Disabling the `eventignore` guard fails "eventignore".
     - Running against base `session_sync.lua` fails 7 specs, including the `:checktime` reload + auto-save case, which now ends in a submit that reads the baseline.
   - Not covered: a foreign write that lands between the first keystroke and the operator's own auto-save before the scheduled check runs. Neovim then sees the operator's write, and the race is not flagged. This is a narrow window and it was already lossy before this change; it doesn't need to be fixed for this boundary.

6. **Architectural notes**
   - **ARCH-DRY: pass.** `mtime_moved` is now shared by `disk_changed` and the first-edit snapshot. I found no other copy of the baseline check.
   - **ARCH-PURE: pass, given the domain.** The "whose write" decision depends on Neovim's per-buffer write record, so it can only be tested in integration. The IO is kept inside `disk_changed`.
   - **ARCH-PURPOSE: pass.** All `disk_changed` callers (watch at :437/:439, `violation` at :324, submit at :608, first edit at :535) now get Neovim's answer. None of them reads the stale baseline directly.

7. **Plan revision recommendations:** none. The Core-concepts table matches the code: both `disk_changed` and `attach` are modified in `lua/parley/session_sync.lua`.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Baseline advances only when ok; eventignore guard added; reverting either guard fails its own spec (verified by mutation on the pinned head).
  - id: BR-2
    disposition: addressed
    note: |
      mtime_moved helper at session_sync.lua:266 used by disk_changed (:273) and the first-edit snapshot (:530).
  - id: BR-3
    disposition: addressed
    note: |
      Spec comment now says "watch ticks (when on)"; Log names the :checktime-no-reload case as the fourth base failure and notes the checktime-reload case passed on base.
  - id: BR-4
    disposition: addressed
    note: |
      The case now ends with a submit that reads the baseline; verified it fails against base session_sync.lua.
findings:
  - id: new
    severity: Minor
    family: claim-not-matching-code
    title: |
      disk_changed's doc comment now sits on mtime_moved after the BR-2 extraction
    detail: |
      session_sync.lua:257-265 describes disk_changed (checktime, "never call from inside an autocmd") but is attached to mtime_moved, which the first-edit autocmd calls legitimately; disk_changed (:271) has no comment. 2nd finding in this family. Rule: a comment must describe the code it is attached to, so an extracted or moved function takes its doc comment with it. Swept every comment in the window; this is the only instance. Fix: one-line comment on mtime_moved, move the block down to disk_changed.
```
