# Boundary Review — parley.nvim#314 (whole-issue close)

| field | value |
|-------|-------|
| issue | 314 — Session-sync hardening: no reload prompt under the operator's lock, complain to the agent, a 'TL owes' band, and a liveness ping |
| repo | parley.nvim |
| issue file | workshop/issues/000314-session-sync-hardening-no-reload-prompt-under-the-operator-s-lock-complain-to-the-agent-a-tl-owes-band-and-a-liveness-ping.md |
| boundary | whole-issue close |
| milestone | — |
| window | 6a4bf805419155016eab0c3e42d250da591ab4b3..cf0868a3bc74776fb4a1cb924164747eddd756cf |
| command | sdlc close --issue 314 |
| reviewer | claude |
| timestamp | 2026-10-11T00:07:14-07:00 |
| verdict | REWORK |

## Review

I'm reading the #314 diff and am about to run the session-sync specs.

Still reviewing: I confirmed one crash path in the ping probe, and I'm checking README coverage for the new config key now.

```verdict
verdict: REWORK
confidence: high
```

All three Done-when items are delivered and tested, and `make test-spec SPEC=modes/session_sync` passes: 22/22 integration tests, plus all the unit specs. Two things block SHIP. First, the ping probe crashes on a JSON `null`, and after that crash it never pings again for that buffer. A Go encoder writes an empty slice as `null`, so `"Owed": null` is a likely answer from pair#437 when nothing is owed. Second, the violation handler writes the operator's copy over the file even when it failed to save the agent's copy first. The complaint message then points the agent at a `.clobbered` file that is missing or left over from an earlier violation.

**1. Strengths**
- All three detectors (the watch, `FileChangedShell`, submit) go through one `violation(buf)`, and it checks `disk_changed` first. When two detectors fire for the same write, the second does nothing (`lua/parley/session_sync.lua:271`).
- `send` is now one function used by submit, the complaint and the ping (ARCH-DRY). The send-failure path behaves as it did before.
- Async callbacks check `state[buf] ~= s` before acting, and the lock condition is re-read before a lock-based ping (`lock_owed() ~= since`). This applies the BR-1 lesson from #313.
- `parse_time` and `find_actor` are pure and have unit tests that cover time offsets, leap days, an ambiguous prefix and a nil actor list.
- The integration tests use a fake `couch` and cover each Done-when item: one message per operator turn, a quiet second violation, the `:checktime` path with no prompt, a mid-turn owner that goes quiet, no ping when nothing is owed, no ping for an owner that isn't live, and a ping driven only by the status verb.

**2. Critical findings**
- **The probe crashes on JSON `null`, and the in-flight guard stays set** (`lua/parley/session_sync.lua:316`, also `M.find_actor` at `:139`).
  - `vim.json.decode` turns `null` into the userdata `vim.NIL`, which is truthy, so `status.Status.Owed or {}` does not fall back to `{}`.
  - I confirmed it headless: `ipairs(vim.NIL)` raises "table expected, got userdata".
  - The same failure happens for `"Status": null`, `"Actors": null` and `"Binding": null`.
  - The error escapes the callback before `s.probing = false`, so this buffer never probes again, which also turns off the lock-based ping.
  - Fix sketch: decode with `{ luanil = { object = true, array = true } }`, check `type(x) == "table"` before each `ipairs` or field access, and reset `probing` on every exit path (for example, wrap the callbacks in `pcall`).
  - Add a test where the fake `couch` answers with `Owed:null` and `Actors:null`, and a later lock-owed ping still fires.

**3. Important findings**
- **`violation` ignores a failed `fs_copyfile` and overwrites anyway** (`:276-280`).
  - If the copy fails (the agent deleted or renamed the file, a permission problem, a full disk), the agent's version is lost.
  - The band and the couch message still say "yours is at <path>.clobbered", and that path may hold an older violation's copy.
  - Fix sketch: check the return value of `fs_copyfile`. When the file is missing, skip the copy and say "deleted" in the message. When the copy fails for another reason, notify at ERROR level and don't run `write!`, or say in the message that nothing was kept.
  - Add a test where the agent deletes the file while the operator holds the lock.

