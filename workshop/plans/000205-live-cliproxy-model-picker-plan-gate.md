---
gate: plan-quality
issue: 205
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-08-31T19:35:16-07:00"
      agent: claude
      findings:
        - id: PQ-1
          severity: Critical
          title: Catalog-derived resolve_channel returns a provider where a channel is required
          detail: |-
            Task 4.1 inverts PROVIDER_OWNED_BY (cliproxy_config.lua:227-235) to derive a
            channel, but its keys are login-shaped providers, not channels. CHANNEL_LOGIN
            (cliproxy_config.lua:140-149) has no `google` key — it has gemini/gemini-cli/
            aistudio, three channels sharing one login — and the comment at
            cliproxy_config.lua:154-158 warns that keying credential health by the login
            axis "silently finds nothing". The Spec itself says owned_by is "never a
            channel identifier".
          family: channel-axis-collapse
          round: 1
        - id: PQ-2
          severity: Important
          title: build_agent re-implements the anthropic-family test that providers.lua already single-sources
          detail: |-
            providers.lua:142-147 is is_cliproxy_anthropic_route_model; providers.lua:170-179
            documents that it was extracted because two call sites used two different tests,
            one of which "checked `^claude%-` alone". Task 1.6's build_agent writes that exact
            copy and drops the `^code_execution_` arm. Export the canonical function and call it.
          family: single-source-wire-decision
          round: 1
        - id: PQ-3
          severity: Important
          title: resolve_channel's second caller resolve_login_provider is not threaded with the catalog
          detail: |-
            Task 4.1 Step 4 says "update the one caller at cliproxy.lua:1236", but
            resolve_login_provider (cliproxy_config.lua:218-220) also calls resolve_channel
            and its docstring claims it derives from it "so there is one model to channel
            source (ARCH-DRY)". Enumerate the callers and thread all of them in the same pass.
          family: caller-sweep-incomplete
          round: 1
        - id: PQ-4
          severity: Important
          title: The displayName-derived series fallback is specified in two places and implemented in neither
          detail: |-
            Spec Components and the plan's concepts table both state series falls back to a
            displayName-derived stem for opaque-id owners. Task 1.3's parse sets
            series = M.series(m.id) unconditionally, and no Task 1.2 or 1.5 test covers the
            fallback. Implement it with a test, or delete the claim from both artifacts.
          family: stated-design-not-implemented
          round: 1
        - id: PQ-5
          severity: Important
          title: M2 models /v1beta/models in the fake with no live conformance check on the assumed shape
          detail: |-
            tests/integration/cliproxy_conformance_spec.lua is the existing seam (#197) that boots
            the real binary and asserts the fields the code reads still exist. Task 2.1 asserts a
            shape — name "models/<id>", displayName, description, and the `^models/` strip in parse —
            into the fake without extending that spec. Task 1.1 Step 2 also verifies only the v1
            awkward rows, never that the join actually lands.
          family: fake-without-conformance
          round: 1
        - id: PQ-6
          severity: Important
          title: Task 2.2's never-spawns assertion calls cliproxy._spawned_pids(), which does not exist
          detail: |-
            Zero occurrences of _spawned_pids in lua/ or tests/. It is the only named mechanism for
            the Done-when "Opening the picker never starts the proxy", so that criterion currently
            has no verification path.
          family: invented-test-api
          round: 1
        - id: PQ-7
          severity: Minor
          title: curate writes provider onto the caller's rows in a module declared side-effect-free
          detail: |-
            curate does m.provider = parsed.provider on the same table refs it received, which are
            the rows held by the disk cache and re-curated on every <C-a> toggle and background
            repaint. Shallow-copy the row before tagging (ARCH-PURE).
          family: pure-fn-mutates-input
          round: 1
        - id: PQ-8
          severity: Minor
          title: rank_key's -1000 + version band overlaps the epoch band its comment says it never touches
          detail: |-
            The docstring asserts a created-less row ranks "always BELOW any dated row", but
            -1000 + version exceeds a small positive `created` once a parsed display version reaches
            1000. The invariant the third test case exists to protect is not actually guaranteed.
          family: rank-band-not-disjoint
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-08-31T19:42:05-07:00"
      agent: claude
      dispose:
        - id: PQ-1
          disposition: addressed
          note: OWNER_CHANNELS returns candidates; resolve_channel answers only when exactly one.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: Task 1.6 puts the three-way strategy in providers.lua reusing the local family test.
          round: 2
        - id: PQ-3
          disposition: addressed
          note: Step 4 enumerates both callers and threads them in the same commit.
          round: 2
        - id: PQ-4
          disposition: addressed
          note: Claim withdrawn from Spec, concepts table, and the series docstring.
          round: 2
        - id: PQ-5
          disposition: addressed
          note: Two cases added to the real-binary conformance spec plus a join check in Task 1.1.
          round: 2
        - id: PQ-6
          disposition: addressed
          note: Replaced with a port-observable; see the new invented-test-api finding on its helper.
          round: 2
        - id: PQ-7
          disposition: addressed
          note: curate shallow-copies each row before tagging provider.
          round: 2
        - id: PQ-8
          disposition: addressed
          note: Band base is now -1e9, disjoint for any parsed version.
          round: 2
      findings:
        - id: PQ-9
          severity: Minor
          title: Task 2.2 calls ready_port.free_port() and port_is_listening(), neither of which exists
          detail: |-
            2nd in family. tests/helpers/ready_port.lua exports only wait_for_port; free_port
            and wait_listening are spec-local at tests/integration/cliproxy_lifecycle_spec.lua:17
            and :50, so the dormancy test would die on a nil call. Rule, not instance: every
            helper a test block calls must carry a file:line where it exists today or appear in
            the task's Files section as newly created. Run that grep once over all proposed test
            blocks; 2 of 2 named test-only APIs on this issue have now been non-existent.
          family: invented-test-api
          round: 2
      blocked: false
    - "n": 3
      timestamp: "2026-08-31T19:49:50-07:00"
      agent: claude
      dispose:
        - id: PQ-9
          disposition: not-addressed
          note: Rule written into Notes-for-the-implementer but never run; port_is_listening, fake_plugin, agent_picker_spec.lua and get(route) all still fail it.
          round: 3
      findings:
        - id: PQ-10
          severity: Critical
          title: Catalog-derived resolve_channel returns nil for both providers the default config ships, and the named proof spec cannot detect it
          detail: |-
            channels_for_owner gives anthropic {antigravity,claude} and openai
            {antigravity,codex}, so the "exactly one candidate" rule never fires for
            any shipped model. verdict.provider is set only by the one no_auth pattern
            at cliproxy_auth.lua:28; the expired kinds a dead Claude token produces
            (cliproxy_auth.lua:31-34) capture no provider, so the alias block deleted in
            Task 4.2 is today's only resolver. Task 4.2 Step 3 offers
            cliproxy_recovery_e2e as proof, but that spec builds its own
            oauth-model-alias at cliproxy_recovery_e2e_spec.lua:74-77 and passes either
            way. The give_up text at cliproxy.lua:1249 also still tells the operator to
            add the key M4 removes. The plan's rationale cites
            credential_health_for_login + healthier (cliproxy.lua:474-491) as the
            machinery for plural candidates, then no step calls it. 2nd in family
            after PQ-4: fix the rule, not the site - every rationale sentence
            justifying a design by naming existing machinery needs a step in the same
            task that invokes it, or the sentence goes and Done-when absorbs the
            consequence.
          family: stated-design-not-implemented
          round: 3
        - id: PQ-11
          severity: Minor
          title: No adversarial-input strategy named for series, the only pattern mangler over vendor-controlled ids
          detail: |-
            series() rewrites arbitrary model ids with gsub; an all-numeral id reduces
            to the empty string, collapsing every such model into one series so curate
            drops all but one. The plan has seven enumerated curate cases and no
            strategy line for the malformed class. One line replaces them - property
            test that series output is non-empty and that ids with distinct alphabetic
            stems stay distinct.
          family: test-strategy-not-enumeration
          round: 3
      blocked: true
    - "n": 4
      timestamp: "2026-08-31T19:54:01-07:00"
      agent: claude
      dispose:
        - id: PQ-9
          disposition: addressed
          note: Task 2.2 Files now promotes free_port + wait_listening into tests/helpers/ready_port.lua and rewrites the lifecycle spec.
          round: 4
        - id: PQ-10
          disposition: addressed
          note: resolve_channels plural, credential_health_across extracted with an injected reducer, empty-alias proof spec, both give_up texts rewritten.
          round: 4
        - id: PQ-11
          disposition: addressed
          note: Task 1.2 carries a malformed-id invariant plus an id fallback, not seven more cases.
          round: 4
      findings:
        - id: PQ-12
          severity: Critical
          title: resolve_channels' candidate set has no source; the owner-to-channels relation it asserts exists nowhere in code
          detail: |-
            Task 4.1 asserts resolve_channels("claude-opus-5", {}, {{id="claude-opus-5",
            owner="anthropic"}}) returns {"antigravity","claude"}, but grep -rn
            "channels_for_owner|OWNER_CHANNELS" lua/ tests/ finds nothing;
            PROVIDER_OWNED_BY (cliproxy_config.lua:227-234) maps antigravity to
            "antigravity" and the plan explicitly rejects inverting it; the one supplied
            catalog row carries a single owner. No step defines the relation, so M4's
            central function cannot be written from the plan.
            3rd in family after PQ-4 and PQ-10. Do not patch this site. The plan already
            states the covering rule in Notes for the implementer, scoped to test helpers:
            generalize it to ANY identifier or relation a code block, test block, or
            rationale sentence names, and run that grep once over the whole plan. That
            sweep also catches port_is_listening.
          family: stated-design-not-implemented
          round: 4
        - id: PQ-13
          severity: Minor
          title: Task 2.2's dormancy test calls port_is_listening, which exists nowhere and is not in the task's Files section
          detail: |-
            The task promotes free_port and wait_listening but the assertion needs a
            negative predicate that neither provides; grep finds no port_is_listening in
            lua/ or tests/. 3rd in family; measured prevalence is 3 of 3 test-only APIs
            named on this issue that did not exist. Swept by the generalized
            name-must-have-a-referent rule above, not by adding one more helper by hand.
          family: invented-test-api
          round: 4
      blocked: true
    - "n": 5
      timestamp: "2026-08-31T19:57:13-07:00"
      agent: claude
      dispose:
        - id: PQ-12
          disposition: addressed
          note: Task 4.1 Step 3 now defines OWNER_CHANNELS + channels_for_owner as the named source; the covering name-must-have-a-referent rule is in Notes for the implementer.
          round: 5
        - id: PQ-13
          disposition: addressed
          note: port_is_listening replaced by ready_port.is_listening, declared as new in Task 2.2's Files section; swept by the generalized rule, not patched per-site.
          round: 5
      findings:
        - id: PQ-14
          severity: Minor
          title: The producer of the logged-out rows is named twice and defined nowhere; the plan's own referent sweep was stated but not run
          detail: |-
            Task 3.2 calls M._logged_out_providers(plugin) attributed to Task 3.1, but
            Task 3.1 only extends _build_items and injects logged_out rows in its test;
            the Integration-points table calls the same capability provider_states. No
            step creates either. It also reads credential_health_for_login
            (lua/parley/cliproxy.lua:474), which is callback-async, so a synchronous
            call in view_for on picker-open contradicts the plan's own "zero network
            work on the main thread" envelope. 4th in family (PQ-4, PQ-12, this;
            3 of 3 in the sibling invented-test-api family). Do not patch this site —
            the covering rule already exists in Notes for the implementer; run the
            grep it prescribes once over the whole plan and dispose of its output.
          family: stated-design-not-implemented
          round: 5
      blocked: false
