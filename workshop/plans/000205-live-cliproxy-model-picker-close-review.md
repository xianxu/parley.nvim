# Boundary Review — parley.nvim#205 (whole-issue close)

| field | value |
|-------|-------|
| issue | 205 — live cliproxy model picker; retire hardcoded model lists |
| repo | parley.nvim |
| issue file | workshop/issues/000205-live-cliproxy-model-picker.md |
| boundary | whole-issue close |
| milestone | — |
| window | 42d72b9d2f12bad462d847d8e5b24876a1a6a63b..031cf82ef25d982f45a506be091a79c704e89748 |
| command | sdlc close --issue 205 |
| reviewer | claude |
| timestamp | 2026-09-01T13:13:10-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

`make test` is **green at HEAD** — I ran the full suite in the working tree and re-ran the roster-sensitive and arch specs against a clean `git archive` of `031cf82` in a separate checkout, so the boundary is not red and the uncommitted `config.lua` is not propping anything up. The feature itself is real and well-built: the pure catalog core is tested against captured fixtures with no mocks, the picker's live/logged-out/`<C-a>` surface is pinned by full-string equalities, `oauth-model-alias` is genuinely retired with an e2e case that runs with an *empty* alias block, and the cold-install warm now sits at `pre_query` where both managed and bring-your-own dispatches reach it. What blocks a clean SHIP is not runtime behaviour but **verification truth**: I mutation-tested three claimed fixes and three of the plan's own completion claims, and BR-72, BR-80, BR-87 and BR-91 are verifiably not delivered — including a 21-line double docstring on `warm_catalog` added *by this window* under a Revisions bullet asserting "0 remain … checked mechanically rather than by eye". Fix those (all cheap), re-run, and ship.

## 1. Strengths

- **`lua/parley/cliproxy_catalog.lua`** is a textbook ARCH-PURE core: `series`/`rank_key`/`curate` are deterministic, `curate` copies rows before tagging (`:189`), and the `SPEC_RENDERS` table in `tests/unit/cliproxy_catalog_spec.lua:171-186` derives one equality test per documented Spec row so a render cannot be added without a test.
- **BR-13's rule genuinely landed.** `rank_key` (`cliproxy_catalog.lua:106-111`) rejects a numeral glued to a letter, and the test covers magnitude *shape* — `20B`, `70B`, `32K`, `8x7B` — not the one value the finding named.
- **BR-68 and BR-100 verified by probe.** Deleting `M._on_login_success(provider)` at `cliproxy.lua:1250` now reddens `cliproxy_login_spec`; dropping the third argument from `agent_picker.lua`'s `repaint()` reddens `picker_items_spec`; appending `M._brand_new_seam = catalog_path` reddens the arch guard. Fixes pinned at the site, as asked.
- **`credential_health_across` serialization + `CULPRIT_RANK`** (`cliproxy_auth.lua:186-215`) is the right shape: eligibility as a separate predicate from ranking, declared-order tiebreak, and the fan-out no longer races `credential_health`'s one-shot repair flag.
- **The docs gate is met for the user-facing surface** — README documents `live_models`, `<C-a>` and the `(logged out)` row; `atlas/ui/pickers.md:101-120` now states the `update`/`selected` handle contract that BR-52/BR-60 kept re-breaking.

## 2. Critical findings

None. No correctness defect, crash, or contract drift found in the runtime path.

## 3. Important findings

All are prior findings re-disposed `not-addressed`; details and measurements are in the `findings` block below. In brief:

