# Boundary Review — parley.nvim#393 (whole-issue close)

| field | value |
|-------|-------|
| issue | 393 — spelling: the Blink corrections menu is off by default (underlines stay on) |
| repo | parley.nvim |
| issue file | workshop/issues/000393-spelling-the-blink-corrections-menu-is-off-by-default-underlines-stay-on.md |
| boundary | whole-issue close |
| milestone | — |
| window | e6737a3a0c75df580efb761a5e10542e109a8ea8..bccb5aa99d44c54ee946f806bc0487d927a0c56f |
| command | sdlc close --issue 393 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-18T21:18:55-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned change fulfills #393: bare setup retains spell underlines and disables both corrections menus; explicit Blink opt-in restores suggestions. The mapped tests pass, and no blocking defects were found.

Done-when: current — both default-off and explicit-on behavior remain covered; the revisions clarify documentation and verification without expanding the behavior contract.

```findings
{}
```

1. **Strengths**
   - One shared default changes plugin and packaged-app behavior (`lua/parley/config.lua:322`).
   - The regression exercises real setup and chat attachment with a ready, stateful Blink backend, plus an opt-in positive control (`tests/integration/spell_blink_spec.lua:143`).
   - Atlas documentation correctly explains table replacement and includes `enable = true` in the opt-in example (`atlas/chat/spell_typeahead.md:50`).

2. **Critical findings:** None.

3. **Important findings:** None. Atlas covers the changed default; README has no spelling-default claim requiring correction.

4. **Minor findings:** None.

5. **Test coverage:** `make test-spec SPEC=chat/spell_typeahead` passed all 79 cases. `git diff --check` passed. The full suite was not rerun during this review.

6. **Architecture**
   - **ARCH-DRY: pass** — both consumers derive from the shared configuration; no duplicate default introduced.
   - **ARCH-PURE: pass** — existing pure state logic and thin integration boundaries remain intact.
   - **ARCH-PURPOSE: pass** — both Done-when states are exercised; the change delivers the requested default without changing opt-in behavior.

7. **Plan revision recommendations:** None.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"70ef1ab7-f01c-4668-b7c6-3d44f5de599d","repository":"github.com/xianxu/parley.nvim","issue_id":"000393","recipe":"small-diff-review","round":1,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/727dfe7aea07d771","reviewed_head":"bccb5aa99d44c54ee946f806bc0487d927a0c56f","slot":"parley.nvim:1","requested_at":"2026-10-19T04:18:02.110159Z"},"phase":"finished","pid":25333,"started_at":"2026-10-19T04:18:02.517853Z","finished_at":"2026-10-19T04:18:54.975559Z","session_id":"01a15261-7cdf-7413-aa9b-b25563543a0f","outcome":"returned"}] -->
