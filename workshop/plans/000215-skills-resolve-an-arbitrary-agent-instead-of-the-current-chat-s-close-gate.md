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

## Open findings

- **BR-1** [Important] `seam-untested-by-pure-double` The transcript seam — the issue's actual deliverable — is pinned by no test
- **BR-2** [Important] `debug-level-silent-degrade` pcall failure at the seam logs at debug level, which never notifies the user
- **BR-3** [Important] `redundant-buffer-reparse` Full parse_chat run eagerly on a keystroke path to read four header lines
- **BR-4** [Important] `weaker-adhoc-predicate` Chat detection re-invented as "buffer contains a ---", weaker than p.not_chat
- **BR-5** [Minor] `derived-doc-drift` The transcript tier is numbered four different ways across code, tests, atlas and Spec
- **BR-6** [Minor] `seam-untested-by-pure-double` Cascade tests placed in define_spec.lua, which is outside the skill-system traceability map
- **BR-7** [Minor] `comment-asserts-unexercised-behavior` define_spec.lua:243-248 comment describes a code path its fixture never reaches
- **BR-8** [Minor] `dead-defensive-branch` info.model or selected.model at skill_invoke.lua:217 is a dead fallback
