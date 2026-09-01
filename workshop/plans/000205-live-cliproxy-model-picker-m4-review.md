# Boundary Review — parley.nvim#205 (milestone M4)

| field | value |
|-------|-------|
| issue | 205 — live cliproxy model picker; retire hardcoded model lists |
| repo | parley.nvim |
| issue file | workshop/issues/000205-live-cliproxy-model-picker.md |
| boundary | milestone M4 |
| milestone | M4 |
| window | 44b9c0d0b9559c5d95f237aaf6a734097390f6b3..89fe5bebcf932c9fa106c96674733e27fe230f8f |
| command | sdlc milestone-close --issue 205 --milestone M4 |
| reviewer | claude |
| timestamp | 2026-09-01T10:42:56-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

M4's structural work is sound — `resolve_channels`/`channels_for_owner` are properly pure, well-unit-tested, and the fan-out extraction with an injected comparator is a genuine ARCH-DRY win. The full suite is green (0 failures). But the milestone's own Done-when — "auth diagnosis still names the right login for a failing model, proven by a case that runs with an EMPTY alias block" — is not delivered: I ran the resolution path and confirmed that with the shipped (alias-free) config, every expired-credential 401 on a `claude-*` or `gpt-*` model now names **antigravity**, because `unhealthier` ranks `missing` (rank 0, "no credential at all") as the *least healthy* candidate, and a channel with no credential cannot have served the request. The load-bearing regression test's title says "names the claude login" and asserts nothing that would catch this — it passes while parley prompts the operator to `:ParleyProxy login antigravity`. Separately, the commit silently gutted the shipped default agent roster from 19 agents to 1, contradicting the Spec ("keep the six configured cliproxyapi agents as pinned favorites") and Task 4.2 ("removes `oauth-model-alias` and nothing else"), and left `config.review_agent`/`skill_agent`, `scripts/refresh_goldens.lua` and the atlas pointing at agents that no longer exist — measured live.

## 1. Strengths

- **`resolve_channels` / `channels_for_owner` (`lua/parley/cliproxy_config.lua:186-228`)** — the plural-candidate design is right, the "not derived from `PROVIDER_OWNED_BY`" rationale is accurate (CHANNEL_LOGIN genuinely has no `google` key), and `cliproxy_config_spec.lua:360-425` pins the axis error with a test that would fail on an inversion. This is the strongest part of the milestone.
- **`credential_health_across` (`cliproxy.lua:498-515`)** — a real ARCH-DRY extraction, not a cosmetic one: one traversal, injected comparator, and `credential_health_for_login` becomes a two-line caller. The two reducers cannot drift.
- **The `get_agent` fix (`init.lua:4381-4397`)** is a genuine bug with a genuine test. I verified the mutation: with the old body, `_state.agent = "AgentThatWasDeleted"` reaches `agent_rec.model` on nil and the `pcall` in `config_tools_spec.lua:390` goes red. That claim holds.
- **The goldens/harness pin (`parley_harness.lua:67-76`, `parley_harness_golden_spec.lua:27-38`)** correctly identifies that a golden must depend on nothing a product decision can move, and the goldens matched with no regeneration — that *is* the evidence the pin is faithful.
- **The empty-alias e2e case is the right shape** — parameterising `serve(error_mode, overlay, alias)` and seeding via `_write_catalog` is exactly the seam Task 4.1 called for. The problem is only what it asserts.

## 2. Critical findings

### C1 — `unhealthier` blames the channel that has no credential (`cliproxy.lua:529`, `cliproxy_config.lua:186`)

`OWNER_CHANNELS.anthropic = { "antigravity", "claude" }` and `HEALTH_RANK.missing = 0` (the worst). So for the shipped alias-free config, an expired Claude token produces:

