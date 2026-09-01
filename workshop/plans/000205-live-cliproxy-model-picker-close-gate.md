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
    - "n": 5
      timestamp: "2026-08-31T21:10:30-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: not-addressed
          note: Referent sweep verifiably ran, but no Task step still creates or tests `_providers_without_models`; plan.md:1079 credits Task 3.1, which does not produce it.
          round: 5
        - id: BR-5
          disposition: addressed
          note: Verified by revert — SPEC_RENDERS["antigravity"] goes red under the naive rank_key; no tbl_contains remains as a behavioural assertion.
          round: 5
        - id: BR-6
          disposition: addressed
          note: Verified by revert — "contributes nothing for a provider it does not know" goes red without the `owner and models or {}` guard.
          round: 5
        - id: BR-7
          disposition: addressed
          note: Verified by revert — fixed at the parse boundary; the empty-id test goes red without it, and the test title no longer overstates the guard.
          round: 5
        - id: BR-8
          disposition: addressed
          note: Verified by revert — build_agent returns nil; the test goes red without the guard, and both callers handle nil.
          round: 5
        - id: BR-9
          disposition: addressed
          note: All 26 SPEC references now read providers/cliproxy-managed, which resolves in atlas/traceability.yaml and runs green.
          round: 5
        - id: BR-13
          disposition: not-addressed
          note: Rule is correct but unpinned — restoring the `< 100` threshold leaves all 41 tests passing; the magnitude-SHAPE coverage the finding asked for was not added.
          round: 5
      findings:
        - id: BR-14
          severity: Important
          title: M3 Task 3.3 code (register_live_agent + refresh_state restore) crossed the M1 boundary with no test and no caller
          detail: |-
            init.lua:1329-1343 and 4327-4348 are Task 3.3 in the plan, whose named spec
            tests/unit/live_agent_state_spec.lua does not exist at HEAD. register_live_agent has
            zero call sites and the restore branch only fires on _state.live_agent, which only it
            sets — so all 38 lines are unreachable and the suite passes identically with them
            deleted. 440ab17's message does not mention init.lua. 2nd in family: do NOT just add
            the one spec — adopt the covering rule in the plan's Notes, that before
            milestone-close `git diff <base>..HEAD --name-only -- lua/` must name a test for every
            file listed, and a file belonging to a later milestone does not cross at all. At this
            boundary that check yields cliproxy_catalog.lua yes, providers.lua yes, init.lua no.
          family: missing-test-for-shipped-behavior
          round: 5
        - id: BR-15
          severity: Important
          title: cliproxy_default_web_search_strategy is not in the resolution chain; five config sites still hand-state what it derives
          detail: |-
            2nd in family — do NOT patch the five sites. The rule: every consumer of a newly
            single-sourced decision must derive from it in the same round, including consumers
            that predate the extraction; a hand-maintained restatement is a deferred consumer.
            Enumeration: config.lua:239, 247, 259, 377, 384 each hand-write
            web_search_strategy = "anthropic_tools_route", and get_cliproxy_strategy
            (providers.lua:111-129) resolves model to strategy from config without consulting the
            new source. The fix is a precedence decision, not a config edit — inserting the
            derived default changes what providers.cliproxyapi.web_search_strategy means. Either
            decide and wire the chain, or record in the plan that the pinned agents deliberately
            declare their own strategy and why the single source does not govern them.
          family: single-source-not-enforced
          round: 5
        - id: BR-16
          severity: Important
          title: atlas/providers/cliproxy-managed.md gains no entry for cliproxy_catalog.lua, the third pure module of the feature it maps
          detail: |-
            Its "## Pieces" section names cliproxy_config.lua (:18) and cliproxy_auth.lua (:33)
            but not the new module, nor the Model row shape, `series`, or the two-band rank_key.
            Only atlas/traceability.yaml was touched (2 lines) — that is the file-to-spec mapping,
            not the map. README needs nothing at M1: no config key or keybinding lands until M4.
          family: atlas-not-updated-for-new-surface
          round: 5
        - id: BR-17
          severity: Minor
          title: The agent-registration block is copy-pasted between register_live_agent and the refresh_state restore, and the copies already disagree
          detail: |-
            init.lua:4339-4342 does `M.agents[name] = agent`; init.lua:1337-1340 does
            `M.agents[name] = M.agents[name] or agent`. Same four-line operation, divergent
            clobber semantics — a live pick replaces a same-named configured agent for the
            session but not after a restart. ARCH-DRY: extract one M._register_agent(agent) and
            make the clobber rule a single decision.
          family: duplicated-logic-not-extracted
          round: 5
        - id: BR-18
          severity: Minor
          title: The BR-9 referent sweep collapsed four distinct spec keys into four identical commands, destroying which surfaces the step covers
          detail: |-
            2nd in family — do NOT edit the two blocks. The rule: a mechanical referent sweep must
            preserve the distinction the old referents carried; when N distinct keys map to one
            key, emit the command ONCE and keep the enumeration of what it covers in prose.
            plan.md:1391-1397 now runs `make test-spec SPEC=providers/cliproxy-managed` four
            identical times where it previously named unit/cliproxy_config, unit/cliproxy_auth,
            unit/failure_notice and integration/cliproxy_recovery_e2e; plan.md:1442-1446 repeats
            it twice.
          family: plan-command-does-not-run
          round: 5
      boundary: M1
      blocked: false
    - "n": 6
      timestamp: "2026-08-31T21:30:15-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: '`_logged_out_providers` and `provider_states` are gone from the plan; Task 3.1 Steps 4-6 now create and test `_providers_without_models`, which the code delivers, and the prescribed referent grep runs clean (74 referents, 4 unresolved and all defined in Task 4.1''s own code blocks). See new finding I7 for the hole the grep still has.'
          round: 6
      findings:
        - id: BR-19
          severity: Critical
          title: M3's restart-restore and the whole of Task 3.2 ship with no test that can fail
          detail: '3rd in family. Deleting lua/parley/init.lua:1329-1343 in a scratch copy of c9e83d8 leaves all four mapped specs green (0 failures); grep confirms no other spec touches `live_agent`. live_agent_state_spec.lua:69-75 calls build_agent twice and compares, asserting only determinism. M.agent_picker (agent_picker.lua:118-216) has zero tests and Task 3.2 has no Step-1 test block. Fix the rule, not the site: run the mutation check per task before milestone-close and record the result in `## Log`.'
          family: missing-test-for-shipped-behavior
          round: 6
        - id: BR-20
          severity: Important
          title: fetch_catalog logs nothing and discards the HTTP status; "cache in memory" and `providers = nil` are unimplemented
          detail: '2nd in family. cliproxy.lua:1437 keeps only split_status''s first return, so a 401 body is parsed as a catalog and is indistinguishable from an empty one; there is no logger call anywhere in fetch_catalog despite the envelope''s "logged at debug", and the fake''s new 401 branch (fake_cliproxy:407) is entered by no test. catalog_cached re-reads and re-decodes the file 2-3x per picker open with a mkdir each time — no in-memory cache exists. curate(models, {}) returns {} where the Spec documents "nil providers = every known provider, unfiltered" (measured). Rule: walk the Spec Components and the Operating envelope bullet by bullet at each close; implement and pin, or strike in `## Revisions`.'
          family: stated-design-not-implemented
          round: 6
        - id: BR-21
          severity: Important
          title: BR-6/BR-7's boundary guards applied to one site while two new boundaries shipped without them
          detail: '2nd in family. Measured: _providers_without_models(models, {''claud''}) and (models, {''anthropic''}) both emit actionable `(logged out)` rows that run `:ParleyProxy login <typo>`, while curate returns {} for the same input; with an ownerless catalog row the answer silently flips to {}, which is BR-6''s original defect verbatim (agent_picker.lua:28 vs cliproxy_catalog.lua:161). Separately catalog_cached validates only that decoded.models is a table, then view_for(true) hands raw rows to _build_items, which concatenates m.display/m.id unguarded — a row without owner renders `X - x (nil)`. Rule: one guarded provider->owner helper, and shape-check rows once at each entry boundary (parse, catalog_cached, live_models.providers, the expanded path).'
          family: missing-input-guard
          round: 6
        - id: BR-22
          severity: Important
          title: The empty-catalog early return suppresses the logged-out rows that case exists for
          detail: '2nd in family. agent_picker.lua:142 lets `#models == 0` decide both "are there models to curate" and "which providers are logged out". On a fresh install with no OAuth logins the proxy returns data:[], so no `(logged out)` row renders at all — the onboarding path the Spec''s "why is my provider missing" purpose targets. Same gate, second effect: fetch_catalog writes only when #models > 0 (cliproxy.lua:1445), so catalog_stale stays permanently true and every :ParleyAgent fires two curls forever. Rule: scope a degenerate-case guard to the decision it actually informs.'
          family: one-value-two-decisions
          round: 6
        - id: BR-23
          severity: Important
          title: The ready_port promotion left three copies and its docstring claims the duplication was removed
          detail: '2nd in family. ready_port.lua:67-69 says the helpers were "Promoted from file-local copies in cliproxy_lifecycle_spec.lua and cliproxy_recovery_e2e_spec.lua ... worth removing (ARCH-DRY)", but cliproxy_lifecycle_spec.lua:17,50 and cliproxy_recovery_e2e_spec.lua:18,26 still define their own, and the latter is not in the window at all despite being listed in Task 2.2''s Files. Two copies became three, and they have diverged in implementation. Rule: a docstring claiming a consolidation must be grep-verifiable when written, and call sites named in a task''s Files section are that task''s Definition of Done.'
          family: duplicated-logic-not-extracted
          round: 6
        - id: BR-24
          severity: Important
          title: No atlas or README update for live_models, the picker live/login sections, C-a, or catalog.json
          detail: '2nd in family. The only atlas change in the range is traceability.yaml, a test map. `grep -rn live_models README.md atlas/` returns nothing; atlas/providers/agents.md still describes agent selection with no live section; the derived-artifact list at cliproxy-managed.md:43 does not mention catalog.json. The instance is not the fix: the plan lumps docs into a terminal Task 4.3, which structurally guarantees every earlier milestone crosses its boundary undocumented (AGENTS.md 8). Dissolve 4.3 into per-milestone docs steps naming file and section.'
          family: atlas-not-updated-for-new-surface
          round: 6
        - id: BR-25
          severity: Important
          title: The picker's documented rows drifted (em dash, separator, grouping) with only containment assertions
          detail: 2nd in family. Measured render is `  Claude Opus 5 - claude-opus-5 (anthropic)` and `  antigravity - (logged out)`; the Spec documents an em dash, a separator between the configured agents and the live section, and one group per configured provider — none present. picker_items_spec.lua:337-343 asserts only find(..., plain), so all four drifts pass. BR-5 already settled this for curate ("equality, not containment") and produced SPEC_RENDERS; the picker's rows are documented renders in the same Spec and did not inherit the rule. Extend the keyed-equality table to the live row, login row and separator.
          family: documented-render-not-pinned
          round: 6
        - id: BR-26
          severity: Important
          title: Core concepts names `catalog_write`, which exists nowhere; three new entities are absent from both tables
          detail: '2nd in family. The Integration points table lists catalog_write; the code ships M._write_catalog and the plan''s own Task 2.2 code block writes inline. Also missing from both tables: M.catalog_stale, M._catalog_path, M.register_live_agent (called at agent_picker.lua:177). The Notes'' referent grep matches only dotted call syntax, so bare table names are structurally exempt from the check meant to keep names honest — which is how this survived a round that reported the sweep clean. Extend the check to run in both directions over table cells.'
          family: plan-table-missing-entity
          round: 6
        - id: BR-27
          severity: Minor
          title: The M3 implementation commit sits inside the M2 review window
          detail: Base 45d9f28 is the M1 close, so this M2 gate reviews both 0b4c577 (M2) and c9e83d8 (M3); M3's own milestone-close will have only fix commits left to review. `## Plan`'s M2 box is unticked and `## Log` has no M2 entry. Also, `live_models` in config.lua is assigned to Task 4.2 (M4) by the plan but shipped in the M3 commit.
          family: boundary-crossed-out-of-order
          round: 6
        - id: BR-28
          severity: Minor
          title: The `<id>*` live-agent naming convention is written in two modules
          detail: agent_picker.lua:93 builds `m.id .. "*"` to decide is_current; cliproxy_catalog.build_agent owns the same convention at :220. Changing the suffix in one place makes the current-agent checkmark silently stop rendering with every test green — picker_items_spec.lua:355 hardcodes the literal rather than deriving it from build_agent.
          family: duplicated-logic-not-extracted
          round: 6
        - id: BR-29
          severity: Minor
          title: 'Assorted envelope and idiom nits: is_managed gate, 4s chained budget, repaint-under-cursor, pending vs SKIP'
          detail: agent_picker.lua:209 gates the refresh on is_managed(), so a self-managed running proxy never populates the catalog though fetch_catalog cannot spawn anything. The two GETs are chained, making the worst case 2x CURL_MAX_TIME rather than the stated 2s, and handle.update swaps the list under a user mid-type (sel_idx is preserved by index, not identity). cliproxy_conformance_spec.lua:241,260 use pending() where the file's five siblings print "SKIP:". catalog_path duplicates config_path's mkdir idiom.
          family: stated-design-not-implemented
          round: 6
      boundary: M2
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

