# Boundary Review — parley.nvim#196 (whole-issue close)

| field | value |
|-------|-------|
| issue | 196 — Path typeahead caches stale neighborhood; diverges from live tool-exec cwd |
| repo | parley.nvim |
| issue file | workshop/issues/000196-typeahead-stale-neighborhood-cache.md |
| boundary | whole-issue close |
| milestone | — |
| window | 27ac6efc4d67bdc2c9ac0a8679b286f1dbde8d21..HEAD |
| command | sdlc close --issue 196 |
| reviewer | claude |
| timestamp | 2026-07-19T18:33:54-07:00 |
| verdict | SHIP |

## Review

I have completed a thorough static trace. Note: I could **not execute the test suite in-session** — the Bash tool fails at the harness level (`EPERM` creating `~/.claude/session-env/…`, independent of sandbox mode). I verified the fix and test by reading and cross-referencing the code paths instead.

```verdict
verdict: SHIP
confidence: high
```

This is a clean, minimal, root-cause bugfix. `policy_for_completion` now always derives live via `M.policy_for_buf(buf)` (neighborhood.lua:174-182), and the attach-time cache write `vim.b[buf].parley_root_policy = policy` is removed from `attach_completion` (was neighborhood.lua:294). A repo-wide grep confirms `parley_root_policy` no longer appears in any `lua/` file — only in issue/history docs — so the frozen cache had exactly one reader and one writer, both removed, with no orphaned consumer left reading a now-never-written var. Completion and execution now provably share one derivation: execution derives live at chat_respond.lua:1402-1403 (`params.root_policy or policy_for_buf(buf)`) and completion at neighborhood.lua:181/226/253/268 all funnel through the same `policy_for_buf`. The Spec's stated requirement — "Completion and `neighborhood.policy_for_buf(buf)` yield the same `write_root` for the same buffer at the same time" — is satisfied by construction. Nothing blocks SHIP.

**1. Strengths**
- **True consolidation, not a patch (ARCH-DRY).** The fix removes the divergent cached copy entirely rather than adding invalidation logic — a cache that *can't* go stale because it no longer exists. neighborhood.lua:174-181 makes the single-owner intent explicit and correct.
- **Test drives the real production entry point across the actual Done-when transition** (neighborhood_completion_spec.lua:94-129). It uses a genuine second repo recognized only *after* attach and asserts on `neighborhood.completefunc` behavior (`{}` → `{"../nbr2/"}`), not a planted buffer var — so it survives a freeze re-introduced under any variable name. Tracing the derivation confirms it is RED pre-fix (frozen fallback root globs `repo2/workshop/nbr2*` → `{}` even after recognition) and GREEN post-fix (live root widens to `repo2`, `../nbr2` reaches `tmpdir/nbr2` via the default `tool_read_roots = {'../'}` read root at config.lua:417).
- **The replaced idempotency assertion is now meaningful** (spec:60-67): the old test asserted `parley_root_policy` equality (vacuous once removed); the new one checks the completefunc still points at the parley entry point after a re-`prep_md`, which actually pins re-entry idempotency.
- **Performance tradeoff is correctly reasoned.** `get_chat_roots()` resolves to an in-memory `_root_mgr.get_roots()` (chat_dirs.lua:24), and `policy_from_roots` adds ~3 `fs_realpath` calls — genuinely negligible against the per-match `glob`/`isdirectory`/`resolve_read_path` the completion already runs. The Spec's acceptance of recompute cost holds.

**2. Critical findings** — none.

**3. Important findings** — none.

**4. Minor findings**
- **Verification gap (environment, not code):** I could not run `make test-spec SPEC=neighborhood_completion` in this session (Bash unavailable — harness `EPERM`). The Log claims 10/10; my static trace agrees, but the operator/close-gate should confirm the suite is green before recording the verdict. This is the normal gate re-run, so no code change.

**5. Test coverage notes**
- The new #196 regression is exactly the missing coverage the diff needed: it would have caught the shipped bug (stale fallback root persisting after recognition). Good separation — the existing hand-built-policy tests (spec:141-176) cover `completion_candidates` in isolation (PURE), while the new test covers the live-derivation glue end to end (INTEGRATION via the real `completefunc`), and the cmp-source test (spec:178-220) mocks `cmp` appropriately as an injected UI-boundary fake. No test asserts a mock reasserting the implementation.

**6. Architectural notes**
- **ARCH-DRY — PASS.** One derivation, one owner; the cached copy is deleted, not shadowed. Cited correctly in-code.
- **ARCH-PURE — PASS.** `policy_for_completion` is a thin wrapper; derivation (`derive_for_path`/`policy_from_roots`) is pure over its inputs, IO (`fs_realpath`, `glob`) stays at the `completefunc`/`completion_candidates` boundary. Tests exercise real logic without mocking the derivation.
- **ARCH-PURPOSE — PASS.** Shadow-sweep of policy consumers: (1) execution — chat_respond.lua:1403, tool_loop.lua:243, skill_invoke.lua:220 → `policy_for_buf` (live); (2) completion — all four call sites → `policy_for_completion` → `policy_for_buf` (now live). No hand-maintained restatement of the neighborhood remains; the issue's actual purpose (completion tracks the live root) is fully delivered, not a cheap subset.
- **Docs gate:** `atlas/infra/repo_mode.md` updated to record the live-derivation invariant, and the wording is accurate to the code. No README surface changed (bugfix — no new command/flag/keybinding/config), so no README finding.

**7. Plan revision recommendations** — none. The Plan (all three items) and Done-when match the delivered code and test; the Log accurately reflects the diff.