- **BR-72** — `lua/parley/cliproxy.lua:1558`. The fix moved `_force_stale = false` below `io.open`, but **no test pins it**: I re-inserted the clear at the top of `_write_catalog` in a clone and all 20 `cliproxy_catalog_spec` + 13 `cliproxy_login_spec` cases stayed green. The write failure is still unlogged and its boolean discarded at `:1698`.
- **BR-80** — `lua/parley/cliproxy.lua:478-499` and `:629-650`. Two stacked doc blocks remain; `warm_catalog` carries two complete near-duplicate docstrings, added by this window. The `@param`-vs-signature lint BR-80 asked for was never written; I wrote it and it fires on `:485` immediately. `recover`'s superseded paragraph at `:1346-1349` still sits directly above its replacement at `:1350`.
- **BR-91** — `tests/arch/single_source_sweeps_spec.lua:121-124`. Still `grep -rl` on a bare name. `resolve_login_provider` was deleted this window, the plan still tables it `modified` (`plan.md:39`), and the guard is green **only** because `cliproxy_config_spec.lua:271` mentions it in a comment — removing that one word turns the guard red naming it.
- **BR-90 / BR-93 / BR-15 / BR-16** — ordering contract, repair budget, the un-wired strategy chain, and the missing atlas Pieces entry, all unchanged.

## 4. Minor findings

- BR-17 `init.lua:1337` vs `:4339` — same four-line registration, still divergent clobber semantics.
- BR-18 `plan.md:1493-1496`, `1541-1542` — four/two identical `make test-spec` lines.
- BR-29 `cliproxy_conformance_spec.lua:235,254` — `pending()` where five siblings `print("SKIP: …")`.
- BR-35 `keybinding_registry.lua:759` — scope moved `global`→`parley_buffer`; still no `agent_picker` scope, still no `agent_picker_mappings` in `config.lua`.
- BR-71 `float_picker.lua:1705-1715` — two stacked paragraphs saying the same thing.
- BR-87 `plan.md:1356` — "the LEAST healthy candidate" unannotated, despite `plan.md:2159` claiming it was.
- BR-95 `init.lua:4398` — bare `error(...)`, so the operator sees an `init.lua:4398:` prefix.
- BR-96 `cliproxy_recovery_e2e_spec.lua:109` (5-space indent) and `chat_respond_spec.lua:1296-1308` (column-0 block) — both still there.
- Residuals noted on otherwise-addressed findings: `fake_cliproxy:203` claims a duplicate id `CATALOG_V1` does not contain; `refresh_goldens.lua:13` still says "Keep in sync with READONLY_TOOLS in …_golden_spec.lua" after the constant moved to `golden_fixture.lua`; `cliproxy_auth_spec.lua:587`'s title says "least healthy" for a `CULPRIT_RANK` that is not an inverted `HEALTH_RANK`; `atlas/providers/agents.md:5` still lists `Proxy-GPT5.4` and `Claude-Code`, neither of which ships.

## 5. Test coverage notes

Coverage is strong where it was measured and thin exactly where a claim replaced a measurement. Confirmed-good by mutation: the login call site, the repaint identity argument, the arch guard's alias-export matcher, and the declined-refresh invalidation. Confirmed-absent by mutation: the `_write_catalog` success-path flag clear (BR-72) — the one path where the fetch is *accepted* and the store fails has no case. `cliproxy_budget_spec.lua:40-46` asserts ≥5s headroom over a term list that no longer models the path (BR-93), so it is green about a path production does not take. `cliproxy_auth_spec.lua:602`'s `assert.is_not_nil(channel)` still passes for either answer in the all-`missing` case, which is the case BR-90 is about.

## 6. Architectural notes