## Round 5 — 2026-08-31T21:10:30-07:00 (claude) — passed

### Disposed

- BR-1 — not-addressed — Referent sweep verifiably ran, but no Task step still creates or tests `_providers_without_models`; plan.md:1079 credits Task 3.1, which does not produce it.
- BR-5 — addressed — Verified by revert — SPEC_RENDERS["antigravity"] goes red under the naive rank_key; no tbl_contains remains as a behavioural assertion.
- BR-6 — addressed — Verified by revert — "contributes nothing for a provider it does not know" goes red without the `owner and models or {}` guard.
- BR-7 — addressed — Verified by revert — fixed at the parse boundary; the empty-id test goes red without it, and the test title no longer overstates the guard.
- BR-8 — addressed — Verified by revert — build_agent returns nil; the test goes red without the guard, and both callers handle nil.
- BR-9 — addressed — All 26 SPEC references now read providers/cliproxy-managed, which resolves in atlas/traceability.yaml and runs green.
- BR-13 — not-addressed — Rule is correct but unpinned — restoring the `< 100` threshold leaves all 41 tests passing; the magnitude-SHAPE coverage the finding asked for was not added.

### Raised

- **BR-14** [Important] `missing-test-for-shipped-behavior` M3 Task 3.3 code (register_live_agent + refresh_state restore) crossed the M1 boundary with no test and no caller
  init.lua:1329-1343 and 4327-4348 are Task 3.3 in the plan, whose named spec
  tests/unit/live_agent_state_spec.lua does not exist at HEAD. register_live_agent has
  zero call sites and the restore branch only fires on _state.live_agent, which only it
  sets — so all 38 lines are unreachable and the suite passes identically with them
  deleted. 440ab17's message does not mention init.lua. 2nd in family: do NOT just add
  the one spec — adopt the covering rule in the plan's Notes, that before
  milestone-close `git diff <base>..HEAD --name-only -- lua/` must name a test for every
  file listed, and a file belonging to a later milestone does not cross at all. At this
  boundary that check yields cliproxy_catalog.lua yes, providers.lua yes, init.lua no.
