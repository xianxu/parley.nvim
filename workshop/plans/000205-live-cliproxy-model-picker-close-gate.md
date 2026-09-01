---
gate: boundary-review
issue: 205
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-08-31T20:22:26-07:00"
      agent: sdlc
      findings:
        - id: BR-1
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
            (carried from plan-quality PQ-14, deferred to the boundary review)
          family: stated-design-not-implemented
          round: 1
      boundary: '*'
      no_cap: true
      blocked: false
    - "n": 2
      timestamp: "2026-08-31T20:22:26-07:00"
      agent: claude
      findings:
        - id: BR-2
          severity: Critical
          title: build_agent's "none" web-search strategy is discarded by the resolver; a gemini live pick ships the broken web_search payload
          detail: |-
            get_cliproxy_strategy (lua/parley/providers.lua:103) whitelists only the three
            positive strategies at the model level, so build_agent's "none" falls through to
            the provider default openai_tools_route (config.lua:101). Verified at runtime on
            HEAD: cliproxy_strategy returns "openai_tools_route" and format_payload emits
            tools = { { type = "web_search" } } with tool_choice = "auto" for
            build_agent({id="gemini-3-flash"}) — the exact configuration the Spec measured as
            producing finish_reason "malformed_function_call" and no content. config.web_search
            defaults to true, so this fires on the default configuration, and the commit body's
            claim that gemini "ships with server-side search off rather than broken" is false.
            Fix: accept "none" in the model-level whitelist; pin with the payload-level test
            Task 1.6 Step 5 specifies.
          family: single-source-not-enforced
          round: 2
        - id: BR-3
          severity: Important
          title: cliproxy_default_web_search_strategy ships with no direct test; Task 1.6 Steps 1-5 produced no artifact
          detail: |-
            The function appears nowhere under tests/. Plan Task 1.6 specified five cases in
            tests/unit/provider_params_spec.lua, which is untouched in the window. It is covered
            only transitively by three build_agent assertions, which is why the "none" value was
            never followed to its consumer. The plan's code_execution_claude and mystery-1
            fallback cases are unexercised. This is the direct enabler of the Critical above.
          family: missing-test-for-shipped-behavior
          round: 2
        - id: BR-4
          severity: Important
          title: rank_key reads the first numeral in displayName as a version, so "GPT-OSS 120B" outranks every Gemini row
          detail: |-
            lua/parley/cliproxy_catalog.lua:97 matches "(%d+%.?%d*)" anywhere in the display
            name. For created-less antigravity rows that yields 120 for "GPT-OSS 120B (Medium)"
            against 3.x for every Gemini row. Run against the fixture, the Spec's own default
            config entry (bare "antigravity") renders GPT-OSS 120B, Claude Opus 4.6 and Claude
            Sonnet 4.6 — hiding every Gemini model the provider exists to offer. Reject a
            numeral immediately followed by a letter, or anchor the match to the series stem.
          family: rank-key-version-extraction
          round: 2
        - id: BR-5
          severity: Important
          title: The one curate render exercising both displayName matching and created-less ranking is asserted with tbl_contains, not equality
          detail: |-
            The issue states the four Spec-table rows are the unit-test cases for curate. Three
            are pinned with assert.same; the antigravity row is reduced to a tbl_contains check
            on a single-term variant (tests/unit/cliproxy_catalog_spec.lua:150). The documented
            row does render correctly today, but the weakened assertion is why the rank_key
            ordering defect stayed invisible. Assert the documented row as an equality and add a
            bare-"antigravity" case.
          family: documented-render-not-pinned
          round: 2
        - id: BR-6
          severity: Minor
          title: A typo'd provider spec resolves owned_by to nil and then pools every row missing owned_by
          detail: |-
            lua/parley/cliproxy_catalog.lua:137-143 — provider_owned_by("claud") returns nil and
            the pool filter m.owner == owner then matches rows whose owned_by is absent. Silent
            empty (or wrong) group with no operator signal.
          family: unknown-input-silently-ignored
          round: 2
        - id: BR-7
          severity: Minor
          title: series("") returns "" under a test titled "never returns an empty key, whatever the id"
          detail: |-
            The plan's version of the loop listed "" with an explicit escape; the shipped loop
            drops the case rather than handling it. lua/parley/cliproxy_catalog.lua:37 falls back
            to the id, which is also "" for an empty id.
          family: test-title-overstates-guard
          round: 2
        - id: BR-8
          severity: Minor
          title: build_agent raises on a row with a nil id while every sibling function type-guards
          detail: lua/parley/cliproxy_catalog.lua:194 concatenates m.id directly.
          family: missing-input-guard
          round: 2
        - id: BR-9
          severity: Minor
          title: Plan Chunk 1 repeats `make test-spec SPEC=unit/cliproxy_catalog`, which is not a valid SPEC key
          detail: |-
            SPEC takes an atlas spec key; the correct value is providers/cliproxy-managed.
            Executing the plan literally produces "No tests mapped for spec" at seven steps.
          family: plan-command-does-not-run
          round: 2
        - id: BR-10
          severity: Minor
          title: Core concepts table omits cliproxy_default_web_search_strategy, the new PURE entity Task 1.6 delivers
          detail: |-
            Listing it (lua/parley/providers.lua, new) is what would have made its missing test
            row visible during the cross-check. Warrants a `## Revisions` entry.
          family: plan-table-missing-entity
          round: 2
        - id: BR-11
          severity: Minor
          title: The Spec's "gemini / antigravity -> neither" row is implemented as `^gemini`, leaving antigravity's gpt-oss row on openai_tools_route
          detail: |-
            gpt-oss-120b-medium is antigravity-owned but gpt-family by id, so it gets
            openai_tools_route — unmeasured against the live proxy, and the Spec's table does not
            disambiguate owner from family for that row.
          family: unmeasured-family-branch
          round: 2
      boundary: M1
      blocked: true
    - "n": 3
      timestamp: "2026-08-31T20:41:43-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: not-addressed
          note: Plan unchanged on this point; `_logged_out_providers` still appears only at plan:1073 attributed to Task 3.1, which creates neither it nor `provider_states` (plan:56). 3rd in family; M3 is next.
          round: 3
        - id: BR-2
          disposition: addressed
          note: Verified by revert — removing `none = true` from CLIPROXY_STRATEGIES makes the new test fail with openai_tools_route vs none.
          round: 3
        - id: BR-3
          disposition: addressed
          note: Six direct tests incl. code_execution_claude and mystery-1; they live in cliproxy_catalog_spec.lua, not provider_params_spec.lua as the plan states.
          round: 3
        - id: BR-4
          disposition: addressed
          note: Verified by revert — restoring the single-match extraction makes "does not let a parameter count outrank a version" fail.
          round: 3
        - id: BR-5
          disposition: not-addressed
          note: Equality landed on `antigravity:pro`, a single-term variant that is not one of the four documented rows; the documented `antigravity:pro,flash` render and the bare-`antigravity` case (added as a tbl_contains negative, the exact weak form the finding named) are still unpinned — 2 of 5 Spec renders unasserted. State the rule (every Spec render row is a curate equality on the documented spec string) and sweep all five.
          round: 3
        - id: BR-6
          disposition: not-addressed
          note: 'curate is unchanged; owner may still be nil and `m.owner == owner` still pools rows lacking owned_by. Measured: `claud:opus` renders silently empty.'
          round: 3
        - id: BR-7
          disposition: not-addressed
          note: Measured at HEAD — cat.series("") still returns ""; the test loop still omits the "" case.
          round: 3
        - id: BR-8
          disposition: not-addressed
          note: Measured at HEAD — build_agent({owner="anthropic"}) raises "attempt to concatenate field 'id' (a nil value)" at cliproxy_catalog.lua:204.
          round: 3
        - id: BR-9
          disposition: not-addressed
          note: '`SPEC=unit/cliproxy_catalog` still at 10 plan sites; spec_test_map.sh list-tests returns nothing for that key.'
          round: 3
        - id: BR-10
          disposition: addressed
          note: Both rows added to the Core concepts table plus a `## Revisions` entry.
          round: 3
        - id: BR-11
          disposition: addressed
          note: owner == "antigravity" now yields none regardless of family, with two tests; but see the new finding — that change also moves the wire.
          round: 3
      findings:
        - id: BR-12
          severity: Important
          title: web_search_strategy also selects the wire, so the BR-11 owner rule makes owned_by decide the transport — contradicting build_agent's own docstring
          detail: |-
            cliproxy_route (lua/parley/providers.lua:194) returns "openai" for any strategy
            that is not anthropic_tools_route, so the BR-11 fix (owner == "antigravity" =>
            "none") retargets the wire as a side effect. Measured at HEAD: build_agent for
            claude-sonnet-4-6 with owner=antigravity yields strategy=none route=openai, while
            the same id with owner=anthropic yields anthropic_tools_route route=anthropic.
            cliproxy_catalog.lua:192 states the opposite as a contract — "The wire follows the
            MODEL FAMILY, never owner ... a claude model speaks the Anthropic wire whichever
            channel serves it" — and cites claude-sonnet-4-6 flipping owned_by between proxy
            starts as the reason. Both antigravity-owned claude rows are in the fixture and
            both surface in the bare "antigravity" render, which is the Spec's default config
            entry. No test asserts the route for a built agent; the BR-11 tests stop at the
            strategy string. Either decide the wire independently of the strategy, or amend
            the docstring and Spec Component 4 — and pin the choice for both owners of one id.
          family: one-value-two-decisions
          round: 3
      boundary: M1
      blocked: true
    - "n": 4
      timestamp: "2026-08-31T20:53:57-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: not-addressed
          note: Plan Revisions cover BR-2..BR-5, BR-10..BR-12 only; `M._logged_out_providers` (plan:1073) is still attributed to a Task 3.1 that defines no such function, `provider_states` (plan:56,65) still names the same capability, and the prescribed whole-plan referent grep was not run.
          round: 4
        - id: BR-5
          disposition: not-addressed
          note: The tbl_contains is gone and a bare-`antigravity` case was added, but the equality pins `antigravity:pro` — a single-term variant — not the Spec's documented `antigravity:pro,flash` row, which I measured rendering exactly as documented (gemini-3.1-pro-low, gemini-pro-agent, gemini-3.7-flash-high).
          round: 4
        - id: BR-6
          disposition: not-addressed
          note: 'Verified at HEAD: curate with provider "claud" returns [], and the `m.owner == owner` filter with owner==nil still pools every row whose owned_by is absent. No guard added.'
          round: 4
        - id: BR-7
          disposition: not-addressed
          note: The shipped test now drops "" from the input list entirely rather than handling it; `series("")` still returns "" under a title reading "never returns an empty key, whatever the id".
          round: 4
        - id: BR-8
          disposition: not-addressed
          note: 'Verified: build_agent({owner="anthropic"}) raises "attempt to concatenate field ''id'' (a nil value)" at cliproxy_catalog.lua:206.'
          round: 4
        - id: BR-9
          disposition: not-addressed
          note: '`scripts/spec_test_map.sh list-tests unit/cliproxy_catalog` returns nothing; the plan still repeats invalid SPEC keys at twelve steps across Chunks 1-3.'
          round: 4
        - id: BR-12
          disposition: addressed
          note: 'Verified by revert in a scratch checkout: hoisting the `owner == "antigravity"` check above the family test turns two tests red; docstring and Spec reading now agree.'
          round: 4
      findings:
        - id: BR-13
          severity: Important
          title: 'rank_key''s `< 100` threshold answers the 120B instance, not the class: any parameter count below 100 still reads as a version'
          detail: |-
            2nd in family — do NOT patch the site. The rule the code needs: a numeral
            scraped from a free-text display name is a version only when it is
            DELIMITED (not followed by a letter). `120B`, `20B`, `70B`, `8B`, `32K` are
            magnitudes with unit suffixes; the round-1 review sketched exactly this rule
            and the shipped fix substituted a magnitude threshold that happens to
            exclude the single fixture row and nothing else. Measured at HEAD by adding
            `gpt-oss-20b-medium` / "GPT-OSS 20B (Medium)" (no created, sibling size of
            the row already in the fixture): the antigravity group renders
            gpt-oss-20b-medium, claude-opus-4-6-thinking, claude-sonnet-4-6 —
            rank_key = -999999980 vs -999999996.3 for "Gemini 3.7 Flash" — so every
            Gemini row is pushed out of the Spec's shipped 3-cap `antigravity` entry.
            That is BR-4's exact failure mode with a size the threshold misses. Fix the
            rule (reject `%d+%.?%d*` followed by `%a`, or anchor the version to the
            alphabetic stem `series` already derives) and cover it by magnitude SHAPE
            (20B / 120B / 8B), not by value. Related: within the created-less band the
            scraped number is compared across product lines, so "Claude Opus 4.6"
            outranks "Gemini 3.7" on 4.6 > 3.7 — a cross-vendor version comparison the
            bare-`antigravity` test currently pins as correct; decide that deliberately
            at M3 rather than by pattern accident.
          family: rank-key-version-extraction
          round: 4
      boundary: M1
      blocked: true
