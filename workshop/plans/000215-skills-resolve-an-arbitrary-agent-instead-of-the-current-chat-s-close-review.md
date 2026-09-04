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
