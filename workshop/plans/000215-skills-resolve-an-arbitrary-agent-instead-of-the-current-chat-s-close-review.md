# Boundary Review — parley.nvim#215 (whole-issue close)

| field | value |
|-------|-------|
| issue | 215 — Skills resolve an arbitrary agent instead of the current chat's |
| repo | parley.nvim |
| issue file | workshop/issues/000215-skills-resolve-an-arbitrary-agent-instead-of-the-current-chat-s.md |
| boundary | whole-issue close |
| milestone | — |
| window | b7d4595d3aca461494593fc6daebf8b131c0246f..3d70331d1779687f20ea92346eb4aef02a4a0622 |
| command | sdlc close --issue 215 |
| reviewer | claude |
| timestamp | 2026-09-04T16:23:21-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The cascade rework is correct and I verified it live: a chat pinned to `provider: anthropic` / `model: claude-opus-5-pinned` resolves to exactly that pair, the selection's other fields survive, the chat's `system_prompt` does not leak, and both `provider: googleai` (wireless) and `provider: bogus-provider` fall through to the roster without error. The class was swept properly — one resolver, one `capable()` predicate at every tier, all four skills routed through the single `skill_invoke.lua:228` call site, both atlas restatements updated, defaults nilled, lint and the three relevant spec files green (17 + 31 + 16). What blocks SHIP is that the piece which *is* the issue — the header merge at `skill_invoke.lua:206-226` — ships untested and silent on failure. I scratch-reverted `current_agent = transcript_agent()` to `nil` (the whole deliverable disabled) and **all 64 tests still passed**; the plan's `[x] Integration coverage … header-override path` is three pure `resolve_agent` calls with hand-built `current_agent` tables that never touch `find_header_end`/`parse_chat`/`get_agent_info`. Paired with a `logger.debug` swallow that per `logger.lua:94-96` never reaches `vim.notify`, a break in that seam silently restores the exact pre-#215 defect.

### 1. Strengths

- **The PQ-3 ARCH-DRY win actually landed.** `skill_invoke.lua:213` reuses `p.get_agent_info` → `agent_info.resolve` rather than hand-rolling the JSON decode + string→table coercion. Verified end-to-end: the resolved model arrives as `{ model = "claude-opus-5-pinned" }`, the shape `prepare_payload` wants.
- **`capable()` at `skill_assembly.lua:91-95` is the right consolidation of C3** — one predicate, applied uniformly at all six tiers, replacing a check that existed only in the roster scan. Downstream only reads `agent.model`/`agent.provider`, so tier 6's raw `deps.agents[name]` record remains a valid answer.
- **The test-double correction was real work, not ceremony.** `tests/unit/skill_assembly_spec.lua:65-88` fixes the strict-lookup inversion *and* the six bare `{name="A1"}` fixtures it exposed — fixed by giving fixtures providers rather than weakening the predicate. That is the honest direction.
- **Atlas gained a section that never existed** (`atlas/skills/skill-system.md:93-118`), including the two traps (`get_agent` never nil; tier 5 unreachable while `skill_agent` is set) that cost two plan rounds.
- **The `system_prompt` non-inheritance is genuinely correct**, not just asserted: `prepare_payload(inv.messages, agent.model, agent.provider, inv.tools)` never consults `agent.system_prompt`, and `inv.messages[1]` carries the skill body.

### 2. Critical findings

None.

### 3. Important findings

**I1 — `lua/parley/skill_invoke.lua:206` — the transcript seam has no test; the plan item claiming it is ticked.**
Scratch-reverting line 233 to `current_agent = nil` leaves `tests/unit/skill_assembly_spec.lua` (17), `tests/integration/define_spec.lua` (31) and `tests/integration/skill_invoke_spec.lua` (16) all green. The three tests added at `define_spec.lua:199-256` inject a hand-made `current_agent` straight into the pure resolver — they pin tier 4, which `skill_assembly_spec.lua:118-121` already pins, and nothing else.
*Fix:* one integration test that sets buffer lines with `provider:`/`model:` frontmatter, drives the real `skill_invoke.invoke` (the file already stubs `assembly.resolve_agent` at `define_spec.lua:95` — capture the `deps.current_agent` it receives instead of discarding it), and asserts provider+model came from the headers. That test must go red under the revert above.