---

# Gate ledger — parley.nvim#205 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-08-31T20:22:26-07:00 (sdlc) — passed

### Raised

- **BR-1** [Minor] `stated-design-not-implemented` The producer of the logged-out rows is named twice and defined nowhere; the plan's own referent sweep was stated but not run
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
  (carried from plan-quality PQ-14, deferred to the boundary review)

## Round 2 — 2026-08-31T20:22:26-07:00 (claude) — BLOCKED

### Raised

- **BR-2** [Critical] `single-source-not-enforced` build_agent's "none" web-search strategy is discarded by the resolver; a gemini live pick ships the broken web_search payload
  get_cliproxy_strategy (lua/parley/providers.lua:103) whitelists only the three
  positive strategies at the model level, so build_agent's "none" falls through to
  the provider default openai_tools_route (config.lua:101). Verified at runtime on
  HEAD: cliproxy_strategy returns "openai_tools_route" and format_payload emits
  tools = { { type = "web_search" } } with tool_choice = "auto" for
  build_agent({id="gemini-3-flash"}) — the exact configuration the Spec measured as
  producing finish_reason "malformed_function_call" and no content. config.web_search
  defaults to true, so this fires on the default configuration, and the commit body's
  claim that gemini "ships with server-side search off rather than broken" is false.
  Fix: accept "none" in the model-level whitelist; pin with the payload-level test
  Task 1.6 Step 5 specifies.
