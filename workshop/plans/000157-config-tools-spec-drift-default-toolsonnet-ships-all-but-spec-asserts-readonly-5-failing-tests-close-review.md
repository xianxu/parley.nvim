# Boundary Review — parley.nvim#157 (whole-issue close)

| field | value |
|-------|-------|
| issue | 157 — config_tools_spec drift: default ToolSonnet ships @all but spec asserts @readonly (5 failing tests) |
| repo | parley.nvim |
| issue file | workshop/issues/000157-config-tools-spec-drift-default-toolsonnet-ships-all-but-spec-asserts-readonly-5-failing-tests.md |
| boundary | whole-issue close |
| milestone | — |
| window | 8bd3e4b56f01b048b924e5a29dd49fb4eb01a90e..HEAD |
| command | sdlc close --issue 157 |
| reviewer | claude |
| timestamp | 2026-07-01T08:54:32-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The diff resolves #157's config↔test drift exactly as the issue's resolved decision directs: it refits `config_tools_spec.lua` from the stale `@readonly` expectations to the shipped `@all` default and rewrites the three misleading "read-only" comment blocks in `config.lua`. I verified independently (not from the commit/Log) that the target spec is **22/22 green**, the golden spec is **7/7 green** (unaffected), lint is clean on both changed files, the `config.lua` change is **comment-only** (no behavior change — grep for non-comment `+/-` lines is empty), and the `@all` swap (`8381829`) is an ancestor of the base commit, so this diff carries zero behavior risk — it's purely a test/comment reconciliation to a default that already shipped. Nothing blocks SHIP; the two findings below are Minor documentation polish, one of them pre-existing and out-of-window.

**1. Strengths**
- **Anti-drift canary is the right shape** (`config_tools_spec.lua:172-182`): it discovers tool-enabled agents *dynamically* by iterating `parley.agents` rather than hardcoding a name list, so a future swap of either the tool set *or* the agent roster fails loudly at one source. The `checked >= 1` guard correctly prevents a vacuous green if the discovery loop ever matches nothing.
- **DRY consolidation** (`config_tools_spec.lua:25`): four scattered `{ "@readonly" }` literals collapse to one `EXPECTED_DEFAULT_TOOLS` local; the canary reads the live config, so the pin isn't just a duplicated literal.
- **Absence→presence flips are complete**: all three `is_nil(edit_file/write_file)` sites plus their message strings were flipped to `is_true(...)` (`:258-259`, `:284`), and the `it`/`describe` names + block comment were updated in lockstep — no half-refit assertions left claiming "read-only".
- **Atlas already consistent**: `atlas/providers/agents.md:5` already documents ToolSonnet/ToolOpus as shipping "all 7 builtin tools", so the Atlas update gate needs no new change here.

**2. Critical findings** — none.

**3. Important findings** — none.

**4. Minor findings**
- `tests/unit/parley_harness_golden_spec.lua:19-24` — stale comment, the same drift class #157 set out to kill. It still reads "ToolSonnet now selects tools via the `@readonly` sentinel"; ToolSonnet now ships `@all`. The `READONLY_TOOLS` override itself is *correct and deliberate* (deterministic goldens), only the justifying comment is wrong — and `config_tools_spec.lua:22` explicitly points readers here ("mirrors the READONLY_TOOLS hoist in `parley_harness_golden_spec.lua`"). Fix: reword to "ToolSonnet ships `@all`; goldens pin the read-only subset explicitly for determinism." Out of the modified window (pre-existing), so non-blocking — but cheap and on-theme.
- `lua/parley/config.lua:219-222` (and the two mirrored blocks) — the "Done when" asked for a one-line *rationale* for why the default agent ships write access. The comment documents the *what* (read+write), *history* (swapped in `8381829`), and *alternative* (`@readonly`), and scopes it to "inside the working directory", but doesn't state the *why* (default = full coding assistant). Given a write-capable default is a notable permission posture (ties to #129), one clause of intent would close the gate more cleanly. Note only.

**5. Test coverage notes**
The refit both fixes the 5 red assertions and *adds* coverage (the canary) that would have caught the original drift class — a net coverage gain, not just a green-washing edit. The full wiring-chain test genuinely resolves the `@all` sentinel through `dispatcher.prepare_payload` (real expansion, no mocks) and correctly asserts membership rather than exact count (portable across machines where `ack` may/may not be installed). PURE-config assertions run with `web_search=false` to isolate client tools — appropriate. No gap I'd block on.

**6. Architectural notes**
- **ARCH-DRY — pass.** Single `EXPECTED_DEFAULT_TOOLS` source; the canary reads live config rather than restating the literal. The remaining conceptual restatement (golden spec's `READONLY_TOOLS`) is a *different* value serving a different purpose (determinism), not a duplication to consolidate.
- **ARCH-PURE — pass.** Tests exercise pure config + payload assembly with no IO/network; no mocks required to run the "pure" assertions.
- **ARCH-PURPOSE — pass (with one thread).** Shadow-sweep of the "default tool set" fact across consumers: `config.lua` (source ✓), `config_tools_spec` (✓ refit + durable pin), `atlas/providers/agents.md` (✓ already "all 7 builtin tools"). The only hand-maintained restatement still telling the old `@readonly` story is the golden-spec comment (Minor #4 above) — the issue's core purpose (kill the drift + pin it durably) is fulfilled; that comment is the one loose thread of the same theme.

**7. Plan revision recommendations** — none. The Plan's four checked items all match the delivered code (refit, hoist+canary, comment fix, 22/22 confirmed); no `## Revisions` entry needed.
