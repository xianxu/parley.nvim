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

## Open findings

- **PQ-1** [Critical] `channel-axis-collapse` Catalog-derived resolve_channel returns a provider where a channel is required
- **PQ-2** [Important] `single-source-wire-decision` build_agent re-implements the anthropic-family test that providers.lua already single-sources
- **PQ-3** [Important] `caller-sweep-incomplete` resolve_channel's second caller resolve_login_provider is not threaded with the catalog
- **PQ-4** [Important] `stated-design-not-implemented` The displayName-derived series fallback is specified in two places and implemented in neither
- **PQ-5** [Important] `fake-without-conformance` M2 models /v1beta/models in the fake with no live conformance check on the assumed shape
- **PQ-6** [Important] `invented-test-api` Task 2.2's never-spawns assertion calls cliproxy._spawned_pids(), which does not exist
- **PQ-7** [Minor] `pure-fn-mutates-input` curate writes provider onto the caller's rows in a module declared side-effect-free
- **PQ-8** [Minor] `rank-band-not-disjoint` rank_key's -1000 + version band overlaps the epoch band its comment says it never touches