**4. Minor findings**
- **ARCH-ORDER:** per-buffer state is a growing set of loose flags (`turn`, `stale`, `violated`, `complained`, `probing`, `probed`, `pinged`, `minutes`, `gen`), and their legal combinations aren't written down anywhere. `violated` and `complained` only matter in the operator turn, so they could be fields of that state instead of separate booleans.
- **`.clobbered` notice can vanish** (ARCH-FUNERAL is otherwise fine: at most one file per session file, as the plan says). Suppose the operator unlocks while the agent is mid-reply, the reply lands under the operator's lock and is moved to `.clobbered`, and then the agent deletes the lock. The turn goes free, the violated band clears, and the only remaining trace is a one-time WARN notification.
- **ARCH-MOCK:** the fake `couch` is stateless and env-driven, and nothing checks it against the real `couch --actors --json` output. The `Resting` misreading fixed in Revisions is the kind of drift such a check would catch. Add one once pair#437 lands.
- `README.md` doesn't document session-sync or its config keys at all. That gap existed before this diff; `session_sync_ping_minutes` adds one more undocumented key.
- If `write!` fails inside the watch (for example, a read-only file system), the error repeats every second.

**5. Test coverage notes**
- Every Done-when item has a test, and the fallback when the status verb fails is covered by the fake's default exit 2.
- Not covered:
  - null or malformed couch JSON (the Critical finding);
  - the agent deleting the file under the lock;
  - a second ping episode after the owner replies and a later submit (a new `since`);
  - `find_actor` used through the actors JSON in an integration test with a prefixed slot.

**6. Architectural notes**
- **ARCH-DRY:** pass.
- **ARCH-PURE:** pass. The decision logic in `probe` (earliest owed time, threshold, quiet check) sits inside IO callbacks; pulling it into a pure `should_ping(lock_since, owed, actor, now, cfg)` would make the null-safety above unit-testable.
- **ARCH-PURPOSE:** pass.
- **ARCH-MOCK:** minor flag, as above.
- **ARCH-CONSTRAINTS:** pass. At most one `couch` process per minute per buffer, guarded so only one runs at a time.
- **ARCH-SECURE:** flagged. The external JSON is trusted to be well-formed (the Critical finding).
- **ARCH-ORDER:** minor flag, as above.
- **ARCH-FUNERAL:** pass. `.clobbered` is bounded, the timers end with the buffer, and processes are one-shot.

**7. Plan revision recommendations**
- Add a `## Revisions` entry: couch JSON is decoded null-safely and the probe guard is reset on every exit. In §1, say what `violation` does when the copy fails or the file was deleted.

```findings
findings:
  - id: new
    severity: Critical
    family: untrusted-json-shape
    title: |
      Probe crashes on JSON null (Owed/Status/Actors/Binding) and leaves s.probing stuck, disabling pings for the buffer
    detail: |
      vim.json.decode maps null to truthy vim.NIL; `Owed or {}` passes it to ipairs, which raises (verified headless). A Go nil slice encodes as null. Decode with luanil, type-check tables, and reset probing on all paths; add a fake-couch test with Owed:null / Actors:null.
  - id: new
    severity: Important
    family: unchecked-io-before-destructive-write
    title: |
      violation() ignores fs_copyfile failure, then write! overwrites the agent copy and the message names a missing or stale .clobbered
    detail: |
      lua/parley/session_sync.lua:276-280. Check the copy result; handle a deleted file explicitly; do not claim a copy that was not made. Add a test where the agent deletes the file under the lock.
  - id: new
    severity: Minor
    family: flag-constellation-state
    title: |
      Per-buffer state grows as loose booleans (violated/complained/probing/pinged) with unwritten legal combinations
    detail: |
      ARCH-ORDER: fold violated/complained into the operator-turn state rather than parallel flags.
  - id: new
    severity: Minor
    family: fake-without-conformance
    title: |
      Fake couch (--actors/--session-sync status) has no conformance check against the real binary
    detail: |
      The Resting misreading in Revisions is exactly the drift such a check catches; add one when pair#437 lands.
  - id: new
    severity: Minor
    family: readme-surface-gap
    title: |
      README does not document session-sync or its config keys (session_sync_ping_minutes added)
```