- **BR-3** [Important] `missing-test-for-shipped-behavior` cliproxy_default_web_search_strategy ships with no direct test; Task 1.6 Steps 1-5 produced no artifact
  The function appears nowhere under tests/. Plan Task 1.6 specified five cases in
  tests/unit/provider_params_spec.lua, which is untouched in the window. It is covered
  only transitively by three build_agent assertions, which is why the "none" value was
  never followed to its consumer. The plan's code_execution_claude and mystery-1
  fallback cases are unexercised. This is the direct enabler of the Critical above.
- **BR-4** [Important] `rank-key-version-extraction` rank_key reads the first numeral in displayName as a version, so "GPT-OSS 120B" outranks every Gemini row
  lua/parley/cliproxy_catalog.lua:97 matches "(%d+%.?%d*)" anywhere in the display
  name. For created-less antigravity rows that yields 120 for "GPT-OSS 120B (Medium)"
  against 3.x for every Gemini row. Run against the fixture, the Spec's own default
  config entry (bare "antigravity") renders GPT-OSS 120B, Claude Opus 4.6 and Claude
  Sonnet 4.6 — hiding every Gemini model the provider exists to offer. Reject a
  numeral immediately followed by a letter, or anchor the match to the series stem.
- **BR-5** [Important] `documented-render-not-pinned` The one curate render exercising both displayName matching and created-less ranking is asserted with tbl_contains, not equality
  The issue states the four Spec-table rows are the unit-test cases for curate. Three
  are pinned with assert.same; the antigravity row is reduced to a tbl_contains check
  on a single-term variant (tests/unit/cliproxy_catalog_spec.lua:150). The documented
  row does render correctly today, but the weakened assertion is why the rank_key
  ordering defect stayed invisible. Assert the documented row as an equality and add a
  bare-"antigravity" case.
