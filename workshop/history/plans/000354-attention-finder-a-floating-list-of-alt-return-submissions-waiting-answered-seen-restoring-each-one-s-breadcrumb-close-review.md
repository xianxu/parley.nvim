# Boundary Review — parley.nvim#354 (whole-issue close)

| field | value |
|-------|-------|
| issue | 354 — Attention finder: a floating list of Alt+Return submissions (waiting / answered / seen), restoring each one's breadcrumb |
| repo | parley.nvim |
| issue file | workshop/issues/000354-attention-finder-a-floating-list-of-alt-return-submissions-waiting-answered-seen-restoring-each-one-s-breadcrumb.md |
| boundary | whole-issue close |
| milestone | — |
| window | d455f7ebc1a684063ccbfc3e904cc9adf1ff49cd..57c581887b9cb89eec44d9e4c2e004128982750a |
| command | sdlc close --issue 354 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T18:56:25-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Reviewing the changes since the last round (head 4fdadd49): the new "viewed" semantics, the current-file filter, and the Alt+Space binding. Next I'm checking their tests and docs.

Prior findings look addressed; now running the attention specs and a quick BR-16 revert check.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The issue does what its Spec and Plan say. All five attention spec files pass at head: model 34, store 15, rows 6, finder 23, record 12. The 15 mapped keybinding spec files also pass. Three changes landed since the last round (head 4fdadd49):
- seen now counts any time the operator looks at the file, through the new `viewed` event and its autocmds;
- the finder hides the file in the current window;
- the finder is bound to Alt+Space and `<C-y><Space>`, and `<C-y><Space>` still accepts a completion when the popup is showing.

All three are recorded in the plan's Revisions, the atlas and the README, and each has a spec. I reverted the BR-16 fix in the checkout: its spec went red, and it passed again once restored. Nothing blocks. Two things are left: BR-7, a Minor finding still open, and two small new gaps. Issue #367, which the docs point to, isn't in the tracker, and two of the five view triggers have no test.

1. **Strengths**
   - `lua/parley/attention.lua:29-34`: every store change goes through one local `apply`, which rebuilds the in-memory set of answered paths. A cursor move only does a table lookup. If a view is rejected (for example, in the same second as the answer), the path goes back into the set and the next move retries.
   - `lua/parley/attention_model.lua:161-172`: `viewed` is pure and has guards (it counts only after `answered_at`, and only for answered entries). The unit specs cover a view before or at the answer and a view of a waiting, seen or unknown path.
   - `lua/parley/keybinding_registry.lua:1420-1429`: `pum_passthrough` feeds the key noremap. Its spec drives a real `<C-n>` completion popup.
   - BR-16's fix (`attention.lua:93`, `type(data) ~= "table"`) is pinned by "a probe that raises as it starts reads as couch unavailable". I checked this by reverting it.

2. **Critical findings:** none.

3. **Important findings:** none.

4. **Minor findings**
   - `atlas/ui/attention_finder.md:17` and the issue Log point to #367 for bringing back side docs the agent rewrites. No `000367-*` issue exists in `workshop/issues/` or `workshop/history/` at head, so the deferral isn't tracked.
   - The WinEnter and WinScrolled triggers have no spec (`attention.lua:197-206`). Neither does the guard that ignores a scroll in a window other than the current one. Only BufEnter and CursorMoved are covered.
   - The `pum_passthrough` check `key:sub(1, 5) == "<C-y>"` is case-sensitive. A user key written as `<c-y><space>` would lose the passthrough.
   - In `viewed`, if the store write fails (busy lease), the view is lost until the next `apply` rebuilds the set. A warning is shown, so the failure is visible.

5. **Test coverage notes:** the new behaviour is tested through the real autocmds and store, against the stateful fake Couch. The "answered while already current, then a cursor move" case matches the gap the operator found. The current-file filter has its own spec.

6. **Architecture notes**
   - ARCH-DRY: pass. Frontmatter is read through `frontmatter.parse`, the side folder through `side_path`, probes run through `async_operation_queue`, and store writes go through the one `apply`.
   - ARCH-PURE: pass. `viewed` is a pure transition, and the autocmd layer is thin.
   - ARCH-PURPOSE: pass. The #367 deferral is a separable extension the TL approved, but it needs to be filed (finding below).
   - ARCH-MOCK: the fake is stateful (`--owe`/`--fold`). BR-7 is still open.
   - ARCH-CONSTRAINTS: pass. The cursor-move path costs a lookup, a store write happens once per answered file, and the startup `Store.load` reads at most 256 entries.
   - ARCH-SECURE: pass. The store is parsed into typed entries when read, and a reply that isn't a table counts as a failure.
   - ARCH-ORDER: pass. The answered set is rebuilt after every store write. Answers observed in another editor aren't seen here; the Revisions say so ("paths this editor last saw answered").
   - ARCH-FUNERAL: pass. Entries and `retired` are capped at 256, and the augroup is replaced with `clear = true`.

7. **Plan revision recommendations:** none needed. The Revisions entries for the key decisions and for "seen however the operator looks" match the code.

```findings
dispose:
  - id: BR-6
    disposition: addressed
    note: |
      Plan Task 6 (plan line 219) now includes README.md, and README.md:95-103 documents Alt+Space, Ctrl+Y Space, :ParleyAttention and attention.seen_grace_minutes.
  - id: BR-7
    disposition: not-addressed
    note: |
      No conformance script covers the --send-to receipt line, and the atlas (attention_finder.md:22,41) does not say this is unchecked. Plan line 98 still points only at the operator's smoke check.
  - id: BR-16
    disposition: addressed
    note: |
      attention.lua:93 treats anything but a table as a failure. Reverting it to `if not data` fails "a probe that raises as it starts reads as couch unavailable" (verified in the checkout, then restored).
findings:
  - id: new
    severity: Minor
    kind: defect
    family: deferred-work-untracked
    title: |
      The #367 deferral of side-doc resurfacing is cited but not in the tracker
    detail: |
      atlas/ui/attention_finder.md:17 and the issue Log say bringing back a seen or retired side doc on an agent rewrite is #367, but no 000367-* issue exists in workshop/issues or workshop/history at head. File #367 before closing, so the deferred behaviour is tracked.
  - id: new
    severity: Minor
    kind: defect
    family: trigger-branch-untested
    title: |
      The WinEnter and WinScrolled view triggers and the current-window scroll guard have no spec
    detail: |
      attention.lua:197-206 handles WinScrolled by checking tonumber(args.match) against the current window, but the specs fire only BufEnter and CursorMoved. Add one spec: scrolling a non-current window on an answered file leaves it answered, and scrolling it while it is current makes it seen.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"8a05cd77-a1c8-4685-8430-ec5a04bf294d","repository":"github.com/xianxu/parley.nvim","issue_id":"000354","recipe":"milestone-review","round":8,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/fbb274b6cf23063f","reviewed_head":"57c581887b9cb89eec44d9e4c2e004128982750a","slot":"parley.nvim:3","requested_at":"2026-10-17T01:51:26.069088Z"},"phase":"finished","pid":94254,"started_at":"2026-10-17T01:51:26.367893Z","finished_at":"2026-10-17T01:56:24.566937Z","session_id":"d2e4210c-5763-4cae-bcc9-584ee42c47de","outcome":"returned"}] -->
