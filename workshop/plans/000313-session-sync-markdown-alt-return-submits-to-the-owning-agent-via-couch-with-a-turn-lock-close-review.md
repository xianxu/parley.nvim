# Boundary Review — parley.nvim#313 (whole-issue close)

| field | value |
|-------|-------|
| issue | 313 — session-sync markdown: Alt+Return submits to the owning agent via couch, with a turn lock |
| repo | parley.nvim |
| issue file | workshop/issues/000313-session-sync-markdown-alt-return-submits-to-the-owning-agent-via-couch-with-a-turn-lock.md |
| boundary | whole-issue close |
| milestone | — |
| window | 03dce091dce9b627d0142e44179c1ee6f5a2baa7..39f6b58261ec49bebfc9183b51f7be46f6417f39 |
| command | sdlc close --issue 313 |
| reviewer | claude |
| timestamp | 2026-10-10T13:15:14-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Now the full session_sync.lua and init.lua diffs (truncated above).

Both specs pass at HEAD (9 integration, 6 unit). I'm writing up the review now.

```verdict
verdict: FIX-THEN-SHIP
confidence: medium
```

The issue delivers what its Spec and both Revisions ask for. A `type: session-sync` file gets an `<M-CR>` submit that's decided when the key is pressed. A sidecar lock names whose turn it is: free, operator or agent. The send goes out through couch, and a failed send gives the turn back. A poll detects the agent's reply and unlocks the buffer. `<C-g>u` is the manual escape. Each state renders as a full-width winbar band plus a StatusLine colour, with no lualine component. Atlas and traceability are updated. I ran `make test-spec SPEC=modes/session_sync` at HEAD 39f6b582 and both specs passed (9 integration, 6 unit). Nothing blocks shipping. Two ordering gaps are worth closing first because they're cheap. A couch exit that arrives after the turn has moved on can still rewrite the lock. And a free-state buffer can go stale without the operator seeing it, which reintroduces the clobbering the issue exists to prevent.

**1. Strengths**
- The pure core is cleanly separated. `parse_header`, `lock_body`, `turn` and `view` (`lua/parley/session_sync.lua:31-80`) are tested without IO. Every surface renders from `view`, so the label and colour mapping lives in one place (ARCH-DRY / ARCH-PURE).
- One `refresh(buf)` re-reads the turn from disk and derives `modifiable`, the poll's lifetime and the rendering from it. That's why a buffer reopened during the agent's turn is read-only for free, and there's no second in-memory copy of the turn to drift.
- The fake `couch` on PATH asserts the exact argv, and it writes that argv atomically through a tmp file and rename, which fixes the race noted in the Log. The failure path is tested through a real non-zero exit.
- `dispatch` decides at call time (`session_sync.lua` `M.dispatch`), so editing the frontmatter takes effect without re-attaching. Plain markdown keeps the review action, and a test covers that.
- Timer lifecycles are stated and enforced. The poll runs only during the agent's turn, the idle timer is replaced on each edit, and both close on `BufWipeout` (ARCH-FUNERAL).

**2. Critical:** none.

**3. Important**
- **A late couch exit can overwrite the current turn** (ARCH-ORDER, `session_sync.lua` `M.submit`, the `vim.system` callback). The callback only checks `state[buf]`. Example: submit #1's couch hangs, the operator presses `<C-g>u`, then submit #2 succeeds. When couch #1 finally exits non-zero, `fail()` writes `holder: operator` and makes the buffer editable while the agent is working on submit #2. A late failure after the agent has replied (lock deleted) would likewise create an operator lock the operator never took. The same thing happens if the buffer is wiped and reopened, because `state[buf]` is then the new state.
  - Fix: give each submit a generation number (`s.submit_seq`) and capture it in the callback. Act only if it still matches and `read_turn(buf) == "agent"`. Add a spec that unlocks and resubmits, then lets a delayed failing fake exit; the lock must stay `agent`.