- **ARCH-DRY — flag.** Good consolidations (`agent_name`, `api_argv`, `CLIPROXY_STRATEGIES`, `golden_fixture.lua`, the single `repaint()`, `ready_port.free_port`). Remaining: the duplicated agent-registration block (BR-17) and five config sites restating what `cliproxy_default_web_search_strategy` derives (BR-15).
- **ARCH-PURE — pass.** `catalog_stale` moved out of the IO shell into `cliproxy_config.lua:339` and is now six unit cases with no clock and no curl; `likeliest_culprit`/`healthiest` are pure and injected into `credential_health_across` as a `choose` argument; `_view_for`/`_providers_without_models`/`_identity` are pure and drive the production path.
- **ARCH-PURPOSE — flag.** The shadow-sweep of the `oauth-model-alias` → catalog replacement passes: `recover` derives, the default config drops it, README and atlas follow, and `pre_query` writes on every path the original covered. The *other* single source introduced this issue does not: `cliproxy_default_web_search_strategy` has exactly one consumer (`build_agent`), while `get_cliproxy_strategy` (`providers.lua:102-129`) never consults it and `config.lua` hand-states `anthropic_tools_route` at five sites — a hand-maintained restatement of the model, i.e. a deferred consumer (BR-15).
- **ARCH-MOCK — pass with one flag.** `fake_cliproxy`'s `/v1beta/models` mirrors `/v1/models` mode-for-mode, the catalog integration specs run the whole stack against it, and `single_source_sweeps_spec.lua:148-162` now guarantees every cliproxy integration spec redirects its data dir. Flag: `fake_cliproxy:203` documents a behaviour ("one id claimed by a second owner") the fixture does not model — an unmeasured assumption inside the double.
- **ARCH-CONSTRAINTS — flag.** The picker envelope is enforced: zero main-thread network, an mtime-memoized ~5 KB read, async stale-gated refresh with a ~30s failure backoff, and a dormancy test that asserts a free port stays free. The recovery envelope is not: serializing the fan-out added up to +3×`CURL_MAX_TIME` for a google-owned model (21s → 27s against a 30s backstop, i.e. 3s headroom under a 5s asserted floor) and `M._repair_budget_sec` gained no term (BR-93).

## 7. Plan revision recommendations

1. **Correct three overstated completion claims** — `plan.md:2256` ("Every stacked doc block is collapsed — 0 remain … checked mechanically"), `plan.md:2159` ("Task 4.1's superseded … phrasing is annotated in place"), and `plan.md:2251-2255` (BR-91/BR-92, which left `resolve_login_provider` tabled as `modified` at `plan.md:39` and referenced as live code at `plan.md:1486`). Per BR-69's own rule, each replacement bullet must name the mutation and the spec that goes red.
2. **Record the BR-15 decision.** Either wire `cliproxy_default_web_search_strategy` into `get_cliproxy_strategy`'s chain, or add a Revisions entry stating that the pinned cliproxyapi agents deliberately declare their own strategy and why the single source does not govern them.
3. **Strike or re-scope the issue's Problem paragraph.** It opens on "pins `claude-opus-4-8` while the proxy advertises `claude-opus-5`, leaving all three Opus agents a model generation behind"; the shipped `config.lua` at HEAD still pins `claude-opus-4-8` at four agent entries. The roster cleanup was deliberately handed back to the operator (`plan.md:2126-2128`), so say so in the issue rather than leaving the motivating complaint reading as delivered.
4. **Annotate Task 4.1 in place** (`plan.md:1356`) with a pointer to the C1/BR-75 revision, which is what round 2 said it had done.