---

## Re-review — 2026-10-11T00:10:34-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 314 — Session-sync hardening: no reload prompt under the operator's lock, complain to the agent, a 'TL owes' band, and a liveness ping |
| repo | parley.nvim |
| issue file | workshop/issues/000314-session-sync-hardening-no-reload-prompt-under-the-operator-s-lock-complain-to-the-agent-a-tl-owes-band-and-a-liveness-ping.md |
| boundary | whole-issue close |
| milestone | — |
| window | 6a4bf805419155016eab0c3e42d250da591ab4b3..c32a350ba2e02cd9bf4616394d73b9f540b87185 |
| command | sdlc close --issue 314 |
| reviewer | claude |
| timestamp | 2026-10-11T00:10:34-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Tests pass (25 integration + 9 unit). I'm checking the issue log and README to settle the remaining prior findings.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

**Summary.** Both blocking findings from round 1 are fixed, and each has a regression test. BR-1: every couch query now decodes JSON nulls as nil, and the code checks a value's type before treating it as a list or table. This covers all the couch JSON fields, not just the one the finding named. The new test feeds `null` values and shows the probe recovers and pings later. The original `Owed or {}` code would fail that test. BR-2: `violation()` now handles three cases separately: the file was deleted, the copy succeeded, or the copy failed. Each case has its own band text and message, and each has a test. The suite passes: 25 integration and 9 unit specs in `make test-spec SPEC=modes/session_sync`. One new Important finding remains, and it is cheap to fix. When the `.clobbered` copy fails, `submit` still goes on to write the file and hand the turn to the agent.

1. **Strengths**
   - `query()` (`lua/parley/session_sync.lua` ~246) is the one place couch JSON gets decoded. It decodes nulls as nil, checks `Code == "ok"`, and returns nil on any failure. Together with `list()` and the type checks in `find_actor`, the fix covers all the affected fields.
   - The `probing` flag is now reset on every path that returns early, both in the status callback and in the actors callback.
   - BR-2's outcomes are honest. A deleted file never claims a `.clobbered` copy, and a failed copy never overwrites the agent's file. After a failed copy, the buffer records the disk's timestamp, so the watch does not retry every tick. The test confirms only one message is sent.
   - The watch now stops once the buffer is unloaded (`:bdelete`), and a test covers it. The author found this from a stray notice in the suite.
   - `parse_time` and `find_actor` are pure and have unit tests for the edge cases: offsets, ambiguous prefixes, and junk entries.

2. **Critical:** none.

3. **Important**
   - `lua/parley/session_sync.lua` (`M.submit`, the `disk_changed` branch): if the copy fails, `violation()` deliberately leaves the agent's file on disk. `submit` then still runs `silent write`, which brings up Neovim's "changed since reading" prompt. If the operator declines, the write does not happen. Even so, `write_lock(buf, "agent")` runs and "submitted" is sent. The agent then gets the turn with its own file on disk, and the operator's edits stay unsaved in a buffer that is now read-only. **Fix:** after `violation(buf)` in `submit`, if the outcome was a failed copy, refuse to submit, as the free-turn branch already does. Add a test that pairs the "copy cannot be kept" setup with `<M-CR>`.

4. **Minor**
   - `violation()` decides whether to overwrite with `band:find("not be kept")`, so control flow depends on display text. Return a tagged outcome (deleted / copied / copy failed) and build the band and message from it. This belongs with BR-3 (ARCH-ORDER).
   - The "is something owed, and since when" calculation inside `probe` is business logic sitting inside the IO callback. It could be a pure `owed_since(lock_since, owed_list)` with unit tests (ARCH-PURE).
   - The `## Plan` step still says "`--actors --json` Resting", but the Revisions entry and the code use LastActivity.

