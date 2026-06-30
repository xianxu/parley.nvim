# Boundary Review — ariadne#154 (whole-issue close)

| field | value |
|-------|-------|
| issue | 154 — raise max_tool_iterations default to 42 |
| repo | parley.nvim |
| issue file | workshop/issues/000154-raise-max-tool-iterations-default-to-42.md |
| boundary | whole-issue close |
| milestone | — |
| window | abec1be6a1bc7959beebee1173d76293d54ea587..HEAD |
| command | sdlc close --issue 154 |
| reviewer | claude |
| timestamp | 2026-06-29T18:46:50-07:00 |
| verdict | SHIP |

## Review

VERDICT: SHIP (confidence: high)

A clean, exemplary single-sourcing change that does exactly what issue #154 specifies and nothing more. The three drifted literals (`init.lua` `or 20`, `tool_loop.lua` `or 20`, `chat_respond.lua` `or 10` — the stale `10` being the live symptom of the duplication) now all derive from one constant `defaults.max_tool_iterations = 42`, so no code path can structurally disagree about the default. Full suite green (127 PASS, 0 fail/error), lint clean (0/0 in 237 files), both atlas docs and the config example comment swept. Every Plan checkbox is delivered. Nothing blocks SHIP.

**1. Strengths**
- True root-cause fix, not a re-sync. The plan-quality judge's earlier ARCH-DRY FAILURE (logged at `000154…md:98`) pushed this from "hand-edit three literals" to "single-source in `defaults.lua`" — the diff reflects that: `defaults.lua:71` is the lone source, referenced by `init.lua:689`, `tool_loop.lua:234`, `chat_respond.lua:1693`.
- Correct home choice: the constant lives in `defaults.lua` (already the values module, `M.defaults` bound at `init.lua:23`), not in `config.lua` which returns the user data table — avoids polluting the config namespace.
- Tests pin real behavior through `fresh_setup` (actual `init.lua` setup path), not mocks: the constant-pin (`config_tools_spec.lua:80`), setup-time resolution (`:93`), default-agent (`:154`), and full `get_agent` wiring chain (`:183`), with the explicit-override test (`:109`) left intact to guard the override path.
- Tight scope discipline: `tool_result_max_bytes` (same triple-literal shape but consistent at 102400) is explicitly left out of scope per the Spec rather than opportunistically swept.

**2. Critical findings** — none.

**3. Important findings** — none.

**4. Minor findings**
- Three different idioms fetch the same constant: `init.lua` reuses the cached `M.defaults`, `tool_loop.lua` adds a module-top `local defaults = require(...)`, `chat_respond.lua:1693` does an inline `require("parley.defaults").…`. The inline require is idiomatic here (`init.lua:2880/4163` do the same, and Lua caches modules), so no real cost — just note the stylistic non-uniformity for future consolidation.
- Stale doc text was corrected as a side-effect: `atlas/providers/tool_use.md:66` previously read `📎: (iteration limit reached)` but the code already emits `(iteration limit reached — max N rounds)` (that synthetic-message line in `tool_loop.lua` is unchanged context, not new). Good catch, but flagging that this doc drift predated #154 — worth confirming nothing else asserted the old string (nothing does; the cap test at `tool_loop_spec.lua:203` asserts only the `"done"` outcome, not the message text).

**5. Test coverage notes**
- The kind of bug this diff could ship (a stray literal disagreeing with the source) is covered by the constant-pin plus setup-resolution tests.
- Gap (Minor, not worth blocking): no test exercises the *defensive nil-fallback* paths in `tool_loop.lua:234` / `chat_respond.lua:1693` (i.e. `agent_info.max_tool_iterations == nil → defaults.max_tool_iterations`). All `tool_loop_spec` cases pass explicit values. Since `init.lua` always populates the field at setup, these fallbacks rarely fire and the single-source removes the drift risk that motivated the issue, so the value of adding such a test is low — note it, don't require it.

**6. Architectural notes for upcoming work**
- ARCH-DRY — **PASS** (and the point of the issue): one source of truth, three derivations; the duplicated magic number is eliminated.
- ARCH-PURE — **PASS**: `defaults.lua` is a pure constants module; `tool_loop.lua`'s added `require` is a pure module-top binding; all fetches are side-effect-free.
- ARCH-PURPOSE — **PASS** (shadow-sweep): the three *code* consumers all derive from the source; the two atlas docs + the `config.lua:260` example comment are hand-maintained restatements, which is acceptable for documentation (making markdown derive from a Lua constant would be over-engineering and is out of scope). The purpose — "no code path can structurally disagree" — is fully met, not deferred.
- Forward note: `tool_result_max_bytes` (102400, hardcoded in `init.lua`, `tool_loop.lua`, `chat_respond.lua`) is the obvious next single-sourcing candidate; the Spec already flags it. When picked up, it slots into the same `defaults.lua` pattern established here.

**7. Plan revision recommendations** — none. The plan matches the code exactly; all checkboxes are delivered and the Log accurately records the green test/lint runs and the ARCH-DRY pivot.