content_hash: e8f358c25f3f944d993a157e332c681f74c296a3a20a4b0bc207801dbd97ff1e
---

# Gate ledger — parley.nvim#205 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-08-31T19:35:16-07:00 (claude) — BLOCKED

### Raised

- **PQ-1** [Critical] `channel-axis-collapse` Catalog-derived resolve_channel returns a provider where a channel is required
  Task 4.1 inverts PROVIDER_OWNED_BY (cliproxy_config.lua:227-235) to derive a
  channel, but its keys are login-shaped providers, not channels. CHANNEL_LOGIN
  (cliproxy_config.lua:140-149) has no `google` key — it has gemini/gemini-cli/
  aistudio, three channels sharing one login — and the comment at
  cliproxy_config.lua:154-158 warns that keying credential health by the login
  axis "silently finds nothing". The Spec itself says owned_by is "never a
  channel identifier".
- **PQ-2** [Important] `single-source-wire-decision` build_agent re-implements the anthropic-family test that providers.lua already single-sources
  providers.lua:142-147 is is_cliproxy_anthropic_route_model; providers.lua:170-179
  documents that it was extracted because two call sites used two different tests,
  one of which "checked `^claude%-` alone". Task 1.6's build_agent writes that exact
  copy and drops the `^code_execution_` arm. Export the canonical function and call it.
