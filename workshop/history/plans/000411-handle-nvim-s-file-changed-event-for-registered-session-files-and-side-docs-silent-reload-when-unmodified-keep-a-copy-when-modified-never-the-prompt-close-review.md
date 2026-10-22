# Boundary Review — parley.nvim#411 (whole-issue close)

| field | value |
|-------|-------|
| issue | 411 — Handle nvim's file-changed event for registered session files and side docs: silent reload when unmodified, keep-a-copy when modified, never the prompt |
| repo | parley.nvim |
| issue file | workshop/issues/000411-handle-nvim-s-file-changed-event-for-registered-session-files-and-side-docs-silent-reload-when-unmodified-keep-a-copy-when-modified-never-the-prompt.md |
| boundary | whole-issue close |
| milestone | — |
| window | 4b8e61ed5f5b5b3ab969bc3df6314dac442e753c..cfe4c2049db2f720ac7e9b34242208ac8a37fec4 |
| command | sdlc close --issue 411 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-22T06:18:25-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned change satisfies the issue’s contract: registered documents reload clean buffers silently and preserve conflicting operator work through the existing copy path. Tests passed, documentation covers the behavior, and no blocking defects were found.

Done-when: current — the existing clauses cover the clarified admission-history handling and repeated foreign writes.

```findings
{}
```

1. **Strengths**
   - Reuses admission history before preservation clears `modified` (`lua/parley/session_sync.lua:896`).
   - Deferred preservation checks attachment, epoch, identity, move state, and buffer lifetime (`lua/parley/session_sync.lua:917`).
   - Native tests cover both document kinds, multiple windows, repeated writes, copy failure, detachment, and unregistered handling.
   - README, atlas, and traceability updates match the implementation.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage:** Independently ran 243 checks successfully: new native 9, existing native 142, session integration 72, admission unit 18, and ownership architecture 2. Harness exited successfully with no surviving test processes. Pinned-range diff whitespace checks passed. Full suite was not rerun.

6. **Architecture**
   - **ARCH-DRY: pass** — existing preservation and admission mechanisms are reused.
   - **ARCH-PURE: pass** — history remains in the pure admission owner; editor effects remain in the integration layer.
   - **ARCH-PURPOSE: pass** — both registered document kinds and the unregistered control are covered.
   - **ARCH-EVOLVE: pass** — no persisted format changes.

7. **Plan revision recommendations:** None.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"c353dab4-c164-4e33-b2c7-078457d58b1a","repository":"github.com/xianxu/parley.nvim","issue_id":"000411","recipe":"small-diff-review","round":1,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/aee5db6da81c2cf3","reviewed_head":"cfe4c2049db2f720ac7e9b34242208ac8a37fec4","slot":"parley.nvim:2","requested_at":"2026-10-22T13:16:01.9001Z"},"phase":"finished","pid":77462,"started_at":"2026-10-22T13:16:02.074673Z","finished_at":"2026-10-22T13:18:25.411187Z","session_id":"01a163c1-1d44-79d1-bf63-75284f66ca71","outcome":"returned"}] -->
