# Boundary Review — parley.nvim#322 (whole-issue close)

| field | value |
|-------|-------|
| issue | 322 — Alt+Return on a plain markdown file silently sends nothing after the process-instruction prompt (no 'sent' or error notice) |
| repo | parley.nvim |
| issue file | workshop/issues/000322-alt-return-on-a-plain-markdown-file-silently-sends-nothing-after-the-process-instruction-prompt-no-sent-or-error-notice.md |
| boundary | whole-issue close |
| milestone | — |
| window | c50641e7c54bc648d0e3e2b5c3e7ab398343c25f..b2a6e58e990199e9f29dfa4044f1940272726564 |
| command | sdlc close --issue 322 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-23T14:47:56-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The implementation matches the active Spec: outside Couch, Alt+Return visibly requests the existing local review with empty arguments, without prompting or rewriting metadata. No blocking defects found. One minor documentation contradiction remains. Recorded full-suite results and live acceptance remain separate landing conditions.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: documentation-matches-runtime
    title: |
      Correct the attention-finder recording exclusion
    detail: |
      atlas/ui/attention_finder.md:34 now says document submissions are not recorded, contradicting the preceding recording description and lua/parley/session_sync.lua:1137–1144, which records successful submitted-path deliveries. Replace this with a statement that local review requests are not recorded, or delete the bullet. Family instances introduced in this window: this one recording-exclusion claim.
```

1. **Strengths**
   - `lua/parley/review_send.lua:22` preserves coordinator dispatch and delegates local admission to the existing owner.
   - Adapter regressions verify exact empty arguments, one invocation, preserved document content, and no prompt/send.
   - Native tests retain builtin notification behavior and verify subsequent typing in both Normal and Insert modes.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** The attention-finder documentation contradiction above.

5. **Test coverage:** Passed `make test-spec SPEC=modes/review` on Neovim 0.12.5 and 0.11.7, including native mapping tests. Passed `make test-spec SPEC=skills/skill-system`, covering existing cancellation, transport-error and lifecycle behavior. Changed-file lint and diff whitespace checks passed; process censuses were clean.

6. **Architecture**
   - **ARCH-DRY — pass:** reuses `review.run_via_invoke`; removed helpers have no remaining consumers.
   - **ARCH-PURE — pass:** adapter remains thin; admission and lifecycle retain their existing owners.
   - **ARCH-PURPOSE — pass:** addresses visible local submission across plain, partial-header and legacy-instruction documents.
   - **ARCH-EVOLVE — pass:** no persisted-format changes or metadata rewrites.
   
   README and atlas updates cover the changed shortcut behavior.

7. **Plan revisions:** None required. The plan and tracker explicitly preserve the pending landing conditions.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"d59902d8-722f-40d2-b24f-b325f2ed3ba3","repository":"github.com/xianxu/parley.nvim","issue_id":"000322","recipe":"small-diff-review","round":1,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/f41707648ce998dd","reviewed_head":"b2a6e58e990199e9f29dfa4044f1940272726564","slot":"parley.nvim:3","requested_at":"2026-10-23T21:44:54.172256Z"},"phase":"finished","pid":938,"started_at":"2026-10-23T21:44:54.325457Z","finished_at":"2026-10-23T21:47:55.015113Z","session_id":"01a16ab9-5abd-7e70-9d19-fbe6069bb14d","outcome":"returned"}] -->