- **BR-6** [Minor] `unknown-input-silently-ignored` A typo'd provider spec resolves owned_by to nil and then pools every row missing owned_by
  lua/parley/cliproxy_catalog.lua:137-143 — provider_owned_by("claud") returns nil and
  the pool filter m.owner == owner then matches rows whose owned_by is absent. Silent
  empty (or wrong) group with no operator signal.
- **BR-7** [Minor] `test-title-overstates-guard` series("") returns "" under a test titled "never returns an empty key, whatever the id"
  The plan's version of the loop listed "" with an explicit escape; the shipped loop
  drops the case rather than handling it. lua/parley/cliproxy_catalog.lua:37 falls back
  to the id, which is also "" for an empty id.
- **BR-8** [Minor] `missing-input-guard` build_agent raises on a row with a nil id while every sibling function type-guards
  lua/parley/cliproxy_catalog.lua:194 concatenates m.id directly.
- **BR-9** [Minor] `plan-command-does-not-run` Plan Chunk 1 repeats `make test-spec SPEC=unit/cliproxy_catalog`, which is not a valid SPEC key
  SPEC takes an atlas spec key; the correct value is providers/cliproxy-managed.
  Executing the plan literally produces "No tests mapped for spec" at seven steps.
- **BR-10** [Minor] `plan-table-missing-entity` Core concepts table omits cliproxy_default_web_search_strategy, the new PURE entity Task 1.6 delivers
  Listing it (lua/parley/providers.lua, new) is what would have made its missing test
  row visible during the cross-check. Warrants a `## Revisions` entry.
