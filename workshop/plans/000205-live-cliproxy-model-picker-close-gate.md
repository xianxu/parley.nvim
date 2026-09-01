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
    - "n": 7
      timestamp: "2026-08-31T21:45:46-07:00"
      agent: claude
      dispose:
        - id: BR-19
          disposition: not-addressed
          note: 'Re-measured at 4c79c45: deleting init.lua:1329-1343 leaves live_agent_state (3), picker_items (37) and cliproxy_catalog (42) all green, 0 failures; M.agent_picker still has zero tests and no mutation check was recorded in the Log.'
          round: 7
        - id: BR-20
          disposition: not-addressed
          note: 'cliproxy.lua untouched by the fix commit; status still discarded at :1437, no logger call, no in-memory cache, curate(models, {}) still {}. Also: _write_catalog''s false return is discarded and _catalog_inflight has no release path if vim.system throws.'
          round: 7
        - id: BR-21
          disposition: not-addressed
          note: 'Measured at head: _providers_without_models(models, {"claud"}) and {"anthropic"} both return a login row. Worse than reported — _build_items:112 THROWS "attempt to concatenate field ''display'' (a nil value)" on a shape-less row, which the <C-a> raw path can reach.'
          round: 7
        - id: BR-22
          disposition: not-addressed
          note: view_for's `#models == 0` early return (agent_picker.lua:154) and fetch_catalog's `#models > 0` write gate (cliproxy.lua:1445) are both unchanged.
          round: 7
        - id: BR-23
          disposition: not-addressed
          note: Prevalence is 8, not 3 — free_port is defined file-locally in cliproxy_lifecycle, recovery_e2e, conformance, dispatch, download, caller_teardown, auth_login and openai_tool_loop. Task 2.2's Files still names lifecycle:17,50 and recovery_e2e:18,26 as modify targets; neither was touched, and ready_port.lua:67-69 still claims the consolidation.
          round: 7
        - id: BR-24
          disposition: addressed
          note: atlas/providers/agents.md gained the live section, cliproxy-managed.md gained the routes/catalog.json/live_models, and terminal Task 4.3 was dissolved into per-milestone docs steps (1.7 S5, 2.2 S5, 3.3 S6) — the rule, not the instance. README live_models is now scheduled at M3's boundary and must land there. See new Minor on the heading placement.
          round: 7
        - id: BR-25
          disposition: not-addressed
          note: Separator and equality pinning landed, but agent_picker.lua:112,121 still render a hyphen while the Spec (issue lines 83, 90) documents an em dash, with no Revisions entry striking it; picker_items_spec.lua:343 now names the hyphen "DOCUMENTED" and this round's atlas page restates it a third time. Per-provider grouping is ordering-only.
          round: 7
        - id: BR-26
          disposition: addressed
          note: 'catalog_write is gone, _write_catalog/_catalog_path/catalog_stale/register_live_agent are in the tables, and the check now runs both directions — but see the new finding: both directions have syntactic blind spots that exempt the assignment form register_live_agent itself uses.'
          round: 7
        - id: BR-27
          disposition: not-addressed
          note: The issue file is unchanged across the whole window — M2 box unticked, no Log entry — and live_models is still assigned to Task 4.2 despite shipping in the M3 commit.
          round: 7
        - id: BR-28
          disposition: not-addressed
          note: '`m.id .. "*"` still at agent_picker.lua:105 and cliproxy_catalog.lua:220; the test still hardcodes the literal.'
          round: 7
        - id: BR-29
          disposition: not-addressed
          note: is_managed gate still at agent_picker.lua:224, GETs still chained, pending() still at conformance:241,260, catalog_path still duplicates the config_path mkdir idiom.
          round: 7
      findings:
        - id: BR-30
          severity: Critical
          title: A picked live model renders twice in the picker, both rows checkmarked and sharing one recall key
          detail: 'Measured at head: with `_agents = {"alpha","claude-opus-5*"}` and a live catalog row for claude-opus-5, `_build_items` emits 2 rows named `claude-opus-5*` — one from the configured loop (register_live_agent inserts the name at init.lua:4338, and the restart restore at :1336 does the same) and one from the live section at agent_picker.lua:105. Both carry is_current, and `recall_id_fn` keys on the duplicated name. Visible on the second `:ParleyAgent` after the first live pick, and on every restart after. `make_plugin` (picker_items_spec.lua:10) never holds a live agent, so no test reaches the state. Fix in `view_for` so the `<C-a>` path inherits the exclusion, and pin it with a make_plugin variant whose `_agents` contains the live name.'
          family: section-merge-not-deduped
          round: 7
        - id: BR-31
          severity: Important
          title: The bidirectional referent check added this round has two syntactic blind spots and already misses a shipped entity
          detail: '3rd in family — do not fix the instance, fix the rule. The reverse pass (plan:1568-1570) is `^\+function M\.`, which misses `M.register_live_agent = function(model)` (init.lua:4333) and `M._catalog_path = catalog_path` (cliproxy.lua:1372) — the assignment form used by the very entity BR-26 added. The forward pass still matches only backticked dotted call syntax, so non-function referents escape: plan:1584 and Task 2.1 Step 1 both name a `catalog` mode on fake_cliproxy that exists nowhere (grep finds only comments; the step body contradicts its own title by prescribing an extension of `healthy`, which is what shipped). The rule: enumerate every definition form the codebase uses and every referent KIND a plan cell can name (function, fixture mode, route, file, flag), and run both directions over that enumeration.'
          family: plan-table-missing-entity
          round: 7
        - id: BR-32
          severity: Minor
          title: The new atlas section was inserted between `## Flow` and its body, refiling 60 lines of flow narrative under the catalog heading
          detail: atlas/providers/cliproxy-managed.md:36-38 — `## Model catalog (#205)` now sits immediately after the `## Flow` heading, leaving Flow with an empty body and putting the `setup{ cliproxy.manage = true }` → pre_query → ensure_running narrative (lines 39-98) under the catalog section. Move the new H2 after the Flow body or before `## Auth & secrets`.
          family: docs-insert-orphans-section
          round: 7
      boundary: M2
      blocked: true
    - "n": 8
      timestamp: "2026-08-31T22:04:28-07:00"
      agent: claude
      dispose:
        - id: BR-19
          disposition: not-addressed
          note: 'Re-measured at 28af157: deleting init.lua:1329-1343 leaves live_agent_state (3), picker_items (38), cliproxy_catalog unit (42) and integration (7) all green. M.agent_picker still has zero tests, Task 3.2 still has no Step-1 test block, and no per-task mutation check appears in `## Log`. Note the code sits in 440ab17, inside the M1 window — the check must run per TASK, not per commit range, or it keeps falling between boundaries.'
          round: 8
        - id: BR-20
          disposition: not-addressed
          note: 'Status capture is fixed and pinned. Still open: zero logger calls in fetch_catalog (cliproxy.lua:1420-1467) vs the envelope''s "logged at debug"; no in-memory cache (catalog_cached re-decodes + mkdirs 3-4x per open); curate(models, {}) still returns {} against the Spec''s "nil providers = every known provider"; _write_catalog''s false return discarded; _catalog_inflight has no release path if vim.system throws. Nothing struck in `## Revisions`.'
          round: 8
        - id: BR-21
          disposition: not-addressed
          note: 'Unchanged and measured at head: _providers_without_models(models,{''claud''}) and (models,{''anthropic''}) both emit actionable login rows; an ownerless catalog row still flips the answer to {}. The throw moved one step earlier — not_already_an_agent (agent_picker.lua:162) concatenates m.id before _build_items:105/:112 does, so a corrupt catalog.json crashes the <C-a> path outright. The four-boundary enumeration is unchanged.'
          round: 8
        - id: BR-22
          disposition: not-addressed
          note: 'The two sites the finding named are fixed with good comments. The class survives at two more in the same function: agent_picker.lua:174 lets `all` decide both "bypass curation" and "hide login rows", and :245 gates the background repaint on `#models > 0`, so the 200-plus-empty-registry case the write gate was just fixed to record never repaints. Gate repaint on fetch success; scope the expanded bypass to curation only.'
          round: 8
        - id: BR-23
          disposition: addressed
          note: '`grep -rn ''local function free_port|local function wait_listening'' tests/` returns nothing; 12 specs now require the helper, including two outside the plan''s Files list. Residue: ready_port.lua:66-69 still says "promoted from two files" when it was eight, and nothing guards against a ninth copy — folded into the new single-source-not-enforced finding.'
          round: 8
        - id: BR-25
          disposition: addressed
          note: The separator ships, picker_items_spec.lua:343-346 pins separator/live/current/login as full-string equalities keyed off a DOCUMENTED table, and the issue carries a `## Revisions` entry striking the em dash and the grouping claim with reasons. Code and Spec now agree.
          round: 8
        - id: BR-27
          disposition: not-addressed
          note: '`## Plan`''s M2 box is still unticked with no `## Log` entry, and plan.md:1471 still assigns `live_models` to Task 4.2 though it shipped in the M3 commit.'
          round: 8
        - id: BR-28
          disposition: not-addressed
          note: 'Worse this round: `m.id .. "*"` is now at agent_picker.lua:105 and :162, cliproxy_catalog.lua:220, and picker_items_spec.lua:444 — the BR-30 fix added a third production copy and a fourth in its own test.'
          round: 8
        - id: BR-29
          disposition: not-addressed
          note: is_managed() gate at agent_picker.lua:243, GETs still chained, pending() at conformance:235,254 vs five siblings printing "SKIP:", catalog_path still duplicating config_path's mkdir idiom.
          round: 8
        - id: BR-30
          disposition: not-addressed
          note: 'The code fix is correct; the test cannot fail. picker_items_spec.lua:441-447 re-implements the exclusion in the spec body and hands an already-filtered list to _build_items, which never had the bug. Measured: reverting agent_picker.lua:174 and :180 to the pre-fix expressions leaves the file 38/38 green. Blocker is structural — extract M._view_for(models, cfg, all) as a pure function so a test can call the production path.'
          round: 8
        - id: BR-31
          disposition: addressed
          note: 'The plan''s Notes now enumerate definition forms (function M.x(, M.x = function(, M.x = alias, local function) and referent kinds (functions, fixture modes, routes, files, flags). I ran both passes: the reverse surfaces all 7 M.* entities the window adds and each has a table row; the forward''s only unresolved names are historical mentions inside `## Revisions` and file paths. The phantom `catalog` fixture mode is gone from Task 2.1, and the plan''s stated mode list matches fake_cliproxy''s own Modes header exactly.'
          round: 8
        - id: BR-32
          disposition: not-addressed
          note: atlas/providers/cliproxy-managed.md:36-38 unchanged — `## Model catalog (#205)` still sits immediately after the `## Flow` heading, leaving Flow with an empty body and ~60 lines of flow narrative filed under the catalog section.
          round: 8
      findings:
        - id: BR-33
          severity: Important
          title: The new <C-a> bypasses the keybinding registry, and this round's two consolidations have no executable guard
          detail: '3rd in family — the rule, not the instance. agent_picker.lua:228 hardcodes <C-a> while every sibling picker key carries a help_only registry row with a config_key (keybinding_registry.lua:757, :822, :869 are all <C-a>), so the key is neither discoverable nor rebindable — and the mapping directly above it (:220-226) binds <C-g>? to the very help that omits it. Measured prevalence: 8 literal keys in float_picker mappings tables across agent_picker (1, new), root_dir_picker (3) and system_prompt_picker (4), none registered. The same rule covers this round''s correct-but-unguarded sweeps: nothing stops a ninth file-local free_port, and nothing stops the next tests/integration/cliproxy_*_spec.lua from omitting _set_data_dir — the omission that broke the operator''s live proxy. Rule: when a fix is "sweep every consumer onto the single source," the deliverable includes the guard that keeps them there. tests/arch/scratch_placement_spec.lua is the in-repo precedent; three greps in one arch spec cover all three invariants.'
          family: single-source-not-enforced
          round: 8
        - id: BR-34
          severity: Minor
          title: The fake's two new /v1beta/models branches are unmeasured assumptions, and one now backs a test
          detail: '2nd in family. fake_cliproxy:404-410 has needs_login serve the FULL CATALOG_V1BETA while /v1/models serves data:[] — a combination not measured against the real proxy — and client_key_mismatch answer 401. The conformance spec exercises /v1beta only on a healthy proxy, so neither branch is checked against the binary, and the new "records a genuinely empty catalog" case rides the first. Rule: a fake branch no live conformance check covers is an assumption and should be labelled as one at the branch, so a later reader does not mistake it for measured behaviour.'
          family: unmeasured-family-branch
          round: 8
      boundary: M2
      blocked: true
    - "n": 9
      timestamp: "2026-08-31T22:19:51-07:00"
      agent: claude
      dispose:
        - id: BR-19
          disposition: not-addressed
          note: 'Re-measured at a568ddf — deleted init.lua:1329-1343 in a scratch copy and ran every unit/integration/arch spec: 0 new failures vs baseline. M.agent_picker and the new key_for have zero tests; no mutation check recorded in the Log.'
          round: 9
        - id: BR-20
          disposition: not-addressed
          note: Status capture fixed and pinned; zero logger calls in fetch_catalog, no in-memory cache (mkdir+decode 2-3x per open), curate(models, {}) still {} — all measured, none struck in Revisions.
          round: 9
        - id: BR-21
          disposition: not-addressed
          note: All four reproduced at head, including two live throws — _view_for concatenates a nil id and _build_items a nil display, so a corrupt catalog.json crashes the picker.
          round: 9
        - id: BR-22
          disposition: addressed
          note: Verified by reverting the empty-catalog early return in a scratch copy — picker_items_spec goes 41/1 red. The write gate keys on HTTP 200 with both sides pinned.
          round: 9
        - id: BR-27
          disposition: not-addressed
          note: M2 box unticked, no Log entry, plan.md:1473 still assigns live_models to Task 4.2; and the tree carries a 192-line uncommitted deletion in config.lua at the boundary.
          round: 9
        - id: BR-28
          disposition: not-addressed
          note: Three production sites now — cliproxy_catalog.lua:220, agent_picker.lua:105 and agent_picker.lua:154.
          round: 9
        - id: BR-29
          disposition: not-addressed
          note: is_managed gate at agent_picker.lua:249, GETs still chained, pending() at conformance:231,249, catalog_path still duplicating config_path's mkdir idiom.
          round: 9
        - id: BR-30
          disposition: addressed
          note: Verified by reverting the exclusion in _view_for — picker_items_spec goes 39/3 red. _view_for is the right structural answer; the test now drives the production path.
          round: 9
        - id: BR-32
          disposition: not-addressed
          note: cliproxy-managed.md:36-38 unchanged; Flow still has an empty body with its narrative filed under the catalog heading.
          round: 9
        - id: BR-33
          disposition: addressed
          note: Registry row + key_for + arch spec; I violated each of the three invariants in a scratch copy and each guard went red. See the new Minor on the row's scope value.
          round: 9
        - id: BR-34
          disposition: not-addressed
          note: Both branches unchanged at fake_cliproxy:399-410, still exercised by no conformance check and still unlabelled as assumptions.
          round: 9
      findings:
        - id: BR-35
          severity: Minor
          title: The new <C-a> registry row declares scope "global", so it renders under Global in every help screen though it only works inside the agent picker
          detail: 'keybinding_registry.lua:759 sets scope = "global" because the scope forest has no agent_picker entry; the three sibling <C-a> rows use chat_finder/note_finder/issue_finder. Rendered help_lines("chat", config) confirms the row appears under the Global heading in a chat buffer, where <C-a> is Vim''s increment and parley binds nothing. keybindings_spec.lua:244 only asserts the scope is a valid label, never the right one. The rule: when a taxonomy has no correct value for a new row, add the value rather than filing it under the nearest wrong one — here, an agent_picker scope with a label and display-order entry, as the three finders already have. Also add agent_picker_mappings to config.lua so the documented config_key has an example, as the other *_mappings keys do.'
          family: wrong-taxonomy-value
          round: 9
      boundary: M2
      blocked: true
    - "n": 10
      timestamp: "2026-08-31T22:35:42-07:00"
      agent: claude
      dispose:
        - id: BR-19
          disposition: addressed
          note: 'Mutation-verified against HEAD: deleting init.lua:1329-1343 fails 2 specs; removing the _select live branch fails 1; removing the _view_for dedupe fails 3; removing catalog_cached''s sanitize fails 1; hardcoding the picker key fails the arch guard.'
          round: 10
        - id: BR-20
          disposition: not-addressed
          note: 'Status half fixed. Still open: no logger call anywhere in fetch_catalog; no in-memory cache (2 reads + 2 mkdirs per picker open, more per toggle/repaint); providers=nil still yields {} against the Spec. None struck in Revisions.'
          round: 10
        - id: BR-21
          disposition: not-addressed
          note: 'Measured: a foreign-mode 200 wipes a warm 7-row catalog to 0 (cliproxy.lua:1475); _beta_status discarded (:1463); _providers_without_models still unguarded (agent_picker.lua:25); <C-a> renders "(nil)" for an ownerless row (:112).'
          round: 10
        - id: BR-24
          disposition: not-addressed
          note: Atlas half done and good. README.md is untouched in the whole window while the diff adds <C-a> and cliproxy.live_models; plan Task 3.3 Step 6 still names it.
          round: 10
        - id: BR-27
          disposition: not-addressed
          note: Unfixable structurally, but plan Task 4.2 still assigns live_models to M4 though it shipped in M3; and the tree carries uncommitted M4 config.lua edits at an M2 gate.
          round: 10
        - id: BR-28
          disposition: not-addressed
          note: 'Now three sites, not two: agent_picker.lua:105, agent_picker.lua:154, cliproxy_catalog.lua:220.'
          round: 10
        - id: BR-29
          disposition: not-addressed
          note: 'All four unchanged: is_managed gate at agent_picker.lua:256, chained 2x CURL_MAX_TIME, repaint-under-cursor, pending() at conformance_spec.lua:235,254.'
          round: 10
        - id: BR-32
          disposition: not-addressed
          note: atlas/providers/cliproxy-managed.md:36-38 unchanged; the H2 still sits directly under "## Flow", orphaning 60 lines of flow narrative.
          round: 10
        - id: BR-34
          disposition: not-addressed
          note: fake_cliproxy:404-410 unchanged and still unlabelled; no live conformance covers the needs_login or client_key_mismatch v1beta branches.
          round: 10
        - id: BR-35
          disposition: not-addressed
          note: 'Measured: help_lines("chat", config) renders the row under Global. No agent_picker scope added; no agent_picker_mappings example in config.lua.'
          round: 10
      findings:
        - id: BR-36
          severity: Minor
          title: The arch guard matches one syntactic form, so the `or "<C-a>"` fallback is a second copy of the registry default it cannot see
          detail: |-
            This is the 4th finding in family `single-source-not-enforced`. Do NOT fix the
            instance. The rule: a syntactic single-source guard must enumerate the FORMS the
            duplicated value can take — BR-31 already wrote that rule for the plan's referent
            grep, and it is now recurring in tests/arch/single_source_sweeps_spec.lua, which
            greps only `key = "<...>"`. agent_picker.lua:243 restates
            keybinding_registry.lua:757's `<C-a>` in an `or` fallback that the guard misses.
            Currently unreachable (resolve_keys always falls back to default_key), so it is
            dead duplication rather than a live bug — which is exactly why no test notices it.
          family: single-source-not-enforced
          round: 10
        - id: BR-37
          severity: Minor
          title: fetch_catalog drops its callback on the in-flight path while calling it with {} on the missing-endpoint path
          detail: |-
            cliproxy.lua:1439 returns without invoking cb when _catalog_inflight is set;
            cliproxy.lua:1444 invokes cb({}) when host/port are missing. A picker opened while
            a refresh is in flight therefore never repaints — the in-flight fetch's callback
            belongs to the earlier, possibly closed, picker. Rule: every exit path of a
            callback-taking async function resolves its callback exactly once.
          family: async-callback-not-resolved
          round: 10
      boundary: M2
      blocked: false
    - "n": 11
      timestamp: "2026-08-31T22:54:26-07:00"
      agent: claude
      dispose:
        - id: BR-20
          disposition: not-addressed
          note: Status capture, 401 coverage, mtime memo and providers=nil all fixed and pinned; still zero logger calls in the catalog block and plan.md:85's "logged at debug" is neither implemented nor struck, and catalog_path() mkdirs on the memo-hit path.
          round: 11
        - id: BR-21
          disposition: not-addressed
          note: 'Measured at HEAD via _write_catalog -> catalog_cached -> _view_for{all=true} -> _build_items: an ownerless row still renders "(nil)"; _providers_without_models still emits actionable login rows for "claud" and "anthropic" where curate returns {}.'
          round: 11
        - id: BR-24
          disposition: addressed
          note: README.md, atlas/providers/agents.md and atlas/providers/cliproxy-managed.md all updated; docs steps dissolved into Tasks 1.7/2.2/3.3.
          round: 11
        - id: BR-27
          disposition: not-addressed
          note: Structurally unfixable, but Task 4.2 still instructs adding live_models with a stale providers list, and the working tree's uncommitted M4 config.lua deletion fails 3 unit specs at the gate.
          round: 11
        - id: BR-28
          disposition: addressed
          note: cliproxy_catalog.agent_name is the single source; no `.. "*"` remains anywhere under lua/.
          round: 11
        - id: BR-29
          disposition: not-addressed
          note: 'All four unchanged: is_managed gate at agent_picker.lua:255, chained GETs, repaint-under-cursor, pending() at conformance_spec.lua:233,250; catalog_path still repeats the mkdir idiom.'
          round: 11
        - id: BR-32
          disposition: addressed
          note: '"## Model catalog (#205)" now sits at cliproxy-managed.md:64, after the Flow body and before "## Auth & secrets".'
          round: 11
        - id: BR-34
          disposition: addressed
          note: The v1beta branches now mirror /v1/models with the inference stated at the branch; the 401 branch is entered by the new "does not erase a good catalog when the proxy answers 401" case.
          round: 11
        - id: BR-35
          disposition: not-addressed
          note: 'Measured: help_lines("chat", {}) now renders the row under Buffer, still a context where parley binds nothing. No agent_picker scope/label/display-order added; no agent_picker_mappings in config.lua.'
          round: 11
        - id: BR-36
          disposition: addressed
          note: Literal removed and the guard enumerates two extra forms; re-adding `or "<C-a>"` in a scratch copy turns the arch spec red.
          round: 11
        - id: BR-37
          disposition: addressed
          note: 'Mutation-verified: restoring the bare `return` on the in-flight path fails "resolves its callback on every exit path".'
          round: 11
      findings:
        - id: BR-38
          severity: Important
          title: Core concepts omits `agent_name` and files the side-effecting `_select` under Pure entities
          detail: |-
            `agent_name` is new at cliproxy_catalog.lua:203, a module both tables name, yet appears in
            neither table — the plan's own bidirectional rule ("every function the milestone's diff adds to
            a module named in the tables must APPEAR in a table row") would have caught it. Separately
            plan.md:34 lists `_select` as PURE while agent_picker.lua:183 calls vim.cmd and vim.schedule,
            and live_agent_state_spec.lua:165 has to monkeypatch vim.cmd to drive it; per the review
            checklist a PURE row whose test needs mocks is a table/code contradiction.
            This is the 4th finding in family `plan-table-missing-entity`. Do NOT fix the instance. The rule:
            three consecutive rounds have missed an entity because the referent sweep is PROSE in "Notes for
            the implementer". Make it executable, as tests/arch/single_source_sweeps_spec.lua already did for
            this issue's other consolidations — a spec that parses the two tables and asserts both directions
            (no row names a nonexistent symbol; no `function M.x`/`M.x = function` in a listed module is
            absent from a row). Then move `_select` to Integration points, or extract its pure decision so the
            PURE label becomes true.
          family: plan-table-missing-entity
          round: 11
        - id: BR-39
          severity: Minor
          title: The new arch guard's comment claims it counts any bracketed key literal; it matches three forms and misses `or { shortcut = "<C-g>?" }`
          detail: |-
            This is the 5th finding in family `single-source-not-enforced`. Do NOT fix the instance.
            Measured: agent_picker.lua:221, root_dir_picker.lua:211 and system_prompt_picker.lua:121 each
            restate keybinding_registry entry `help`'s `default_key = "<C-g>?"`, and all three pass
            single_source_sweeps_spec.lua:72-80 — whose allowance for agent_picker.lua is 0, i.e. the guard
            asserts a measurable falsehood while its own comment at :69 says "Any bracketed key literal in
            the file counts". BR-31 and BR-36 both already stated "enumerate the FORMS", and enumerating
            forms has now failed twice; the rule that covers the class is different: stop matching syntax
            shapes and match the VALUE — count every `"<…` string literal in lua/parley/*_picker.lua
            (measured: agent_picker 1, root_dir 4, system_prompt 5) and freeze that as the shrink-only debt,
            or assert every such literal also appears as a `default_key` in keybinding_registry.entries.
          family: single-source-not-enforced
          round: 11
        - id: BR-40
          severity: Minor
          title: '`_view_for` never dedupes the live list by id, so overlapping `providers` entries render one model twice, both checkmarked'
          detail: |-
            This is the 2nd finding in family `section-merge-not-deduped`. Measured: with
            `providers = { "claude", "claude:opus" }`, _build_items emits `claude-opus-5*` twice — identical
            display, both `is_current`, one shared `recall_id_fn` key. curate resets `seen[series]` per
            provider entry, and _view_for's `unregistered` only excludes ALREADY-REGISTERED agents. This is
            BR-30's symptom reached by a second route, and it is also the route a duplicate id in /v1/models
            would take — a shape fake_cliproxy's own comment claims to model ("one id claimed by two
            owners") while CATALOG_V1 contains no duplicate id. The rule: _view_for returns a live list
            deduped by `cliproxy_catalog.agent_name(m.id)` in ONE pass that subsumes the registered-agent
            exclusion, so no assembly of the live section can emit a name twice regardless of where the
            duplicate came from. Pin it with an overlapping-provider-entry case, and either give the fake a
            genuinely duplicated id or drop the claim from its comment and from plan.md's fake bullet.
          family: section-merge-not-deduped
          round: 11
        - id: BR-41
          severity: Minor
          title: '`fetch_catalog` calls `render_opts()`, so opening the agent picker generates and writes `management.key`'
          detail: |-
            This is the 4th finding in family `stated-design-not-implemented`. Measured: with a fresh data
            dir and nothing listening, one fetch_catalog call creates `<data_root>/` and writes a 0600
            `management.key`. cliproxy.lua:1459 pulls the whole render bundle when it needs only host, port
            and secret; render_opts() is documented at :234 as the input gatherer for write_rendered_config /
            config_drift / status, and it calls M.management_key(), which read-or-CREATES the key. A function
            whose docstring says "a plain GET … a connection-refused is a no-op that leaves the cache in
            place" should provision nothing. The rule covering this family: at each close, walk the block's
            own docstrings and the plan's operating envelope bullet by bullet and either pin the claim with a
            test or strike it in `## Revisions` — the same rule BR-20 wrote, still unapplied to the envelope's
            logging bullet in this very module.
          family: stated-design-not-implemented
          round: 11
      boundary: M2
      blocked: false
    - "n": 12
      timestamp: "2026-08-31T23:15:14-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: '`_providers_without_models` is defined at agent_picker.lua:19 and appears in the plan''s Core-concepts table; I re-ran the referent sweep across both tables and every named symbol resolves.'
          round: 12
      findings:
        - id: BR-42
          severity: Important
          title: '`is_managed()` gates the catalog refresh, so `manage = false` never populates the catalog and the picker shows six false `(logged out)` rows'
          detail: agent_picker.lua:282. fetch_catalog has exactly one production caller and it sits behind cliproxy.is_managed(). With manage=false — documented at config.lua:115 as the supported opt-out — _write_catalog is never reached, catalog_cached() returns {} forever, _view_for falls back to cc.providers() (all six) and every one renders `(logged out)`. The dormancy contract this gate claims to protect is already pinned independently by cliproxy_catalog_spec.lua:103-113; the Spec's condition was "only if the proxy already answers", not "only when managed". This is BR-29's first leg, carried not-addressed for six rounds and then omitted from the round-10 "backlog cleared" revision. ARCH-PURPOSE.
          family: stated-design-not-implemented
          round: 12
        - id: BR-43
          severity: Important
          title: The background repaint preserves the selection by index, so `<CR>` can fire on a row the user never pointed at
          detail: 'agent_picker.lua:283-291 calls handle.update with no next_selection_index; float_picker.lua:1685-1707 keeps sel_idx as an integer and only clamps it. Cold catalog: the picker opens with N agents + separator + 6 `(logged out)` rows; the user arrows onto `antigravity - (logged out)` to start a login; ~200ms later the refresh lands and the tail becomes ~9 live model rows at the same indices; `<CR>` registers a model agent instead of running the login. Fix by capturing recall_id_fn(selected) before update and passing the re-derived index — the picker already owns that identity function. BR-29''s third leg.'
          family: async-callback-not-resolved
          round: 12
        - id: BR-44
          severity: Important
          title: The M3 window is empty and commit 747c8ff falls in no review window at all
          detail: 'This is the 2nd finding in family `boundary-crossed-out-of-order`. Do NOT fix this instance — fix the rule. The rule: sdlc must refuse a milestone-close whose window is empty, and refuse a close for Mx whose window contains commits whose subject claims M(x+1); both are mechanical git log --grep checks. Measured: seven M3 commits (c9e83d8 plus five "M2/M3" commits) landed before M2''s close, and 747c8ff — which changed fetch_catalog, _view_for, _providers_without_models, _build_items and the arch guard — sits outside M2''s window (ended 60b964b3) and outside M3''s (starts at 747c8ff). The #174 "bundle fixes into the close commit so the anchor is HEAD" convention creates the hole by construction; the next window must open at the previous boundary''s PARENT, or close commits must carry no code. The same leak silently dropped BR-29, whose two live legs are the two findings above. I closed this round''s gap by hand: I reviewed 60b964b..747c8ff and revert-verified all four of its fixes go red without them.'
          family: boundary-crossed-out-of-order
          round: 12
        - id: BR-45
          severity: Important
          title: Spec Component 3 names `cliproxy_auth.lua`/`channels_for_login` as the credential source and forbids `owned_by`; the code uses only `owned_by`
          detail: 'This is the 5th finding in family `stated-design-not-implemented`. Do NOT fix this instance — fix the rule. The rule: every repo symbol the Spec names in backticks must be swept EXECUTABLY, the way tests/arch/single_source_sweeps_spec.lua already sweeps this issue''s other consolidations — a spec that parses the issue `## Spec` and the plan''s Core-concepts tables and asserts each named symbol is required/referenced by the milestone''s code or struck in `## Revisions`. BR-1 established this for the plan; the Spec was never brought under it and prose sweeps have now failed five times. Instance: agent_picker.lua never requires cliproxy_auth; _providers_without_models keys on provider_owned_by (agent_picker.lua:25,32), which Component 3 explicitly forbids. Not cosmetic — the Spec''s own measurement (claude-sonnet-4-6 under `anthropic` on one start, `antigravity` on the next) means that with only antigravity logged in, `claude` reads as logged IN and its `(logged out)` row never appears, contradicting the Done-when. No fixture reattributes an id across owners.'
          family: stated-design-not-implemented
          round: 12
        - id: BR-46
          severity: Important
          title: The working tree carries an uncommitted `config.lua` deleting every configured agent, and the plan's close recipe is `git add -u`
          detail: 'git status shows ` M lua/parley/config.lua`: a local edit stripping all 18 agents to one ToolOpus* plus two commented stubs. Plan Task 3.3 Step 7 closes with `git add -u && git commit`, which stages exactly that into the M3 close commit. Stash or revert before the close, and name explicit paths in the recipe instead of `git add -u`.'
          family: close-stages-unreviewed-worktree
          round: 12
        - id: BR-47
          severity: Important
          title: M3's own Done-when e2e — a live pick carrying tools plus web_search on the Anthropic wire, evidenced from `:ParleyLog` — is not recorded in `## Log`
          detail: 'This is the 4th finding in family `missing-test-for-shipped-behavior`. Do NOT fix this instance — fix the rule. The rule: a plan step whose deliverable is EVIDENCE (a manual e2e, a live probe) must be treated like a test at the boundary — recorded in `## Log` with its observation, or struck in `## Revisions` with the reason — because unlike a spec file it leaves no trace when skipped, so the gate cannot tell "done" from "forgotten". Instance: plan Task 3.3 Step 5 demands picking claude-opus-5 and confirming from :ParleyLog that the request carried both the client tools and a web_search tool; `## Log` has M1-close and M2-close entries only. The gap is narrow — build_agent''s three-way strategy is unit-pinned at cliproxy_catalog_spec.lua:289-360 — but it is the Spec''s stated Done-when.'
          family: missing-test-for-shipped-behavior
          round: 12
        - id: BR-48
          severity: Minor
          title: '`fetch_catalog`''s callback argument means the cached catalog on one path and the freshly-parsed, possibly-rejected list on the other'
          detail: cliproxy.lua:1456 resolves with M.catalog_cached() on the in-flight path; :1509 resolves with the parsed list even when the classify() gate declined the write, so a caller that trusts the argument gets {} whenever the proxy is down. Today's sole consumer re-reads the cache and ignores it, but the surface is new. `cb(M.catalog_cached())` in the else branch makes it uniformly "the catalog you should render".
          family: one-value-two-decisions
          round: 12
        - id: BR-49
          severity: Minor
          title: '`render_opts`''s host/port/secret derivation is copied verbatim into `fetch_catalog`'
          detail: 'This is the 4th finding in family `duplicated-logic-not-extracted`. Do NOT fix this instance — fix the rule. The rule: when a helper is avoided because of a side effect, SPLIT the helper rather than inlining its body at the new call site — extract a side-effect-free `endpoint_opts()` that render_opts composes. Instance: cliproxy.lua:238-241 and :1464-1466 are byte-identical derivations that must now stay in sync; BR-41 correctly removed the management.key minting but paid for it with a copy.'
          family: duplicated-logic-not-extracted
          round: 12
        - id: BR-50
          severity: Minor
          title: '`_catalog_inflight` is never cleared if `vim.system` raises synchronously, wedging refresh for the session'
          detail: cliproxy.lua:1471 sets the flag before the first vim.system call; a synchronous raise (missing curl) leaves it true and every later fetch short-circuits to the cache for the rest of the session. A pcall around the launch, or clearing the flag on the failure path, closes it.
          family: missing-input-guard
          round: 12
        - id: BR-51
          severity: Minor
          title: The durable plan has 76 step checkboxes and none are ticked, including for the two closed milestones
          detail: 'workshop/plans/000205-live-cliproxy-model-picker-plan.md: Chunk 1 35 unticked, Chunk 2 10, Chunk 3 18, Chunk 4 13. The issue''s `## Plan` milestone rows carry all the progress state, so the durable plan cannot be read as a record of what was done. Tick them, or state in the plan that the issue file is the record.'
          family: plan-command-does-not-run
          round: 12
      boundary: M3
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

## Round 7 — 2026-08-31T21:45:46-07:00 (claude) — BLOCKED

### Disposed

- BR-19 — not-addressed — Re-measured at 4c79c45: deleting init.lua:1329-1343 leaves live_agent_state (3), picker_items (37) and cliproxy_catalog (42) all green, 0 failures; M.agent_picker still has zero tests and no mutation check was recorded in the Log.
- BR-20 — not-addressed — cliproxy.lua untouched by the fix commit; status still discarded at :1437, no logger call, no in-memory cache, curate(models, {}) still {}. Also: _write_catalog's false return is discarded and _catalog_inflight has no release path if vim.system throws.
- BR-21 — not-addressed — Measured at head: _providers_without_models(models, {"claud"}) and {"anthropic"} both return a login row. Worse than reported — _build_items:112 THROWS "attempt to concatenate field 'display' (a nil value)" on a shape-less row, which the <C-a> raw path can reach.
- BR-22 — not-addressed — view_for's `#models == 0` early return (agent_picker.lua:154) and fetch_catalog's `#models > 0` write gate (cliproxy.lua:1445) are both unchanged.
- BR-23 — not-addressed — Prevalence is 8, not 3 — free_port is defined file-locally in cliproxy_lifecycle, recovery_e2e, conformance, dispatch, download, caller_teardown, auth_login and openai_tool_loop. Task 2.2's Files still names lifecycle:17,50 and recovery_e2e:18,26 as modify targets; neither was touched, and ready_port.lua:67-69 still claims the consolidation.
- BR-24 — addressed — atlas/providers/agents.md gained the live section, cliproxy-managed.md gained the routes/catalog.json/live_models, and terminal Task 4.3 was dissolved into per-milestone docs steps (1.7 S5, 2.2 S5, 3.3 S6) — the rule, not the instance. README live_models is now scheduled at M3's boundary and must land there. See new Minor on the heading placement.
- BR-25 — not-addressed — Separator and equality pinning landed, but agent_picker.lua:112,121 still render a hyphen while the Spec (issue lines 83, 90) documents an em dash, with no Revisions entry striking it; picker_items_spec.lua:343 now names the hyphen "DOCUMENTED" and this round's atlas page restates it a third time. Per-provider grouping is ordering-only.
- BR-26 — addressed — catalog_write is gone, _write_catalog/_catalog_path/catalog_stale/register_live_agent are in the tables, and the check now runs both directions — but see the new finding: both directions have syntactic blind spots that exempt the assignment form register_live_agent itself uses.
- BR-27 — not-addressed — The issue file is unchanged across the whole window — M2 box unticked, no Log entry — and live_models is still assigned to Task 4.2 despite shipping in the M3 commit.
- BR-28 — not-addressed — `m.id .. "*"` still at agent_picker.lua:105 and cliproxy_catalog.lua:220; the test still hardcodes the literal.
- BR-29 — not-addressed — is_managed gate still at agent_picker.lua:224, GETs still chained, pending() still at conformance:241,260, catalog_path still duplicates the config_path mkdir idiom.

### Raised

- **BR-30** [Critical] `section-merge-not-deduped` A picked live model renders twice in the picker, both rows checkmarked and sharing one recall key
  Measured at head: with `_agents = {"alpha","claude-opus-5*"}` and a live catalog row for claude-opus-5, `_build_items` emits 2 rows named `claude-opus-5*` — one from the configured loop (register_live_agent inserts the name at init.lua:4338, and the restart restore at :1336 does the same) and one from the live section at agent_picker.lua:105. Both carry is_current, and `recall_id_fn` keys on the duplicated name. Visible on the second `:ParleyAgent` after the first live pick, and on every restart after. `make_plugin` (picker_items_spec.lua:10) never holds a live agent, so no test reaches the state. Fix in `view_for` so the `<C-a>` path inherits the exclusion, and pin it with a make_plugin variant whose `_agents` contains the live name.
- **BR-31** [Important] `plan-table-missing-entity` The bidirectional referent check added this round has two syntactic blind spots and already misses a shipped entity
  3rd in family — do not fix the instance, fix the rule. The reverse pass (plan:1568-1570) is `^\+function M\.`, which misses `M.register_live_agent = function(model)` (init.lua:4333) and `M._catalog_path = catalog_path` (cliproxy.lua:1372) — the assignment form used by the very entity BR-26 added. The forward pass still matches only backticked dotted call syntax, so non-function referents escape: plan:1584 and Task 2.1 Step 1 both name a `catalog` mode on fake_cliproxy that exists nowhere (grep finds only comments; the step body contradicts its own title by prescribing an extension of `healthy`, which is what shipped). The rule: enumerate every definition form the codebase uses and every referent KIND a plan cell can name (function, fixture mode, route, file, flag), and run both directions over that enumeration.
- **BR-32** [Minor] `docs-insert-orphans-section` The new atlas section was inserted between `## Flow` and its body, refiling 60 lines of flow narrative under the catalog heading
  atlas/providers/cliproxy-managed.md:36-38 — `## Model catalog (#205)` now sits immediately after the `## Flow` heading, leaving Flow with an empty body and putting the `setup{ cliproxy.manage = true }` → pre_query → ensure_running narrative (lines 39-98) under the catalog section. Move the new H2 after the Flow body or before `## Auth & secrets`.

## Round 8 — 2026-08-31T22:04:28-07:00 (claude) — BLOCKED

### Disposed

- BR-19 — not-addressed — Re-measured at 28af157: deleting init.lua:1329-1343 leaves live_agent_state (3), picker_items (38), cliproxy_catalog unit (42) and integration (7) all green. M.agent_picker still has zero tests, Task 3.2 still has no Step-1 test block, and no per-task mutation check appears in `## Log`. Note the code sits in 440ab17, inside the M1 window — the check must run per TASK, not per commit range, or it keeps falling between boundaries.
- BR-20 — not-addressed — Status capture is fixed and pinned. Still open: zero logger calls in fetch_catalog (cliproxy.lua:1420-1467) vs the envelope's "logged at debug"; no in-memory cache (catalog_cached re-decodes + mkdirs 3-4x per open); curate(models, {}) still returns {} against the Spec's "nil providers = every known provider"; _write_catalog's false return discarded; _catalog_inflight has no release path if vim.system throws. Nothing struck in `## Revisions`.
- BR-21 — not-addressed — Unchanged and measured at head: _providers_without_models(models,{'claud'}) and (models,{'anthropic'}) both emit actionable login rows; an ownerless catalog row still flips the answer to {}. The throw moved one step earlier — not_already_an_agent (agent_picker.lua:162) concatenates m.id before _build_items:105/:112 does, so a corrupt catalog.json crashes the <C-a> path outright. The four-boundary enumeration is unchanged.
- BR-22 — not-addressed — The two sites the finding named are fixed with good comments. The class survives at two more in the same function: agent_picker.lua:174 lets `all` decide both "bypass curation" and "hide login rows", and :245 gates the background repaint on `#models > 0`, so the 200-plus-empty-registry case the write gate was just fixed to record never repaints. Gate repaint on fetch success; scope the expanded bypass to curation only.
- BR-23 — addressed — `grep -rn 'local function free_port|local function wait_listening' tests/` returns nothing; 12 specs now require the helper, including two outside the plan's Files list. Residue: ready_port.lua:66-69 still says "promoted from two files" when it was eight, and nothing guards against a ninth copy — folded into the new single-source-not-enforced finding.
- BR-25 — addressed — The separator ships, picker_items_spec.lua:343-346 pins separator/live/current/login as full-string equalities keyed off a DOCUMENTED table, and the issue carries a `## Revisions` entry striking the em dash and the grouping claim with reasons. Code and Spec now agree.
- BR-27 — not-addressed — `## Plan`'s M2 box is still unticked with no `## Log` entry, and plan.md:1471 still assigns `live_models` to Task 4.2 though it shipped in the M3 commit.
- BR-28 — not-addressed — Worse this round: `m.id .. "*"` is now at agent_picker.lua:105 and :162, cliproxy_catalog.lua:220, and picker_items_spec.lua:444 — the BR-30 fix added a third production copy and a fourth in its own test.
- BR-29 — not-addressed — is_managed() gate at agent_picker.lua:243, GETs still chained, pending() at conformance:235,254 vs five siblings printing "SKIP:", catalog_path still duplicating config_path's mkdir idiom.
- BR-30 — not-addressed — The code fix is correct; the test cannot fail. picker_items_spec.lua:441-447 re-implements the exclusion in the spec body and hands an already-filtered list to _build_items, which never had the bug. Measured: reverting agent_picker.lua:174 and :180 to the pre-fix expressions leaves the file 38/38 green. Blocker is structural — extract M._view_for(models, cfg, all) as a pure function so a test can call the production path.
- BR-31 — addressed — The plan's Notes now enumerate definition forms (function M.x(, M.x = function(, M.x = alias, local function) and referent kinds (functions, fixture modes, routes, files, flags). I ran both passes: the reverse surfaces all 7 M.* entities the window adds and each has a table row; the forward's only unresolved names are historical mentions inside `## Revisions` and file paths. The phantom `catalog` fixture mode is gone from Task 2.1, and the plan's stated mode list matches fake_cliproxy's own Modes header exactly.
- BR-32 — not-addressed — atlas/providers/cliproxy-managed.md:36-38 unchanged — `## Model catalog (#205)` still sits immediately after the `## Flow` heading, leaving Flow with an empty body and ~60 lines of flow narrative filed under the catalog section.

### Raised

- **BR-33** [Important] `single-source-not-enforced` The new <C-a> bypasses the keybinding registry, and this round's two consolidations have no executable guard
  3rd in family — the rule, not the instance. agent_picker.lua:228 hardcodes <C-a> while every sibling picker key carries a help_only registry row with a config_key (keybinding_registry.lua:757, :822, :869 are all <C-a>), so the key is neither discoverable nor rebindable — and the mapping directly above it (:220-226) binds <C-g>? to the very help that omits it. Measured prevalence: 8 literal keys in float_picker mappings tables across agent_picker (1, new), root_dir_picker (3) and system_prompt_picker (4), none registered. The same rule covers this round's correct-but-unguarded sweeps: nothing stops a ninth file-local free_port, and nothing stops the next tests/integration/cliproxy_*_spec.lua from omitting _set_data_dir — the omission that broke the operator's live proxy. Rule: when a fix is "sweep every consumer onto the single source," the deliverable includes the guard that keeps them there. tests/arch/scratch_placement_spec.lua is the in-repo precedent; three greps in one arch spec cover all three invariants.
- **BR-34** [Minor] `unmeasured-family-branch` The fake's two new /v1beta/models branches are unmeasured assumptions, and one now backs a test
  2nd in family. fake_cliproxy:404-410 has needs_login serve the FULL CATALOG_V1BETA while /v1/models serves data:[] — a combination not measured against the real proxy — and client_key_mismatch answer 401. The conformance spec exercises /v1beta only on a healthy proxy, so neither branch is checked against the binary, and the new "records a genuinely empty catalog" case rides the first. Rule: a fake branch no live conformance check covers is an assumption and should be labelled as one at the branch, so a later reader does not mistake it for measured behaviour.

## Round 9 — 2026-08-31T22:19:51-07:00 (claude) — BLOCKED

### Disposed

- BR-19 — not-addressed — Re-measured at a568ddf — deleted init.lua:1329-1343 in a scratch copy and ran every unit/integration/arch spec: 0 new failures vs baseline. M.agent_picker and the new key_for have zero tests; no mutation check recorded in the Log.
- BR-20 — not-addressed — Status capture fixed and pinned; zero logger calls in fetch_catalog, no in-memory cache (mkdir+decode 2-3x per open), curate(models, {}) still {} — all measured, none struck in Revisions.
- BR-21 — not-addressed — All four reproduced at head, including two live throws — _view_for concatenates a nil id and _build_items a nil display, so a corrupt catalog.json crashes the picker.
- BR-22 — addressed — Verified by reverting the empty-catalog early return in a scratch copy — picker_items_spec goes 41/1 red. The write gate keys on HTTP 200 with both sides pinned.
- BR-27 — not-addressed — M2 box unticked, no Log entry, plan.md:1473 still assigns live_models to Task 4.2; and the tree carries a 192-line uncommitted deletion in config.lua at the boundary.
- BR-28 — not-addressed — Three production sites now — cliproxy_catalog.lua:220, agent_picker.lua:105 and agent_picker.lua:154.
- BR-29 — not-addressed — is_managed gate at agent_picker.lua:249, GETs still chained, pending() at conformance:231,249, catalog_path still duplicating config_path's mkdir idiom.
- BR-30 — addressed — Verified by reverting the exclusion in _view_for — picker_items_spec goes 39/3 red. _view_for is the right structural answer; the test now drives the production path.
- BR-32 — not-addressed — cliproxy-managed.md:36-38 unchanged; Flow still has an empty body with its narrative filed under the catalog heading.
- BR-33 — addressed — Registry row + key_for + arch spec; I violated each of the three invariants in a scratch copy and each guard went red. See the new Minor on the row's scope value.
- BR-34 — not-addressed — Both branches unchanged at fake_cliproxy:399-410, still exercised by no conformance check and still unlabelled as assumptions.

### Raised

- **BR-35** [Minor] `wrong-taxonomy-value` The new <C-a> registry row declares scope "global", so it renders under Global in every help screen though it only works inside the agent picker
  keybinding_registry.lua:759 sets scope = "global" because the scope forest has no agent_picker entry; the three sibling <C-a> rows use chat_finder/note_finder/issue_finder. Rendered help_lines("chat", config) confirms the row appears under the Global heading in a chat buffer, where <C-a> is Vim's increment and parley binds nothing. keybindings_spec.lua:244 only asserts the scope is a valid label, never the right one. The rule: when a taxonomy has no correct value for a new row, add the value rather than filing it under the nearest wrong one — here, an agent_picker scope with a label and display-order entry, as the three finders already have. Also add agent_picker_mappings to config.lua so the documented config_key has an example, as the other *_mappings keys do.

## Round 10 — 2026-08-31T22:35:42-07:00 (claude) — passed

### Disposed

- BR-19 — addressed — Mutation-verified against HEAD: deleting init.lua:1329-1343 fails 2 specs; removing the _select live branch fails 1; removing the _view_for dedupe fails 3; removing catalog_cached's sanitize fails 1; hardcoding the picker key fails the arch guard.
- BR-20 — not-addressed — Status half fixed. Still open: no logger call anywhere in fetch_catalog; no in-memory cache (2 reads + 2 mkdirs per picker open, more per toggle/repaint); providers=nil still yields {} against the Spec. None struck in Revisions.
- BR-21 — not-addressed — Measured: a foreign-mode 200 wipes a warm 7-row catalog to 0 (cliproxy.lua:1475); _beta_status discarded (:1463); _providers_without_models still unguarded (agent_picker.lua:25); <C-a> renders "(nil)" for an ownerless row (:112).
- BR-24 — not-addressed — Atlas half done and good. README.md is untouched in the whole window while the diff adds <C-a> and cliproxy.live_models; plan Task 3.3 Step 6 still names it.
- BR-27 — not-addressed — Unfixable structurally, but plan Task 4.2 still assigns live_models to M4 though it shipped in M3; and the tree carries uncommitted M4 config.lua edits at an M2 gate.
- BR-28 — not-addressed — Now three sites, not two: agent_picker.lua:105, agent_picker.lua:154, cliproxy_catalog.lua:220.
- BR-29 — not-addressed — All four unchanged: is_managed gate at agent_picker.lua:256, chained 2x CURL_MAX_TIME, repaint-under-cursor, pending() at conformance_spec.lua:235,254.
- BR-32 — not-addressed — atlas/providers/cliproxy-managed.md:36-38 unchanged; the H2 still sits directly under "## Flow", orphaning 60 lines of flow narrative.
- BR-34 — not-addressed — fake_cliproxy:404-410 unchanged and still unlabelled; no live conformance covers the needs_login or client_key_mismatch v1beta branches.
- BR-35 — not-addressed — Measured: help_lines("chat", config) renders the row under Global. No agent_picker scope added; no agent_picker_mappings example in config.lua.

### Raised

- **BR-36** [Minor] `single-source-not-enforced` The arch guard matches one syntactic form, so the `or "<C-a>"` fallback is a second copy of the registry default it cannot see
  This is the 4th finding in family `single-source-not-enforced`. Do NOT fix the
  instance. The rule: a syntactic single-source guard must enumerate the FORMS the
  duplicated value can take — BR-31 already wrote that rule for the plan's referent
  grep, and it is now recurring in tests/arch/single_source_sweeps_spec.lua, which
  greps only `key = "<...>"`. agent_picker.lua:243 restates
  keybinding_registry.lua:757's `<C-a>` in an `or` fallback that the guard misses.
  Currently unreachable (resolve_keys always falls back to default_key), so it is
  dead duplication rather than a live bug — which is exactly why no test notices it.
- **BR-37** [Minor] `async-callback-not-resolved` fetch_catalog drops its callback on the in-flight path while calling it with {} on the missing-endpoint path
  cliproxy.lua:1439 returns without invoking cb when _catalog_inflight is set;
  cliproxy.lua:1444 invokes cb({}) when host/port are missing. A picker opened while
  a refresh is in flight therefore never repaints — the in-flight fetch's callback
  belongs to the earlier, possibly closed, picker. Rule: every exit path of a
  callback-taking async function resolves its callback exactly once.

## Round 11 — 2026-08-31T22:54:26-07:00 (claude) — passed

### Disposed

- BR-20 — not-addressed — Status capture, 401 coverage, mtime memo and providers=nil all fixed and pinned; still zero logger calls in the catalog block and plan.md:85's "logged at debug" is neither implemented nor struck, and catalog_path() mkdirs on the memo-hit path.
- BR-21 — not-addressed — Measured at HEAD via _write_catalog -> catalog_cached -> _view_for{all=true} -> _build_items: an ownerless row still renders "(nil)"; _providers_without_models still emits actionable login rows for "claud" and "anthropic" where curate returns {}.
- BR-24 — addressed — README.md, atlas/providers/agents.md and atlas/providers/cliproxy-managed.md all updated; docs steps dissolved into Tasks 1.7/2.2/3.3.
- BR-27 — not-addressed — Structurally unfixable, but Task 4.2 still instructs adding live_models with a stale providers list, and the working tree's uncommitted M4 config.lua deletion fails 3 unit specs at the gate.
- BR-28 — addressed — cliproxy_catalog.agent_name is the single source; no `.. "*"` remains anywhere under lua/.
- BR-29 — not-addressed — All four unchanged: is_managed gate at agent_picker.lua:255, chained GETs, repaint-under-cursor, pending() at conformance_spec.lua:233,250; catalog_path still repeats the mkdir idiom.
- BR-32 — addressed — "## Model catalog (#205)" now sits at cliproxy-managed.md:64, after the Flow body and before "## Auth & secrets".
- BR-34 — addressed — The v1beta branches now mirror /v1/models with the inference stated at the branch; the 401 branch is entered by the new "does not erase a good catalog when the proxy answers 401" case.
- BR-35 — not-addressed — Measured: help_lines("chat", {}) now renders the row under Buffer, still a context where parley binds nothing. No agent_picker scope/label/display-order added; no agent_picker_mappings in config.lua.
- BR-36 — addressed — Literal removed and the guard enumerates two extra forms; re-adding `or "<C-a>"` in a scratch copy turns the arch spec red.
- BR-37 — addressed — Mutation-verified: restoring the bare `return` on the in-flight path fails "resolves its callback on every exit path".

### Raised

- **BR-38** [Important] `plan-table-missing-entity` Core concepts omits `agent_name` and files the side-effecting `_select` under Pure entities
  `agent_name` is new at cliproxy_catalog.lua:203, a module both tables name, yet appears in
  neither table — the plan's own bidirectional rule ("every function the milestone's diff adds to
  a module named in the tables must APPEAR in a table row") would have caught it. Separately
  plan.md:34 lists `_select` as PURE while agent_picker.lua:183 calls vim.cmd and vim.schedule,
  and live_agent_state_spec.lua:165 has to monkeypatch vim.cmd to drive it; per the review
  checklist a PURE row whose test needs mocks is a table/code contradiction.
  This is the 4th finding in family `plan-table-missing-entity`. Do NOT fix the instance. The rule:
  three consecutive rounds have missed an entity because the referent sweep is PROSE in "Notes for
  the implementer". Make it executable, as tests/arch/single_source_sweeps_spec.lua already did for
  this issue's other consolidations — a spec that parses the two tables and asserts both directions
  (no row names a nonexistent symbol; no `function M.x`/`M.x = function` in a listed module is
  absent from a row). Then move `_select` to Integration points, or extract its pure decision so the
  PURE label becomes true.
- **BR-39** [Minor] `single-source-not-enforced` The new arch guard's comment claims it counts any bracketed key literal; it matches three forms and misses `or { shortcut = "<C-g>?" }`
  This is the 5th finding in family `single-source-not-enforced`. Do NOT fix the instance.
  Measured: agent_picker.lua:221, root_dir_picker.lua:211 and system_prompt_picker.lua:121 each
  restate keybinding_registry entry `help`'s `default_key = "<C-g>?"`, and all three pass
  single_source_sweeps_spec.lua:72-80 — whose allowance for agent_picker.lua is 0, i.e. the guard
  asserts a measurable falsehood while its own comment at :69 says "Any bracketed key literal in
  the file counts". BR-31 and BR-36 both already stated "enumerate the FORMS", and enumerating
  forms has now failed twice; the rule that covers the class is different: stop matching syntax
  shapes and match the VALUE — count every `"<…` string literal in lua/parley/*_picker.lua
  (measured: agent_picker 1, root_dir 4, system_prompt 5) and freeze that as the shrink-only debt,
  or assert every such literal also appears as a `default_key` in keybinding_registry.entries.
- **BR-40** [Minor] `section-merge-not-deduped` `_view_for` never dedupes the live list by id, so overlapping `providers` entries render one model twice, both checkmarked
  This is the 2nd finding in family `section-merge-not-deduped`. Measured: with
  `providers = { "claude", "claude:opus" }`, _build_items emits `claude-opus-5*` twice — identical
  display, both `is_current`, one shared `recall_id_fn` key. curate resets `seen[series]` per
  provider entry, and _view_for's `unregistered` only excludes ALREADY-REGISTERED agents. This is
  BR-30's symptom reached by a second route, and it is also the route a duplicate id in /v1/models
  would take — a shape fake_cliproxy's own comment claims to model ("one id claimed by two
  owners") while CATALOG_V1 contains no duplicate id. The rule: _view_for returns a live list
  deduped by `cliproxy_catalog.agent_name(m.id)` in ONE pass that subsumes the registered-agent
  exclusion, so no assembly of the live section can emit a name twice regardless of where the
  duplicate came from. Pin it with an overlapping-provider-entry case, and either give the fake a
  genuinely duplicated id or drop the claim from its comment and from plan.md's fake bullet.
- **BR-41** [Minor] `stated-design-not-implemented` `fetch_catalog` calls `render_opts()`, so opening the agent picker generates and writes `management.key`
  This is the 4th finding in family `stated-design-not-implemented`. Measured: with a fresh data
  dir and nothing listening, one fetch_catalog call creates `<data_root>/` and writes a 0600
  `management.key`. cliproxy.lua:1459 pulls the whole render bundle when it needs only host, port
  and secret; render_opts() is documented at :234 as the input gatherer for write_rendered_config /
  config_drift / status, and it calls M.management_key(), which read-or-CREATES the key. A function
  whose docstring says "a plain GET … a connection-refused is a no-op that leaves the cache in
  place" should provision nothing. The rule covering this family: at each close, walk the block's
  own docstrings and the plan's operating envelope bullet by bullet and either pin the claim with a
  test or strike it in `## Revisions` — the same rule BR-20 wrote, still unapplied to the envelope's
  logging bullet in this very module.

## Round 12 — 2026-08-31T23:15:14-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — addressed — `_providers_without_models` is defined at agent_picker.lua:19 and appears in the plan's Core-concepts table; I re-ran the referent sweep across both tables and every named symbol resolves.

### Raised

- **BR-42** [Important] `stated-design-not-implemented` `is_managed()` gates the catalog refresh, so `manage = false` never populates the catalog and the picker shows six false `(logged out)` rows
  agent_picker.lua:282. fetch_catalog has exactly one production caller and it sits behind cliproxy.is_managed(). With manage=false — documented at config.lua:115 as the supported opt-out — _write_catalog is never reached, catalog_cached() returns {} forever, _view_for falls back to cc.providers() (all six) and every one renders `(logged out)`. The dormancy contract this gate claims to protect is already pinned independently by cliproxy_catalog_spec.lua:103-113; the Spec's condition was "only if the proxy already answers", not "only when managed". This is BR-29's first leg, carried not-addressed for six rounds and then omitted from the round-10 "backlog cleared" revision. ARCH-PURPOSE.
- **BR-43** [Important] `async-callback-not-resolved` The background repaint preserves the selection by index, so `<CR>` can fire on a row the user never pointed at
  agent_picker.lua:283-291 calls handle.update with no next_selection_index; float_picker.lua:1685-1707 keeps sel_idx as an integer and only clamps it. Cold catalog: the picker opens with N agents + separator + 6 `(logged out)` rows; the user arrows onto `antigravity - (logged out)` to start a login; ~200ms later the refresh lands and the tail becomes ~9 live model rows at the same indices; `<CR>` registers a model agent instead of running the login. Fix by capturing recall_id_fn(selected) before update and passing the re-derived index — the picker already owns that identity function. BR-29's third leg.
- **BR-44** [Important] `boundary-crossed-out-of-order` The M3 window is empty and commit 747c8ff falls in no review window at all
  This is the 2nd finding in family `boundary-crossed-out-of-order`. Do NOT fix this instance — fix the rule. The rule: sdlc must refuse a milestone-close whose window is empty, and refuse a close for Mx whose window contains commits whose subject claims M(x+1); both are mechanical git log --grep checks. Measured: seven M3 commits (c9e83d8 plus five "M2/M3" commits) landed before M2's close, and 747c8ff — which changed fetch_catalog, _view_for, _providers_without_models, _build_items and the arch guard — sits outside M2's window (ended 60b964b3) and outside M3's (starts at 747c8ff). The #174 "bundle fixes into the close commit so the anchor is HEAD" convention creates the hole by construction; the next window must open at the previous boundary's PARENT, or close commits must carry no code. The same leak silently dropped BR-29, whose two live legs are the two findings above. I closed this round's gap by hand: I reviewed 60b964b..747c8ff and revert-verified all four of its fixes go red without them.
- **BR-45** [Important] `stated-design-not-implemented` Spec Component 3 names `cliproxy_auth.lua`/`channels_for_login` as the credential source and forbids `owned_by`; the code uses only `owned_by`
  This is the 5th finding in family `stated-design-not-implemented`. Do NOT fix this instance — fix the rule. The rule: every repo symbol the Spec names in backticks must be swept EXECUTABLY, the way tests/arch/single_source_sweeps_spec.lua already sweeps this issue's other consolidations — a spec that parses the issue `## Spec` and the plan's Core-concepts tables and asserts each named symbol is required/referenced by the milestone's code or struck in `## Revisions`. BR-1 established this for the plan; the Spec was never brought under it and prose sweeps have now failed five times. Instance: agent_picker.lua never requires cliproxy_auth; _providers_without_models keys on provider_owned_by (agent_picker.lua:25,32), which Component 3 explicitly forbids. Not cosmetic — the Spec's own measurement (claude-sonnet-4-6 under `anthropic` on one start, `antigravity` on the next) means that with only antigravity logged in, `claude` reads as logged IN and its `(logged out)` row never appears, contradicting the Done-when. No fixture reattributes an id across owners.
- **BR-46** [Important] `close-stages-unreviewed-worktree` The working tree carries an uncommitted `config.lua` deleting every configured agent, and the plan's close recipe is `git add -u`
  git status shows ` M lua/parley/config.lua`: a local edit stripping all 18 agents to one ToolOpus* plus two commented stubs. Plan Task 3.3 Step 7 closes with `git add -u && git commit`, which stages exactly that into the M3 close commit. Stash or revert before the close, and name explicit paths in the recipe instead of `git add -u`.
- **BR-47** [Important] `missing-test-for-shipped-behavior` M3's own Done-when e2e — a live pick carrying tools plus web_search on the Anthropic wire, evidenced from `:ParleyLog` — is not recorded in `## Log`
  This is the 4th finding in family `missing-test-for-shipped-behavior`. Do NOT fix this instance — fix the rule. The rule: a plan step whose deliverable is EVIDENCE (a manual e2e, a live probe) must be treated like a test at the boundary — recorded in `## Log` with its observation, or struck in `## Revisions` with the reason — because unlike a spec file it leaves no trace when skipped, so the gate cannot tell "done" from "forgotten". Instance: plan Task 3.3 Step 5 demands picking claude-opus-5 and confirming from :ParleyLog that the request carried both the client tools and a web_search tool; `## Log` has M1-close and M2-close entries only. The gap is narrow — build_agent's three-way strategy is unit-pinned at cliproxy_catalog_spec.lua:289-360 — but it is the Spec's stated Done-when.
- **BR-48** [Minor] `one-value-two-decisions` `fetch_catalog`'s callback argument means the cached catalog on one path and the freshly-parsed, possibly-rejected list on the other
  cliproxy.lua:1456 resolves with M.catalog_cached() on the in-flight path; :1509 resolves with the parsed list even when the classify() gate declined the write, so a caller that trusts the argument gets {} whenever the proxy is down. Today's sole consumer re-reads the cache and ignores it, but the surface is new. `cb(M.catalog_cached())` in the else branch makes it uniformly "the catalog you should render".
- **BR-49** [Minor] `duplicated-logic-not-extracted` `render_opts`'s host/port/secret derivation is copied verbatim into `fetch_catalog`
  This is the 4th finding in family `duplicated-logic-not-extracted`. Do NOT fix this instance — fix the rule. The rule: when a helper is avoided because of a side effect, SPLIT the helper rather than inlining its body at the new call site — extract a side-effect-free `endpoint_opts()` that render_opts composes. Instance: cliproxy.lua:238-241 and :1464-1466 are byte-identical derivations that must now stay in sync; BR-41 correctly removed the management.key minting but paid for it with a copy.
- **BR-50** [Minor] `missing-input-guard` `_catalog_inflight` is never cleared if `vim.system` raises synchronously, wedging refresh for the session
  cliproxy.lua:1471 sets the flag before the first vim.system call; a synchronous raise (missing curl) leaves it true and every later fetch short-circuits to the cache for the rest of the session. A pcall around the launch, or clearing the flag on the failure path, closes it.
- **BR-51** [Minor] `plan-command-does-not-run` The durable plan has 76 step checkboxes and none are ticked, including for the two closed milestones
  workshop/plans/000205-live-cliproxy-model-picker-plan.md: Chunk 1 35 unticked, Chunk 2 10, Chunk 3 18, Chunk 4 13. The issue's `## Plan` milestone rows carry all the progress state, so the durable plan cannot be read as a record of what was done. Tick them, or state in the plan that the issue file is the record.

## Open findings

- **BR-13** [Important] `rank-key-version-extraction` rank_key's `< 100` threshold answers the 120B instance, not the class: any parameter count below 100 still reads as a version
- **BR-14** [Important] `missing-test-for-shipped-behavior` M3 Task 3.3 code (register_live_agent + refresh_state restore) crossed the M1 boundary with no test and no caller
- **BR-15** [Important] `single-source-not-enforced` cliproxy_default_web_search_strategy is not in the resolution chain; five config sites still hand-state what it derives
- **BR-16** [Important] `atlas-not-updated-for-new-surface` atlas/providers/cliproxy-managed.md gains no entry for cliproxy_catalog.lua, the third pure module of the feature it maps
- **BR-17** [Minor] `duplicated-logic-not-extracted` The agent-registration block is copy-pasted between register_live_agent and the refresh_state restore, and the copies already disagree
- **BR-18** [Minor] `plan-command-does-not-run` The BR-9 referent sweep collapsed four distinct spec keys into four identical commands, destroying which surfaces the step covers
- **BR-20** [Important] `stated-design-not-implemented` fetch_catalog logs nothing and discards the HTTP status; "cache in memory" and `providers = nil` are unimplemented
- **BR-21** [Important] `missing-input-guard` BR-6/BR-7's boundary guards applied to one site while two new boundaries shipped without them
- **BR-27** [Minor] `boundary-crossed-out-of-order` The M3 implementation commit sits inside the M2 review window
- **BR-29** [Minor] `stated-design-not-implemented` Assorted envelope and idiom nits: is_managed gate, 4s chained budget, repaint-under-cursor, pending vs SKIP
- **BR-35** [Minor] `wrong-taxonomy-value` The new <C-a> registry row declares scope "global", so it renders under Global in every help screen though it only works inside the agent picker
- **BR-38** [Important] `plan-table-missing-entity` Core concepts omits `agent_name` and files the side-effecting `_select` under Pure entities
- **BR-39** [Minor] `single-source-not-enforced` The new arch guard's comment claims it counts any bracketed key literal; it matches three forms and misses `or { shortcut = "<C-g>?" }`
- **BR-40** [Minor] `section-merge-not-deduped` `_view_for` never dedupes the live list by id, so overlapping `providers` entries render one model twice, both checkmarked
- **BR-41** [Minor] `stated-design-not-implemented` `fetch_catalog` calls `render_opts()`, so opening the agent picker generates and writes `management.key`
- **BR-42** [Important] `stated-design-not-implemented` `is_managed()` gates the catalog refresh, so `manage = false` never populates the catalog and the picker shows six false `(logged out)` rows
- **BR-43** [Important] `async-callback-not-resolved` The background repaint preserves the selection by index, so `<CR>` can fire on a row the user never pointed at
- **BR-44** [Important] `boundary-crossed-out-of-order` The M3 window is empty and commit 747c8ff falls in no review window at all
- **BR-45** [Important] `stated-design-not-implemented` Spec Component 3 names `cliproxy_auth.lua`/`channels_for_login` as the credential source and forbids `owned_by`; the code uses only `owned_by`
- **BR-46** [Important] `close-stages-unreviewed-worktree` The working tree carries an uncommitted `config.lua` deleting every configured agent, and the plan's close recipe is `git add -u`
- **BR-47** [Important] `missing-test-for-shipped-behavior` M3's own Done-when e2e — a live pick carrying tools plus web_search on the Anthropic wire, evidenced from `:ParleyLog` — is not recorded in `## Log`
- **BR-48** [Minor] `one-value-two-decisions` `fetch_catalog`'s callback argument means the cached catalog on one path and the freshly-parsed, possibly-rejected list on the other
- **BR-49** [Minor] `duplicated-logic-not-extracted` `render_opts`'s host/port/secret derivation is copied verbatim into `fetch_catalog`
- **BR-50** [Minor] `missing-input-guard` `_catalog_inflight` is never cleared if `vim.system` raises synchronously, wedging refresh for the session
- **BR-51** [Minor] `plan-command-does-not-run` The durable plan has 76 step checkboxes and none are ticked, including for the two closed milestones