**I2 — `lua/parley/skill_invoke.lua:220-224` — the seam degrades silently.**
`logger.debug` writes to the log file and returns before `vim.notify` (`logger.lua:94-96`), so a total failure of the transcript merge is invisible: the user gets the pre-#215 behavior with no signal. Every sibling degradation in the same function uses `logger.warning` (`skill_invoke.lua:236`) or `logger.error` (`:187`). Inconsistent error handling across the diff.
*Fix:* `p.logger.warning`, and include `tostring(err)` — the pcall currently discards the error object entirely, so even the log line carries no diagnostic.

**I3 — `lua/parley/skill_invoke.lua:212` — full `parse_chat` to read four header lines, eagerly, on a keystroke path (ARCH-CONSTRAINTS, ARCH-DRY).**
`parsed.headers` is literally `M.parse_header_metadata(lines, header_end)` (`chat_parser.lua:258`); everything else `parse_chat` builds is discarded. Measured on this machine: `parse_chat` 4.84 ms @ 986 lines / 19.42 ms @ 4906 lines, vs `parse_header_metadata` 0.003 / 0.008 ms. Three compounding issues: it runs even when tier 1–4 will win (`transcript_agent()` is evaluated eagerly as a table field at `:233`) — blocking optional work on a critical UI path; on the `<M-CR>` define path it is the **second** full parse of the same buffer, since `init.lua:1809-1811` already did one immediately before calling `invoke`; and `nvim_buf_get_lines` at `:209` is a third read of content `original` already holds at `:180`.
*Fix:* `p.chat_parser.parse_header_metadata(lines, header_end)` instead of `p.parse_chat`. Identical output, ~2400× cheaper.

**I4 — `lua/parley/skill_invoke.lua:210-211` — "not a chat buffer" is re-invented as "contains a `---`" (ARCH-SECURE, ARCH-DRY).**
`find_header_end` returns an index for any buffer with a `---` line (`chat_parser.lua:35-55`), including the first horizontal rule in plain prose. The codebase's canonical predicate is `p.not_chat(buf, file_name)` (`init.lua:1609`, 15+ call sites), which additionally requires a configured chat root, a timestamped filename, and `topic:`/`file:` headers. `review` and `voice_apply` run on arbitrary markdown artifacts, so as written a document's own frontmatter now selects which vendor receives that document. Every `workshop/**/*.md` in this repo has YAML frontmatter; none carries `provider:`/`model:` today, so this is latent rather than active — but it is untrusted-file metadata steering a decision it should not own, guarded by a weaker check than the one already available. `artifact_path` is in scope at `:164`.
*Fix:* `if p.not_chat(buf, artifact_path) then return selected end`.

### 4. Minor findings

- Tier numbering drifts four ways for the same tier: code comments say `4` (`skill_assembly.lua:124`), atlas says `5`, the issue Spec says `5`, the unit tests say `"tier 4"` — and the code's own `1/1b/2/3/4/5` scheme doesn't match atlas's `1..6` at any position.
- `define_spec.lua:212-224` duplicates `skill_assembly_spec.lua:118-121`; all three new tests are cascade tests living in a define file. `tests/integration/define_spec.lua` is absent from `atlas/traceability.yaml`'s `skills/skill-system` test list (line 710+), so `make test-changed` on the atlas edit won't run them.
- `define_spec.lua:243-248` — the comment claims `agent_info.lua:73-85` "warns and passes it through", but `"{bad json"` never reaches that branch (`value:match("{.*}")` needs a closing brace), and the test never calls `agent_info` at all. The bare-string `model` is also a shape `transcript_agent` cannot produce — `agent_info.resolve` coerces to `{model=…}` before returning.
- `skill_invoke.lua:217` — `info.model or selected.model`: `agent_info.resolve` coerces `info.model` to a string-or-table before returning, so the fallback is dead.
- `atlas/skills/skill-system.md:105` says "First capable tier wins" while the numbered list header says the same thing twice; harmless, but the "Explicit configuration outranks ambient context" sentence is the load-bearing one and reads better first.

