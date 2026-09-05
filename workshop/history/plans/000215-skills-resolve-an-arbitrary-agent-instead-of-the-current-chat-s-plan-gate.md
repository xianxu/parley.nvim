---
gate: plan-quality
issue: 215
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-09-04T15:34:29-07:00"
      agent: claude
      findings:
        - id: PQ-1
          severity: Critical
          title: Both stated causes contradict get_agent's actual never-nil fallback, so the new tier may be a no-op
          detail: |-
            init.lua:4405-4417 shows get_agent never returns nil for an unknown name — it warns and
            returns the _state.agent record (or _agents[1]). tests/unit/config_tools_spec.lua:392-411
            pins exactly this and names skill_agent/review_agent as the callers. So tier 3
            (skill_assembly.lua:90-94) always fires in a default install, tier 4 is unreachable, and
            the agent it yields already equals the current selection — meaning the planned tier 5 is a
            no-op for a chat with no model frontmatter. Re-derive the repro and state which branch
            actually produced the wrong model.
          family: unbacked-existing-behavior-claim
          round: 1
        - id: PQ-2
          severity: Important
          title: Injected get_agent double returns nil on miss while production never does
          detail: |-
            tests/unit/skill_assembly_spec.lua:68-72 models get_agent as a strict lookup, the opposite
            of p.get_agent. The planned unit tests would pass green over the production behavior they
            are meant to guard. Either make the double match production, or change the resolver seam to
            a strict deps.agents lookup and state that contract change explicitly — it redefines tiers
            1, 1b, 2 and 3 for every caller.
          family: injected-double-fidelity
          round: 1
        - id: PQ-3
          severity: Important
          title: Plan does not name agent_info.resolve as the existing header-merge it should reuse
          detail: |-
            ARCH-DRY. agent_info.resolve (agent_info.lua:14-140, reached via p.get_agent_info at
            init.lua:4548) already merges provider/model header overrides and performs the model JSON
            decode plus the string-to-table coercion that skill_invoke.lua:208 depends on. Say whether
            the IO seam reuses it; a hand-rolled merge risks a model-shape mismatch at prepare_payload.
          family: reuse-existing-resolver
          round: 1
        - id: PQ-4
          severity: Minor
          title: Atlas restates the cascade and the default being deleted
          detail: |-
            atlas/skills/skill-system.md:97 documents skill_agent = "Claude-Sonnet" and the cascade;
            atlas/modes/review.md:195 restates review_agent. Both are hand-maintained restatements of
            the model this issue changes and go stale on merge.
          family: derived-doc-drift
          round: 1
        - id: PQ-5
          severity: Minor
          title: No strategy line for malformed chat frontmatter on the new header path
          detail: |-
            The plan names three behaviors to test but not the adversarial input class for the new tier:
            hand-edited frontmatter where model: is malformed JSON (agent_info.lua:73-85 warns and falls
            back to the raw string) or provider: names a provider with no wire.
          family: adversarial-input-strategy
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-09-04T15:37:55-07:00"
      agent: claude
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Problem re-derived from the real branch; nilling skill_agent is now load-bearing so tier 5 is reachable.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: Plan step 1 fixes the double to production semantics before the new tests are written.
          round: 2
        - id: PQ-3
          disposition: addressed
          note: Spec names agent_info.resolve and states the provider+model-only narrowing.
          round: 2
        - id: PQ-4
          disposition: addressed
          note: Both atlas restatements are plan steps.
          round: 2
        - id: PQ-5
          disposition: addressed
          note: Degradation paragraph plus integration coverage names both adversarial input classes.
          round: 2
      blocked: false
content_hash: 4a15cfe4a0eff1f783af683f8d90dc92aaef669842768c6272d0ba778e8ce3b0
---

# Gate ledger — parley.nvim#215 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-04T15:34:29-07:00 (claude) — BLOCKED

### Raised

- **PQ-1** [Critical] `unbacked-existing-behavior-claim` Both stated causes contradict get_agent's actual never-nil fallback, so the new tier may be a no-op
  init.lua:4405-4417 shows get_agent never returns nil for an unknown name — it warns and
  returns the _state.agent record (or _agents[1]). tests/unit/config_tools_spec.lua:392-411
  pins exactly this and names skill_agent/review_agent as the callers. So tier 3
  (skill_assembly.lua:90-94) always fires in a default install, tier 4 is unreachable, and
  the agent it yields already equals the current selection — meaning the planned tier 5 is a
  no-op for a chat with no model frontmatter. Re-derive the repro and state which branch
  actually produced the wrong model.
- **PQ-2** [Important] `injected-double-fidelity` Injected get_agent double returns nil on miss while production never does
  tests/unit/skill_assembly_spec.lua:68-72 models get_agent as a strict lookup, the opposite
  of p.get_agent. The planned unit tests would pass green over the production behavior they
  are meant to guard. Either make the double match production, or change the resolver seam to
  a strict deps.agents lookup and state that contract change explicitly — it redefines tiers
  1, 1b, 2 and 3 for every caller.
- **PQ-3** [Important] `reuse-existing-resolver` Plan does not name agent_info.resolve as the existing header-merge it should reuse
  ARCH-DRY. agent_info.resolve (agent_info.lua:14-140, reached via p.get_agent_info at
  init.lua:4548) already merges provider/model header overrides and performs the model JSON
  decode plus the string-to-table coercion that skill_invoke.lua:208 depends on. Say whether
  the IO seam reuses it; a hand-rolled merge risks a model-shape mismatch at prepare_payload.
- **PQ-4** [Minor] `derived-doc-drift` Atlas restates the cascade and the default being deleted
  atlas/skills/skill-system.md:97 documents skill_agent = "Claude-Sonnet" and the cascade;
  atlas/modes/review.md:195 restates review_agent. Both are hand-maintained restatements of
  the model this issue changes and go stale on merge.
- **PQ-5** [Minor] `adversarial-input-strategy` No strategy line for malformed chat frontmatter on the new header path
  The plan names three behaviors to test but not the adversarial input class for the new tier:
  hand-edited frontmatter where model: is malformed JSON (agent_info.lua:73-85 warns and falls
  back to the raw string) or provider: names a provider with no wire.

## Round 2 — 2026-09-04T15:37:55-07:00 (claude) — passed

### Disposed

- PQ-1 — addressed — Problem re-derived from the real branch; nilling skill_agent is now load-bearing so tier 5 is reachable.
- PQ-2 — addressed — Plan step 1 fixes the double to production semantics before the new tests are written.
- PQ-3 — addressed — Spec names agent_info.resolve and states the provider+model-only narrowing.
- PQ-4 — addressed — Both atlas restatements are plan steps.
- PQ-5 — addressed — Degradation paragraph plus integration coverage names both adversarial input classes.

## Open findings

(none — every finding has been disposed)
