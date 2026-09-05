---
gate: boundary-review
issue: 215
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-04T16:23:21-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Important
          title: The transcript seam — the issue's actual deliverable — is pinned by no test
          detail: |-
            skill_invoke.lua:206-226 (find_header_end -> parse_chat -> get_agent_info ->
            provider+model merge) has zero coverage. Scratch-reverting line 233 to
            current_agent = nil leaves skill_assembly_spec (17), define_spec (31) and
            skill_invoke_spec (16) all green. The three tests at define_spec.lua:199-256
            inject a hand-built current_agent into the pure resolver and duplicate
            skill_assembly_spec.lua:118-121. Plan item "Integration coverage ... header-override
            path" is ticked over work that is not there.
          family: seam-untested-by-pure-double
          round: 1
        - id: BR-2
          severity: Important
          title: pcall failure at the seam logs at debug level, which never notifies the user
          detail: |-
            skill_invoke.lua:220-224 uses p.logger.debug, and logger.lua:94-96 returns before
            vim.notify for DEBUG and below. A broken transcript merge silently restores the
            exact pre-215 defect. Sibling degradations in the same function use logger.warning
            (:236) and logger.error (:187). The pcall also discards the error object, so even
            the log line carries no diagnostic.
          family: debug-level-silent-degrade
          round: 1
        - id: BR-3
          severity: Important
          title: Full parse_chat run eagerly on a keystroke path to read four header lines
          detail: |-
            skill_invoke.lua:212 calls p.parse_chat where p.chat_parser.parse_header_metadata
            produces the identical headers table (chat_parser.lua:258). Measured 4.84 ms at 986
            lines and 19.42 ms at 4906 lines, versus 0.003/0.008 ms. It runs even when tiers 1-4
            will win (eager evaluation at :233), and on the define path it is the second full
            parse of the same buffer (init.lua:1809-1811 already did one). ARCH-CONSTRAINTS,
            ARCH-DRY.
          family: redundant-buffer-reparse
          round: 1
        - id: BR-4
          severity: Important
          title: Chat detection re-invented as "buffer contains a ---", weaker than p.not_chat
          detail: |-
            skill_invoke.lua:210-211 treats any buffer with a --- line as a chat, so an
            arbitrary markdown artifact's frontmatter now steers provider+model for review and
            voice_apply. The canonical predicate p.not_chat (init.lua:1609, 15+ call sites) also
            requires a configured chat root, timestamped filename and topic:/file: headers.
            artifact_path is already in scope at :164. Latent today (no repo doc carries
            provider:/model:), but it is untrusted-file metadata owning a decision it should
            not. ARCH-SECURE, ARCH-DRY.
          family: weaker-adhoc-predicate
          round: 1
        - id: BR-5
          severity: Minor
          title: The transcript tier is numbered four different ways across code, tests, atlas and Spec
          detail: |-
            skill_assembly.lua:124 says "4" under a 1/1b/2/3/4/5 scheme; atlas/skills/skill-system.md
            and the issue Spec both say 5 under a 1..6 scheme; the unit tests label it "tier 4".
          family: derived-doc-drift
          round: 1
        - id: BR-6
          severity: Minor
          title: Cascade tests placed in define_spec.lua, which is outside the skill-system traceability map
          detail: |-
            The three new tests are resolve_agent cascade tests, not define tests, and
            tests/integration/define_spec.lua is absent from atlas/traceability.yaml's
            skills/skill-system test list — so make test-changed on the edited atlas file will
            not run them.
          family: seam-untested-by-pure-double
          round: 1
        - id: BR-7
          severity: Minor
          title: define_spec.lua:243-248 comment describes a code path its fixture never reaches
          detail: |-
            The comment cites agent_info.lua:73-85 warning on a failed JSON decode, but
            "{bad json" has no closing brace so value:match("{.*}") never matches and the decode
            branch is never entered — and the test does not call agent_info at all. The bare-string
            model is also a shape transcript_agent cannot produce (agent_info coerces to {model=...}).
          family: comment-asserts-unexercised-behavior
          round: 1
        - id: BR-8
          severity: Minor
          title: info.model or selected.model at skill_invoke.lua:217 is a dead fallback
          detail: |-
            agent_info.resolve coerces info.model to a string or table before returning
            (agent_info.lua:128-137), so it is never nil.
          family: dead-defensive-branch
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-09-04T16:37:52-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: Verified by revert — current_agent=nil turns 4 of the 5 new define_spec tests red; finer reverts pin the header merge and the not_chat guard individually.
          round: 2
        - id: BR-2
          disposition: addressed
          note: logger.warning (notifies; logger.lua:94-96 only returns at DEBUG and below) and the pcall error object is in the message; path observed firing in skill_invoke_spec output.
          round: 2
        - id: BR-3
          disposition: not-addressed
          note: Line 231 no longer calls parse_chat, but the not_chat guard added two lines above calls it via parse_chat_headers (init.lua:206-222). Re-measured on this branch — parse_chat 3.07ms at 1005 lines / 14.02ms at 5005 vs 0.003ms for parse_header_metadata — and the define path still runs it twice (init.lua:1810 plus not_chat), the same count as before the fix. The tier is also still eagerly evaluated at skill_invoke.lua:260, so a user with skill_agent set pays both parses for a tier that cannot fire. Impact is modest on this one-shot path, so this is Minor-grade in practice; the deliverable is the Log correction plus, if cheap, threading the headers not_chat already computed out to the caller.
          round: 2
        - id: BR-4
          disposition: addressed
          note: p.not_chat now guards the merge; removing the guard in a scratch copy turns the NON-chat-buffer test red.
          round: 2
        - id: BR-5
          disposition: addressed
          note: One 1..6 scheme across skill_assembly.lua, the unit spec, atlas/skills/skill-system.md and the issue Spec.
          round: 2
        - id: BR-6
          disposition: addressed
          note: scripts/spec_test_map.sh list-tests skills/skill-system now returns tests/integration/define_spec.lua.
          round: 2
        - id: BR-7
          disposition: addressed
          note: 'Fixture is now "{bad json}" and the decode branch is entered — run output shows "Parley.nvim: Failed to parse model JSON: {bad json}".'
          round: 2
        - id: BR-8
          disposition: addressed
          note: The `or selected.*` fallbacks are gone; the comment at skill_invoke.lua:234-237 states the tbl_extend reasoning correctly.
          round: 2
      findings:
        - id: BR-9
          severity: Important
          title: A configured-but-wireless agent is skipped at tiers 1-4 with nothing logged, so an explicit setting is silently overridden
          detail: |-
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
          family: debug-level-silent-degrade
          round: 2
        - id: BR-10
          severity: Minor
          title: Two unreachable nil-guards inside the transcript tier, both added by the commit that cleared BR-8
          detail: |-
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
          family: dead-defensive-branch
          round: 2
        - id: BR-11
          severity: Minor
          title: A strict-lookup get_agent double reappears at skill_assembly_spec.lua:153, the exact shape Plan item 1 removed from the shared helper
          detail: |-
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
          family: double-contradicts-production-contract
          round: 2
      blocked: true
    - "n": 3
      timestamp: "2026-09-04T16:52:07-07:00"
      agent: claude
      dispose:
        - id: BR-3
          disposition: addressed
          note: Class fix landed in parse_chat_headers (init.lua:206-219), not the seam; equivalence verified (parse_chat sets headers once at chat_parser.lua:258, never mutates); laziness pinned — eager revert turns 4 integration tests red.
          round: 3
        - id: BR-9
          disposition: addressed
          note: configured() covers exactly the four config tiers; removing the on_dropped call turns 1 unit test red. The shell's warning half is untested — raised as a new class finding rather than re-opening this.
          round: 3
        - id: BR-10
          disposition: not-addressed
          note: Both guards are still at skill_invoke.lua:225 and :233; round 2 touched neither and the issue Log does not mention BR-10. Re-verified the unreachability claim statically.
          round: 3
        - id: BR-11
          disposition: addressed
          note: Both per-test get_agent overrides now `return SELECTION` on a miss, and the contract is documented in-file at the override site.
          round: 3
      findings:
        - id: BR-12
          severity: Important
          title: The shell half of the seam is unpinned — deleting BR-9's warning, or reverting BR-2's warning to debug, leaves the whole suite green
          detail: |-
            This is the 3rd finding in family `seam-untested-by-pure-double`. Do NOT fix
            this instance alone. The rule covering all three: when a finding demands a
            behavior the USER observes, the test must pin it where the user observes it —
            at the shell — not at the pure core's injected boundary; a callback firing is
            not a notify happening. Enumeration by revert on this diff, measured in a
            scratch worktree at HEAD: `current_agent = transcript_agent`
            (skill_invoke.lua:262) → 4 red; the `p.not_chat` guard (:220) → 1 red;
            `on_dropped = … p.logger.warning(…)` (:266-272) → 0 red; the pcall's
            `p.logger.warning` (:247, BR-2's entire fix) → 0 red; and the Done-when
            "the chat's system_prompt does not leak into the skill turn" has no test at
            all. Three of five unenforced, and the two zero-red ones are precisely the
            user-visible halves of the last two rounds' Important findings. Failure
            scenario: someone simplifies the on_dropped block away, or a future refactor
            restores logger.debug, and the suite stays green while a user's explicit
            skill_agent is silently overridden — the exact defect BR-2 and BR-9 were
            raised for. skill_invoke_spec.lua already stubs assembly.resolve_agent, so
            the fix is three cases that stub p.logger.warning into a capture table:
            wireless configured skill_agent, a raising p.get_agent, and a chat carrying a
            system_prompt: header.
          family: seam-untested-by-pure-double
          round: 3
        - id: BR-13
          severity: Minor
          title: The transcript tier re-reads the buffer and re-parses headers that not_chat parsed one line earlier in the same tick
          detail: |-
            This is the 3rd finding in family `redundant-buffer-reparse`. Do NOT fix this
            instance alone. The rule covering all three: before reading or parsing a
            buffer at a seam, check whether the call immediately above already did it,
            and whether the codebase already owns that computation as a named helper —
            reuse it rather than restating its body. Enumeration on this diff is one
            site: skill_invoke.lua:220 calls p.not_chat, which does
            nvim_buf_get_lines + find_header_end + parse_header_metadata
            (init.lua:1617-1621); lines 223-231 then do all three again. init.lua:206-219
            is that exact sequence as `parse_chat_headers`, currently file-local.
            Exporting it and calling it here removes the duplication and simultaneously
            deletes BR-10's dead `if not header_end` guard at :225. Cost today is one
            extra whole-buffer read per skill invocation on a path that then makes an
            HTTP request — small, which is why this is Minor rather than a repeat of
            BR-3's severity.
          family: redundant-buffer-reparse
          round: 3
        - id: BR-14
          severity: Minor
          title: The new drop warning can name an agent the user never configured
          detail: |-
            skill_invoke.lua:267 reports `dropped.name`, but get_agent never returns nil —
            an unknown configured name yields the live selection, so with
            skill_agent = "Typo" and a wireless selection the message reads "configured
            agent 'SEL' (skill_agent) has no tool wire", naming an agent the user did not
            set. Narrow (needs both conditions) and get_agent's own "Agent Typo not found,
            using SEL" precedes it, so it is traceable. Passing the configured name into
            `source` would make the line self-describing.
          family: misattributed-diagnostic
          round: 3
      blocked: true
    - "n": 4
      timestamp: "2026-09-04T17:04:33-07:00"
      agent: claude
      dispose:
        - id: BR-10
          disposition: not-addressed
          note: Both guards remain at skill_invoke.lua:225 and :233, untouched by round 3; re-verified statically that not_chat (init.lua:1604-1634) already required find_header_end to succeed and agent_info.resolve unconditionally returns info (agent_info.lua:143).
          round: 4
        - id: BR-12
          disposition: addressed
          note: 'Both user-observable halves pinned and verified by mutation in a scratch worktree (warning→debug = 1 red; on_dropped removed = 1 red; restored = 0). The third enumerated item is withdrawn on inspection: nothing in the skill path reads agent.system_prompt, so that Done-when has no observable failure mode to pin.'
          round: 4
        - id: BR-13
          disposition: not-addressed
          note: skill_invoke.lua:224-231 still re-reads the buffer and re-runs find_header_end + parse_header_metadata after p.not_chat did all three; init.lua:206-219 remains file-local and unexported.
          round: 4
        - id: BR-14
          disposition: addressed
          note: source now carries the configured name at all four tiers; reverting skill_assembly.lua:144 to the bare "skill_agent" string turns skill_assembly_spec.lua:179 red.
          round: 4
      findings:
        - id: BR-15
          severity: Minor
          title: The BR-2 test restores its parley.get_agent stub only on the happy path, so one raise poisons every later test in the file
          detail: |-
            define_spec.lua:309 restores parley.get_agent as the last statement inside
            the captured block, and again at :311 after capture_warnings returns — but
            capture_warnings re-raises with `error(err)` at :288 before either runs, and
            after_each does not restore it. Demonstrated by injecting one error() into
            the captured block in a scratch worktree at HEAD: 5 tests fail instead of 1,
            the four extras with a cause unrelated to the injected fault. The rule: a
            test that replaces module-level state must restore it on every exit path —
            in after_each, or inside the same pcall-guarded wrapper that already does
            this correctly for logger.warning ten lines above (define_spec.lua:283-291).
          family: stub-outlives-its-test
          round: 4
      blocked: false
---

# Gate ledger — parley.nvim#215 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-04T16:23:21-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `seam-untested-by-pure-double` The transcript seam — the issue's actual deliverable — is pinned by no test
  skill_invoke.lua:206-226 (find_header_end -> parse_chat -> get_agent_info ->
  provider+model merge) has zero coverage. Scratch-reverting line 233 to
  current_agent = nil leaves skill_assembly_spec (17), define_spec (31) and
  skill_invoke_spec (16) all green. The three tests at define_spec.lua:199-256
  inject a hand-built current_agent into the pure resolver and duplicate
  skill_assembly_spec.lua:118-121. Plan item "Integration coverage ... header-override
  path" is ticked over work that is not there.
- **BR-2** [Important] `debug-level-silent-degrade` pcall failure at the seam logs at debug level, which never notifies the user
  skill_invoke.lua:220-224 uses p.logger.debug, and logger.lua:94-96 returns before
  vim.notify for DEBUG and below. A broken transcript merge silently restores the
  exact pre-215 defect. Sibling degradations in the same function use logger.warning
  (:236) and logger.error (:187). The pcall also discards the error object, so even
  the log line carries no diagnostic.
- **BR-3** [Important] `redundant-buffer-reparse` Full parse_chat run eagerly on a keystroke path to read four header lines
  skill_invoke.lua:212 calls p.parse_chat where p.chat_parser.parse_header_metadata
  produces the identical headers table (chat_parser.lua:258). Measured 4.84 ms at 986
  lines and 19.42 ms at 4906 lines, versus 0.003/0.008 ms. It runs even when tiers 1-4
  will win (eager evaluation at :233), and on the define path it is the second full
  parse of the same buffer (init.lua:1809-1811 already did one). ARCH-CONSTRAINTS,
  ARCH-DRY.
- **BR-4** [Important] `weaker-adhoc-predicate` Chat detection re-invented as "buffer contains a ---", weaker than p.not_chat
  skill_invoke.lua:210-211 treats any buffer with a --- line as a chat, so an
  arbitrary markdown artifact's frontmatter now steers provider+model for review and
  voice_apply. The canonical predicate p.not_chat (init.lua:1609, 15+ call sites) also
  requires a configured chat root, timestamped filename and topic:/file: headers.
  artifact_path is already in scope at :164. Latent today (no repo doc carries
  provider:/model:), but it is untrusted-file metadata owning a decision it should
  not. ARCH-SECURE, ARCH-DRY.
- **BR-5** [Minor] `derived-doc-drift` The transcript tier is numbered four different ways across code, tests, atlas and Spec
  skill_assembly.lua:124 says "4" under a 1/1b/2/3/4/5 scheme; atlas/skills/skill-system.md
  and the issue Spec both say 5 under a 1..6 scheme; the unit tests label it "tier 4".
- **BR-6** [Minor] `seam-untested-by-pure-double` Cascade tests placed in define_spec.lua, which is outside the skill-system traceability map
  The three new tests are resolve_agent cascade tests, not define tests, and
  tests/integration/define_spec.lua is absent from atlas/traceability.yaml's
  skills/skill-system test list — so make test-changed on the edited atlas file will
  not run them.
- **BR-7** [Minor] `comment-asserts-unexercised-behavior` define_spec.lua:243-248 comment describes a code path its fixture never reaches
  The comment cites agent_info.lua:73-85 warning on a failed JSON decode, but
  "{bad json" has no closing brace so value:match("{.*}") never matches and the decode
  branch is never entered — and the test does not call agent_info at all. The bare-string
  model is also a shape transcript_agent cannot produce (agent_info coerces to {model=...}).
- **BR-8** [Minor] `dead-defensive-branch` info.model or selected.model at skill_invoke.lua:217 is a dead fallback
  agent_info.resolve coerces info.model to a string or table before returning
  (agent_info.lua:128-137), so it is never nil.

## Round 2 — 2026-09-04T16:37:52-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — addressed — Verified by revert — current_agent=nil turns 4 of the 5 new define_spec tests red; finer reverts pin the header merge and the not_chat guard individually.
- BR-2 — addressed — logger.warning (notifies; logger.lua:94-96 only returns at DEBUG and below) and the pcall error object is in the message; path observed firing in skill_invoke_spec output.
- BR-3 — not-addressed — Line 231 no longer calls parse_chat, but the not_chat guard added two lines above calls it via parse_chat_headers (init.lua:206-222). Re-measured on this branch — parse_chat 3.07ms at 1005 lines / 14.02ms at 5005 vs 0.003ms for parse_header_metadata — and the define path still runs it twice (init.lua:1810 plus not_chat), the same count as before the fix. The tier is also still eagerly evaluated at skill_invoke.lua:260, so a user with skill_agent set pays both parses for a tier that cannot fire. Impact is modest on this one-shot path, so this is Minor-grade in practice; the deliverable is the Log correction plus, if cheap, threading the headers not_chat already computed out to the caller.
- BR-4 — addressed — p.not_chat now guards the merge; removing the guard in a scratch copy turns the NON-chat-buffer test red.
- BR-5 — addressed — One 1..6 scheme across skill_assembly.lua, the unit spec, atlas/skills/skill-system.md and the issue Spec.
- BR-6 — addressed — scripts/spec_test_map.sh list-tests skills/skill-system now returns tests/integration/define_spec.lua.
- BR-7 — addressed — Fixture is now "{bad json}" and the decode branch is entered — run output shows "Parley.nvim: Failed to parse model JSON: {bad json}".
- BR-8 — addressed — The `or selected.*` fallbacks are gone; the comment at skill_invoke.lua:234-237 states the tbl_extend reasoning correctly.

### Raised

- **BR-9** [Important] `debug-level-silent-degrade` A configured-but-wireless agent is skipped at tiers 1-4 with nothing logged, so an explicit setting is silently overridden
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
- **BR-10** [Minor] `dead-defensive-branch` Two unreachable nil-guards inside the transcript tier, both added by the commit that cleared BR-8
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
- **BR-11** [Minor] `double-contradicts-production-contract` A strict-lookup get_agent double reappears at skill_assembly_spec.lua:153, the exact shape Plan item 1 removed from the shared helper
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

## Round 3 — 2026-09-04T16:52:07-07:00 (claude) — BLOCKED

### Disposed

- BR-3 — addressed — Class fix landed in parse_chat_headers (init.lua:206-219), not the seam; equivalence verified (parse_chat sets headers once at chat_parser.lua:258, never mutates); laziness pinned — eager revert turns 4 integration tests red.
- BR-9 — addressed — configured() covers exactly the four config tiers; removing the on_dropped call turns 1 unit test red. The shell's warning half is untested — raised as a new class finding rather than re-opening this.
- BR-10 — not-addressed — Both guards are still at skill_invoke.lua:225 and :233; round 2 touched neither and the issue Log does not mention BR-10. Re-verified the unreachability claim statically.
- BR-11 — addressed — Both per-test get_agent overrides now `return SELECTION` on a miss, and the contract is documented in-file at the override site.

### Raised

- **BR-12** [Important] `seam-untested-by-pure-double` The shell half of the seam is unpinned — deleting BR-9's warning, or reverting BR-2's warning to debug, leaves the whole suite green
  This is the 3rd finding in family `seam-untested-by-pure-double`. Do NOT fix
  this instance alone. The rule covering all three: when a finding demands a
  behavior the USER observes, the test must pin it where the user observes it —
  at the shell — not at the pure core's injected boundary; a callback firing is
  not a notify happening. Enumeration by revert on this diff, measured in a
  scratch worktree at HEAD: `current_agent = transcript_agent`
  (skill_invoke.lua:262) → 4 red; the `p.not_chat` guard (:220) → 1 red;
  `on_dropped = … p.logger.warning(…)` (:266-272) → 0 red; the pcall's
  `p.logger.warning` (:247, BR-2's entire fix) → 0 red; and the Done-when
  "the chat's system_prompt does not leak into the skill turn" has no test at
  all. Three of five unenforced, and the two zero-red ones are precisely the
  user-visible halves of the last two rounds' Important findings. Failure
  scenario: someone simplifies the on_dropped block away, or a future refactor
  restores logger.debug, and the suite stays green while a user's explicit
  skill_agent is silently overridden — the exact defect BR-2 and BR-9 were
  raised for. skill_invoke_spec.lua already stubs assembly.resolve_agent, so
  the fix is three cases that stub p.logger.warning into a capture table:
  wireless configured skill_agent, a raising p.get_agent, and a chat carrying a
  system_prompt: header.
- **BR-13** [Minor] `redundant-buffer-reparse` The transcript tier re-reads the buffer and re-parses headers that not_chat parsed one line earlier in the same tick
  This is the 3rd finding in family `redundant-buffer-reparse`. Do NOT fix this
  instance alone. The rule covering all three: before reading or parsing a
  buffer at a seam, check whether the call immediately above already did it,
  and whether the codebase already owns that computation as a named helper —
  reuse it rather than restating its body. Enumeration on this diff is one
  site: skill_invoke.lua:220 calls p.not_chat, which does
  nvim_buf_get_lines + find_header_end + parse_header_metadata
  (init.lua:1617-1621); lines 223-231 then do all three again. init.lua:206-219
  is that exact sequence as `parse_chat_headers`, currently file-local.
  Exporting it and calling it here removes the duplication and simultaneously
  deletes BR-10's dead `if not header_end` guard at :225. Cost today is one
  extra whole-buffer read per skill invocation on a path that then makes an
  HTTP request — small, which is why this is Minor rather than a repeat of
  BR-3's severity.
- **BR-14** [Minor] `misattributed-diagnostic` The new drop warning can name an agent the user never configured
  skill_invoke.lua:267 reports `dropped.name`, but get_agent never returns nil —
  an unknown configured name yields the live selection, so with
  skill_agent = "Typo" and a wireless selection the message reads "configured
  agent 'SEL' (skill_agent) has no tool wire", naming an agent the user did not
  set. Narrow (needs both conditions) and get_agent's own "Agent Typo not found,
  using SEL" precedes it, so it is traceable. Passing the configured name into
  `source` would make the line self-describing.

## Round 4 — 2026-09-04T17:04:33-07:00 (claude) — passed

### Disposed

- BR-10 — not-addressed — Both guards remain at skill_invoke.lua:225 and :233, untouched by round 3; re-verified statically that not_chat (init.lua:1604-1634) already required find_header_end to succeed and agent_info.resolve unconditionally returns info (agent_info.lua:143).
- BR-12 — addressed — Both user-observable halves pinned and verified by mutation in a scratch worktree (warning→debug = 1 red; on_dropped removed = 1 red; restored = 0). The third enumerated item is withdrawn on inspection: nothing in the skill path reads agent.system_prompt, so that Done-when has no observable failure mode to pin.
- BR-13 — not-addressed — skill_invoke.lua:224-231 still re-reads the buffer and re-runs find_header_end + parse_header_metadata after p.not_chat did all three; init.lua:206-219 remains file-local and unexported.
- BR-14 — addressed — source now carries the configured name at all four tiers; reverting skill_assembly.lua:144 to the bare "skill_agent" string turns skill_assembly_spec.lua:179 red.

### Raised

- **BR-15** [Minor] `stub-outlives-its-test` The BR-2 test restores its parley.get_agent stub only on the happy path, so one raise poisons every later test in the file
  define_spec.lua:309 restores parley.get_agent as the last statement inside
  the captured block, and again at :311 after capture_warnings returns — but
  capture_warnings re-raises with `error(err)` at :288 before either runs, and
  after_each does not restore it. Demonstrated by injecting one error() into
  the captured block in a scratch worktree at HEAD: 5 tests fail instead of 1,
  the four extras with a cause unrelated to the injected fault. The rule: a
  test that replaces module-level state must restore it on every exit path —
  in after_each, or inside the same pcall-guarded wrapper that already does
  this correctly for logger.warning ten lines above (define_spec.lua:283-291).

## Open findings

- **BR-10** [Minor] `dead-defensive-branch` Two unreachable nil-guards inside the transcript tier, both added by the commit that cleared BR-8
- **BR-13** [Minor] `redundant-buffer-reparse` The transcript tier re-reads the buffer and re-parses headers that not_chat parsed one line earlier in the same tick
- **BR-15** [Minor] `stub-outlives-its-test` The BR-2 test restores its parley.get_agent stub only on the happy path, so one raise poisons every later test in the file