- **A free-state buffer can be stale when the operator takes the turn** (ARCH-ORDER / spec purpose: "one side's edits get clobbered"). In the free state, `attach` relies only on `autoread`. Neovim reloads on `checktime` triggers (focus gained, buffer enter, shell commands), not when the file changes on disk. So if the agent rewrites the file while nvim already has focus, the operator's first keystroke takes the lock on outdated content. At submit, `silent write` then either hits the "file changed since reading" prompt or overwrites the agent's newer rewrite.
  - Fix: run `checktime` on the buffer before `write_lock(buf, "operator")`, refusing or warning if the disk copy is newer. Or watch the file with `uv.new_fs_event` while the turn is free. Add a spec that rewrites the file on disk in the free state, then edits, and asserts that neither copy is silently lost.

**4. Minor**
- `restart_idle` opens the lock file and closes and recreates a uv timer on every `TextChangedI`. That's cheap, but it's file IO on every keystroke; caching the turn in `refresh` would avoid it (ARCH-CONSTRAINTS).
- A buffer reopened with an existing `holder: operator` lock never starts the idle timer until the next edit, so a stale lock from an earlier session shows as "your turn" rather than "stale".
- If `silent write` fails inside `submit`, the Lua error propagates without a `session-sync:` prefix. The behaviour is correct (no lock is written); only the message could be clearer.
- The plan's Core-concepts prose still describes the first design. It says `attach` is idempotent via `vim.b[buf].parley_session_sync` (the code uses a module `state` table), mentions an eol extmark reminder, and says "unlock: lock file stays". The Revisions entries supersede most of this, but the table text is stale.
- `parse_header` reads only the first 40 lines. That's fine, but the limit isn't documented.