- **BR-15** [Important] `single-source-not-enforced` cliproxy_default_web_search_strategy is not in the resolution chain; five config sites still hand-state what it derives
  2nd in family — do NOT patch the five sites. The rule: every consumer of a newly
  single-sourced decision must derive from it in the same round, including consumers
  that predate the extraction; a hand-maintained restatement is a deferred consumer.
  Enumeration: config.lua:239, 247, 259, 377, 384 each hand-write
  web_search_strategy = "anthropic_tools_route", and get_cliproxy_strategy
  (providers.lua:111-129) resolves model to strategy from config without consulting the
  new source. The fix is a precedence decision, not a config edit — inserting the
  derived default changes what providers.cliproxyapi.web_search_strategy means. Either
  decide and wire the chain, or record in the plan that the pinned agents deliberately
  declare their own strategy and why the single source does not govern them.
- **BR-16** [Important] `atlas-not-updated-for-new-surface` atlas/providers/cliproxy-managed.md gains no entry for cliproxy_catalog.lua, the third pure module of the feature it maps
  Its "## Pieces" section names cliproxy_config.lua (:18) and cliproxy_auth.lua (:33)
  but not the new module, nor the Model row shape, `series`, or the two-band rank_key.
  Only atlas/traceability.yaml was touched (2 lines) — that is the file-to-spec mapping,
  not the map. README needs nothing at M1: no config key or keybinding lands until M4.