### 5. Test coverage notes

The pure resolver is well covered — 17 assertions, every tier plus both wireless-fallthrough directions, and I confirmed the new tier-4 test goes red without the resolver change. The gap is entirely at the IO seam (I1): nothing in `tests/` constructs a chat buffer and asserts the resulting agent, so the bug class this diff exists to fix is the one class the suite cannot catch. PQ-5 was disposed `addressed` on the promise of "integration coverage names both adversarial input classes"; as landed, no test exercises `agent_info.resolve` with a malformed `model:` header at all. I verified those degradations manually (malformed-with-braces, malformed-without-braces, `googleai`, unknown provider — all `ok=true`, all fall through to the roster), so they work; they just aren't pinned.

### 6. Architectural notes

- **ARCH-DRY — flag** (I3, I4, and the duplicated tests). The `agent_info.resolve` reuse is the counterweight and it's the right call.
- **ARCH-PURE — pass.** `resolve_agent` stays a pure function of injected deps; all IO moved to the shell. The `wire.resolve` → `providers.cliproxy_strategy` ambient read documented at `skill_assembly.lua:10-14` now fires from `capable()` rather than the roster loop — still one call site, so the header comment remains accurate.
- **ARCH-PURPOSE — flag.** The *class* sweep is exemplary: one resolver, four consumers, both hand-maintained atlas restatements, defaults nilled. But the specific deliverable that is the point of the issue ships unverified and silent-on-failure (I1+I2) — the easy subset at the level of the plan item rather than the feature.
- **ARCH-MOCK — pass.** No new external dependency; the LLM boundary is unchanged and already faked in `define_spec`/`skill_invoke_spec`.
- **ARCH-CONSTRAINTS — flag** (I3): eager, repeated, expensive work on a keystroke path.
- **ARCH-SECURE — flag** (I4). Positives worth recording: the wireless-provider fallthrough is a real blast-radius reduction, and `system_prompt` non-inheritance is correct.
- Forward-looking: `get_agent`'s never-nil contract is now documented in three places (config comment, resolver docstring, atlas) rather than *enforced*. A `deps.lookup_agent` that returns nil on a miss would make tiers 1–4 fall through on a typo'd name — today a typo silently yields the selection **without** header overrides, which is strictly worse than tier 5's selection **with** them. Worth a follow-up issue, not this boundary.

### 7. Plan revision recommendations

Add to the issue's `## Revisions`:

> **### 2026-09-04 — close-review: coverage claim narrowed**
> Plan item "Integration coverage in `tests/integration/define_spec.lua`: header-override path + malformed-frontmatter degradation" was ticked, but what landed are three pure `resolve_agent` calls with injected `current_agent` tables — they do not exercise `skill_invoke.transcript_agent` (`find_header_end` → `parse_chat` → `get_agent_info`). Verified: disabling `current_agent` at the seam leaves the whole suite green. The item is re-opened as "buffer-level test driving `skill_invoke.invoke` on frontmatter-pinned lines"; the malformed-frontmatter degradations were verified manually but remain unpinned.

