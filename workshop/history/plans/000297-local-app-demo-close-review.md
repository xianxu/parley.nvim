# Boundary Review — parley.nvim#297 (whole-issue close)

| field | value |
|-------|-------|
| issue | 297 — Repo-local app demo and development loop |
| repo | parley.nvim |
| issue file | workshop/issues/000297-local-app-demo.md |
| boundary | whole-issue close |
| milestone | — |
| window | e50c216405de3086e6d9dae16e92f11a0d8cd670..6f1cdd6dbf63f21d4bed91ac6b81fbe4561e3d38 |
| command | sdlc close --issue 297 |
| reviewer | codex |
| timestamp | 2026-09-28T19:11:15-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned change fulfills #297’s Spec and Plan. The recording profile reuses the packaged starter, selects the nested workspace, preserves trials between launches, and provides distinct reset/nuke behavior. I found no blocking correctness, architecture, or documentation gaps.

1. **Strengths**
   - Existing ownership, locking, and live-editor guards protect the new mode’s destructive operations.
   - `demo/init.lua:14` reuses the starter; bootstrap tests verify Screenkey is enabled only in the demo.
   - Launcher tests exercise production chat recognition and nested read/write roots, plus cleared versus retained data.
   - README, TOOLING, and the existing indexed atlas page document the new commands and reset scope.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage**
   - `python3 tests/packaging/test_local_app.py`: **11 passed**.
   - `make test-spec SPEC=infra/starter`: **passed**, including all 15 bootstrap tests.
   - Shell syntax and pinned-range whitespace checks passed.
   - Verified the installed Screenkey commit and its configuration API against the demo settings.
   - Cold-install smoke was not independently repeated. The harness could not perform its orphan-process census because `ps` was unavailable.

6. **Architecture**
   - **ARCH-DRY — pass:** shared launcher guards and starter configuration remain authoritative.
   - **ARCH-PURE — pass:** additions are small filesystem/process/UI boundary operations; no business logic was buried in a new integration layer.
   - **ARCH-PURPOSE — pass:** configuration, recording startup, reset isolation, compatibility, and documentation are delivered together.

7. **Plan revision recommendations:** None. Existing revisions accurately clarify reset paths and chat recognition.

```findings
{}
```
