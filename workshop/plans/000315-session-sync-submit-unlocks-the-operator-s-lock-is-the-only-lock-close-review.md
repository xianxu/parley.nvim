# Boundary Review — parley.nvim#315 (whole-issue close)

| field | value |
|-------|-------|
| issue | 315 — session-sync: submit unlocks; the operator's lock is the only lock |
| repo | parley.nvim |
| issue file | workshop/issues/000315-session-sync-submit-unlocks-the-operator-s-lock-is-the-only-lock.md |
| boundary | whole-issue close |
| milestone | — |
| window | 5b47b1823d5508b191a9989f13d858aee1375e14..c260fa2e658b3a087a865568104fa3c620833b7f |
| command | sdlc close --issue 315 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-11T09:40:43-07:00 |
| verdict | SHIP |

## Review

Checked the diff; now looking at leftover references and the tests.

Tests pass (35/35, same pre-existing cmdline noise at base). Checking README and the `FileChangedShell` reload path, then writing the verdict.

```verdict
verdict: SHIP
confidence: high
```

The change does what #315 asks for. Submit now saves, deletes `<file>.lock` and sends `submitted: <path>`. The `holder: agent` rewrite, the read-only buffer, the submit-generation guard and `<C-g>u` unlock are gone everywhere they appeared: config, registry, init binding, atlas and keybindings atlas. `M.turn` reads a legacy agent lock as free. The band and the ping come only from couch's owed events. The first-edit race now takes the lock and goes through `violation(buf, true)`, so the operator's text is kept and the agent's copy goes to `.clobbered`.

I ran `make test-spec SPEC=modes/session_sync` at head: 25/25 integration and 10/10 unit tests pass. It prints one `Error in command line:` line, and the same line appears at base, so it was already there. Every `## Done when` clause has a test. The two-state clauses are tested in both states: clean-buffer reload with no lock and the violation path under the operator's lock (#314 tests); band with owed events and band empty or failing. Nothing blocks the gate. Three Minor findings remain: a ping guard that can never fire, a forced re-probe that can be dropped or skipped (so the "within one tick" claim doesn't always hold), and a pure helper that could be pulled out.

**1. Strengths**
- `lua/parley/session_sync.lua:79-84`: `M.turn` handles the legacy lock in one place. Every consumer (`read_turn`, the watch, `FileChangedShell`, submit) goes through it, so no caller needs a separate legacy check.
- `M.view` (`:98-107`) stays pure and covers the new `owed` state. The unit tests check that the operator's states win over `owed` (`tests/unit/session_sync_spec.lua:46-48`).
- Each place the agent lock was used was removed or replaced: the `lock_minutes`/`lock_mtime` band, `lock_owed` in the ping, `modifiable` toggles in `reload`/`refresh`, the `unlock` key across config, registry and init, and the `ParleySessionSyncAgent` highlight. A grep finds nothing left over outside the issue file.
- The race test (`tests/integration/session_sync_spec.lua:217-230`) checks the lock, the buffer, the file on disk, `.clobbered`, the band wording and the couch message wording.
- Ping tests now feed a fake `status --json`. They include a negative case (a legacy agent lock 60 minutes old owes nothing) and a positive one (pings while the operator holds the lock).

**2. Critical findings**
None.

**3. Important findings**
None.

**4. Minor findings**
- **M1 — the "reply landed" ping guard can never fire.** At `session_sync.lua:370-371` the comment says "The reply may have landed while couch answered", and the guard checks `s.owed ~= since`. But only this same probe callback writes `s.owed`, a few lines earlier, and `s.probing` stops a second probe from running in between. So the condition is always false. The old code re-read the lock at this point, so the guard did something. Fix: either drop the clause and the comment, or re-query `status` before sending the ping. This is the only dead guard in the window.
- **M2 — the forced re-probe doesn't always happen.** The atlas and Plan say the probe also runs "right after a submit or a reload", so the band follows within one tick. That fails in three places:
  - `reload()` (`:265-271`) sets `probed = nil` and calls `probe`, but `probe` returns early while `s.probing` is set. If a probe is in flight, the forced one is dropped.
  - The submit success callback (`:592-595`) has the same problem.
  - A reload through `FileChangedShell` (`fcs_choice = "reload"`, on focus or `:checktime`) never forces a probe at all.

  In each case the band can lag by up to `PING_CHECK_MS` (60 s). Fix: set a `reprobe` flag that the in-flight callback acts on, and call the forced probe from `FileChangedShellPost` as well.