```findings
findings:
  - id: new
    severity: Important
    family: seam-untested-by-pure-double
    title: |
      The transcript seam — the issue's actual deliverable — is pinned by no test
    detail: |
      skill_invoke.lua:206-226 (find_header_end -> parse_chat -> get_agent_info ->
      provider+model merge) has zero coverage. Scratch-reverting line 233 to
      current_agent = nil leaves skill_assembly_spec (17), define_spec (31) and
      skill_invoke_spec (16) all green. The three tests at define_spec.lua:199-256
      inject a hand-built current_agent into the pure resolver and duplicate
      skill_assembly_spec.lua:118-121. Plan item "Integration coverage ... header-override
      path" is ticked over work that is not there.
  - id: new
    severity: Important
    family: debug-level-silent-degrade
    title: |
      pcall failure at the seam logs at debug level, which never notifies the user
    detail: |
      skill_invoke.lua:220-224 uses p.logger.debug, and logger.lua:94-96 returns before
      vim.notify for DEBUG and below. A broken transcript merge silently restores the
      exact pre-215 defect. Sibling degradations in the same function use logger.warning
      (:236) and logger.error (:187). The pcall also discards the error object, so even
      the log line carries no diagnostic.
  - id: new
    severity: Important
    family: redundant-buffer-reparse
    title: |
      Full parse_chat run eagerly on a keystroke path to read four header lines
    detail: |
      skill_invoke.lua:212 calls p.parse_chat where p.chat_parser.parse_header_metadata
      produces the identical headers table (chat_parser.lua:258). Measured 4.84 ms at 986
      lines and 19.42 ms at 4906 lines, versus 0.003/0.008 ms. It runs even when tiers 1-4
      will win (eager evaluation at :233), and on the define path it is the second full
      parse of the same buffer (init.lua:1809-1811 already did one). ARCH-CONSTRAINTS,
      ARCH-DRY.
  - id: new
    severity: Important
    family: weaker-adhoc-predicate
    title: |
      Chat detection re-invented as "buffer contains a ---", weaker than p.not_chat
    detail: |
      skill_invoke.lua:210-211 treats any buffer with a --- line as a chat, so an
      arbitrary markdown artifact's frontmatter now steers provider+model for review and
      voice_apply. The canonical predicate p.not_chat (init.lua:1609, 15+ call sites) also
      requires a configured chat root, timestamped filename and topic:/file: headers.
      artifact_path is already in scope at :164. Latent today (no repo doc carries
      provider:/model:), but it is untrusted-file metadata owning a decision it should
      not. ARCH-SECURE, ARCH-DRY.
  - id: new
    severity: Minor
    family: derived-doc-drift
    title: |
      The transcript tier is numbered four different ways across code, tests, atlas and Spec
    detail: |
      skill_assembly.lua:124 says "4" under a 1/1b/2/3/4/5 scheme; atlas/skills/skill-system.md
      and the issue Spec both say 5 under a 1..6 scheme; the unit tests label it "tier 4".
  - id: new
    severity: Minor
    family: seam-untested-by-pure-double
    title: |
      Cascade tests placed in define_spec.lua, which is outside the skill-system traceability map
    detail: |
      The three new tests are resolve_agent cascade tests, not define tests, and
      tests/integration/define_spec.lua is absent from atlas/traceability.yaml's
      skills/skill-system test list — so make test-changed on the edited atlas file will
      not run them.
  - id: new
    severity: Minor
    family: comment-asserts-unexercised-behavior
    title: |
      define_spec.lua:243-248 comment describes a code path its fixture never reaches
    detail: |
      The comment cites agent_info.lua:73-85 warning on a failed JSON decode, but
      "{bad json" has no closing brace so value:match("{.*}") never matches and the decode
      branch is never entered — and the test does not call agent_info at all. The bare-string
      model is also a shape transcript_agent cannot produce (agent_info coerces to {model=...}).
  - id: new
    severity: Minor
    family: dead-defensive-branch
    title: |
      info.model or selected.model at skill_invoke.lua:217 is a dead fallback
    detail: |
      agent_info.resolve coerces info.model to a string or table before returning
      (agent_info.lua:128-137), so it is never nil.
```

---

## Re-review — 2026-09-04T16:37:52-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 215 — Skills resolve an arbitrary agent instead of the current chat's |
| repo | parley.nvim |
| issue file | workshop/issues/000215-skills-resolve-an-arbitrary-agent-instead-of-the-current-chat-s.md |
| boundary | whole-issue close |
| milestone | — |
| window | b7d4595d3aca461494593fc6daebf8b131c0246f..39ae27e432e74da0098fc5920639009009ee3a17 |
| command | sdlc close --issue 215 |
| reviewer | claude |
| timestamp | 2026-09-04T16:37:52-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The deliverable is real and now genuinely pinned: I scratch-reverted `current_agent = transcript_agent()` to `nil` and 4 of the 5 new `define_spec` tests went red; finer reverts (disabling only the header merge, and removing only the `not_chat` guard) each turned exactly one test red, and reverting the per-tier `capable()` calls turned 2 unit tests red. The full suite is green (`make test-unit test-integration`, exit 0). One prior finding does not survive: **BR-3 is not-addressed** — swapping `parse_chat` for `parse_header_metadata` at `skill_invoke.lua:231` removed the named call, but the `not_chat` guard added two lines above for BR-4 runs `parse_chat_headers` → `chat_parser.parse_chat` internally (`init.lua:206-222`), so the full parse is still on the path. I measured it: **3.07 ms at 1005 lines, 14.02 ms at 5005 lines**, versus 0.003 ms for `parse_header_metadata`. The `<M-CR>` define path now runs `parse_chat` twice (once at `init.lua:1810`, once inside `not_chat`) — the same count as before the fix. Nothing here blocks the gate: the residual cost precedes a ~30 s network call, and the two new Minor findings are latent. The one Important finding is an observability gap the issue Log already flagged but did not close.

