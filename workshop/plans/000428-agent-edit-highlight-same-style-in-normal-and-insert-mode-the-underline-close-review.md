# Boundary Review — parley.nvim#428 (whole-issue close)

| field | value |
|-------|-------|
| issue | 428 — Agent-edit highlight: same style in normal and insert mode (the underline disappears in insert) |
| repo | parley.nvim |
| issue file | workshop/issues/000428-agent-edit-highlight-same-style-in-normal-and-insert-mode-the-underline.md |
| boundary | whole-issue close |
| milestone | — |
| window | 1ea0c744f51dc91624176356f94dde0f7c53f4e5..e6e2a208d14027b4eb52c5056d2b916a5228a27c |
| command | sdlc close --issue 428 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-24T07:53:58-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned change satisfies the issue’s Spec and Plan. The logged cause matches the diagnostic refresh path, and the namespace-local fix preserves consistent edit styling across modes. No blocking findings.

```findings
{}
```

1. **Strengths**
   - `lua/parley/skill_render.lua:35` centralizes the policy for round, skill, footnote, and restored diagnostics.
   - `tests/integration/edit_highlight_native_spec.lua:88` compares effective screen attributes across Normal, Insert, Replace, and Visual modes.
   - Controls verify custom styling, reference underlines, foreign diagnostics, messages, signs, and existing diagnostic settings.
   - README and atlas updates accurately describe the change.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage:** `make test-spec SPEC=ui/highlights` passed all 106 tests, including seven native highlight cases. Process census was clean; pinned-range `git diff --check` passed. The full suite was not run.

6. **Architecture**
   - **ARCH-DRY — pass:** One namespace configuration covers all consumers.
   - **ARCH-PURE — pass:** Configuration remains in the existing thin UI boundary.
   - **ARCH-PURPOSE — pass:** Both Done-when clauses are delivered; independent reference styling survives.
   - **ARCH-EVOLVE — pass:** No persisted formats change.

7. **Plan revision recommendations:** None.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"fdac8dcd-0527-4cdb-ad55-86e35119a246","repository":"github.com/xianxu/parley.nvim","issue_id":"000428","recipe":"small-diff-review","round":1,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/40cad66cb1176da9","reviewed_head":"e6e2a208d14027b4eb52c5056d2b916a5228a27c","slot":"parley.nvim:2","requested_at":"2026-10-24T14:52:06.339118Z"},"phase":"finished","pid":16601,"started_at":"2026-10-24T14:52:06.484565Z","finished_at":"2026-10-24T14:53:55.372969Z","session_id":"01a16e65-cae8-7c43-934e-858be2ab6f5a","outcome":"returned"}] -->