- **M3 — the oldest-owed calculation is inline in the IO callback.** The min-over-`Owed[].At` loop (`:347-352`) sits inside the couch callback. A pure `M.oldest_owed(status)` would let the unit tests cover the null and garbage cases without going through the fake couch (ARCH-PURE, minor). This is the only such site.
- **Nit:** in `atlas/modes/session_sync.md:46`, "They drive the band. When owed for …" runs well past the file's line width.
- **Nit:** the `lock_body` doc says "parley only writes operator", but the unit test still builds an `agent` body. That's fine, since the legacy test fixture uses it.

**5. Test coverage notes**
- Each Done-when row is covered:
  - Lock gone and buffer editable after submit (`:125`).
  - Silent reload, both by the watch (`:153`) and by `:checktime` (`:168`).
  - Agent write under the lock gives no prompt (#314 tests, kept).
  - Owed band from a fake status (`:324`).
  - Ping from owed events, including while the operator holds the lock (`:410`).
  - A legacy agent lock doesn't block the operator (`:179`) and owes nothing (`:342`, `:380`).
- Not tested:
  - Submit where removing the lock fails (`cannot remove`).
  - The M2 cases: a forced probe while one is in flight, and a `:checktime` reload refreshing the band.

**6. Architectural notes**
- **ARCH-DRY: pass.** No duplicated blocks. The race and under-lock wording share one `violation()` through the `verb`/`when` parameters.
- **ARCH-PURE: pass, with the M3 note.** `turn` and `view` are pure and unit-tested. IO stays in `probe`, `submit` and the autocmds.
- **ARCH-PURPOSE: pass.** I checked every consumer of the agent lock (band, ping, read-only, unlock key, config, registry, init, atlas, keybindings atlas): each one now uses the operator-lock-only model or is removed. No follow-up has been put off.

**7. Plan revision recommendations**
None needed. The Core-concepts table matches the code: `turn`, `view` and `violation` are modified, `owed_minutes` is new, and `lock_minutes` and `unlock` are deleted. If M2 isn't fixed, change the Plan's "so the band follows within one tick" to say a probe already in flight delays it.

```findings
findings:
  - id: new
    severity: Minor
    family: dead-guard-after-model-change
    title: |
      Ping's "reply may have landed" guard (s.owed ~= since) can never be true
    detail: |
      session_sync.lua:370-371. Only this same probe callback writes s.owed, and s.probing blocks a concurrent probe, so the check is always false. The old code re-read the lock there. Either drop the clause and its comment, or re-query status before pinging. This is the only instance in the window.
  - id: new
    severity: Minor
    family: forced-probe-not-guaranteed
    title: |
      The forced re-probe after a submit or reload can be dropped or skipped, so the band can lag up to 60 s
    detail: |
      All instances: reload() at :265-271 and the submit success callback at :592-595 both return early when s.probing is set (a probe in flight), and a FileChangedShell reload (fcs_choice "reload", on focus or :checktime) forces no probe at all. Use a reprobe flag that the in-flight callback acts on, and call the forced probe from FileChangedShellPost, or reword the Plan/atlas claim.
  - id: new
    severity: Minor
    family: pure-logic-in-io-callback
    title: |
      The oldest-owed calculation is inline in the couch callback; could be a pure M.oldest_owed(status)
    detail: |
      session_sync.lua:347-352 (ARCH-PURE). Pulling it out would let the unit tests cover null and garbage Owed entries without the fake couch. This is the only such site.
```