5. **Test coverage**
   - Tests cover: a violation found by the watch, by `:checktime` and by `submit`; a second violation in the same turn sends no second message; deletion; a failed copy; an unloaded buffer; the band's minute count; and the ping (sent once, not sent mid-turn, not before the threshold, nothing owed, owner not live, nulls, owed items reported by couch with no lock).
   - Not covered: `submit` after a failed copy (the Important finding above).
   - The ping tests use one real-time order of events and have no way to inject a different one. That is acceptable at this size.

6. **Architecture notes**
   - **ARCH-DRY:** pass.
   - **ARCH-PURE:** pass, with the minor note above.
   - **ARCH-PURPOSE:** pass. BR-1 was fixed for the whole class.
   - **ARCH-MOCK:** BR-4 is still open. The fake couch has no conformance check yet, which is a reasonable deferral until pair#437 lands.
   - **ARCH-CONSTRAINTS:** pass. Each buffer runs one probe at a time, at most once per check interval.
   - **ARCH-SECURE:** pass. Couch output is handled as untrusted input and failures are visible.
   - **ARCH-ORDER:** BR-3 is still open. The per-buffer state is still a set of loose flags (`violated` is now a string or false, plus `complained`, `probing`, `probed`, `pinged`).
   - **ARCH-FUNERAL:** pass. There is one `.clobbered` file per file, and each violation overwrites it. The header comment's claim that it is "removed by whoever reads it" isn't backed by any code, but it is bounded at one file.

7. **Plan revisions:** add a `## Revisions` entry saying the ping's "turn ended" test is `now - LastActivity >= QUIET_SECONDS`, not `Resting`, so the Plan step's wording matches the code.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      query() decodes with luanil and returns nil unless Code=ok; list()/find_actor type-check; probing reset on all paths; integration test with Owed:null, Status:null, Binding:null, LastActivity:null fails under the old `Owed or {}` code and passes now.
  - id: BR-2
    disposition: addressed
    note: |
      violation() distinguishes deleted / copied / copy-failed; a failed copy is never overwritten and the message says so; tests for deletion and for a failed copy (directory at .clobbered) both pass.
  - id: BR-3
    disposition: not-addressed
    note: |
      violated now carries the outcome text, but violated/complained/probing/probed/pinged are still independent fields, and violation() branches on its own band text.
  - id: BR-4
    disposition: not-addressed
    note: |
      Reasonably deferred until pair#437 lands the verb; still open.
  - id: BR-5
    disposition: not-addressed
    note: |
      README still lacks session-sync and session_sync_ping_minutes; the author declined, and atlas documents it.
findings:
  - id: new
    severity: Important
    family: unchecked-io-before-destructive-write
    title: |
      submit hands the turn to the agent after violation() left the agent's copy on disk (copy failed)
    detail: |
      This is the 2nd finding in family unchecked-io-before-destructive-write. Rule: every caller of violation() must act on its outcome. When the outcome is "copy failed", no later writer (submit, write_lock agent) may proceed. Return a tagged outcome from violation(), make submit refuse on copy-failed the way the free-turn branch refuses, and test <M-CR> after a failed copy.