- **BR-17** [Minor] `duplicated-logic-not-extracted` The agent-registration block is copy-pasted between register_live_agent and the refresh_state restore, and the copies already disagree
  init.lua:4339-4342 does `M.agents[name] = agent`; init.lua:1337-1340 does
  `M.agents[name] = M.agents[name] or agent`. Same four-line operation, divergent
  clobber semantics — a live pick replaces a same-named configured agent for the
  session but not after a restart. ARCH-DRY: extract one M._register_agent(agent) and
  make the clobber rule a single decision.
- **BR-18** [Minor] `plan-command-does-not-run` The BR-9 referent sweep collapsed four distinct spec keys into four identical commands, destroying which surfaces the step covers
  2nd in family — do NOT edit the two blocks. The rule: a mechanical referent sweep must
  preserve the distinction the old referents carried; when N distinct keys map to one
  key, emit the command ONCE and keep the enumeration of what it covers in prose.
  plan.md:1391-1397 now runs `make test-spec SPEC=providers/cliproxy-managed` four
  identical times where it previously named unit/cliproxy_config, unit/cliproxy_auth,
  unit/failure_notice and integration/cliproxy_recovery_e2e; plan.md:1442-1446 repeats
  it twice.

## Round 6 — 2026-08-31T21:30:15-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — addressed — `_logged_out_providers` and `provider_states` are gone from the plan; Task 3.1 Steps 4-6 now create and test `_providers_without_models`, which the code delivers, and the prescribed referent grep runs clean (74 referents, 4 unresolved and all defined in Task 4.1's own code blocks). See new finding I7 for the hole the grep still has.