## 1. Strengths

- **The revert check was run and it worked.** `define_spec.lua:196-203` documents *why* asserting on `resolve_agent` with a hand-built `current_agent` pins nothing, and the tests it replaced them with drive the real chain. This is the single most valuable thing in the diff.
- **`not_chat` was the right predicate, and the test knows why it's hard.** `define_spec.lua:229-234` records that `config.chat_dir` alone leaves the resolved roots untouched, so the first attempt silently exercised the non-chat path while claiming to test headers. That comment will save the next person an hour.
- **ARCH-PURPOSE shadow-sweep passes.** `resolve_agent` has exactly one call site (`skill_invoke.lua:255`), and all four consumers — define (`init.lua:1816`), review (`skills/review/init.lua:611`), voice_apply and disk-discovered skills (`skill_picker.lua:26`) — route through `skill_invoke.invoke`. No consumer hand-maintains its own cascade.
- **ARCH-DRY at the merge.** Reusing `agent_info.resolve` rather than re-decoding `model:` JSON means the skill path and the chat path (`chat_respond.lua:744`) cannot drift on model shape. I confirmed there is no `headers.agent` support anywhere, so "selection + provider/model headers" really is the transcript's effective agent.
- **`traceability.yaml:726` verified working** — `scripts/spec_test_map.sh list-tests skills/skill-system` now returns `tests/integration/define_spec.lua`.

## 2. Critical findings

None.

## 3. Important findings

**An explicitly configured agent that lacks a tool wire is now skipped with no user-visible signal** — `lua/parley/skill_assembly.lua:100-123`. `capable()` is correct per the Spec's Done-when, but a user who sets `skills = {{ name = "review", agent = "MyGemini" }}` or `skill_agent = "MyGemini"` now gets a *different* agent silently. `get_agent` still warns on an unknown *name*, so only the known-but-wireless case is silent — precisely the C1 defect this issue exists to fix ("the configured tier is a lie"), inverted. See the findings block for the rule.

## 4. Minor findings

- `lua/parley/skill_invoke.lua:225,233` — two nil-guards that cannot fire (`not_chat` returning nil already guarantees `find_header_end`; `agent_info.resolve` always returns a table).
- `tests/unit/skill_assembly_spec.lua:153` — a strict-lookup `get_agent` double, the exact shape the same commit's Plan item 1 removed from the shared `deps()` helper.
- `skill_assembly.lua:96` still defaults `deps.get_agent` to `function() return nil end` while the docstring six lines above says it is "NEVER nil". Harmless, but the two disagree.
- `define_spec.lua:265` (`dofile("lua/parley/config.lua")`) is cwd-relative and needs none of the `before_each` chat-root scaffolding it sits inside.

## 5. Test coverage notes

- Coverage is now genuinely load-bearing at both levels: the pure resolver covers all six tiers plus capability-at-every-tier, and the seam covers header merge, bare selection, non-chat rejection, and malformed-JSON degradation. I verified each by targeted revert rather than by reading.
- The Done-when clause "the chat's `system_prompt` does not leak into the skill turn" has no test — deliberately not raised as a finding, because it is structurally unreachable twice over: the merge copies only two keys, and `agent` is consumed downstream only as `.model`/`.provider` (`skill_invoke.lua:268,275,289`). A test would assert something the code cannot express.
- `p.logger.warning` at the seam has no assertion, but I confirmed the path is reachable — it fires 16+ times in `skill_invoke_spec` output with the error object attached.