- **PQ-3** [Important] `caller-sweep-incomplete` resolve_channel's second caller resolve_login_provider is not threaded with the catalog
  Task 4.1 Step 4 says "update the one caller at cliproxy.lua:1236", but
  resolve_login_provider (cliproxy_config.lua:218-220) also calls resolve_channel
  and its docstring claims it derives from it "so there is one model to channel
  source (ARCH-DRY)". Enumerate the callers and thread all of them in the same pass.
- **PQ-4** [Important] `stated-design-not-implemented` The displayName-derived series fallback is specified in two places and implemented in neither
  Spec Components and the plan's concepts table both state series falls back to a
  displayName-derived stem for opaque-id owners. Task 1.3's parse sets
  series = M.series(m.id) unconditionally, and no Task 1.2 or 1.5 test covers the
  fallback. Implement it with a test, or delete the claim from both artifacts.
- **PQ-5** [Important] `fake-without-conformance` M2 models /v1beta/models in the fake with no live conformance check on the assumed shape
  tests/integration/cliproxy_conformance_spec.lua is the existing seam (#197) that boots
  the real binary and asserts the fields the code reads still exist. Task 2.1 asserts a
  shape — name "models/<id>", displayName, description, and the `^models/` strip in parse —
  into the fake without extending that spec. Task 1.1 Step 2 also verifies only the v1
  awkward rows, never that the join actually lands.
- **PQ-6** [Important] `invented-test-api` Task 2.2's never-spawns assertion calls cliproxy._spawned_pids(), which does not exist
  Zero occurrences of _spawned_pids in lua/ or tests/. It is the only named mechanism for
  the Done-when "Opening the picker never starts the proxy", so that criterion currently
  has no verification path.
- **PQ-7** [Minor] `pure-fn-mutates-input` curate writes provider onto the caller's rows in a module declared side-effect-free
  curate does m.provider = parsed.provider on the same table refs it received, which are
  the rows held by the disk cache and re-curated on every <C-a> toggle and background
  repaint. Shallow-copy the row before tagging (ARCH-PURE).
- **PQ-8** [Minor] `rank-band-not-disjoint` rank_key's -1000 + version band overlaps the epoch band its comment says it never touches
  The docstring asserts a created-less row ranks "always BELOW any dated row", but
  -1000 + version exceeds a small positive `created` once a parsed display version reaches
  1000. The invariant the third test case exists to protect is not actually guaranteed.

## Round 2 — 2026-08-31T19:42:05-07:00 (claude) — passed

### Disposed

- PQ-1 — addressed — OWNER_CHANNELS returns candidates; resolve_channel answers only when exactly one.
- PQ-2 — addressed — Task 1.6 puts the three-way strategy in providers.lua reusing the local family test.
- PQ-3 — addressed — Step 4 enumerates both callers and threads them in the same commit.
- PQ-4 — addressed — Claim withdrawn from Spec, concepts table, and the series docstring.
- PQ-5 — addressed — Two cases added to the real-binary conformance spec plus a join check in Task 1.1.
- PQ-6 — addressed — Replaced with a port-observable; see the new invented-test-api finding on its helper.
- PQ-7 — addressed — curate shallow-copies each row before tagging provider.
- PQ-8 — addressed — Band base is now -1e9, disjoint for any parsed version.

### Raised

- **PQ-9** [Minor] `invented-test-api` Task 2.2 calls ready_port.free_port() and port_is_listening(), neither of which exists
  2nd in family. tests/helpers/ready_port.lua exports only wait_for_port; free_port
  and wait_listening are spec-local at tests/integration/cliproxy_lifecycle_spec.lua:17
  and :50, so the dormancy test would die on a nil call. Rule, not instance: every
  helper a test block calls must carry a file:line where it exists today or appear in
  the task's Files section as newly created. Run that grep once over all proposed test
  blocks; 2 of 2 named test-only APIs on this issue have now been non-existent.

## Round 3 — 2026-08-31T19:49:50-07:00 (claude) — BLOCKED

### Disposed

- PQ-9 — not-addressed — Rule written into Notes-for-the-implementer but never run; port_is_listening, fake_plugin, agent_picker_spec.lua and get(route) all still fail it.

### Raised

- **PQ-10** [Critical] `stated-design-not-implemented` Catalog-derived resolve_channel returns nil for both providers the default config ships, and the named proof spec cannot detect it
  channels_for_owner gives anthropic {antigravity,claude} and openai
  {antigravity,codex}, so the "exactly one candidate" rule never fires for
  any shipped model. verdict.provider is set only by the one no_auth pattern
  at cliproxy_auth.lua:28; the expired kinds a dead Claude token produces
  (cliproxy_auth.lua:31-34) capture no provider, so the alias block deleted in
  Task 4.2 is today's only resolver. Task 4.2 Step 3 offers
  cliproxy_recovery_e2e as proof, but that spec builds its own
  oauth-model-alias at cliproxy_recovery_e2e_spec.lua:74-77 and passes either
  way. The give_up text at cliproxy.lua:1249 also still tells the operator to
  add the key M4 removes. The plan's rationale cites
  credential_health_for_login + healthier (cliproxy.lua:474-491) as the
  machinery for plural candidates, then no step calls it. 2nd in family
  after PQ-4: fix the rule, not the site - every rationale sentence
  justifying a design by naming existing machinery needs a step in the same
  task that invokes it, or the sentence goes and Done-when absorbs the
  consequence.
- **PQ-11** [Minor] `test-strategy-not-enumeration` No adversarial-input strategy named for series, the only pattern mangler over vendor-controlled ids
  series() rewrites arbitrary model ids with gsub; an all-numeral id reduces
  to the empty string, collapsing every such model into one series so curate
  drops all but one. The plan has seven enumerated curate cases and no
  strategy line for the malformed class. One line replaces them - property
  test that series output is non-empty and that ids with distinct alphabetic
  stems stay distinct.

## Round 4 — 2026-08-31T19:54:01-07:00 (claude) — BLOCKED

### Disposed

- PQ-9 — addressed — Task 2.2 Files now promotes free_port + wait_listening into tests/helpers/ready_port.lua and rewrites the lifecycle spec.
- PQ-10 — addressed — resolve_channels plural, credential_health_across extracted with an injected reducer, empty-alias proof spec, both give_up texts rewritten.
- PQ-11 — addressed — Task 1.2 carries a malformed-id invariant plus an id fallback, not seven more cases.

### Raised

- **PQ-12** [Critical] `stated-design-not-implemented` resolve_channels' candidate set has no source; the owner-to-channels relation it asserts exists nowhere in code
  Task 4.1 asserts resolve_channels("claude-opus-5", {}, {{id="claude-opus-5",
  owner="anthropic"}}) returns {"antigravity","claude"}, but grep -rn
  "channels_for_owner|OWNER_CHANNELS" lua/ tests/ finds nothing;
  PROVIDER_OWNED_BY (cliproxy_config.lua:227-234) maps antigravity to
  "antigravity" and the plan explicitly rejects inverting it; the one supplied
  catalog row carries a single owner. No step defines the relation, so M4's
  central function cannot be written from the plan.
  3rd in family after PQ-4 and PQ-10. Do not patch this site. The plan already
  states the covering rule in Notes for the implementer, scoped to test helpers:
  generalize it to ANY identifier or relation a code block, test block, or
  rationale sentence names, and run that grep once over the whole plan. That
  sweep also catches port_is_listening.
- **PQ-13** [Minor] `invented-test-api` Task 2.2's dormancy test calls port_is_listening, which exists nowhere and is not in the task's Files section
  The task promotes free_port and wait_listening but the assertion needs a
  negative predicate that neither provides; grep finds no port_is_listening in
  lua/ or tests/. 3rd in family; measured prevalence is 3 of 3 test-only APIs
  named on this issue that did not exist. Swept by the generalized
  name-must-have-a-referent rule above, not by adding one more helper by hand.

## Round 5 — 2026-08-31T19:57:13-07:00 (claude) — passed

### Disposed

- PQ-12 — addressed — Task 4.1 Step 3 now defines OWNER_CHANNELS + channels_for_owner as the named source; the covering name-must-have-a-referent rule is in Notes for the implementer.
- PQ-13 — addressed — port_is_listening replaced by ready_port.is_listening, declared as new in Task 2.2's Files section; swept by the generalized rule, not patched per-site.

### Raised

- **PQ-14** [Minor] `stated-design-not-implemented` The producer of the logged-out rows is named twice and defined nowhere; the plan's own referent sweep was stated but not run
  Task 3.2 calls M._logged_out_providers(plugin) attributed to Task 3.1, but
  Task 3.1 only extends _build_items and injects logged_out rows in its test;
  the Integration-points table calls the same capability provider_states. No
  step creates either. It also reads credential_health_for_login
  (lua/parley/cliproxy.lua:474), which is callback-async, so a synchronous
  call in view_for on picker-open contradicts the plan's own "zero network
  work on the main thread" envelope. 4th in family (PQ-4, PQ-12, this;
  3 of 3 in the sibling invented-test-api family). Do not patch this site —
  the covering rule already exists in Notes for the implementer; run the
  grep it prescribes once over the whole plan and dispose of its output.

## Open findings

- **PQ-14** [Minor] `stated-design-not-implemented` The producer of the logged-out rows is named twice and defined nowhere; the plan's own referent sweep was stated but not run