### Raised

- **BR-19** [Critical] `missing-test-for-shipped-behavior` M3's restart-restore and the whole of Task 3.2 ship with no test that can fail
  3rd in family. Deleting lua/parley/init.lua:1329-1343 in a scratch copy of c9e83d8 leaves all four mapped specs green (0 failures); grep confirms no other spec touches `live_agent`. live_agent_state_spec.lua:69-75 calls build_agent twice and compares, asserting only determinism. M.agent_picker (agent_picker.lua:118-216) has zero tests and Task 3.2 has no Step-1 test block. Fix the rule, not the site: run the mutation check per task before milestone-close and record the result in `## Log`.
- **BR-20** [Important] `stated-design-not-implemented` fetch_catalog logs nothing and discards the HTTP status; "cache in memory" and `providers = nil` are unimplemented
  2nd in family. cliproxy.lua:1437 keeps only split_status's first return, so a 401 body is parsed as a catalog and is indistinguishable from an empty one; there is no logger call anywhere in fetch_catalog despite the envelope's "logged at debug", and the fake's new 401 branch (fake_cliproxy:407) is entered by no test. catalog_cached re-reads and re-decodes the file 2-3x per picker open with a mkdir each time — no in-memory cache exists. curate(models, {}) returns {} where the Spec documents "nil providers = every known provider, unfiltered" (measured). Rule: walk the Spec Components and the Operating envelope bullet by bullet at each close; implement and pin, or strike in `## Revisions`.
