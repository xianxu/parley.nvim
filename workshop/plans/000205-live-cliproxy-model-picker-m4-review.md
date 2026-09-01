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