```findings
dispose:
  - id: BR-13
    disposition: addressed
    note: |
      Delimiter rule shipped; magnitude SHAPE cases (20B/70B/32K/8x7B) pin it, not a value.
  - id: BR-14
    disposition: addressed
    note: |
      live_agent_state_spec drives the real refresh_state; register_live_agent is called from _select.
  - id: BR-15
    disposition: not-addressed
    note: |
      get_cliproxy_strategy (providers.lua:102-129) still never consults the new source; config.lua
      hand-states anthropic_tools_route at five sites; no Revisions entry records the decision.
  - id: BR-16
    disposition: not-addressed
    note: |
      atlas/providers/cliproxy-managed.md "## Pieces" (:16-35) still names only cliproxy_config,
      cliproxy and cliproxy_auth; cliproxy_catalog.lua appears in no atlas file (only traceability.yaml).
  - id: BR-17
    disposition: not-addressed
    note: |
      init.lua:1337 `= M.agents[name] or agent` vs :4339 `= agent`; still two copies, still divergent.
  - id: BR-18
    disposition: not-addressed
    note: |
      plan.md:1493-1496 still four identical commands; :1541-1542 two. Rule not applied.
  - id: BR-20
    disposition: addressed
    note: |
      Status honored, declines logged at debug, mtime-memoized cache, providers=nil handled in _view_for.
  - id: BR-21
    disposition: addressed
    note: |
      One `loggable` guard in _providers_without_models; catalog_cached sanitizes rows at the one boundary.
  - id: BR-27
    disposition: addressed
    note: |
      Plan boxes ticked and Log carries M1-M4 entries; the window overlap itself is historical and recorded.
  - id: BR-29
    disposition: not-addressed
    note: |
      is_managed gate, repaint identity and catalog_path mkdir all fixed; cliproxy_conformance_spec.lua:235,254
      still use pending() where five siblings print "SKIP:".
  - id: BR-35
    disposition: not-addressed
    note: |
      Scope moved global -> parley_buffer, still the nearest-wrong value; no agent_picker scope was added
      and config.lua still has no agent_picker_mappings example.
  - id: BR-38
    disposition: addressed
    note: |
      agent_name is tabled; _select moved to Integration points; the sweep is executable.
  - id: BR-39
    disposition: addressed
    note: |
      Guard now counts every "<…" literal with measured allowances (agent_picker 1 / root_dir 4 / system_prompt 5).
  - id: BR-40
    disposition: addressed
    note: |
      One-pass dedupe by id + registered-agent exclusion, pinned by the overlapping-entry case. Residual:
      fake_cliproxy:203 still claims "one id claimed by a second owner" and CATALOG_V1 has no duplicate id.
  - id: BR-41
    disposition: addressed
    note: |
      endpoint_opts() replaces render_opts(); pinned by "does not mint a management key just to refresh".
  - id: BR-45
    disposition: addressed
    note: |
      Spec Component 3 restated with a Revisions entry; the issue file is now inside the arch sweep's doc
      list, though only its table rows are matched — prose backticks stay outside the sweep.
  - id: BR-48
    disposition: addressed
    note: |
      All four exit paths now resolve with M.catalog_cached() or the freshly stored list.
  - id: BR-66
    disposition: addressed
    note: |
      float_picker_spec:1209 title and the `selected` doc comment both state the shipped contract.
  - id: BR-68
    disposition: addressed
    note: |
      Verified by probe: deleting cliproxy.lua:1250 reddens cliproxy_login_spec; dropping repaint's third
      argument reddens picker_items_spec.
  - id: BR-69
    disposition: not-addressed
    note: |
      The two named bullets are now true, but the rule was not adopted and three fresh overstated claims
      shipped: plan.md:2256 ("0 stacked blocks remain"), :2159 ("Task 4.1 annotated in place"), :2251-2255
      (BR-91/92) — all three measurably false at HEAD.
  - id: BR-71
    disposition: not-addressed
    note: |
      float_picker.lua:1705-1715 still carries both paragraphs.
  - id: BR-72
    disposition: not-addressed
    note: |
      MEASURED: re-inserting `_force_stale = false` at the top of _write_catalog leaves cliproxy_catalog_spec
      (20/20) and cliproxy_login_spec (13/13) green — the fix has no test. The write failure is still
      unlogged (cliproxy.lua:1562) and its boolean discarded at :1698.
  - id: BR-73
    disposition: addressed
    note: |
      The guard slices `## Core concepts` to the next `^## ` and _on_login_success has an Integration row.
  - id: BR-74
    disposition: addressed
    note: |
      One repaint() using M._identity; both call sites collapsed.
  - id: BR-78
    disposition: addressed
    note: |
      AGENT/READONLY_TOOLS/FIXTURES/OPENAI_FIXTURES all live in scripts/golden_fixture.lua. Residual: the
      prescribed sweep was not run — refresh_goldens.lua:13 still reads "Keep in sync with READONLY_TOOLS
      in tests/unit/parley_harness_golden_spec.lua", which is now false.
  - id: BR-80
    disposition: not-addressed
    note: |
      MEASURED: two stacked blocks remain. cliproxy.lua:478-499 is credential_health_for_login's docstring
      (@param login/@param cb) stranded above credential_health_across — the exact instance BR-80 named;
      cliproxy.lua:629-650 is a NEW 21-line double docstring on warm_catalog added by this window. The
      recover paragraph at :1346-1349 still sits above its replacement at :1350. The @param-vs-signature
      lint was never written; I wrote it and it fires on :485 on the first run.
  - id: BR-86
    disposition: addressed
    note: |
      The rule is in the plan Notes and the window itself is clean. The tree is still dirty at the boundary
      (config.lua roster deletion, untracked docs/parley.nvim.md), but that is operator-owned and documented
      at plan.md:2126-2128, and *.parley-backup.* is now gitignored.
  - id: BR-87
    disposition: not-addressed
    note: |
      plan.md:1356 still reads "the LEAST healthy candidate is the one that plausibly failed" with no
      annotation; the only "superseded" mentions are at :2159 and :2253, both in Revisions narrative.
  - id: BR-90
    disposition: not-addressed
    note: |
      cliproxy_config.lua:197 still declares the order "sorted"; OWNER_CHANNELS is unchanged, so antigravity
      is still candidates[1] for anthropic/openai/google; cliproxy_auth_spec.lua:602 still asserts only
      is_not_nil(channel) for the all-missing case. channels_for_owner's order IS now pinned by equality,
      which is half the rule.
  - id: BR-91
    disposition: not-addressed
    note: |
      MEASURED: single_source_sweeps_spec.lua:121-124 still greps a bare name. resolve_login_provider was
      deleted this window, plan.md:39 still tables it `modified`, plan.md:1486 still cites it at a file:line,
      and the guard is green only because cliproxy_config_spec.lua:271 names it in a comment — removing that
      mention turns the guard red naming it.
  - id: BR-92
    disposition: addressed
    note: |
      unhealthier deleted; the empty-channels branch now states why it must settle. I ran the enumeration
      over the window's 36 added M.x symbols — only the three `_`-prefixed test seams have no production
      caller.
  - id: BR-93
    disposition: not-addressed
    note: |
      M._repair_budget_sec (cliproxy.lua:360-368) still carries one auth_files term. Shipped constants give
      21s vs a 30s backstop; a google-owned model now costs 4 sequential reads, i.e. 27s, below the 5s floor
      cliproxy_budget_spec.lua:40-46 asserts.
  - id: BR-94
    disposition: addressed
    note: |
      The atlas no longer states an inverted ordering and no longer routes through resolve_login_provider.
      Residual: cliproxy_auth_spec.lua:587's title still says "picks the least healthy".
  - id: BR-95
    disposition: not-addressed
    note: |
      init.lua:4398 is still a bare error(); the seven sibling operator-facing raises use error(msg, 0).
  - id: BR-96
    disposition: not-addressed
    note: |
      cliproxy_recovery_e2e_spec.lua:109 still has a 5-space indent; chat_respond_spec.lua:1296-1308 is still
      de-indented to column 0 inside the enclosing describe.
  - id: BR-97
    disposition: addressed
    note: |
      The sort now states its reason and asserts its precondition. The rule (resolve the default through the
      production accessor) was deliberately declined in a documented comment; the describe title still
      overstates what is measured.
  - id: BR-98
    disposition: addressed
    note: |
      "Eligibility before ranking" and "a replaced single source needs a writer on every path" both landed
      in workshop/lessons.md.
  - id: BR-100
    disposition: addressed
    note: |
      Verified by probe: appending `M._brand_new_seam = catalog_path` to cliproxy.lua now reddens the guard.
```