- **BR-21** [Important] `missing-input-guard` BR-6/BR-7's boundary guards applied to one site while two new boundaries shipped without them
  2nd in family. Measured: _providers_without_models(models, {'claud'}) and (models, {'anthropic'}) both emit actionable `(logged out)` rows that run `:ParleyProxy login <typo>`, while curate returns {} for the same input; with an ownerless catalog row the answer silently flips to {}, which is BR-6's original defect verbatim (agent_picker.lua:28 vs cliproxy_catalog.lua:161). Separately catalog_cached validates only that decoded.models is a table, then view_for(true) hands raw rows to _build_items, which concatenates m.display/m.id unguarded — a row without owner renders `X - x (nil)`. Rule: one guarded provider->owner helper, and shape-check rows once at each entry boundary (parse, catalog_cached, live_models.providers, the expanded path).
- **BR-22** [Important] `one-value-two-decisions` The empty-catalog early return suppresses the logged-out rows that case exists for
  2nd in family. agent_picker.lua:142 lets `#models == 0` decide both "are there models to curate" and "which providers are logged out". On a fresh install with no OAuth logins the proxy returns data:[], so no `(logged out)` row renders at all — the onboarding path the Spec's "why is my provider missing" purpose targets. Same gate, second effect: fetch_catalog writes only when #models > 0 (cliproxy.lua:1445), so catalog_stale stays permanently true and every :ParleyAgent fires two curls forever. Rule: scope a degenerate-case guard to the decision it actually informs.
- **BR-23** [Important] `duplicated-logic-not-extracted` The ready_port promotion left three copies and its docstring claims the duplication was removed
  2nd in family. ready_port.lua:67-69 says the helpers were "Promoted from file-local copies in cliproxy_lifecycle_spec.lua and cliproxy_recovery_e2e_spec.lua ... worth removing (ARCH-DRY)", but cliproxy_lifecycle_spec.lua:17,50 and cliproxy_recovery_e2e_spec.lua:18,26 still define their own, and the latter is not in the window at all despite being listed in Task 2.2's Files. Two copies became three, and they have diverged in implementation. Rule: a docstring claiming a consolidation must be grep-verifiable when written, and call sites named in a task's Files section are that task's Definition of Done.
- **BR-24** [Important] `atlas-not-updated-for-new-surface` No atlas or README update for live_models, the picker live/login sections, C-a, or catalog.json
  2nd in family. The only atlas change in the range is traceability.yaml, a test map. `grep -rn live_models README.md atlas/` returns nothing; atlas/providers/agents.md still describes agent selection with no live section; the derived-artifact list at cliproxy-managed.md:43 does not mention catalog.json. The instance is not the fix: the plan lumps docs into a terminal Task 4.3, which structurally guarantees every earlier milestone crosses its boundary undocumented (AGENTS.md 8). Dissolve 4.3 into per-milestone docs steps naming file and section.
- **BR-25** [Important] `documented-render-not-pinned` The picker's documented rows drifted (em dash, separator, grouping) with only containment assertions
  2nd in family. Measured render is `  Claude Opus 5 - claude-opus-5 (anthropic)` and `  antigravity - (logged out)`; the Spec documents an em dash, a separator between the configured agents and the live section, and one group per configured provider — none present. picker_items_spec.lua:337-343 asserts only find(..., plain), so all four drifts pass. BR-5 already settled this for curate ("equality, not containment") and produced SPEC_RENDERS; the picker's rows are documented renders in the same Spec and did not inherit the rule. Extend the keyed-equality table to the live row, login row and separator.
- **BR-26** [Important] `plan-table-missing-entity` Core concepts names `catalog_write`, which exists nowhere; three new entities are absent from both tables
  2nd in family. The Integration points table lists catalog_write; the code ships M._write_catalog and the plan's own Task 2.2 code block writes inline. Also missing from both tables: M.catalog_stale, M._catalog_path, M.register_live_agent (called at agent_picker.lua:177). The Notes' referent grep matches only dotted call syntax, so bare table names are structurally exempt from the check meant to keep names honest — which is how this survived a round that reported the sweep clean. Extend the check to run in both directions over table cells.
