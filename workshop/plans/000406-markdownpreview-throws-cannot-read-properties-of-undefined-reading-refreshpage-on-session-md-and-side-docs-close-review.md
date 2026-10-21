# Boundary Review — parley.nvim#406 (whole-issue close)

| field | value |
|-------|-------|
| issue | 406 — MarkdownPreview throws 'Cannot read properties of undefined (reading refreshPage)' on session.md and side docs |
| repo | parley.nvim |
| issue file | workshop/issues/000406-markdownpreview-throws-cannot-read-properties-of-undefined-reading-refreshpage-on-session-md-and-side-docs.md |
| boundary | whole-issue close |
| milestone | — |
| window | efc65ba6a44a965d94441b586310118a0b978584..790a2dbdd6de6d878cfe6816d5521bdcfdae1919 |
| command | sdlc close --issue 406 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-20T21:44:27-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The change matches the revised configuration-only Spec: it pins MarkdownPreview to port 18999, preserves existing startup restrictions, and documents collision recovery. No blocking defects found. The recorded full-suite pass remains a separate landing prerequisite.

Done-when: current — it covers the startup regression, real parent/side-document refresh verification, and remaining landing gates.

```findings
{}
```

1. **Strengths**

   - The setting stays at the plugin configuration boundary, with the collision explained ([init.lua:205](packaging/starter-config/init.lua:205)).
   - The regression observes the production starter’s initialized port through the injected Lazy fixture ([starter_bootstrap_spec.lua:192](tests/integration/starter_bootstrap_spec.lua:192)).
   - Both the starter README and atlas document port selection and recovery ([README.md:178](packaging/starter-config/README.md:178), [starter.md:354](atlas/infra/starter.md:354)).

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage notes**

   - Independently ran all 21 bootstrap cases: passed; sentinel and process-cleanup checks passed.
   - Independently reran the preserved reproduction in disposable scratch space: occupied-port startup produced `EADDRINUSE` and the exact `refreshPage` TypeError.
   - Independently reran the real pinned dependency check: Socket.IO delivered external edits for both `session.md` and `session.side/discussion.md` on port 18999.
   - Inspected preserved red-run evidence showing the new regression fails with a missing port setting.
   - Pinned-range whitespace checks passed; checkout remains unchanged. Full suite was not rerun during this review.

6. **Architectural notes**

   - **ARCH-DRY: pass.** One production assignment; documentation and tests serve distinct purposes.
   - **ARCH-PURE: pass.** Configuration remains in the existing thin startup boundary; no business logic added.
   - **ARCH-PURPOSE: pass.** Delivers the revised starter-port contract, with both document modes verified.
   - **ARCH-EVOLVE: pass.** No persisted format or rewrite behavior changes.

7. **Plan revision recommendations:** None. No Core concepts table is claimed; the Plan and Revisions match the delivered scope.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"4ae315d7-ec48-4061-bb5c-38e32d9348c1","repository":"github.com/xianxu/parley.nvim","issue_id":"000406","recipe":"small-diff-review","round":1,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/8a36277bb17ad55f","reviewed_head":"790a2dbdd6de6d878cfe6816d5521bdcfdae1919","slot":"parley.nvim:1","requested_at":"2026-10-21T04:43:02.506992Z"},"phase":"finished","pid":12830,"started_at":"2026-10-21T04:43:02.706442Z","finished_at":"2026-10-21T04:44:26.353733Z","session_id":"01a15cc5-1819-7763-9643-7d11ab7334b8","outcome":"returned"}] -->