```
candidates for claude-opus-4-8 = { "antigravity", "claude" }
unhealthier(missing, error)    = true
chosen channel = antigravity   state = missing
login named    = antigravity
diagnosis      = cliproxy for "claude-opus-4-8": no credential is loaded for
                 this channel — log in to create one
```
(measured against the real modules, stubbing only `credential_health`'s two reads)

`credential_action` then returns `prompt_login` with `login_provider = "antigravity"`, so parley pops a `vim.ui.select` telling the operator to log into a channel they have never used, while the credential that actually failed goes unnamed. This is the exact "fabricates a diagnosis about the wrong account" failure #197 exists to prevent, and it fires on **every** auth failure for an anthropic- or openai-owned model under the default config — which is now every user, because M4 deleted the alias block that used to short-circuit it.

**The rule, not the site:** a candidate that could not have served the request is not a candidate. cliproxy only routes through a channel that *has* a credential, so `missing` must be excluded from candidacy before the reducer runs — not preferred by it. Fix sketch: filter `state == "missing"` out of the fan-out results, then apply `ca.unhealthier` to what remains; fall back to the whole set only if every candidate is `missing` (genuinely "you are logged into none of these"). Put that eligibility rule in `cliproxy_auth.lua` as a pure function beside `healthier`/`unhealthier` so it is unit-testable without the fan-out (ARCH-PURE — the policy currently lives hardcoded in the IO shell at `cliproxy.lua:529`).

`atlas/providers/cliproxy-managed.md` documents the broken rule verbatim ("the least healthy candidate is the one that plausibly caused the failure") and must be corrected in the same pass.

### C2 — the roster deletion left dangling referents in shipped config and scripts

Measured on a clean `parley.setup({})`:

```
agents: { "ToolOpus*" }
review_agent config = Claude-Sonnet
review_agent in roster?  false
skill_agent in roster?   false
Parley.nvim: Agent Claude-Sonnet not found, using ToolOpus*
```

- `lua/parley/config.lua:380,385` — `review_agent`/`skill_agent` name an agent the same file no longer ships. `skill_assembly.resolve_agent` is wired with `get_agent = p.get_agent` (`skill_invoke.lua:198`), which never returns nil — it warns and falls back. So step 1b/3 of the cascade short-circuits on a dead name, emitting a user-visible warning on every review and skill invocation, and steps 2 and 4 become unreachable.
- `scripts/refresh_goldens.lua:26` still passes `agent_name = "ToolSonnet"`. That falls back to `ToolOpus*`, which carries `synthetic_system_prompt = true` and injects an extra message pair — so regenerating the goldens now produces payloads that do **not** match `parley_harness_golden_spec`'s pinned `GOLDEN_AGENT`. The documented regeneration path (`workshop/history/issues/000143…:62`, "same ToolSonnet + READONLY_TOOLS as the spec") is broken; the spec side was swept and the regenerator was not.
- `scripts/parley_harness.lua:6,10` — the module header still advertises `agent_name = "ToolSonnet"` and `PARLEY_HARNESS_AGENT=ToolSonnet` as the usage example.

**The rule:** removing a definition requires sweeping every name that referred to it — config defaults, scripts, doc comments, atlas — in the same commit. The plan already states this ("Every name must have a referent", plan §Notes) and mandates a bidirectional grep; it was not run over the roster deletion, only over `oauth-model-alias`.

### C3 — the default agent roster went 19 → 1, undeclared and contradicting the Spec

`lua/parley/config.lua:202-224` now ships exactly one agent (`ToolOpus*`, provider `cliproxyapi`, model `claude-opus-4-8`). Consequences:

- A fresh install with only an `ANTHROPIC_API_KEY`/`OPENAI_API_KEY` and no cliproxyapi has **zero** usable agents.
- The Spec's Component 3 says "keep the six configured cliproxyapi agents as pinned favorites"; five of six (`ToolSonnet*`, `ToolFable*`, `ToolSol*`, `Claude-Sonnet*`, `Claude-Opus*`) are gone.
- Task 4.2 Step 1 says "This step removes `oauth-model-alias` and nothing else."
- The sole surviving agent pins `claude-opus-4-8` — the stale model the issue's own Problem statement was filed about.
- Neither the commit subject/body of `ba20423` nor any Done-when, `## Revisions` entry, or README line records it. The only trace is a parenthetical in a plan post-hoc note ("the operator's own `config.lua` cleanup").

> **This is the 8th finding in family `stated-design-not-implemented`.** Earlier rounds fixed instances. Do not fix this instance alone — the rule that covers all eight is already written in `workshop/lessons.md` ("a doc comment and a test title are assertions about the code, swept in the same commit as the change"), and what it is missing is the *artifact* half: **the Spec and the plan are assertions about the shipped code too.** A commit that makes a Spec sentence false must strike or revise that sentence in the same commit, and a change no plan task declares must get a task or a `## Revisions` entry before it lands. Measured prevalence on this issue: 8 findings, of which this is the first to invalidate a Done-when-adjacent Spec clause rather than a comment.

If the roster reduction is intended (it may well be the operator's call), the fix is not to revert it — it is to record it: a `## Revisions` entry replacing the "six pinned favorites" clause, README + atlas swept, and `review_agent`/`skill_agent` repointed. If it was not intended to ship, it needs to come out of the plugin default and live in the operator's own `setup{}`.

## 3. Important findings

### I1 — `credential_health_across` drops `repaired`, defeating the one-restart-per-claim guard (`cliproxy.lua:530`)

`credential_health` signals a management-route repair via a second callback arg (`cliproxy.lua:469`). `credential_health_across` ignores it, and `credential_health_across_or_one` passes `nil` through on the multi-candidate branch. So `restarted_this_claim` stays false and `execute` can issue a second restart — the compound ~36s repair-then-restart path that `cliproxy.lua:1298-1303` documents as "past the dispatcher's 25s backstop, which would replace the diagnosis with 'recovery timed out'". The docstring at `:517-519` even says "One candidate → … preserving its `repaired` flag", acknowledging the signal matters, then discards it on the other branch. With the alias block gone, the multi-candidate branch is the default path.

*Family: `extracted-seam-drops-a-signal` — an extraction must carry every out-parameter its call sites depended on. Fix: thread `repaired` through the fan-out (true if any read repaired), or exclude the repair path from the fan-out entirely.*

### I2 — the reducer, the fan-out, and `unhealthier` have zero direct tests

`grep -rn "unhealthier\|credential_health_across" tests/` returns nothing. `unhealthier` is listed in the plan's **Pure entities** table — a pure entity with no unit test. `credential_health_across`/`_or_one` are listed as INTEGRATION with no fake-driven case that asserts which channel wins. The one test that traverses the path (`cliproxy_recovery_e2e_spec.lua:124`) asserts only negatives (`is_nil(find("unknown_channel"))`, `find("credential")`) — all four of which pass while the diagnosis names the wrong channel, as C1 shows. This is precisely the kind of bug the diff shipped.

> **This is the 7th finding in family `missing-test-for-shipped-behavior`.** The rule that covers all seven: *a test must assert the value the code chose, not that the code didn't fail.* Three of this round's four assertions are `is_nil(find(…))` — absence-of-a-string guards, which a wrong answer satisfies as readily as a right one. The enumeration this implies, and which should be swept in one pass rather than per-finding: for every spec added on #205, list each assertion that is `is_nil(find(...))` or `is_true(find(...) ~= nil)` on a *substring* of a rendered message, and replace it with an equality (or a positive assertion on the discriminating token — here, `login antigravity` vs `login claude`). Measured prevalence: 7 findings across 6 rounds.

### I3 — atlas and README not swept for the roster and default changes

- `atlas/providers/agents.md:5` — "Default agents: GPT5.4 (openai), Claude-Sonnet (anthropic), ToolSonnet …" describes a roster that no longer exists at all.
- `atlas/skills/skill-system.md:97` — `skill_agent = "Claude-Sonnet"` as the documented example, now a dead name (and the shipped default, per C2).
- `README.md:198` — the `live_models` example still reads `"claude:opus,sonnet"` while the shipped default became `"claude:opus,sonnet,fable"` in this same commit, and `SPEC_RENDERS` gained a row for it.
- `atlas/providers/cliproxy-managed.md` — documents C1's incorrect rule.

> **This is the 4th finding in family `atlas-not-updated-for-new-surface`.** The rule: *a boundary that changes a value the atlas or README restates must sweep every restatement of that value in the same commit.* The enumeration is mechanical and should be written once rather than rediscovered each round — for each identifier or literal the diff changes in `lua/parley/config.lua`, `grep -rn` it across `README.md atlas/ docs/` and fix or strike every hit. Measured prevalence: 4 findings.

### I4 — the new doc block orphans `credential_health_for_login`'s (`cliproxy.lua:478-497`)

`credential_health_across`'s docstring was inserted **between** `credential_health_for_login`'s docstring (`:478-486`, still ending in `@param login string` / `@param cb fun(health: table)`) and the function it described. `credential_health_for_login` (`:532`) now has no docstring, and a reader following the file sees the login-provider prose introduce the fan-out. Separately, `cliproxy.lua:1283-1288` retains the pre-M4 comment paragraph ("fall back to resolving the model through oauth-model-alias") immediately above its replacement (`:1288-1293`) — two paragraphs stating different contracts back to back.

> **This is the 3rd finding in family `docs-insert-orphans-section`.** The rule is already recorded, at `workshop/lessons.md:962-964`: *"An insertion goes after the preceding function's body, never between a doc block and the function it documents."* It was written down and then violated by the commit that follows it. Since the rule exists and restating it has not worked, make it mechanical: a lint/CI check that flags a `function M.x` whose immediately-preceding `---@param` names an identifier absent from its signature would have caught both this and the prior two instances. Measured prevalence: 3 findings.

### I5 — `scripts/parley_harness.lua`'s new `opts.agent` seam is in no plan table

The diff adds a new public option to `build_payload` (`parley_harness.lua:67-76`) — a real API change consumed by two spec files — and neither `scripts/parley_harness.lua` nor `build_payload` appears in the plan's Pure or Integration tables.

> **This is the 7th finding in family `plan-table-missing-entity`.** The rule: *the tables must enumerate every module the milestone's diff touches, not every module the milestone anticipated touching.* The plan's own §Notes already prescribes running the referent grep "in BOTH directions"; the missing half is the input list — it should be `git diff --name-only <base> <head> -- lua/ scripts/ tests/fixtures/`, not the author's memory. Wire that command into the check and the family closes. Measured prevalence: 7 findings.

## 4. Minor findings

- `cliproxy_config.lua:263-271` — `@param models` is placed *after* `@return`, breaking the annotation block; `resolve_login_provider` also has zero production call sites (pre-existing, but now carries a new parameter no caller passes).
- `cliproxy.lua:499-502` — the `#channels == 0` branch of `credential_health_across` is unreachable: both callers guard for it first. Either delete it or route `credential_health_for_login`'s guard through it.
- `cliproxy.lua:1315,1358` — both rewritten give_up texts still name `cliproxy.config['oauth-model-alias']`. The e2e guard is `is_nil(find("Add it to"))`, a literal the rewrite clears trivially while the key is still recommended. The wording is defensible; the guard is not what it claims to check.
- `config_tools_spec.lua:160` — `assert.equals("anthropic", agent.provider)` was weakened to `assert.is_string(agent.provider)`. The discovery helper is right, but the provider assertion now passes for any value; if the point is "a tool-enabled agent ships", drop the provider line rather than assert a tautology.
- Untracked `docs/parley.nvim.md` sits in the worktree and is outside this review window — keep it out of the milestone-close commit (`close-stages-unreviewed-worktree`, 3rd occurrence).

## 5. Test coverage notes

- Full suite green: `make test` exits 0, zero `Failed`/`Errors` lines. `make test-spec SPEC=providers/cliproxy-managed` green across all mapped files. The boundary does not ship a red gate.
- `channels_for_owner`/`resolve_channels` coverage is good — five cases including the nil-catalog guard and the "is NOT derived from PROVIDER_OWNED_BY" axis assertion.
- The gap is entirely on the *choice* side: nothing asserts which channel the fan-out returns, which reducer is applied, or that `repaired` survives. A single unit case — stub `credential_health` to return `{state="missing"}` for antigravity and `{state="error"}` for claude, call `credential_health_across_or_one({"antigravity","claude"}, cb)`, assert `chosen == "claude"` — fails today and would have caught C1 before it shipped.
- The empty-alias e2e case should assert the positive discriminator (`login claude` / `me@example.com` present, `antigravity` absent) rather than four absence-of-substring guards.

## 6. Architectural notes

- **ARCH-DRY — pass.** The `credential_health_across` extraction is real; `unhealthier` is defined beside the ranking it inverts. The only duplication is prose (I4).
- **ARCH-PURE — flag.** `resolve_channels`/`channels_for_owner`/`unhealthier` are correctly pure. But the *policy* — "least healthy wins", and the missing eligibility rule — is hardcoded inside the IO shell at `cliproxy.lua:529`, which is why C1 has no cheap unit test. Extract the candidate-selection decision (eligible set + reducer) into `cliproxy_auth.lua` as a pure function taking `{channel → health}` and returning a channel; the shell then only gathers and applies. (`pure-decision-in-io-shell`, 2nd occurrence — the rule: if a branch names a *policy*, it belongs in the pure module even when its inputs arrive asynchronously.)
- **ARCH-PURPOSE — flag.** Two Done-when clauses are unmet: "auth diagnosis still names the right login" (C1) and, in the Spec's Components, "keep the six configured cliproxyapi agents as pinned favorites" (C3). The shadow-sweep for the single-source change found the remaining hand-maintained restatements listed in C2/I3 — `refresh_goldens.lua`, `config.review_agent`, `atlas/providers/agents.md`.
- **ARCH-MOCK — pass with one gap.** `fake_cliproxy` serves `/v0/management/auth-files` and the e2e drives the whole recovery path through it; production and test flow share the boundary. The gap is that no fake-driven case varies credential state *per channel*, which is the only way to exercise the reducer.
- **ARCH-CONSTRAINTS — flag.** The recovery path now issues N concurrent management reads (4 for google-owned models) under the dispatcher's 25s backstop, and one candidate's read can restart the proxy out from under the other in-flight reads. Combined with I1's lost `repaired`, the worst case stacks two repair budgets. Bound the fan-out and thread the repair signal before this reaches a google-owned model.

## 7. Plan revision recommendations

The plan needs three `## Revisions` entries (append, don't overwrite):

1. **"Default agent roster reduced to one"** — reason, delta, and an explicit strike of the Spec's Component 3 clause "keep the six configured cliproxyapi agents as pinned favorites". State what the shipped roster now is and why, and add a Done-when for `review_agent`/`skill_agent` resolving to an agent that ships.
2. **"Candidate eligibility precedes the reducer"** — record that `unhealthier` alone is the wrong rule (a `missing` channel cannot have served the request), and that the eligibility filter is a pure function in `cliproxy_auth.lua`. Correct the M4-landed note's claim that "credential health picks the LEAST healthy one — the credential that plausibly failed", which is what shipped and is wrong.
3. **"Task 4.1's regression proof restated"** — the "load-bearing regression test" note claims the empty-alias case asserts "what actually distinguishes the two worlds". It does not; it passes with the wrong channel named. Record the discriminating assertion the case must carry.

Also add `scripts/parley_harness.lua` / `build_payload` (`opts.agent`) to the Integration-points table (I5), and correct the M4-landed bullet that says the block "is still HONORED as an explicit channel pin" — that is true, but the note omits that the same commit deleted 18 default agents.

---

## Re-review — 2026-09-01T11:06:28-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 205 — live cliproxy model picker; retire hardcoded model lists |
| repo | parley.nvim |
| issue file | workshop/issues/000205-live-cliproxy-model-picker.md |
| boundary | milestone M4 |
| milestone | M4 |
| window | 44b9c0d0b9559c5d95f237aaf6a734097390f6b3..b475d476f42a363b1a7516f0bb653aa595abea6a |
| command | sdlc milestone-close --issue 205 --milestone M4 |
| reviewer | claude |
| timestamp | 2026-09-01T11:06:28-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

M4's structural work is sound and the headline C1 fix is real and mutation-verified: with the eligibility filter reverted, `cliproxy_recovery_e2e_spec`'s empty-alias case goes red on `me@example.com`, so the alias block's deletion is genuinely pinned. C2/C3 (the 19→1 roster gutting) are properly reverted — the committed `config.lua` now changes exactly two things — and the whole suite is green at head (191 spec files pass, luacheck 0/0; the only red file, `tests/arch/destructive_recipe_spec.lua`, fails solely because my review worktree cannot resolve the `Makefile → ../ariadne/Makefile` symlink). What blocks SHIP is that the C1 fix answered one value of an enum instead of the rule it stated. `could_have_served` excludes only `missing`; I measured the shipped fan-out and an `unknown` reading (a channel whose health read failed — rank −1, worse than everything) and a `disabled` reading (rank 1, worse than `error`) both still outrank a genuinely expired credential and get blamed — one degrading the diagnosis to "proxy unreachable", the other firing `prompt_login` naming *someone else's account*. That is the #197 wrong-account failure the milestone's own Done-when targets, still live on the default multi-candidate path, and the 404-repair race makes the `unknown` variant deterministic rather than hypothetical.

## 1. Strengths

- **The C1 fix is properly pure and properly pinned.** `could_have_served`/`likeliest_culprit` (`lua/parley/cliproxy_auth.lua:186-231`) sit beside the ranking they qualify, take no IO, and have five direct unit cases. I reverted `could_have_served` to `return true` and the e2e case went red on the discriminating assertion — the fix is load-bearing, not decorative.
- **The empty-alias e2e case is the right test.** Parameterising `serve(error_mode, overlay, alias)` and seeding via `_write_catalog` is exactly the seam Task 4.1 asked for, and the fixture now genuinely models an expired claude token so `assert.matches("me@example.com")` discriminates. It is the one assertion in the case that does work — see M3 below.
- **`resolve_channels` / `channels_for_owner` (`lua/parley/cliproxy_config.lua:186-228`)** — the plural-candidate design and the "not inverted from `PROVIDER_OWNED_BY`" rationale are correct, with five unit cases including the nil-catalog guard and the axis assertion.
- **C2/C3 disposed correctly.** The roster is restored; `git diff 44b9c0d b475d47 -- lua/parley/config.lua` is now only the `fable` filter and the alias-block deletion, and the operator's cleanup is parked uncommitted.
- **The goldens pin is faithful.** `parley_harness_golden_spec` 11/11 green with no regeneration — that *is* the evidence the `GOLDEN_AGENT` pin reproduces what `ToolSonnet` used to produce.

## 2. Critical findings

### C-A — eligibility excludes one health state; `unknown` and `disabled` still blame the wrong channel (`lua/parley/cliproxy_auth.lua:198`)

Measured against the shipped modules, stubbing only `credential_health`'s single read and driving the real `credential_health_across_or_one({"antigravity","claude"}, …)`:

```
one read fails (unreachable), the other is an expired claude token
  -> blames channel=antigravity state=unknown account=nil   credential_action = report
antigravity credential operator-DISABLED, claude expired
  -> blames channel=antigravity state=disabled account=someone-else@x.com
                                                  credential_action = prompt_login
```

`HEALTH_RANK` is `{missing=0, disabled=1, unavailable=2, error=3, healthy=4}` and `healthier` maps an unlisted state to `-1`, so `unknown` is the *worst* reading in the table — worse even than `missing`. `could_have_served` filters `missing` only, so both survive to the reducer and win. Reachability is not theoretical: `auth_files` returns `state="unknown"` for six distinct read failures (`unreachable`, `no_management_route`, `management_key_mismatch`, `http_*`, `undecodable`, `no_endpoint`), and the 404-repair path makes the asymmetry **deterministic** — in a 2-channel fan-out the first read sets `_management_restart_done` and restarts, the second hits `if _management_restart_done then return cb(health) end` (`cliproxy.lua:459`) and returns `unknown`, which then outranks the real post-restart reading.

**The rule, not the site.** `could_have_served` should be defined over the whole enum, not spot-checked against one member: a reading is a candidate only when it is *evidence that a credential the proxy actually tried to use failed*. `missing` (nothing there) and `disabled` (operator turned it off) cannot have served; `unknown`/nil is "we could not look", which is not evidence either way. Fix sketch, in `cliproxy_auth.lua` beside `HEALTH_RANK`:

```lua
local INELIGIBLE = { missing = true, disabled = true }
function M.could_have_served(health)
    local state = (health or {}).state
    return HEALTH_RANK[state] ~= nil and not INELIGIBLE[state]
end
```

and a table-driven test that iterates **every** key of `HEALTH_RANK` plus `nil`/`"unknown"`, so adding a state to the rank table without classifying it fails. `atlas/providers/cliproxy-managed.md:110-117` documents the incomplete rule ("A channel holding NO credential cannot have served the request") and must be corrected in the same pass — that sentence is exactly the one-value framing that produced this.

## 3. Important findings

### I-A — `credential_health_across_or_one` hardcodes `repaired = nil` on the multi-candidate branch (`lua/parley/cliproxy.lua:539`)

`cb(health, channel, nil)`. `recover` sets `restarted_this_claim = repaired == true` (`:1391`), so on the fan-out path — which is now the *default*, since the alias block is gone and every anthropic/openai model yields two candidates — the flag is permanently false and the `restarted_this_claim` guard at `:1357` never fires. `credential_health`'s own docstring (`:430-432`) calls the compound repair-then-restart case "made UNREACHABLE rather than budgeted"; this refactor makes it reachable again, stacking ~36s past the dispatcher's 25s backstop so "recovery timed out" replaces the diagnosis. It has no test, and the docstring at `:523-525` acknowledges the signal matters ("One candidate → … preserving its `repaired` flag") immediately before discarding it on the other branch. Fix: thread `repaired` through the fan-out (true if any reading repaired), or route the repair through a single pre-flight read before fanning out.

### I-B — the fan-out's tie-break is nondeterministic (`lua/parley/cliproxy.lua:511`)

`readings[#readings + 1] = …` runs inside each async callback, so the list is in *completion* order, not candidate order. `likeliest_culprit` keeps the first of equal-ranked readings (`unhealthier` is strict), so when two candidates share a state — two `error` credentials, say — the account named in the diagnosis depends on which management read returns first. Same input, different user-visible answer across runs, and unreproducible bug reports. One-line fix: capture the loop index and write `readings[i] = …`, then compact, so order is the declared candidate order.

### I-C — the golden pin is duplicated into two hand-synced copies (`scripts/refresh_goldens.lua:26-31`, `tests/unit/parley_harness_golden_spec.lua:33-38`)

The fix's own stated rule is "a golden must depend on nothing that a product decision can move" — but `GOLDEN_AGENT` is now defined twice, verbatim, in the regenerator and the verifier, joining the pre-existing hand-synced `READONLY_TOOLS` (whose comment already says "Keep in sync with…"). The boundary doubled the number of literals a human must keep equal to make `make fixtures` produce goldens the spec accepts. Fix: hoist both into one shared table (e.g. `tests/fixtures/golden_pin.lua`) that both files require.

> **This is the 6th finding in family `single-source-not-enforced`.** Earlier rounds fixed instances. The rule that covers all six: *when two files must agree on a literal, the agreement must be executable — one definition required by both — never a "keep in sync" comment.* The enumeration to sweep in one pass rather than per-finding: `grep -rn "[Kk]eep in sync\|mirrors the .* in " lua/ tests/ scripts/` and convert every hit to a shared require. Measured prevalence: 6 findings.

### I-D — `scripts/parley_harness.lua` / `build_payload` (`opts.agent`) is in neither plan table

The diff adds a new public option to `build_payload` (`scripts/parley_harness.lua:67-76`), consumed by three spec files and the regenerator, and neither the Pure nor the Integration table in `workshop/plans/000205-…-plan.md:23-88` mentions the module or the function.

> **This is the 7th finding in family `plan-table-missing-entity`.** The rule was already *stated* last round — "the input list should be `git diff --name-only <base> <head> -- lua/ scripts/ tests/fixtures/`, not the author's memory" — and then not implemented, which is why this recurs. Do not add one row: add the command to the plan's §Notes check so the table's completeness is derived from the diff, and reconcile all rows in one pass. Measured prevalence: 7 findings.

### I-E — three stacked doc blocks precede `credential_health_across`, one documenting a parameter that does not exist (`lua/parley/cliproxy.lua:478-504`)

`credential_health_for_login`'s docstring (`:478-486`, still ending in `@param login`/`@param cb`) is followed by a block describing a `prefer fun(a, b): boolean` comparator — a signature that no longer exists anywhere — and only then by the current `@param choose` block, all above one function. `credential_health_for_login` itself (`:532`) now has no docstring at all. Separately, `recover` retains the pre-M4 comment paragraph "fall back to resolving the model through oauth-model-alias" (`:1303-1306`) immediately above its replacement (`:1307-1312`), two paragraphs stating different contracts back to back.

> **This is the 3rd finding in family `docs-insert-orphans-section`.** The rule is already written at `workshop/lessons.md:962-964` ("An insertion goes after the preceding function's body, never between a doc block and the function it documents") and was violated again by the commit range that appends to that same file. Restating it has now failed twice — make it mechanical: a lint check that flags any `function M.x(…)` whose immediately-preceding `---@param` block names an identifier absent from the signature would catch all three instances, including the dead `prefer`.

## 4. Minor findings

- `tests/integration/cliproxy_recovery_e2e_spec.lua:158,163` — both negative guards are inert. When I reverted the fix the notice read `…no credential is loaded for this channel…`: it never contains the string `antigravity` (the channel name reaches only `vim.ui.select`, which the spec stubs), and `Add it to` is a literal the rewrite cleared trivially while the key is still recommended. Only `assert.matches("me@example.com")` discriminates; drop the two or assert on the `vim.ui.select` argument.
- `tests/unit/config_tools_spec.lua:390` pins a state production cannot reach: `refresh_state` (`init.lua:1345`) resets `_state.agent` to `_agents[1]` whenever the persisted name is absent, so a deleted-selected-agent never reaches `get_agent`. I probed it — a `state.json` naming a vanished agent yields `state.agent after setup = Claude-Fable`, no crash, on the *old* logic too. The genuinely reachable variant is `_state.agent == nil` (every agent disabled → `#_agents == 0`), which the old code crashed on via `"Agent " .. nil` and the new `error(…)` handles cleanly — and which has no test. The plan note's claim that this "crashed every request until the state file was hand-edited" is not supported; the fix is worth keeping as a guard, but the claim and the test title should describe what they actually cover. (4th in `test-title-overstates-guard`; the rule — *a test title and its fixture must describe the same reachable state* — is the one to fix, by requiring each regression test to name the production caller that produces its input.)
- `README.md:199` and `atlas/providers/cliproxy-managed.md:94` still show `"claude:opus,sonnet"` while the same commit range changed the shipped default to `"claude:opus,sonnet,fable"` (`config.lua:145`). (4th in `atlas-not-updated-for-new-surface`; rule as stated last round — grep every literal the diff changes in `config.lua` across `README.md atlas/ docs/`.)
- `lua/parley/cliproxy_config.lua:265-271` — `@param models` is placed *after* `@return`, breaking the annotation block; and `resolve_login_provider` has zero production call sites (tests only) yet gained a new parameter this round. Either wire it or delete it.
- `lua/parley/cliproxy.lua:499-502` — `credential_health_across`'s `#channels == 0` branch is unreachable; both callers guard first.
- `lua/parley/cliproxy_auth.lua:479-497` — `credential_health_for_login`'s "healthiest wins" reducer is an inline closure in the IO shell while its twin policy was extracted to the pure module. Asymmetric: extract it as `ca.healthiest` next to `likeliest_culprit`.
- `tests/unit/config_tools_spec.lua:160` — `assert.is_string(agent.provider)` is a tautology (every agent has a string provider after setup); drop the line rather than assert nothing. `default_tool_agent()` also returns the *alphabetically first* tool-enabled agent, not "the default" — rename or key it off `_state.agent`.
- `tests/integration/chat_respond_spec.lua:1296-1308` — the inserted `TOOL_AGENT` block sits at column 0 inside a `describe` body while its first comment line is indented four. Cosmetic; luacheck is clean.
- Worktree is dirty at the boundary: `lua/parley/config.lua` carries the operator's uncommitted −192-line roster cleanup and `docs/parley.nvim.md` is untracked. Neither is in this window. (3rd in `close-stages-unreviewed-worktree`; rule: build the close commit from an explicit path list, never `git commit -a`.)
- `workshop/plans/000205-…-plan.md:1350-1354` (Task 4.1 prose) still presents "the LEAST healthy candidate is the one that plausibly failed" as the design. The appended C1 note supersedes it, but a reader reaching Task 4.1 first gets the rule the code deliberately no longer implements.

## 5. Test coverage notes

- Verified green at the pinned head in a clean worktree: 191 spec files pass, `luacheck lua tests` → 0 warnings / 0 errors in 345 files. The single failing file (`tests/arch/destructive_recipe_spec.lua`) fails only because the worktree cannot resolve `Makefile → ../ariadne/Makefile`; it is an artifact of my checkout, not the boundary. **The boundary does not ship a red gate.**
- Mutation-checked the headline claim: `could_have_served → return true` turns `cliproxy_recovery_e2e_spec`'s "names the claude login … with NO alias block" red. Confirmed addressed.
- `credential_health_across`, `credential_health_across_or_one` and `unhealthier` still have **zero** direct tests (`grep -rn "credential_health_across\|unhealthier" tests/` → empty). The e2e now covers the happy multi-candidate path, which is a real improvement, but nothing asserts `repaired` survives (I-A), nothing asserts the tie-break (I-B), and nothing varies a candidate's state to `unknown`/`disabled` — which is precisely the bug C-A shipped. One unit case per row of `HEALTH_RANK` would have caught it.
- The `fake_cliproxy` gap: no fake-driven case makes one channel's management read fail while another succeeds, so the deterministic 404-repair asymmetry has no witness at all.

## 6. Architectural notes

- **ARCH-DRY — flag.** The `credential_health_across` extraction is genuine and both reducers now share one traversal. Against it: `GOLDEN_AGENT` duplicated across the regenerator and its verifier (I-C), and the healthiest-wins reducer left inline while its twin was extracted.
- **ARCH-PURE — flag (improved).** Moving the eligibility policy into `cliproxy_auth.lua` is exactly right and is why C-A has a cheap unit-test fix. The residue is `credential_health_for_login`'s inline reducer at `cliproxy.lua:485-495` — a policy still living in the IO shell. (`pure-decision-in-io-shell`, 2nd. Rule: *if a branch names a policy, it belongs in the pure module even when its inputs arrive asynchronously* — apply it to the twin, not just the one the last finding named.)
- **ARCH-PURPOSE — flag.** C-A is the class-vs-instance failure in its clearest form: the round *named* the rule ("eligibility before ranking") and then implemented it for one of five enum values. The Done-when "credential health picks between them rather than the code guessing" is met for `missing` and unmet for `unknown` and `disabled`. The shadow-sweep over the alias-block removal is otherwise complete — `oauth-model-alias` survives only as an honored override, its give_up texts, README and atlas.
- **ARCH-MOCK — pass with one gap.** The new e2e drives a real per-channel credential difference through `fake_cliproxy` (claude expired in the store, antigravity absent), so production and test flow share the boundary. The gap is that the fake cannot express a *read failure* on one channel, which is the shape C-A needs.
- **ARCH-CONSTRAINTS — flag.** The recovery path now issues N unbounded concurrent management reads (4 for a google-owned model) inside the dispatcher's 25s backstop, one of which can restart the proxy out from under the others; combined with I-A's lost `repaired` flag the worst case stacks two repair budgets. Bound the fan-out (or pre-flight one read, then fan out) before this reaches a google-owned model.

## 7. Plan revision recommendations

Append these `## Revisions` entries (do not overwrite; the two post-hoc notes added this round are fine to leave and correct in place by appending):

1. **"Eligibility is an enumeration, not a special case."** Record that the 2026-09-01 C1 note's rule ("a channel with NO credential could not have served the request") is a strict subset of the real rule, and state the corrected one over every `HEALTH_RANK` state plus the implicit `unknown`. Correct the atlas paragraph it seeded.
2. **"The fan-out drops `repaired`."** Record that `credential_health_across_or_one` returns `nil` on the multi-candidate branch, that this is now the default path, and that the compound repair-then-restart case `credential_health`'s docstring calls "UNREACHABLE" is reachable again — with the Done-when that closes it.
3. **Task 4.1 prose correction** — strike or annotate the "the LEAST healthy candidate is the one that plausibly failed" sentence at the design-rationale level, so the plan does not keep asserting the rule the code was fixed to stop implementing.
4. Add `scripts/parley_harness.lua` / `build_payload` (`opts.agent`) to the Integration-points table, and replace the table's authorship with the diff-derived enumeration named in I-D.

```findings
findings:
  - id: new
    severity: Critical
    family: missing-input-guard
    title: |
      could_have_served excludes only `missing`; `unknown` and `disabled` still outrank a real failure and name the wrong account
    detail: |
      Measured against the shipped fan-out (stubbing only credential_health's single read):
      an `unknown` reading (rank -1, the worst in HEALTH_RANK — six distinct auth_files read
      failures produce it) beats an expired `error` credential and degrades credential_action
      to `report`; a `disabled` reading (rank 1) beats it too and fires prompt_login naming
      someone-else@x.com. The 404-repair path makes the `unknown` case deterministic: in a
      2-channel fan-out the second read hits `if _management_restart_done then return cb(health)`
      at cliproxy.lua:459 and returns unknown. This is the #197 wrong-account diagnosis the M4
      Done-when targets, still live on the default multi-candidate path.
      This is the 4th finding in family `missing-input-guard`. Do NOT patch the two states —
      state the rule over the whole enum: a candidate is a reading that is EVIDENCE a credential
      the proxy actually used failed, i.e. `HEALTH_RANK[state] ~= nil and not INELIGIBLE[state]`
      with INELIGIBLE = { missing, disabled }; pin it with a test that iterates every key of
      HEALTH_RANK plus nil, so a new state cannot be added without classifying it. Correct
      atlas/providers/cliproxy-managed.md:110-117, which documents the one-value rule verbatim.
  - id: new
    severity: Important
    family: extracted-seam-drops-a-signal
    title: |
      credential_health_across_or_one hardcodes repaired=nil on the multi-candidate branch, defeating the one-restart-per-claim guard
    detail: |
      cliproxy.lua:539 passes nil, so `restarted_this_claim` at :1391 is permanently false on
      the fan-out path — now the DEFAULT path, since deleting the alias block gives every
      anthropic/openai model two candidates. The guard at :1357 never fires, re-enabling the
      compound repair-then-restart (~36s) that credential_health's docstring at :430-432 calls
      "made UNREACHABLE rather than budgeted"; the operator gets "recovery timed out" instead of
      the diagnosis parley computed. No test covers it. Thread `repaired` through the fan-out
      (true if any reading repaired), or pre-flight one read before fanning out.
  - id: new
    severity: Important
    family: fanout-result-order-nondeterministic
    title: |
      readings are collected in callback-completion order, so a tie in likeliest_culprit names a random channel
    detail: |
      cliproxy.lua:511 appends inside each async callback. likeliest_culprit keeps the first of
      equal-ranked readings, so two candidates in the same state (two `error` credentials) yield
      a different named account run to run — an unreproducible user-visible diagnosis. Capture
      the loop index and write readings[i], then compact, so the order is the declared candidate
      order.
  - id: new
    severity: Important
    family: single-source-not-enforced
    title: |
      GOLDEN_AGENT is defined twice — once in the regenerator, once in the verifier — and must be kept equal by hand
    detail: |
      scripts/refresh_goldens.lua:26-31 and tests/unit/parley_harness_golden_spec.lua:33-38 hold
      verbatim copies, joining the pre-existing hand-synced READONLY_TOOLS ("Keep in sync with…").
      The fix's own stated rule is that a golden must depend on nothing a product decision can
      move; it now depends on two humans keeping two literals equal.
      This is the 6th finding in family `single-source-not-enforced`. Do NOT fix this instance —
      the rule is that agreement between two files must be EXECUTABLE (one definition both
      require), never a comment. Sweep the enumeration in one pass:
      `grep -rn "[Kk]eep in sync\|mirrors the .* in " lua/ tests/ scripts/`.
  - id: new
    severity: Important
    family: plan-table-missing-entity
    title: |
      scripts/parley_harness.lua / build_payload's new `opts.agent` option is in neither Core-concepts table
    detail: |
      A new public option consumed by three spec files and the regenerator (parley_harness.lua:67-76);
      neither the module nor the function appears in the plan's Pure or Integration tables.
      This is the 7th finding in family `plan-table-missing-entity`. The rule was already STATED
      last round — the table's input list must be `git diff --name-only <base> <head> -- lua/
      scripts/ tests/fixtures/`, not the author's memory — and not implemented, which is why it
      recurs. Do NOT add one row: wire that command into the plan's §Notes check and reconcile
      every row in one pass.
  - id: new
    severity: Important
    family: docs-insert-orphans-section
    title: |
      Three stacked doc blocks precede credential_health_across, one documenting a `prefer` parameter that no longer exists
    detail: |
      cliproxy.lua:478-504 — credential_health_for_login's docstring (still ending in @param login /
      @param cb), then a block describing `prefer fun(a,b): boolean` (a signature deleted in this
      same range), then the current @param choose block, all above one function;
      credential_health_for_login at :532 has no docstring. Separately recover retains the pre-M4
      paragraph "fall back to resolving the model through oauth-model-alias" (:1303-1306) directly
      above its replacement (:1307-1312).
      This is the 3rd finding in family `docs-insert-orphans-section`. The rule is already at
      workshop/lessons.md:962-964 and was violated again by the range that appends to that file.
      Restating it has failed twice — make it mechanical: lint any `function M.x(...)` whose
      immediately-preceding ---@param block names an identifier absent from the signature.
  - id: new
    severity: Minor
    family: test-title-overstates-guard
    title: |
      The get_agent stale-selection test pins a state production cannot produce; the reachable variant is untested
    detail: |
      refresh_state (init.lua:1345) resets _state.agent to _agents[1] whenever the persisted name
      is absent, so a deleted-selected-agent never reaches get_agent. Probed: a state.json naming
      a vanished agent yields "state.agent after setup = Claude-Fable", no crash, under the OLD
      logic too — so the plan note's "crashed every request until the state file was hand-edited"
      is unsupported. The genuinely reachable variant is _state.agent == nil (every agent disabled,
      #_agents == 0), which the old code crashed on via string-concat and the new error() handles
      cleanly, and which has no test.
      This is the 4th finding in family `test-title-overstates-guard`. The rule: a regression test
      must name the production caller that produces its input; if none exists, it is a defensive
      guard and must be titled as one.
  - id: new
    severity: Minor
    family: atlas-not-updated-for-new-surface
    title: |
      README and atlas still show `claude:opus,sonnet` after the same range shipped `claude:opus,sonnet,fable`
    detail: |
      README.md:199 and atlas/providers/cliproxy-managed.md:94 restate a default that config.lua:145
      changed in this window.
      This is the 4th finding in family `atlas-not-updated-for-new-surface`. The rule was stated
      last round: for each literal the diff changes in lua/parley/config.lua, grep it across
      README.md atlas/ docs/ and fix or strike every hit. Wire that grep into the docs step rather
      than fixing these two lines.
  - id: new
    severity: Minor
    family: test-title-overstates-guard
    title: |
      Two of the empty-alias e2e case's guards are inert — the notice can never contain "antigravity"
    detail: |
      tests/integration/cliproxy_recovery_e2e_spec.lua:158,163. Reverting the fix produced
      'cliproxy for "claude-opus-4-8": no credential is loaded for this channel' — no channel name
      (that reaches only vim.ui.select, which the spec stubs), and "Add it to" is a literal the
      rewrite clears trivially while the key is still recommended. Only assert.matches("me@example.com")
      discriminates. Assert on the vim.ui.select argument, or drop the two.
  - id: new
    severity: Minor
    family: pure-decision-in-io-shell
    title: |
      credential_health_for_login's healthiest-wins reducer stays an inline closure in the IO shell while its twin was extracted
    detail: |
      cliproxy.lua:485-495. This is the 2nd finding in family `pure-decision-in-io-shell`. The rule:
      if a branch names a POLICY it belongs in the pure module even when its inputs arrive
      asynchronously — apply it to both reducers, not the one the last finding named. Extract
      `ca.healthiest` next to `likeliest_culprit`.
  - id: new
    severity: Minor
    family: dead-api-extended
    title: |
      resolve_login_provider has zero production call sites yet gained a new parameter, and its @param sits after @return
    detail: |
      cliproxy_config.lua:265-271. Only tests call it. Either wire it into recover (it now derives
      from the same source as resolve_channels) or delete it; and move @param models above @return
      so the annotation block parses.
  - id: new
    severity: Minor
    family: close-stages-unreviewed-worktree
    title: |
      The worktree carries an uncommitted 192-line config.lua roster deletion and an untracked docs/parley.nvim.md at the boundary
    detail: |
      Neither is in the review window. This is the 3rd finding in family
      `close-stages-unreviewed-worktree`. The rule: build the close commit from an explicit path
      list, never `git commit -a` — enforce it in the close step rather than re-checking by eye.
  - id: new
    severity: Minor
    family: stated-design-not-implemented
    title: |
      Plan Task 4.1 still presents "the LEAST healthy candidate is the one that plausibly failed" as the design
    detail: |
      workshop/plans/000205-live-cliproxy-model-picker-plan.md:1350-1354. The appended C1 note
      supersedes it, but a reader reaching Task 4.1 first gets the rule the code was fixed to stop
      implementing. Annotate in place with a pointer to the revision.
```