- **BR-27** [Minor] `boundary-crossed-out-of-order` The M3 implementation commit sits inside the M2 review window
  Base 45d9f28 is the M1 close, so this M2 gate reviews both 0b4c577 (M2) and c9e83d8 (M3); M3's own milestone-close will have only fix commits left to review. `## Plan`'s M2 box is unticked and `## Log` has no M2 entry. Also, `live_models` in config.lua is assigned to Task 4.2 (M4) by the plan but shipped in the M3 commit.
- **BR-28** [Minor] `duplicated-logic-not-extracted` The `<id>*` live-agent naming convention is written in two modules
  agent_picker.lua:93 builds `m.id .. "*"` to decide is_current; cliproxy_catalog.build_agent owns the same convention at :220. Changing the suffix in one place makes the current-agent checkmark silently stop rendering with every test green — picker_items_spec.lua:355 hardcodes the literal rather than deriving it from build_agent.
- **BR-29** [Minor] `stated-design-not-implemented` Assorted envelope and idiom nits: is_managed gate, 4s chained budget, repaint-under-cursor, pending vs SKIP
  agent_picker.lua:209 gates the refresh on is_managed(), so a self-managed running proxy never populates the catalog though fetch_catalog cannot spawn anything. The two GETs are chained, making the worst case 2x CURL_MAX_TIME rather than the stated 2s, and handle.update swaps the list under a user mid-type (sel_idx is preserved by index, not identity). cliproxy_conformance_spec.lua:241,260 use pending() where the file's five siblings print "SKIP:". catalog_path duplicates config_path's mkdir idiom.

## Open findings

- **BR-13** [Important] `rank-key-version-extraction` rank_key's `< 100` threshold answers the 120B instance, not the class: any parameter count below 100 still reads as a version
- **BR-14** [Important] `missing-test-for-shipped-behavior` M3 Task 3.3 code (register_live_agent + refresh_state restore) crossed the M1 boundary with no test and no caller
- **BR-15** [Important] `single-source-not-enforced` cliproxy_default_web_search_strategy is not in the resolution chain; five config sites still hand-state what it derives
- **BR-16** [Important] `atlas-not-updated-for-new-surface` atlas/providers/cliproxy-managed.md gains no entry for cliproxy_catalog.lua, the third pure module of the feature it maps
- **BR-17** [Minor] `duplicated-logic-not-extracted` The agent-registration block is copy-pasted between register_live_agent and the refresh_state restore, and the copies already disagree
- **BR-18** [Minor] `plan-command-does-not-run` The BR-9 referent sweep collapsed four distinct spec keys into four identical commands, destroying which surfaces the step covers
- **BR-19** [Critical] `missing-test-for-shipped-behavior` M3's restart-restore and the whole of Task 3.2 ship with no test that can fail
- **BR-20** [Important] `stated-design-not-implemented` fetch_catalog logs nothing and discards the HTTP status; "cache in memory" and `providers = nil` are unimplemented
- **BR-21** [Important] `missing-input-guard` BR-6/BR-7's boundary guards applied to one site while two new boundaries shipped without them
- **BR-22** [Important] `one-value-two-decisions` The empty-catalog early return suppresses the logged-out rows that case exists for
- **BR-23** [Important] `duplicated-logic-not-extracted` The ready_port promotion left three copies and its docstring claims the duplication was removed
- **BR-24** [Important] `atlas-not-updated-for-new-surface` No atlas or README update for live_models, the picker live/login sections, C-a, or catalog.json
- **BR-25** [Important] `documented-render-not-pinned` The picker's documented rows drifted (em dash, separator, grouping) with only containment assertions
- **BR-26** [Important] `plan-table-missing-entity` Core concepts names `catalog_write`, which exists nowhere; three new entities are absent from both tables
- **BR-27** [Minor] `boundary-crossed-out-of-order` The M3 implementation commit sits inside the M2 review window
- **BR-28** [Minor] `duplicated-logic-not-extracted` The `<id>*` live-agent naming convention is written in two modules
- **BR-29** [Minor] `stated-design-not-implemented` Assorted envelope and idiom nits: is_managed gate, 4s chained budget, repaint-under-cursor, pending vs SKIP
