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