**5. Test coverage notes**
Every Done-when item has a test: lock creation, exact argv, failed send, reply reload, reopened read-only, unlock, stale state, dark-red colour, plain-markdown fallback. Not covered:
- out-of-order couch completions (Important #1);
- a disk change in the free state (Important #2).

The `BufModifiedSet` firing is simulated with `nvim_exec_autocmds`. The Log justifies this with a real-input headless check, and the live check covers it.

**6. Architectural notes (ARCH-* pass)**

| Principle | Result | Note |
|---|---|---|
| ARCH-DRY | pass | The private frontmatter reader is justified in the plan, with a promotion trigger for a shared helper. |
| ARCH-PURE | pass | Pure core, thin controller. |
| ARCH-PURPOSE | pass | All Spec and Revision items are delivered; the live check is logged. |
| ARCH-MOCK | pass (acceptable) | `couch` is fire-and-forget, so a stateless fake on PATH sharing the production argv seam fits. The live check with the ops TL served as conformance. |
| ARCH-CONSTRAINTS | pass | Minor note on per-keystroke IO. |
| ARCH-SECURE | pass | `owner` comes from file frontmatter but goes into an argv array, not a shell string. The lock is parsed defensively (an unknown holder is treated as the operator's turn, which blocks the agent). |
| ARCH-ORDER | flag | The two Important findings above. The turn state machine itself is explicit (lock file → `turn` → `refresh`), which is good. |
| ARCH-FUNERAL | pass | The agent removes the lock; the stale state names the case where the operator never submits; timers are bounded. |

**7. Plan revision recommendations**
- Add a Revisions entry noting that `attach` idempotency comes from the module `state` table (not `vim.b`), that `unlock` now rewrites the holder to `operator` instead of leaving the old lock in place, and that the Core-concepts prose describing the extmark reminder is superseded.

```findings
findings:
  - id: new
    severity: Important
    family: stale-async-completion-guard
    title: |
      A late couch exit can rewrite the lock after the turn has moved on (unlock and resubmit, or the agent already replied)
    detail: |
      The vim.system callback in M.submit checks only state[buf]. A failing exit from an earlier submit calls fail(), which writes holder: operator and makes the buffer editable during a later agent turn. Guard it with a per-submit generation number plus read_turn == agent, and add a spec with a delayed failing fake.
  - id: new
    severity: Important
    family: free-state-disk-staleness
    title: |
      In the free state the buffer can be stale, so the first keystroke takes the turn on outdated content and submit can overwrite the agent's rewrite
    detail: |
      autoread only reloads on checktime triggers (focus, buffer enter), not when the file changes on disk. Run checktime before write_lock(operator), or watch the file in the free state, and add a spec that rewrites the file on disk while free and then edits.
  - id: new
    severity: Minor
    family: per-keystroke-io
    title: |
      restart_idle reads the lock file and recreates a uv timer on every TextChangedI
  - id: new
    severity: Minor
    family: plan-text-drift
    title: |
      The plan's Core-concepts prose still describes vim.b idempotency, the eol extmark reminder and the old unlock-keeps-lock behaviour
  - id: new
    severity: Minor
    family: idle-timer-on-attach
    title: |
      A buffer reopened with an existing holder: operator lock never starts the idle timer, so it shows "your turn" instead of "stale" until the next edit
```

---

## Re-review — 2026-10-10T13:24:43-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 313 — session-sync markdown: Alt+Return submits to the owning agent via couch, with a turn lock |
| repo | parley.nvim |
| issue file | workshop/issues/000313-session-sync-markdown-alt-return-submits-to-the-owning-agent-via-couch-with-a-turn-lock.md |
| boundary | whole-issue close |
| milestone | — |
| window | 03dce091dce9b627d0142e44179c1ee6f5a2baa7..706d9f61858374f48d4f69e59bc87b9f87d77f05 |
| command | sdlc close --issue 313 |
| reviewer | claude |
| timestamp | 2026-10-10T13:24:43-07:00 |
| verdict | SHIP |

## Review

Prior fixes look sound so far. Next I'm checking whether parley's markdown auto-save can still overwrite the agent's rewrite (a BR-2 sibling).

Running the session-sync specs now to confirm the fixes hold.

```verdict
verdict: SHIP
confidence: medium
```

Round 2 at the close of #313. All five open findings from round 1 are fixed. BR-1 and BR-2 are fixed for every case, not just the one each finding named, and each fix has a spec that exercises it. The two session-sync spec files pass when I run them: 13 integration tests and 6 unit tests, with no failures. I found nothing that blocks the close. I'm raising two Minor findings, and both belong to families that are already open. The more important one: parley's markdown auto-save is a third way to write the file, and the round-1 submit guard doesn't cover it. Neovim's own "file changed since reading" prompt still stands in front of it, and parley has already warned the operator by then. So the agent's rewrite can only be lost if the operator answers that prompt "yes".

**Strengths**
- `lua/parley/session_sync.lua:337-349`: every completion checks three things before acting: the buffer state is the same, its submit generation still matches, and the lock on disk still says `holder: agent`. `unlock` also bumps the generation (`:375`). This covers late exits after an unlock, a resubmit or a reply, not just the one interleaving the finding named.
- `refresh` (`:192`) is the one place that applies the turn. It reads the turn from disk, then sets `modifiable`, starts or stops the watch, and renders. The cached `s.turn` exists only to avoid re-reading the lock on every keystroke.
- The pure functions `parse_header`, `turn`, `view` and `lock_body` have unit tests that need no IO. The couch call passes an argv array, so the `owner:` value can't inject shell syntax.
- The new specs drive real orderings: a slow failing fake couch, a disk rewrite under a stale buffer, and a file reopened during the operator's turn.

**Critical**
None.

**Important**
None.

**Minor**
1. **The submit guard can be bypassed through auto-save** (`init.lua:1799-1820` and `session_sync.lua:271-274`).
   - **Scenario:** the agent rewrites the file during a free turn, and the operator edits before the next watch poll (up to 1s later). The first edit only warns. Then `prep_md`'s auto-save runs `silent! write`. If the operator answers "yes" to Neovim's prompt, the agent's rewrite is overwritten, `s.loaded` advances, and `submit`'s `disk_changed` check passes.
   - **Family:** this is the 2nd finding in `free-state-disk-staleness`. Don't add a guard at this one write path.
   - **Rule:** the operator's turn must never start on a copy older than the file on disk. When taking the turn, if `disk_changed(buf)`, refuse the lock (reload, or undo the edit) instead of warning. Then every later writer (submit, auto-save, `:w`) is safe without needing its own guard.
2. **The atlas prose drifted** (`atlas/modes/session_sync.md`).
   - It says parley polls "during the agent's turn" only. The watch now also runs during free turns, reloading an unmodified buffer, and submit refuses when the file changed on disk. Neither change is documented.
   - It says `operator:` is "recorded as the lock holder", but the lock literally records `holder: operator`, and the `operator` key is parsed but never used.
   - **Family:** this is the 2nd finding in `plan-text-drift`. **Rule:** a behaviour fix updates every place that restates that behaviour (the module header comment, the plan's Revisions, the atlas) in the same commit.

**Test coverage**
- The late-exit spec depends on wall-clock timing: a 0.4s fake sleep against `vim.wait(800)`. Under heavy load it could show only one interleaving. A seam for completion order, such as an injected `system` function, would make it deterministic.
- The specs don't wire `prep_md`'s auto-save, so the path in Minor 1 is not exercised.

**Architecture**
- **ARCH-DRY:** pass. The frontmatter reader is justified in the plan, and `reload` and `close_timer` are shared helpers.
- **ARCH-PURE:** pass. The pure core is unit-tested; the shell around it is thin.
- **ARCH-PURPOSE:** pass. All the Done-when items are delivered, including the live check.
- **ARCH-MOCK:** pass, with a note. The fake couch on PATH is stateless, which is fine for a one-shot send. The only conformance check against the real binary was the manual live check.
- **ARCH-CONSTRAINTS:** pass. Each keystroke is now cheap, and the 1s poll costs one stat plus one lock read per buffer.
- **ARCH-SECURE:** pass. An unparseable lock counts as the operator's turn, which is the conservative reading.
- **ARCH-ORDER:** acceptable, with a note. The turn is an enum read from disk, and `stale` matters only during the operator's turn. The ordering tests rely on timing (see Test coverage).
- **ARCH-FUNERAL:** pass. The agent removes the lock; the timers close on BufWipeout.

**Plan revisions**
- None needed beyond the atlas fix in Minor 2.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Generation + state identity + read_turn==agent guard (session_sync.lua:337-349), unlock bumps gen; spec "a late failing exit..." passes.
  - id: BR-2
    disposition: addressed
    note: |
      Free-turn watch reloads unmodified buffer; submit refuses when disk_changed; specs for both pass (auto-save sibling raised as Minor).
  - id: BR-3
    disposition: addressed
    note: |
      restart_idle uses cached s.turn and reuses one timer; first-edit read_turn short-circuits behind s.turn=="free".
  - id: BR-4
    disposition: addressed
    note: |
      Plan Revisions "close review round 1" supersedes the vim.b / extmark / unlock prose (append-only convention).
  - id: BR-5
    disposition: addressed
    note: |
      attach now calls restart_idle; spec "a file reopened during an operator turn still turns stale" passes.
findings:
  - id: new
    severity: Minor
    family: free-state-disk-staleness
    title: |
      The markdown auto-save (init.lua:1818) can write a stale copy, which bypasses submit's disk_changed guard
    detail: |
      2nd finding in this family. Rule: the operator's turn must never start on a copy older than the file on disk. When taking the turn, refuse the lock (reload or undo) when disk_changed instead of warning, so every writer (submit, auto-save, :w) is safe without its own guard.
  - id: new
    severity: Minor
    family: plan-text-drift
    title: |
      The atlas still says the lock is polled only during the agent's turn and that operator: is recorded as the lock holder
    detail: |
      2nd finding in this family. Rule: a behaviour fix updates every place that restates that behaviour (module header, plan Revisions, atlas) in the same commit. The free-turn reload and the submit refusal are missing from atlas/modes/session_sync.md.
```

---

## Re-review — 2026-10-10T13:28:37-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 313 — session-sync markdown: Alt+Return submits to the owning agent via couch, with a turn lock |
| repo | parley.nvim |
| issue file | workshop/issues/000313-session-sync-markdown-alt-return-submits-to-the-owning-agent-via-couch-with-a-turn-lock.md |
| boundary | whole-issue close |
| milestone | — |
| window | 03dce091dce9b627d0142e44179c1ee6f5a2baa7..df3b00d600c47b9de78854214616b922db7d5a67 |
| command | sdlc close --issue 313 |
| reviewer | claude |
| timestamp | 2026-10-10T13:28:37-07:00 |
| verdict | SHIP |

## Review

Reviewing #313's round-3 fix. Next I'm running the session-sync specs to confirm the stale-edit regression test passes.

```verdict
verdict: SHIP
confidence: high
```

I recommend SHIP. Both open findings are fixed in df3b00d6, and nothing new reaches Minor or above. BR-6 is fixed in the right place. The disk-changed guard used to warn after the first edit had already taken the lock. It now runs before the lock is written, at `lua/parley/session_sync.lua:268-281`: if the file changed on disk, parley reloads the buffer and returns without taking the turn. So no writer (submit, auto-save or `:w`) can start an operator turn on an old copy. The new test "the first edit on a stale copy reloads instead of taking the turn" (`tests/integration/session_sync_spec.lua:186`) would fail on the old code, because the old code wrote the lock before warning and the test asserts that no lock exists. BR-7 is fixed too: `atlas/modes/session_sync.md` now says the file is watched whenever the turn is not the operator's, describes the reload on a stale first edit and the submit refusal, and no longer calls `operator:` the lock holder. `make test-spec SPEC=modes/session_sync` passes: 14 integration and 6 unit tests, no failures.

1. **Strengths**
   - The turn is always read from disk (`read_turn`), so a reopened buffer shows the right state, and a single check now protects every writer.
   - The generation counter in `submit` (`session_sync.lua:327-333`) stops a late couch exit from changing a turn that has already moved on.
   - The pure helpers (`parse_header`, `lock_body`, `turn`, `view`) have direct unit tests. The integration specs run against a fake `couch` on PATH that records the exact arguments it was called with.
   - `<M-CR>` decides at call time whether the file is session-sync (`dispatch`), so editing the frontmatter takes effect at once.

2. **Critical:** none.
3. **Important:** none.
4. **Minor** (below the bar, not raised as findings):
   - The tests fire `BufModifiedSet` by hand. The `:edit!` reload inside that autocmd, triggered by a real keystroke in insert mode, is only checked in a headless run. It is worth one live check that typing on a stale copy reloads cleanly.
   - `disk_changed` compares modification times, so a write that only touches the file (same content, new mtime) also drops the first keystroke. That is safe but a little noisy.
5. **Test coverage:** every lock-holder transition, the late failing couch exit, a stale free buffer, the submit refusal, a reopened buffer, rendering, and the fallback to the review action are all covered.
6. **Architecture:**
   - **ARCH-DRY:** pass.
   - **ARCH-PURE:** pass. The decision logic is pure; the IO stays in thin local helpers.
   - **ARCH-PURPOSE:** pass. All the Done-when items are delivered.
   - **ARCH-MOCK:** pass. The fake couch sits behind the same seam production uses (PATH lookup of `couch`).
   - **ARCH-CONSTRAINTS:** pass. The watch polls once a second and only outside the operator's turn; the idle timer is reused.
   - **ARCH-SECURE:** pass. Lock text that can't be parsed counts as the operator's turn, which is the safe side, and couch gets an argument list rather than a shell string.
   - **ARCH-ORDER:** pass, with a note. Turn state is derived from the lock file rather than from a set of flags, and stale completions are guarded by generation and by re-reading the turn.
   - **ARCH-FUNERAL:** pass. The lock is removed by the agent's reply, and timers are closed on `BufWipeout`.
7. **Plan revisions:** none needed.

```findings
dispose:
  - id: BR-6
    disposition: addressed
    note: |
      First-edit guard now reloads instead of taking the lock when disk_changed (session_sync.lua:268-281); regression test at integration spec :186 fails on the old lock-then-warn code.
  - id: BR-7
    disposition: addressed
    note: |
      atlas/modes/session_sync.md now describes the watch outside the operator turn, the free-turn reload, the stale first-edit reload and submit refusal; operator: no longer called the lock holder.
```
