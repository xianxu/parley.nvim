# Boundary Review — parley.nvim#278 (whole-issue close)

| field | value |
|-------|-------|
| issue | 278 — Enable smart case search in the app |
| repo | parley.nvim |
| issue file | workshop/issues/000278-app-smart-case-search.md |
| boundary | whole-issue close |
| milestone | — |
| window | c231e52d3bfaab13eaec73983c1aa20ae2a4f8e3..8d93716c2e155d05fa92f26ab9d0b6e08ad755ee |
| command | sdlc close --issue 278 |
| reviewer | codex |
| timestamp | 2026-09-25T23:38:24-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned implementation satisfies #278’s Spec and Done when clause. Native searches behave correctly for lowercase, mixed-case, and uppercase patterns. The broader launcher, shortcut, and statusline changes passed focused verification. No blocking findings.

1. **Strengths**
   - `packaging/starter-config/init.lua:13` uses Neovim’s native `ignorecase` and `smartcase`, without duplicating search logic.
   - The packaged README accurately explains case-sensitive and case-insensitive behavior.
   - Existing starter, keybinding, and statusline integrations are reused.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage notes**
   - Clean pinned snapshot: **183 starter tests passed**.
   - **Six launcher tests passed**.
   - Independently reran the temporary search probe: **five forward/backward searches passed**.
   - Real statusline checks passed across **19 theme choices**.
   - Shell syntax and pinned diff whitespace checks passed.
   - Search verification remains a temporary script, not a committed regression.
   - Process-survivor checking was unavailable because the harness could not access `ps`.

6. **Architectural notes**
   - **ARCH-DRY — pass:** native search and existing integrations remain the behavior owners.
   - **ARCH-PURE — pass:** search changes are declarative; startup and process IO remain at their existing boundaries.
   - **ARCH-PURPOSE — pass:** both case modes required by the issue were exercised successfully.

7. **Plan revision recommendations:** None.

```findings
{}
```