```

---

## Re-review — 2026-10-11T00:18:28-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 314 — Session-sync hardening: no reload prompt under the operator's lock, complain to the agent, a 'TL owes' band, and a liveness ping |
| repo | parley.nvim |
| issue file | workshop/issues/000314-session-sync-hardening-no-reload-prompt-under-the-operator-s-lock-complain-to-the-agent-a-tl-owes-band-and-a-liveness-ping.md |
| boundary | whole-issue close |
| milestone | — |
| window | 6a4bf805419155016eab0c3e42d250da591ab4b3..e53f5d94d977c82ff14d2341688a04215f9a4506 |
| command | sdlc close --issue 314 |
| reviewer | claude |
| timestamp | 2026-10-11T00:18:28-07:00 |
| verdict | SHIP |

## Review

Checking the BR-6 fix is done; now running the session-sync specs.

```verdict
verdict: SHIP
confidence: high
```

**Verdict: SHIP.** The BR-6 fix is complete and has a test. `violation()` now returns whether the file on disk is the operator's copy. If the agent's copy can't be kept, `violation()` remembers it by the disk mtime (`s.unkept`), so the watch tick no longer retries or re-sends the complaint every second. `submit` refuses on that outcome (`lua/parley/session_sync.lua:567-571`). I checked every writer that can follow a violation:

- **Submit:** its `silent write` and `write_lock(agent)` are both skipped after a refusal.
- **Watch tick and `FileChangedShell`:** they only call `violation()` and then render.
- **A plain `:w`:** it meets Neovim's own "changed since reading" prompt, as documented.

So no later writer can overwrite the agent's copy. Both session-sync specs pass (`make test-spec SPEC=modes/session_sync`: 25/0/0 and 9/0/0). The only open items are the three earlier Minor findings, and none of them blocks the gate.

1. **Strengths**
   - `violation()` now returns a value that every caller must handle. That fixes the whole `unchecked-io-before-destructive-write` family, not just the submit site.
   - Remembering the unkept copy by mtime (`:289`) gives free deduplication: the same agent write is not reprocessed, and a new agent write (new mtime) is tried again.
   - The BR-6 regression test (`tests/integration/session_sync_spec.lua:290-295`) checks the observable result: the lock stays `holder: operator`, the agent's line 8 is still on disk, and no extra message is sent. Without the fix, submit would write over the file and hand the turn to the agent, so the test would fail.
   - JSON reads stay null-safe. The parser maps `null` to nil, `list()` guards the arrays, and `find_actor` and `parse_time` reject unexpected types.

2. **Critical:** none.

3. **Important:** none.

4. **Minor:** BR-3, BR-4 and BR-5 are still open (see the dispositions below). The new `unkept` field adds to the BR-3 group of loose per-buffer flags, so I am keeping BR-3 open rather than raising a new finding.

5. **Test coverage:** the failed-copy test covers four things: the complaint is sent once, there is no retry loop, submit refuses, and the agent's file is preserved. Nothing tests a new agent write (new mtime) after an unkept copy, which should trigger a fresh copy attempt. That gap is low-risk.

6. **Architecture**
   - **ARCH-DRY:** pass.
   - **ARCH-PURE:** pass. `view`, `turn`, `parse_time` and `find_actor` are pure functions and have unit tests.
   - **ARCH-PURPOSE:** pass. All callers of `violation()` now act on its outcome.
   - **ARCH-MOCK:** flag. BR-4 is still open.
   - **ARCH-CONSTRAINTS:** pass. Polling is 1 s, there is at most one probe at a time per buffer, and the probe check is throttled to once a minute.
   - **ARCH-SECURE:** pass. Untrusted couch JSON is type-checked at every read.
   - **ARCH-ORDER:** flag. BR-3: the per-buffer turn flags (`violated`, `complained`, `unkept`, `probing`, `pinged`) should become one tagged operator-turn state.
   - **ARCH-FUNERAL:** pass. There is one `.clobbered` file per file, overwritten by the next violation, and timers are closed when the buffer is unloaded or wiped.

7. **Plan revisions:** none needed for BR-6. When pair#437 lands, add a conformance-check entry for BR-4.

```findings
dispose:
  - id: BR-6
    disposition: addressed
    note: |
      violation() returns whether the operator's copy is on disk; submit refuses on a failed copy (session_sync.lua:567-571). The regression test at the session_sync_spec.lua:290 failed-copy case asserts the lock stays with the operator and the agent's text stays on disk. The remaining writers (watch tick, FileChangedShell) only render.
  - id: BR-3
    disposition: not-addressed
    note: |
      Still loose booleans; the new unkept field adds to the group. Minor; fold into a tagged operator-turn state later.
  - id: BR-4
    disposition: not-addressed
    note: |
      Still no live conformance check for the fake couch; deferred until pair#437 lands. Minor.
  - id: BR-5
    disposition: not-addressed
    note: |
      README.md is unchanged in the window; session-sync and session_sync_ping_minutes are still undocumented there. Minor.
```