- **BR-11** [Minor] `unmeasured-family-branch` The Spec's "gemini / antigravity -> neither" row is implemented as `^gemini`, leaving antigravity's gpt-oss row on openai_tools_route
  gpt-oss-120b-medium is antigravity-owned but gpt-family by id, so it gets
  openai_tools_route — unmeasured against the live proxy, and the Spec's table does not
  disambiguate owner from family for that row.

## Round 3 — 2026-08-31T20:41:43-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — not-addressed — Plan unchanged on this point; `_logged_out_providers` still appears only at plan:1073 attributed to Task 3.1, which creates neither it nor `provider_states` (plan:56). 3rd in family; M3 is next.
- BR-2 — addressed — Verified by revert — removing `none = true` from CLIPROXY_STRATEGIES makes the new test fail with openai_tools_route vs none.
- BR-3 — addressed — Six direct tests incl. code_execution_claude and mystery-1; they live in cliproxy_catalog_spec.lua, not provider_params_spec.lua as the plan states.
- BR-4 — addressed — Verified by revert — restoring the single-match extraction makes "does not let a parameter count outrank a version" fail.
- BR-5 — not-addressed — Equality landed on `antigravity:pro`, a single-term variant that is not one of the four documented rows; the documented `antigravity:pro,flash` render and the bare-`antigravity` case (added as a tbl_contains negative, the exact weak form the finding named) are still unpinned — 2 of 5 Spec renders unasserted. State the rule (every Spec render row is a curate equality on the documented spec string) and sweep all five.
- BR-6 — not-addressed — curate is unchanged; owner may still be nil and `m.owner == owner` still pools rows lacking owned_by. Measured: `claud:opus` renders silently empty.
- BR-7 — not-addressed — Measured at HEAD — cat.series("") still returns ""; the test loop still omits the "" case.
- BR-8 — not-addressed — Measured at HEAD — build_agent({owner="anthropic"}) raises "attempt to concatenate field 'id' (a nil value)" at cliproxy_catalog.lua:204.
- BR-9 — not-addressed — `SPEC=unit/cliproxy_catalog` still at 10 plan sites; spec_test_map.sh list-tests returns nothing for that key.
- BR-10 — addressed — Both rows added to the Core concepts table plus a `## Revisions` entry.
- BR-11 — addressed — owner == "antigravity" now yields none regardless of family, with two tests; but see the new finding — that change also moves the wire.

### Raised

- **BR-12** [Important] `one-value-two-decisions` web_search_strategy also selects the wire, so the BR-11 owner rule makes owned_by decide the transport — contradicting build_agent's own docstring
  cliproxy_route (lua/parley/providers.lua:194) returns "openai" for any strategy
  that is not anthropic_tools_route, so the BR-11 fix (owner == "antigravity" =>
  "none") retargets the wire as a side effect. Measured at HEAD: build_agent for
  claude-sonnet-4-6 with owner=antigravity yields strategy=none route=openai, while
  the same id with owner=anthropic yields anthropic_tools_route route=anthropic.
  cliproxy_catalog.lua:192 states the opposite as a contract — "The wire follows the
  MODEL FAMILY, never owner ... a claude model speaks the Anthropic wire whichever
  channel serves it" — and cites claude-sonnet-4-6 flipping owned_by between proxy
  starts as the reason. Both antigravity-owned claude rows are in the fixture and
  both surface in the bare "antigravity" render, which is the Spec's default config
  entry. No test asserts the route for a built agent; the BR-11 tests stop at the
  strategy string. Either decide the wire independently of the strategy, or amend
  the docstring and Spec Component 4 — and pin the choice for both owners of one id.