## 6. Architectural notes for upcoming work

- **ARCH-DRY** — flag (folded into BR-3's re-raise): `not_chat` computes `headers, header_end` via a *module-local* `parse_chat_headers` and discards both; the caller immediately re-derives them. Exposing what `not_chat` already knows (or a `chat_headers(buf, path) -> headers|nil` helper) would collapse three full-buffer reads and two header parses into one, and would serve the 15+ existing `not_chat` call sites too.
- **ARCH-PURE** — pass. `resolve_agent` is pure and driven by injected deps; the transcript computation lives entirely in the IO shell. The unit spec runs with no IO.
- **ARCH-PURPOSE** — pass on the feature (shadow-sweep above), flag on one fix: BR-3's benefit was cancelled inside the same commit.
- **ARCH-MOCK** — pass for this window. No new external binary or service; the dispatcher is stubbed through the existing `parley.dispatcher.query` seam with real SSE fixtures.
- **ARCH-CONSTRAINTS** — flag, see BR-3. The keystroke path's parse count is unchanged from pre-fix.
- **ARCH-SECURE** — pass, and improved. The `not_chat` guard closes untrusted-frontmatter steering, pinned by a test that goes red when the guard is removed. Chat files inside a configured root remain trusted to set provider/model, which matches the trust `chat_respond` already grants.
- **Forward:** the deferred `deps.lookup_agent` item in the Log is the right next move. `get_agent`'s never-nil contract is now documented in four places (`skill_assembly.lua:70-77`, the atlas, the unit-spec comment, the issue) and enforced in none — which is what let the strict-lookup double reappear at `skill_assembly_spec.lua:153`. Enforcing it at the seam would make all four restatements derive rather than restate.

## 7. Plan revision recommendations

One `## Revisions` entry, correcting the close-review log entry for I3:

> **2026-09-04 — I3's measured benefit does not hold end-to-end.** The Log records "4.84ms → 0.003ms on a keystroke path". That is true of `skill_invoke.lua:231` in isolation, but the `p.not_chat` guard added for I4 in the same commit calls `parse_chat_headers` (`init.lua:206`), which runs the full `chat_parser.parse_chat`. Re-measured on this branch: `parse_chat` = 3.07 ms at 1005 lines, 14.02 ms at 5005 lines; `parse_header_metadata` = 0.003 ms. The define path therefore still runs `parse_chat` twice (`init.lua:1810` + inside `not_chat`) — the same count as before the fix. The tier is also still evaluated eagerly at `skill_invoke.lua:260`, so a user who sets `skill_agent` pays both parses for a tier that never fires. Strike the ARCH-CONSTRAINTS claim or requalify it as "the explicit second parse was removed; an implicit one inside `not_chat` remains".

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Verified by revert — current_agent=nil turns 4 of the 5 new define_spec tests red; finer reverts pin the header merge and the not_chat guard individually.
  - id: BR-2
    disposition: addressed
    note: |
      logger.warning (notifies; logger.lua:94-96 only returns at DEBUG and below) and the pcall error object is in the message; path observed firing in skill_invoke_spec output.
  - id: BR-3
    disposition: not-addressed
    note: |
      Line 231 no longer calls parse_chat, but the not_chat guard added two lines above calls it via parse_chat_headers (init.lua:206-222). Re-measured on this branch — parse_chat 3.07ms at 1005 lines / 14.02ms at 5005 vs 0.003ms for parse_header_metadata — and the define path still runs it twice (init.lua:1810 plus not_chat), the same count as before the fix. The tier is also still eagerly evaluated at skill_invoke.lua:260, so a user with skill_agent set pays both parses for a tier that cannot fire. Impact is modest on this one-shot path, so this is Minor-grade in practice; the deliverable is the Log correction plus, if cheap, threading the headers not_chat already computed out to the caller.
  - id: BR-4
    disposition: addressed
    note: |
      p.not_chat now guards the merge; removing the guard in a scratch copy turns the NON-chat-buffer test red.
  - id: BR-5
    disposition: addressed
    note: |
      One 1..6 scheme across skill_assembly.lua, the unit spec, atlas/skills/skill-system.md and the issue Spec.
  - id: BR-6
    disposition: addressed
    note: |
      scripts/spec_test_map.sh list-tests skills/skill-system now returns tests/integration/define_spec.lua.
  - id: BR-7
    disposition: addressed
    note: |
      Fixture is now "{bad json}" and the decode branch is entered — run output shows "Parley.nvim: Failed to parse model JSON: {bad json}".
  - id: BR-8
    disposition: addressed
    note: |
      The `or selected.*` fallbacks are gone; the comment at skill_invoke.lua:234-237 states the tbl_extend reasoning correctly.
findings:
  - id: new
    severity: Important
    family: debug-level-silent-degrade
    title: |
      A configured-but-wireless agent is skipped at tiers 1-4 with nothing logged, so an explicit setting is silently overridden
    detail: |
      This is the 2nd finding in family `debug-level-silent-degrade`. Do NOT
      fix this instance alone. The rule that covers both: when a fallback
      overrides something the USER asked for explicitly, the override must
      reach the user at notify level with its reason — never nothing, never
      debug. Enumeration on this diff: skill_assembly.lua:100-123 has four
      tiers (per-skill config, review_agent, manifest.agent, skill_agent) that
      now drop an agent via capable() with no signal; tier 6's silence is
      correct because nobody asked for it, and tier 5's is correct because the
      transcript is ambient. So the enumeration is exactly the four config
      tiers. Failure scenario: a user sets skills = {{name="review",
      agent="MyGemini"}}; get_agent returns the real agent (no name warning),
      wire.resolve("googleai", ...) is nil, and review runs on an entirely
      different agent forever with no line anywhere. That is issue #215's own
      C1 defect ("the configured tier is a lie") re-created in the opposite
      direction. resolve_agent is pure and cannot log, so the shape of the fix
      is to return the skipped explicit names alongside the agent and have
      skill_invoke warn — which also keeps ARCH-PURE intact. The issue Log
      flags this behavior change but does not close it.
  - id: new
    severity: Minor
    family: dead-defensive-branch
    title: |
      Two unreachable nil-guards inside the transcript tier, both added by the commit that cleared BR-8
    detail: |
      This is the 2nd finding in family `dead-defensive-branch`. Do NOT fix
      this instance alone. The rule: before writing a nil-guard, check the
      callee's contract on THIS path; if it cannot return nil here, the guard
      is dead code that reads as protection. Enumeration — the four guards in
      transcript_agent (skill_invoke.lua:206-253): `if p.not_chat(...)` (live),
      `if not header_end` at :225 (DEAD — not_chat returning nil already
      required find_chat_header_end, which IS chat_parser.find_header_end
      (init.lua:201-210), to succeed on the same buffer in the same tick), `if
      not info` at :233 (DEAD — agent_info.resolve unconditionally `return
      info` at agent_info.lua:140), and capable()'s `if not agent`
      (skill_assembly.lua:101, live). Two of four. BR-8 removed one dead
      fallback in this same function and these two survived the sweep, which is
      the class-vs-instance pattern the family exists to catch.
  - id: new
    severity: Minor
    family: double-contradicts-production-contract
    title: |
      A strict-lookup get_agent double reappears at skill_assembly_spec.lua:153, the exact shape Plan item 1 removed from the shared helper
    detail: |
      `get_agent = function(name) return name == "SA" and wireless or nil end`
      returns nil on a miss; production (init.lua:4405-4451) never does — it
      warns and falls back to the selection. The shared deps() helper was
      corrected for exactly this (and the fix is documented at
      skill_assembly_spec.lua:65-70), then the same commit introduced a fresh
      violation in a per-test override. Latent today: with manifest {name =
      "other"} and no skills/manifest.agent, tiers 1-3 never call the double,
      so nothing fails. It becomes a false pass the moment someone adds a
      manifest.agent or a skills entry to that fixture — the double would fall
      through where the real cascade resolves. Rule: a test double stands in
      for a production contract; if it can return a value production cannot,
      it is not a double, and the correction belongs in the shared fixture
      rather than being re-hand-rolled per test.
```
