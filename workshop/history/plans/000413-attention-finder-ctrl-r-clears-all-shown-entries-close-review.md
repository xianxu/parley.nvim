# Boundary Review — parley.nvim#413 (whole-issue close)

| field | value |
|-------|-------|
| issue | 413 — Attention finder: Ctrl+R clears all shown entries |
| repo | parley.nvim |
| issue file | workshop/issues/000413-attention-finder-ctrl-r-clears-all-shown-entries.md |
| boundary | whole-issue close |
| milestone | — |
| window | 17bb5a2ce13566654fb8a94e5af2a66cf294c12b..fe309b7064129e5e25968eab1c12f9a7356999aa |
| command | sdlc close --issue 413 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-22T13:11:33-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The implementation satisfies the issue’s clear-shown behavior, preserves hidden entries, and uses the existing leased store. Focused tests passed. No blocking findings; two nearby comments need a minor correction.

Done-when: current — exact shown-row removal and hidden-row preservation cover the sweep exception; resubmit and documentation requirements remain applicable.

1. **Strengths**

   - Clear uses the picker’s filtered snapshot, including visible ancestor context (`float_picker.lua:1293`).
   - The model reuses side retirement and counts actual removals, including duplicate/missing-path handling (`attention_model.lua:125`).
   - README and both relevant atlas pages document the key, configuration, and native register-paste override.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** Store comments at `attention_store.lua:92` and `:104` still describe sweeping unconditionally.

```findings
findings:
  - id: new
    severity: Minor
    family: comments-match-execution-policy
    title: |
      Store comments omit the clear-event sweep exception
    detail: |
      Both lua/parley/attention_store.lua:92 and :104 describe applying a transition followed by a sweep, but :96 deliberately skips sweeping for clear events. These are both instances in this window; qualify both comments to describe the exception.
```

5. **Test coverage notes**

   `make test-spec SPEC=ui/attention_finder` passed, including model, store, real picker, shared picker/keybinding, and architecture checks. Coverage exercises mixed states, both scopes, filtering, ancestor context, empty results, persistence, resubmit, late observations, and expired hidden seen entries. `git diff --check` passed. The full suite and second Neovim version were not independently rerun.

6. **Architectural notes**

   - **ARCH-DRY: pass** — reuses retirement, filtering, and key resolution.
   - **ARCH-PURE: pass** — removal logic stays in the pure model; UI/store orchestration remains thin.
   - **ARCH-PURPOSE: pass** — clears the exact shown set across scope and filter.
   - **ARCH-EVOLVE: pass** — no persisted format or version changes.

7. **Plan revision recommendations:** None.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"1ccbea03-9877-4637-8c00-a5c9725b571d","repository":"github.com/xianxu/parley.nvim","issue_id":"000413","recipe":"small-diff-review","round":1,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/4c4ba7062ec2c944","reviewed_head":"fe309b7064129e5e25968eab1c12f9a7356999aa","slot":"parley.nvim:1","requested_at":"2026-10-22T20:10:22.853128Z"},"phase":"finished","pid":81833,"started_at":"2026-10-22T20:10:22.952861Z","finished_at":"2026-10-22T20:11:32.906123Z","session_id":"01a1653c-748e-7ae3-acfc-e1c1b15e5b85","outcome":"returned"}] -->