## Round 4 — 2026-08-31T20:53:57-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — not-addressed — Plan Revisions cover BR-2..BR-5, BR-10..BR-12 only; `M._logged_out_providers` (plan:1073) is still attributed to a Task 3.1 that defines no such function, `provider_states` (plan:56,65) still names the same capability, and the prescribed whole-plan referent grep was not run.
- BR-5 — not-addressed — The tbl_contains is gone and a bare-`antigravity` case was added, but the equality pins `antigravity:pro` — a single-term variant — not the Spec's documented `antigravity:pro,flash` row, which I measured rendering exactly as documented (gemini-3.1-pro-low, gemini-pro-agent, gemini-3.7-flash-high).
- BR-6 — not-addressed — Verified at HEAD: curate with provider "claud" returns [], and the `m.owner == owner` filter with owner==nil still pools every row whose owned_by is absent. No guard added.
- BR-7 — not-addressed — The shipped test now drops "" from the input list entirely rather than handling it; `series("")` still returns "" under a title reading "never returns an empty key, whatever the id".
- BR-8 — not-addressed — Verified: build_agent({owner="anthropic"}) raises "attempt to concatenate field 'id' (a nil value)" at cliproxy_catalog.lua:206.
- BR-9 — not-addressed — `scripts/spec_test_map.sh list-tests unit/cliproxy_catalog` returns nothing; the plan still repeats invalid SPEC keys at twelve steps across Chunks 1-3.
- BR-12 — addressed — Verified by revert in a scratch checkout: hoisting the `owner == "antigravity"` check above the family test turns two tests red; docstring and Spec reading now agree.

### Raised

- **BR-13** [Important] `rank-key-version-extraction` rank_key's `< 100` threshold answers the 120B instance, not the class: any parameter count below 100 still reads as a version
  2nd in family — do NOT patch the site. The rule the code needs: a numeral
  scraped from a free-text display name is a version only when it is
  DELIMITED (not followed by a letter). `120B`, `20B`, `70B`, `8B`, `32K` are
  magnitudes with unit suffixes; the round-1 review sketched exactly this rule
  and the shipped fix substituted a magnitude threshold that happens to
  exclude the single fixture row and nothing else. Measured at HEAD by adding
  `gpt-oss-20b-medium` / "GPT-OSS 20B (Medium)" (no created, sibling size of
  the row already in the fixture): the antigravity group renders
  gpt-oss-20b-medium, claude-opus-4-6-thinking, claude-sonnet-4-6 —
  rank_key = -999999980 vs -999999996.3 for "Gemini 3.7 Flash" — so every
  Gemini row is pushed out of the Spec's shipped 3-cap `antigravity` entry.
  That is BR-4's exact failure mode with a size the threshold misses. Fix the
  rule (reject `%d+%.?%d*` followed by `%a`, or anchor the version to the
  alphabetic stem `series` already derives) and cover it by magnitude SHAPE
  (20B / 120B / 8B), not by value. Related: within the created-less band the
  scraped number is compared across product lines, so "Claude Opus 4.6"
  outranks "Gemini 3.7" on 4.6 > 3.7 — a cross-vendor version comparison the
  bare-`antigravity` test currently pins as correct; decide that deliberately
  at M3 rather than by pattern accident.

## Open findings

- **BR-1** [Minor] `stated-design-not-implemented` The producer of the logged-out rows is named twice and defined nowhere; the plan's own referent sweep was stated but not run
- **BR-5** [Important] `documented-render-not-pinned` The one curate render exercising both displayName matching and created-less ranking is asserted with tbl_contains, not equality
- **BR-6** [Minor] `unknown-input-silently-ignored` A typo'd provider spec resolves owned_by to nil and then pools every row missing owned_by
- **BR-7** [Minor] `test-title-overstates-guard` series("") returns "" under a test titled "never returns an empty key, whatever the id"
- **BR-8** [Minor] `missing-input-guard` build_agent raises on a row with a nil id while every sibling function type-guards
- **BR-9** [Minor] `plan-command-does-not-run` Plan Chunk 1 repeats `make test-spec SPEC=unit/cliproxy_catalog`, which is not a valid SPEC key
- **BR-13** [Important] `rank-key-version-extraction` rank_key's `< 100` threshold answers the 120B instance, not the class: any parameter count below 100 still reads as a version
