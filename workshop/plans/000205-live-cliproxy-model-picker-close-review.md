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

---

## Re-review — 2026-09-01T13:42:45-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 205 — live cliproxy model picker; retire hardcoded model lists |
| repo | parley.nvim |
| issue file | workshop/issues/000205-live-cliproxy-model-picker.md |
| boundary | whole-issue close |
| milestone | — |
| window | 42d72b9d2f12bad462d847d8e5b24876a1a6a63b..2acba1adbdc84d0499da23ebd5ee88a7d2e87535 |
| command | sdlc close --issue 205 |
| reviewer | claude |
| timestamp | 2026-09-01T13:42:45-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The feature is delivered and the code is in good shape: `make test` is green both on the working tree and on the *committed* HEAD tree (I ran it both ways), the pure core is genuinely pure and fixture-driven, the live-catalog path replaces `oauth-model-alias` end to end, and the two Importants the last commit set out to fix (BR-90 preference order, BR-93 budget term) are properly fixed *with* the enumeration and per-owner assertion the rule demanded. What keeps this from SHIP is a three-part pattern this gate exists to catch: (1) the final commit's candidate cap (`MAX_CANDIDATE_CHANNELS = 2`) silently narrows auth diagnosis for google-owned models — it drops `aistudio` and `antigravity` from candidacy before any credential is read, its justifying comment is false for the one owner that motivated it, and nothing exercises the >2-candidate path; (2) BR-72's fix is still unpinned — I moved `_force_stale = false` back to the top of `_write_catalog` and all 20 cliproxy spec files stayed green; and (3) two completion claims are measurably false at HEAD (`031cf82` and plan.md:2255 say "0 stacked doc blocks remain across the three cliproxy modules, checked mechanically" — three remain; plan.md:2159 says Task 4.1 is "annotated in place" — plan.md:1355 is unannotated). Those two claims will be copied into the close record if they aren't struck first.

### 1. Strengths

- **BR-90 was answered as a class, not an instance.** `cliproxy_config.lua:186-191` states the ordering *contract* in prose, `channels_for_owner`'s `@return` declares it (`:203`), and `cliproxy_config_spec.lua:411-421` asserts native-first for **every** owner by iterating the enumeration rather than spot-checking two rows. This is exactly the shape the family escalation asked for.
- **The BR-15 wiring resisted three over-reaches and the tests record each one.** `providers.lua:120-168` documents a five-step precedence, and `cliproxy_catalog_spec.lua:410-519` pins each step separately: a provider-level `none` survives derivation, `openai_search_model` survives for a gpt model, and nothing is invented when nothing is configured. The behaviour change (claude cliproxy agents now default to the anthropic wire) is declared as one in the atlas and plan rather than smuggled in as a DRY cleanup.
- **ARCH-PURE is real here, not asserted.** `cliproxy_catalog.lua` (242 lines, zero IO), `could_have_served`/`likeliest_culprit`/`healthiest` in `cliproxy_auth.lua:204-254`, `catalog_stale` in `cliproxy_config.lua`, and `_view_for`/`_build_items`/`_identity`/`_select` in `agent_picker.lua` are all callable from a unit test with no seams. `_view_for`'s own docstring (`agent_picker.lua:148-152`) names the failure mode that forced the extraction — a spec that re-implemented the dedup and therefore couldn't fail.
- **ARCH-MOCK is satisfied at both ends.** `tests/fixtures/fake_cliproxy` grew `/v1beta/models` *and* `cliproxy_conformance_spec.lua:233-269` checks the fake's model against the real binary, including that the two routes actually join on id.
- **`catalog_cached` sanitizes at one boundary** (`cliproxy.lua:1556-1568`) instead of nil-checking per consumer, and memoizes on mtime so the keystroke path doesn't re-read and re-`mkdir`.

### 2. Critical findings

None.

### 3. Important findings

**I1 — `MAX_CANDIDATE_CHANNELS = 2` drops eligible channels for google-owned models, and its justifying comment is false for that owner** (`lua/parley/cliproxy.lua:33-37`, truncation at `:1376-1378`).

`OWNER_CHANNELS.google = { "gemini-cli", "gemini", "aistudio", "antigravity" }`. The cap truncates from the tail, leaving `{ gemini-cli, gemini }`, so `aistudio` — a first-class channel with its own `CHANNEL_LOGIN` entry (`cliproxy_config.lua:145`) — is never read. An operator whose google credential lives in `aistudio` and expires gets both remaining readings as `missing`; `could_have_served` disqualifies both; `likeliest_culprit` falls through to `readings[1]` (`cliproxy_auth.lua:237-238`) and reports **`gemini-cli`: no credential is loaded** for a credential that exists and failed. That is the #197 wrong-account/wrong-state symptom reached by a fourth route — the one the Done-when ("credential health picks between them rather than the code guessing") forbids. The comment at `:34-36` claims the cap keeps "the NATIVE channel first … with one cross-vendor fallback behind it"; for google it keeps two natives and drops the cross-vendor one entirely, so the sentence is untrue for precisely the owner whose four channels made the multiplier necessary. Nothing tests it: no fixture puts a `google`-owned row through `recover` (`cliproxy_recovery_e2e_spec.lua:131` is the only catalog seed and it is `anthropic`), so deleting `:1376-1378` changes no test outcome, and `cliproxy_budget_spec.lua` only sums the declared table. Fix sketch: don't cap by list position. Either (a) drop `poll_healthy`'s slack or `port_release` so `auth_files = CURL_MAX_TIME * 4` fits the 5s headroom floor, or (b) keep the cap but select *which* candidates survive by login-provider coverage (one per distinct `channel_login`) rather than by index, and correct the comment. Either way add a spec that drives `recover` with a `google`-owned catalog row and asserts the channel actually holding the credential is the one named — that spec must go red when the truncation is removed or reintroduced.

**I2 — BR-72's fix is not pinned by any test; the write failure is still silent and its boolean discarded** (`lua/parley/cliproxy.lua:1579-1596`, caller at `:1746`).

The flag now clears in the right place (`:1592`, after the write), but the rule BR-72 asked for was the enumeration + a guard, and neither landed. Measured this round: moving `_force_stale = false` to the top of `_write_catalog` and deleting the later clear leaves **all 20 files** under `make test-spec SPEC=providers/cliproxy-managed` green (0 failures, 0 errors). The early return at `:1584-1586` logs nothing, and `:1746` discards the boolean, so an unwritable data dir consumes a login's invalidation, stores nothing, and the operator waits out the TTL with no trace anywhere. Fix sketch: `logger.debug` on the `io.open` failure; have the caller honour the `false`; and add a spec that points `_set_data_dir` at a read-only path, calls `invalidate_catalog()`, drives a write, and asserts `catalog_stale()` is still true.

**I3 — three stacked doc blocks remain in `cliproxy.lua`, one documenting parameters the function does not have, while the commit and plan claim zero remain.**

`cliproxy.lua:494-514`: `credential_health_for_login`'s docstring (ending `---@param login` / `---@param cb`) sits directly above `function M.credential_health_across(channels, choose, cb)` — the exact instance BR-80 named four rounds ago; `credential_health_for_login` itself (`:585`) has none. `cliproxy.lua:645-665`: `warm_catalog` carries two full paragraphs saying the same thing. `cliproxy.lua:1356-1371`: `recover`'s superseded "fall back to resolving the model through oauth-model-alias" paragraph still sits above its replacement. **This is the 4th finding in family `docs-insert-orphans-section`.** Do not patch the three sites again — the rule was written down at `workshop/lessons.md:962-964`, restated, and re-broken by the range that appends to that file, so restatement has failed three times. The deliverable is the mechanical check BR-80 specified and the last round wrote and then did not commit: lint any `function M.x(...)` whose immediately-preceding `---@param` block names an identifier absent from the signature, wired into `tests/arch/`. It fires on `:501` on the first run.

**I4 — the plan→code guard now requires an assignment, but the fourth alternative accepts any table-field write anywhere in the tree** (`tests/arch/single_source_sweeps_spec.lua:143`).

The pattern is `(function M\.%s\b|M\.%s *=|local function %s\b|%s *=)`. The first three are definition forms; the fourth, bare `%s *=`, is not, and it is load-bearing today. Measured: a row naming `series` is satisfied by `m.series = type(m.series) …` at `cliproxy.lua:1566`; a row naming `parse` is satisfied by `function M.parse` in the unrelated `lua/parley/drill_in.lua`; the `Model` (record) row is satisfied by `lua/parley/exchange_model.lua`. So deleting `cliproxy_catalog.M.series` leaves the guard green — the drift it exists to catch. The guard also never checks the row's *declared path*, which is why an unrelated module can satisfy it. **This is the 7th finding in family `test-title-overstates-guard`.** The rule that covers all seven: *an agreement check must match the definition form at the declared location, and must be verified by injection in both directions before it is claimed to have teeth.* Fix sketch: drop the bare-`=` alternative, restrict the grep to the `.lua` path named in the same table row, and handle non-function rows (`Model` (record), `agent_picker` live section) by an explicit row marker rather than by loosening the matcher for everything.

**I5 — two completion claims are false at HEAD and will be copied into the close record** (`plan.md:2255-2257`, `plan.md:2158-2159`; commit `031cf82` body).

"Every stacked doc block is collapsed — 0 remain across the three cliproxy modules, checked mechanically" — three remain (I3). "Task 4.1's superseded 'least healthy candidate' phrasing is annotated in place" — `plan.md:1355` still reads "the LEAST healthy candidate is the one that plausibly failed" with no annotation. **This is the 7th finding in family `stated-design-not-implemented`**, and the fifth and sixth overstated claims across three rounds. Do not simply rewrite the two bullets. The rule, already at `workshop/lessons.md:914-925` and violated by the window that added it: *a `## Revisions` bullet or commit body claiming a finding fixed must name the mutation that goes red and the spec that catches it; a claim with neither is a claim about intent, and must be written as one ("attempted", "partially") or omitted.* Making that mechanical is cheap here — the close-gate ledger already records a `disposition` per finding; the plan's Revisions should cite the ledger id and disposition rather than restating the outcome in prose.

### 4. Minor findings

- **BR-17 still open.** `init.lua:4339` (`M.agents[name] = agent`) and `:1337` (`M.agents[name] = M.agents[name] or agent`) are the same four-line registration with divergent clobber rules — a live pick replaces a same-named configured agent for the session but not after a restart. One `M._register_agent(agent)`, one clobber decision.
- **BR-18 still open.** `plan.md:1492-1495` runs `make test-spec SPEC=providers/cliproxy-managed` four identical times and `:1540-1541` twice; the enumeration of what those steps cover is still destroyed. `plan.md:1485-1487` also still cites `resolve_login_provider` at `cliproxy_config.lua:218`, deleted this window.
- **BR-29 residuals.** The two catalog GETs are still chained (`cliproxy.lua:1722-1723`), so the worst case is 2×`CURL_MAX_TIME`, not the stated 2s; `cliproxy_conformance_spec.lua:235,254` still use `pending()` where the file's five siblings `print("SKIP: …")`.
- **BR-35 residual.** The `<C-a>` row moved from `scope = "global"` to `"parley_buffer"` (`keybinding_registry.lua:759`), so it no longer renders under Global — but no `agent_picker` scope was added, so it now renders under **Buffer**, where `<C-a>` is Vim's increment and parley binds nothing. The three sibling finders each have their own standalone scope. `agent_picker_mappings` is also still absent from `config.lua` (`chat_finder_mappings`/`note_finder_mappings`/`issue_finder_mappings` are all there), so the documented `config_key` has no example.
- **BR-71 still open.** `float_picker.lua:1706-1714` — two stacked paragraphs in `update`'s numeric branch, the second explaining the removed `sel_idx` write as if the first weren't there.
- **BR-95 still open.** `init.lua:4398` is a bare `error(...)`; the seven sibling operator-facing raises in `lua/parley/` use `error(msg, 0)`.
- **BR-96 still open.** `cliproxy_recovery_e2e_spec.lua:109` has a stray leading space; `chat_respond_spec.lua:1296-1309` is de-indented to column 0 inside its `describe`.
- **`atlas/providers/agents.md:6`** — the "Default agents" line names `Proxy-GPT5.4` and `Claude-Code`, neither of which exists in `config.lua` at HEAD, in the file this window edited for the roster feature.
- **Plan Core-concepts Integration table has a duplicate row** — `invalidate_catalog / _reset_catalog_clock / _set_failed_attempt_at` appears at both `plan.md:76` and `:82`.
- **`workshop/lessons.md` gained nothing from this round.** BR-90 and BR-93 each produced a crisply reusable rule (a list read as a decision must declare and assert its order; a change adding a repeated step to a budgeted path must add the term in the same change) and both live only in code comments. **This is the 3rd finding in family `lesson-not-recorded`.**
- **`chat_respond_spec.lua:1296-1299`** says the cases "named `ToolSonnet`, which stopped shipping" — `ToolSonnet` ships at `config.lua:317` on the committed tree; the comment describes the operator's uncommitted roster deletion.

### 5. Test coverage notes

Coverage is strong where the issue was reviewed hardest: `cliproxy_catalog_spec` drives every documented `curate` render as an equality keyed by its spec string, `picker_items_spec` covers overlap/unknown-provider/ownerless rendering through the production `_view_for`, `live_agent_state_spec` covers the restart restore, and `providers_pre_query_spec` + `cliproxy_catalog_spec.lua:425-478` pin the warm at the seam production actually takes for **both** `manage` modes. The gaps are all at the newest edges: the candidate cap (I1), the catalog write failure (I2), and the arch guard's own teeth (I4) — i.e. the three things added or last touched in the final two commits, each of which is the sort of guard that passes every suite while doing nothing.

### 6. Architectural notes

- **ARCH-DRY — flag (minor).** `agent_name`, `cliproxy_route`, `CLIPROXY_STRATEGIES`, `endpoint_opts` and `golden_fixture.lua` are all proper consolidations with guards. The one live duplication is BR-17's two registration blocks, which already disagree.
- **ARCH-PURE — pass.** See Strengths. No test in the diff needs a mock to run a "pure" entity.
- **ARCH-PURPOSE — flag.** The purpose is delivered, but I1 is the easy-win pattern in miniature: a budget problem was closed by capping the list rather than by re-deriving what the path must still cover, and the capped-away members are exactly the ones the Done-when ("credential health picks between them") promised would be read.
- **ARCH-MOCK — pass.** Stateful process fake behind the same seam, plus a live conformance check that compares the fake's `/v1beta/models` shape and the join against the real binary.
- **ARCH-CONSTRAINTS — flag.** The declared envelope is now internally consistent (`auth_files = CURL_MAX_TIME * MAX_CANDIDATE_CHANNELS`, headroom 7s of 30s), but its key premise — that the code truncates to 2 — is enforced at one line no test reaches (I1), and the picker's refresh still chains its two GETs.

### 7. Plan revision recommendations

1. **Strike the two false completion claims.** `plan.md:2255-2257` ("0 remain across the three cliproxy modules, checked mechanically") and `plan.md:2158-2159` ("annotated in place") — replace each with what is actually true, citing the ledger disposition rather than restating an outcome.
2. **Annotate Task 4.1 in place.** `plan.md:1355` still presents "the LEAST healthy candidate is the one that plausibly failed" as the design; add the inline pointer to the superseding C1/BR-75 revision so a reader arriving at Task 4.1 first doesn't get the rule the code was fixed to stop implementing.
3. **Add a `## Revisions` entry for the candidate cap.** `MAX_CANDIDATE_CHANNELS = 2` is a behavioural narrowing of M4's diagnosis contract that no plan section describes; it must say which channels it drops per owner and why that is acceptable (or record I1's fix).
4. **Fix the referent rot in the M4 steps.** `plan.md:1485-1487` cites `resolve_login_provider` at a file:line deleted this window; `plan.md:1492-1495`/`:1540-1541` collapse distinct spec keys into identical commands — emit the command once and keep the enumeration of what it covers in prose.
5. **De-duplicate the Integration table** (`plan.md:76` and `:82` are the same row).

```findings
dispose:
  - id: BR-15
    disposition: addressed
    note: |
      Five config sites dropped; get_cliproxy_strategy consults the source as a CORRECTION step with a documented five-step precedence and four new spec cases.
  - id: BR-16
    disposition: addressed
    note: |
      atlas/providers/cliproxy-managed.md:66-67 now names cliproxy_catalog.lua as the pure core; residual, the `## Pieces` inventory at :16-34 still lists only three modules.
  - id: BR-17
    disposition: not-addressed
    note: |
      init.lua:4339 and :1337 are still the same four-line registration with divergent clobber rules; no shared helper.
  - id: BR-18
    disposition: not-addressed
    note: |
      plan.md:1492-1495 still runs four identical commands, :1540-1541 two; no prose enumeration of what each step covers.
  - id: BR-29
    disposition: not-addressed
    note: |
      is_managed gate, repaint identity and the catalog_path mkdir are fixed; the chained GETs (cliproxy.lua:1722-1723) and pending() vs SKIP (conformance_spec:235,254) remain.
  - id: BR-35
    disposition: not-addressed
    note: |
      scope moved global to parley_buffer, so it renders under Buffer rather than Global; no agent_picker scope added and agent_picker_mappings is still absent from config.lua.
  - id: BR-69
    disposition: not-addressed
    note: |
      Two claims false at HEAD: plan.md:2255-2257 "0 stacked blocks remain, checked mechanically" (three remain) and :2158-2159 "annotated in place" (plan.md:1355 unannotated).
  - id: BR-71
    disposition: not-addressed
    note: |
      float_picker.lua:1706-1714 still carries both paragraphs.
  - id: BR-72
    disposition: not-addressed
    note: |
      MEASURED: moving `_force_stale = false` back to the top of _write_catalog leaves all 20 files under SPEC=providers/cliproxy-managed green. Write failure still unlogged (:1584) and the boolean still discarded at :1746.
  - id: BR-80
    disposition: not-addressed
    note: |
      MEASURED at HEAD: cliproxy.lua:494-514 (@param login/@param cb above credential_health_across), :645-665 (warm_catalog doubled), :1356-1371 (recover's superseded paragraph). The @param-vs-signature lint was not written.
  - id: BR-87
    disposition: not-addressed
    note: |
      plan.md:1355 still reads "the LEAST healthy candidate is the one that plausibly failed" with no annotation.
  - id: BR-90
    disposition: addressed
    note: |
      Rule stated at cliproxy_config.lua:186-191, contract in the @return at :203, and cliproxy_config_spec.lua:411-421 asserts native-first for every owner by iterating the enumeration.
  - id: BR-91
    disposition: not-addressed
    note: |
      The bare-name grep is gone and the stale resolve_login_provider row was caught, but the fourth alternative `%s *=` is not a definition form: `series` is satisfied by `m.series =` in cliproxy.lua:1566, `parse` by drill_in.lua, `Model` by exchange_model.lua. The guard also ignores the row's declared path.
  - id: BR-93
    disposition: addressed
    note: |
      _repair_budget_sec carries CURL_MAX_TIME * MAX_CANDIDATE_CHANNELS and recover truncates; budget spec green with 7s headroom. See the new finding on what the cap costs and that it is untested.
  - id: BR-95
    disposition: not-addressed
    note: |
      init.lua:4398 is still a bare error(); the seven sibling operator-facing raises use error(msg, 0).
  - id: BR-96
    disposition: not-addressed
    note: |
      cliproxy_recovery_e2e_spec.lua:109 still has the stray leading space; chat_respond_spec.lua:1296-1309 is still at column 0 inside the describe.
findings:
  - id: new
    severity: Important
    family: envelope-not-rederived
    title: |
      MAX_CANDIDATE_CHANNELS drops aistudio and antigravity from google diagnosis, its justifying comment is false for that owner, and no test reaches the path
    detail: |
      cliproxy.lua:1376-1378 truncates the preference list from the tail, so
      OWNER_CHANNELS.google collapses to { gemini-cli, gemini }. An operator whose
      google credential lives in aistudio and expires gets both survivors as
      `missing`, could_have_served disqualifies both, and likeliest_culprit falls
      through to readings[1] (cliproxy_auth.lua:237) reporting "gemini-cli: no
      credential is loaded" for a credential that exists and failed — the wrong-state
      diagnosis M4's Done-when forbids. The comment at :34-36 justifies the constant as
      "the NATIVE channel first, with one cross-vendor fallback behind it", which is
      untrue for google, the only owner with more than two natives and the one whose
      four channels motivated the multiplier. No fixture drives a google-owned row
      through recover (cliproxy_recovery_e2e_spec.lua:131 is anthropic), so deleting
      the truncation changes no test outcome and cliproxy_budget_spec only sums the
      declared table. This is the 2nd finding in family `envelope-not-rederived`; the
      rule: when a budget is balanced by capping a list that other decisions read, the
      cap is a behavioural change and needs its own test and its own revision entry,
      not just a term in the arithmetic.
  - id: new
    severity: Minor
    family: lesson-not-recorded
    title: |
      The close round's two Important findings each produced a reusable rule and workshop/lessons.md gained neither
    detail: |
      BR-90 ("a list whose order is read as a decision must declare that order as its
      contract and assert it") and BR-93 ("a change that adds a repeated step to a
      budgeted path must add the term in the same change") are both stated only in code
      comments; commit 2acba1a does not touch workshop/lessons.md. This is the 3rd
      finding in family `lesson-not-recorded` (AGENTS.md section 4).
  - id: new
    severity: Minor
    family: atlas-not-updated-for-new-surface
    title: |
      atlas/providers/agents.md:6 still names Proxy-GPT5.4 and Claude-Code, neither of which exists in config.lua at HEAD
    detail: |
      The same file gained fourteen lines this window for the live-model section, so the
      stale default-agent inventory directly above it was read past. This is the 5th
      finding in family `atlas-not-updated-for-new-surface`; the rule: when a diff edits
      an atlas file, the surrounding claims in that file are in scope for the same
      verification as the added ones.
```

---

## Re-review — 2026-09-01T13:44:54-07:00 (unknown)

| field | value |
|-------|-------|
| issue | 205 — live cliproxy model picker; retire hardcoded model lists |
| repo | parley.nvim |
| issue file | workshop/issues/000205-live-cliproxy-model-picker.md |
| boundary | whole-issue close |
| milestone | — |
| window | 42d72b9d2f12bad462d847d8e5b24876a1a6a63b..404f5e8219bd5aa4c8db48da4beed34b84f7e5af |
| command | sdlc close --issue 205 |
| reviewer | claude |
| timestamp | 2026-09-01T13:44:54-07:00 |
| verdict | unknown |

## Review

Failed to authenticate. API Error: 401 OAuth access token has been revoked.

---

## Re-review — 2026-09-01T18:08:46-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 205 — live cliproxy model picker; retire hardcoded model lists |
| repo | parley.nvim |
| issue file | workshop/issues/000205-live-cliproxy-model-picker.md |
| boundary | whole-issue close |
| milestone | — |
| window | 42d72b9d2f12bad462d847d8e5b24876a1a6a63b..404f5e8219bd5aa4c8db48da4beed34b84f7e5af |
| command | sdlc close --issue 205 |
| reviewer | claude |
| timestamp | 2026-09-01T18:08:46-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The feature is delivered and the gate is green: `make test` passes at a clean HEAD (lint 0/0 across 345 files, every unit/integration/arch spec PASS — I stashed the operator's local worktree edits, ran it, and restored), and every `## Done when` line is satisfied — `oauth-model-alias` is gone from `config.lua:154-174`, live rows come from the catalog, `<C-a>` expands it, a pick persists via `_state.live_agent`, `(logged out)` rows launch the login, and `fetch_catalog` never routes through `ensure_running`. This round's two commits are both real fixes: `bound_candidates` (`cliproxy_config.lua:211`) keeps the native channel *and* the re-server with four unit cases pinning it, and `OWNER_CHANNELS` is preference-ordered with a per-owner assertion. What stops SHIP is not a correctness bug but the gate's own honesty: the plan's `## Revisions` asserts that BR-72/BR-80/BR-91 are "verified fixed at HEAD by direct measurement," and two of those three are not — BR-80's `recover` half is untouched at `cliproxy.lua:1361-1365` (and this window added a *new* stacked paragraph at `cliproxy.lua:28-30`), and BR-72's fix is unpinned, which I confirmed by reverting it and watching the whole `providers/cliproxy-managed` mapping stay green (50/50, 0 failures). Eleven prior findings remain open, three families are repeating without their rules reaching `lessons.md`, and one new Important gap exists in the single source the issue exists to establish.

## 1. Strengths

- **`bound_candidates` is the right shape for the fix it answers** (`cliproxy_config.lua:211-228`). The choice was pulled into the pure module rather than inlined at `cliproxy.lua:1378`, so the head+tail rule is testable without the recovery path — and `cliproxy_config_spec.lua:428-455` pins it four ways, including a per-owner loop that fails if any owner loses its native channel or its re-server. Reverting to a tail trim genuinely goes red.
- **`likeliest_culprit` / `could_have_served` finally separate eligibility from ranking** (`cliproxy_auth.lua:178-206`). Two explicit orderings with the reasoning for *why* `missing`/`disabled`/`unknown` are absent, ties resolved by declared order for reproducibility, and both reducers pure and injected into one shared fan-out. This is the ARCH-PURE win of the issue.
- **ARCH-MOCK is properly closed.** `cliproxy_conformance_spec.lua:233-268` runs the *real* binary against `/v1beta/models` and asserts the `models/<id>` prefix that `parse()` joins on, plus a case that joins both live routes and requires at least one row to pick up a `displayName`. That is exactly the drift a fixture-plus-fake pair cannot catch by itself.
- **The picker's coordinate-space contract is now documented where the caller reads it** (`atlas/ui/pickers.md:101-120`), and `update()`'s `next_selection` resolves identity-first in one place.
- **`.gitignore:44-47`** closes BR-57 with the reason recorded inline.

## 2. Critical findings

None.

## 3. Important findings

**a. The derived web-search strategy is unreachable for a string `model` config** — `lua/parley/providers.lua:151`, `lua/parley/tools/wire.lua:103`.

`config.lua:206` documents `model` as "string with model name or table with model name and parameters." The derivation step is gated on `type(model_config) == "table"`, and `wire.lua:103` passes `type(model) == "table" and model or nil` — so an agent written `{ provider = "cliproxyapi", model = "claude-opus-5" }` never consults `cliproxy_default_web_search_strategy`, falls to the shipped `openai_tools_route` default (`config.lua:101`), and **cannot override it**, because a string model config has nowhere to put `web_search_strategy`. With web search on it ships the `{type="web_search"}` payload that this issue's own measurement says returns an empty completion for claude. This is the 7th finding in family `single-source-not-enforced`. Per the escalation rule, do not patch the two sites — the rule is: *a derivation keyed on a model NAME must accept every documented shape that carries a model name*; write the enumeration of `model_config` shapes the config accepts, and make the resolver normalize once at its entry rather than type-guarding at each consumer.

**b. BR-72's fix is real but unpinned, and the write failure is still silent** — `lua/parley/cliproxy.lua:1579-1596`.

The clear is correctly placed after the write now. But I verified by reverting: moving `_force_stale = false` back above `vim.fn.mkdir` leaves `make test-spec SPEC=providers/cliproxy-managed` at 50/50, 0 failures — no spec drives `io.open` to fail. The finding also asked for the failure to be logged; `:1583` still returns `false` with no `logger`, and the production caller at `:1758` discards the boolean.

**c. The plan's `## Revisions` again claims completion the tree does not show** — `workshop/plans/000205-live-cliproxy-model-picker-plan.md:2293-2297`. Detail under BR-69 below.

## 4. Minor findings

- `cliproxy.lua:28-30` — a superseded comment paragraph stacked directly above its replacement, and it states the **old alphabetical** channel order (`aistudio, antigravity, gemini, gemini-cli`) that the same commit pair replaced with preference order. The file now documents both orders.
- `cliproxy.lua:371-375` — `_repair_budget_sec`'s justification still says "a google-owned model has four candidate channels… while the code issues four reads"; the cap made it two, one commit later.
- `providers.lua:200-207` — `M.cliproxy_strategy`'s public docstring still describes a two-step chain ("falls back to module-global config") after the resolver grew the family-correction step.
- `tests/arch/single_source_sweeps_spec.lua:145` — the "definition, not a mention" pattern includes a bare `%s *=` alternative, which also matches `name ==` and any table-field assignment. It caught the real drift, but it is looser than the comment claims. (9th in family `test-title-overstates-guard` — the rule, not this instance: an agreement check's matcher must be asserted against a *deliberately planted* false positive, not only a false negative.)
- `atlas/providers/cliproxy-managed.md:66` — the new three-module paragraph was inserted between the `## Model catalog (#205)` heading and that section's own opening paragraph, leaving a doubled blank line at `:71`.

## 5. Test coverage notes

- Coverage of the pure core is strong: `cliproxy_catalog_spec` derives its `curate` cases from a table keyed by the documented spec string, so a Spec row cannot ship without an equality assertion; `catalog_stale` is six pure cases with no clock or seam.
- The new derivation has four describe blocks covering precedence, correction-not-replacement, and override — good.
- Gaps, in priority order: (1) no test drives `_write_catalog` through a failing `io.open`, so BR-72's fix is revertible green (measured); (2) no fixture drives a **string** `model` config through `cliproxyapi.format_payload`, which is why finding 3a is invisible to the suite; (3) `bound_candidates` is pinned at the callee only — no fixture drives a google-owned row through `recover`, so deleting the call at `cliproxy.lua:1378` changes no test outcome (the BR-68 shape, though the unit pin is what the finding asked for).

## 6. Architectural notes

- **ARCH-DRY — flag.** The agent-registration block is still copy-pasted with divergent clobber semantics (`init.lua:4339` vs `:1337`); see BR-17. Everything else consolidated well this window (`golden_fixture.lua`, `ready_port.lua`, `CLIPROXY_STRATEGIES`, `credential_health_across`).
- **ARCH-PURE — pass.** `cliproxy_catalog.lua` and `cliproxy_config.lua` hold parse/rank/curate/`catalog_stale`/`likeliest_culprit`/`healthiest`/`bound_candidates` as pure functions tested without IO; `cliproxy.lua` is the shell. The one ambient read (`get_cliproxy_strategy` → `parley.dispatcher.providers`) is documented as deliberate and is the reason consumers must not re-implement the fallback.
- **ARCH-PURPOSE — flag.** The shadow-sweep over `cliproxy_default_web_search_strategy` finds one consumer shape that still cannot derive (finding 3a). Separately, three families are being answered instance-by-instance again this round rather than by the rule they imply.
- **ARCH-MOCK — pass.** Stateful fake behind the same seam, plus live conformance for both catalog routes and their join.
- **ARCH-CONSTRAINTS — flag.** The two catalog GETs are still chained (`cliproxy.lua:1722-1723`), so picker-open worst case is 2×`CURL_MAX_TIME` = 4s, not the 2s the plan states. The budget arithmetic itself is now sound: `auth_files = CURL_MAX_TIME * MAX_CANDIDATE_CHANNELS` matches the ≤2 sequential reads `credential_health_across_or_one` issues, and `credential_health_for_login`'s unbounded fan-out sits after a 180s interactive login, outside the backstop — so no budget term is missing.

## 7. Plan revision recommendations

1. Correct `plan.md:2293-2297`: BR-80 is **not** fixed at HEAD, and the "zero stacked doc blocks" measurement was scoped to `---@param` blocks only, which is why it missed `recover`'s and `float_picker`'s plain-comment stacks. State which half of BR-72 is pinned (none of it) and which is not.
2. Annotate `plan.md:1354-1356` in place — "the LEAST healthy candidate is the one that plausibly failed" is the rule the code was fixed to stop implementing (BR-87).
3. Annotate or strike `plan.md:1335` and `:1483-1485`, which still table and describe `resolve_login_provider` as modified; it was deleted.
4. Reconcile `plan.md:1548` (`git add lua/parley/config.lua`) with the Note at `:1624` forbidding sweeping the operator's `config.lua` cleanup — the recipe stages exactly the file the Note protects.

```findings
dispose:
  - id: BR-17
    disposition: not-addressed
    note: |
      init.lua:4339 `M.agents[agent.name] = agent` vs :1337 `= M.agents[agent.name] or agent`; still two copies, still divergent.
  - id: BR-18
    disposition: not-addressed
    note: |
      plan.md:1492-1495 still four identical commands, :1540-1541 two; no prose enumeration of what the one key covers.
  - id: BR-29
    disposition: not-addressed
    note: |
      is_managed gate and catalog_path mkdir are fixed; the chained 2x CURL_MAX_TIME and cliproxy_conformance_spec.lua:235,254 pending()-vs-SKIP remain.
  - id: BR-35
    disposition: not-addressed
    note: |
      scope moved global -> parley_buffer (keybinding_registry.lua:759), still the nearest wrong bucket — no agent_picker scope/label/display-order added, and config.lua still has no agent_picker_mappings.
  - id: BR-69
    disposition: not-addressed
    note: |
      7th in family. plan.md:2293-2297 asserts BR-80 "verified fixed at HEAD" while cliproxy.lua:1361-1365 is untouched; the BR-72 bullet names neither mutation nor spec.
  - id: BR-71
    disposition: not-addressed
    note: |
      float_picker.lua:1706-1715 still carries both stacked paragraphs.
  - id: BR-72
    disposition: not-addressed
    note: |
      Clear is correctly placed, but measured: reverting it to the top of _write_catalog leaves providers/cliproxy-managed at 50/50, 0 failures. Write failure still unlogged; boolean discarded at cliproxy.lua:1758.
  - id: BR-80
    disposition: not-addressed
    note: |
      The recover half named in the finding is unfixed at cliproxy.lua:1361-1365, and cliproxy.lua:28-30 added a new instance in the same window.
  - id: BR-86
    disposition: not-addressed
    note: |
      Worktree at the close boundary again carries an uncommitted 211-line config.lua roster deletion plus untracked docs/parley.nvim.md; plan.md:1548 stages that exact file wholesale, contradicting the Note at :1624.
  - id: BR-87
    disposition: not-addressed
    note: |
      plan.md:1354-1356 still unannotated.
  - id: BR-91
    disposition: addressed
    note: |
      single_source_sweeps_spec.lua:141-149 requires a definition form; the cliproxy_config_spec.lua:271 comment no longer satisfies it.
  - id: BR-95
    disposition: not-addressed
    note: |
      init.lua:4398 still bare error(); the named sweep still finds 6 more prose raises (tools/init.lua:62,104,147; tools/wire.lua:126,140; timezone_diagnostics.lua:90).
  - id: BR-96
    disposition: not-addressed
    note: |
      Both regressions present: cliproxy_recovery_e2e_spec.lua:109 stray leading space; chat_respond_spec.lua:1295-1308 at column 0.
  - id: BR-101
    disposition: addressed
    note: |
      bound_candidates keeps head+tail, lives in the pure module, and cliproxy_config_spec.lua:428-455 pins it four ways including per-owner.
  - id: BR-102
    disposition: not-addressed
    note: |
      lessons.md untouched since 031cf82; commits 2acba1a and 404f5e8 recorded none of the BR-90, BR-93 or BR-101 rules.
  - id: BR-103
    disposition: not-addressed
    note: |
      atlas/providers/agents.md:6 still lists Proxy-GPT5.4 and Claude-Code; neither is in config.lua at HEAD.
findings:
  - id: new
    severity: Important
    family: single-source-not-enforced
    title: |
      The derived web-search strategy never reaches a string `model` config, and that shape cannot override it either
    detail: |
      This is the 7th finding in family `single-source-not-enforced`. Do NOT fix the
      two sites. providers.lua:151 gates derivation on `type(model_config) == "table"`
      and tools/wire.lua:103 passes `type(model) == "table" and model or nil`, while
      config.lua:206 documents `model` as "string with model name or table". So
      `{ provider = "cliproxyapi", model = "claude-opus-5" }` falls to the shipped
      `openai_tools_route` default (config.lua:101) and ships the `{type="web_search"}`
      payload this issue measured as returning an empty completion for claude — with no
      override available, since a string cannot carry `web_search_strategy`. The rule:
      a derivation keyed on a model NAME must accept every documented shape that
      carries one; normalize `model_config` once at the resolver's entry and enumerate
      the accepted shapes, instead of type-guarding at each consumer.
  - id: new
    severity: Minor
    family: docs-insert-orphans-section
    title: |
      Two new superseded comment paragraphs shipped this window, and one restates the channel order the same commit pair replaced
    detail: |
      This is the 4th finding in family `docs-insert-orphans-section`. Do NOT fix the
      two sites. cliproxy.lua:28-30 sits directly above its replacement at :31-37 and
      states the OLD alphabetical order (aistudio, antigravity, gemini, gemini-cli)
      that 2acba1a changed to preference order, so the file documents both;
      cliproxy.lua:371-375 still justifies the budget with "the code issues four reads"
      after 404f5e8 capped it at two. BR-80's stated remedy — lint `---@param` blocks
      naming absent identifiers — is why this recurred: both new instances are plain
      `--` comment stacks and neither precedes a function. The rule the lint must
      express: flag any run of two or more comment paragraphs whose opening clauses
      restate the same subject, wherever it sits, not only in `---@param` position.
  - id: new
    severity: Minor
    family: test-title-overstates-guard
    title: |
      The plan-to-code guard's "definition, not a mention" pattern includes a bare `%s *=` alternative that also matches comparisons and table fields
    detail: |
      This is the 9th finding in family `test-title-overstates-guard`. Do NOT fix the
      pattern in isolation. single_source_sweeps_spec.lua:145 builds
      `(function M\.x\b|M\.x *=|local function x\b|x *=)`; the last alternative matches
      `x == y`, `t.x = 1` and `local x = 1`, so the guard is weaker than the comment
      above it claims. It did catch the real drift, which is exactly the trap. The
      rule: an agreement check's matcher must be asserted against a deliberately
      planted FALSE POSITIVE — a table row whose only tree occurrence is a mention —
      not only against a planted false negative.
```

---

## Re-review — 2026-09-01T18:44:52-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 205 — live cliproxy model picker; retire hardcoded model lists |
| repo | parley.nvim |
| issue file | workshop/issues/000205-live-cliproxy-model-picker.md |
| boundary | whole-issue close |
| milestone | — |
| window | 42d72b9d2f12bad462d847d8e5b24876a1a6a63b..56f0df3b35521a39ce20a4b968865301be9ef39d |
| command | sdlc close --issue 205 |
| reviewer | claude |
| timestamp | 2026-09-01T18:44:52-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The feature is delivered and evidenced end to end: the picker builds a live section from cliproxy's own catalog with no model named in `config.lua`, a pick registers a tool-enabled agent that survives restart, `(logged out)` rows launch their login, `oauth-model-alias` is retired, and the full suite is green at HEAD (`make test`, exit 0, 193 specs — verified in this session). Of the 17 open findings, 11 are genuinely addressed and I mutation-verified two of them (BR-72's `_force_stale` placement reddens `cliproxy_catalog_spec` when reverted; BR-104's `as_model_table` normalization reddens two unit cases). What blocks a clean SHIP is that the close bundle's own fixes repeated the two patterns the ledger has been tracking longest: BR-104's fix normalized the resolver but left two enumerable sibling consumers type-guarding in the same file — and one of them, `has_feature`, **regressed** as a direct result (measured: `has_feature("cliproxyapi","web_search","claude-opus-5")` was `true` before commit 6cda59a and is `false` after, while the table form stays `true`); and the `tools/wire.lua` half of that same fix is unpinned — I reverted it and ran the **entire** suite, which stayed green. Separately, BR-80's original site is still in the tree and the fix commits added two more instances of its family.

## 1. Strengths

- **`lua/parley/cliproxy_catalog.lua`** is a genuinely pure core: `parse`/`series`/`rank_key`/`curate`/`build_agent` are deterministic, unit-tested against fixtures captured from a real proxy, and need no mocks to run (ARCH-PURE). `rank_key`'s two disjoint bands with the `-1e9` floor, and the delimiter rule that stops "120B" reading as a version, are the right generalizations rather than threshold patches.
- **`tests/integration/cliproxy_catalog_spec.lua:493-521`** is a model of a discriminating test: it explains *why* the cache must be fresh first (both `_force_stale` placements say "stale" otherwise) — and it does discriminate; I reverted the fix and it went red alone.
- **`tests/arch/single_source_sweeps_spec.lua:41-58`** extracts `definition_pattern` and drives it through real `grep -E` over synthetic text, with four planted false positives. This is exactly what BR-106 asked for, and it is the first guard on this issue that can be shown to *reject*.
- **`lua/parley/cliproxy.lua:1688-1760`** — every exit of `fetch_catalog` resolves exactly once, declined branches resolve with `catalog_cached()` rather than the parse they refused to store, and the `vim.system` *launch* is guarded, not just its callbacks. The `classify`-based write gate reusing the existing single source (ARCH-DRY) is the right call over the three weaker gates the comment enumerates.
- **`workshop/lessons.md:1037-1116`** finally converts six review rounds into stated rules with their measured prevalence, and `atlas/providers/agents.md:6-11` stops restating `config.lua`'s roster — the correct response to a list that drifted three times.

## 2. Critical findings

None.

## 3. Important findings

**(a) `lua/parley/providers.lua:1359` — the string/table disagreement moved rather than closed, and `has_feature` regressed.** `get_cliproxy_strategy` normalizes both documented shapes now, but `has_feature` (:1359) and `cliproxyapi.format_payload` (:1106) still do `type(model_config) == "table" and model_config.model or nil`. Measured at HEAD vs. with `as_model_table` reverted:

| shape | `cliproxy_strategy` | `has_feature web_search` (HEAD) | (pre-fix) |
|---|---|---|---|
| `"claude-opus-5"` | `anthropic_tools_route` | **false** | true |
| `{model="claude-opus-5"}` | `anthropic_tools_route` | true | true |

Fix sketch: hoist `as_model_table` to a module-level normalizer and route `:1106` and `:1359` through it (`local model_name = (as_model_table(model_config) or {}).model`), then extend the existing `"treats the two shapes identically"` case to `has_feature` and `cliproxy_route`.

**(b) `lua/parley/tools/wire.lua:107` — the production half of the BR-104 fix has no test.** The unit cases assert `providers.cliproxy_strategy` directly; nothing asserts `wire.resolve`/`name_for` for a bare string. Fix sketch: add `assert.equals("anthropic", wire.name_for("cliproxyapi", "claude-opus-5"))` beside the existing shape cases — one line, and it reddens on revert.

**(c) `lua/parley/cliproxy.lua:496-504` — BR-80's original site is still live**, plus two new instances the fix commits added (`init.lua:1240`, `init.lua:4346`). Detail in the dispositions below.

## 4. Minor findings

- `lua/parley/init.lua:4410` — still a bare `error(...)`; the operator sees an `init.lua:4410:` prefix. `error(msg, 0)` is the one-token fix (BR-95).
- `lua/parley/keybinding_registry.lua:759` — scope moved `global` → `parley_buffer`, still not an `agent_picker` scope; `agent_picker_mappings` is still absent from `config.lua` (BR-35).
- `workshop/plans/…-plan.md:1502-1506` and `:1551-1552` — the same command still emitted 4× and 2× (BR-18).
- `tests/integration/chat_respond_spec.lua:1309` — `local function open_simple_chat` still at column 0; base had it at 4 (BR-96).
- `tests/integration/cliproxy_conformance_spec.lua:235,254` — `pending()` where five siblings print `SKIP:` (BR-29).
- `atlas/providers/agents.md:30` uses `ToolSonnet` as a badge example three lines after naming it as an agent that stopped shipping. Cosmetic; noting only because the same file's fix was about exactly that.

## 5. Test coverage notes

Coverage is strong where it was weak in earlier rounds: `_view_for`'s dedupe, `_select`'s three branches, the restart restore, `update`'s third argument at the real `<C-a>` closure, `bound_candidates` per-owner, and the write-failure path are all pinned at the production site now. The one gap is finding (b): the newest fix reverted to pinning the callee instead of the call site — the BR-68 rule, re-broken by the commit that closed the round which restated it.

## 6. Architectural notes

- **ARCH-DRY — flag.** `providers.lua`/`wire.lua` now hold four spellings of "get the model name out of a model config" (`as_model_table` :133, `:1106`, `:1359`, `wire.lua:102`). One normalizer, called at each entry.
- **ARCH-PURE — pass.** Business logic (`catalog_stale`, `bound_candidates`, `likeliest_culprit`, `curate`, `_view_for`) is out of the IO shell and injected; `cliproxy.lua` is thin around it.
- **ARCH-PURPOSE — flag.** Two findings this round were answered at the sites they named while enumerable siblings of the same class stayed in the tree (a, c). The issue's own purpose is fully delivered.
- **ARCH-MOCK — pass.** `fake_cliproxy` models both model routes statefully, integration specs run the stack against it through the same seam production uses, and `cliproxy_conformance_spec` is the live drift check. Minor: two of its cases report skips differently from the other five.
- **ARCH-CONSTRAINTS — pass.** Envelope declared and enforced — synchronous UI path reads ~5 KB of disk and no network; refresh is async with `--max-time 2`, one in flight, 600 s TTL, 30 s failure backoff; `_repair_budget_sec` derives from `CURL_MAX_TIME` × `MAX_CANDIDATE_CHANNELS` and `cliproxy_budget_spec` asserts it fits under the dispatcher's backstop.

## 7. Plan revision recommendations

- A `## Revisions` entry stating that BR-104's fix normalized the resolver but **not** its two sibling consumers, naming the measured `has_feature` flip (true → false for the string shape) as a regression the fix introduced, and naming the mutation that proves the wire half is unpinned ("revert `wire.lua:107` → full suite green").
- An entry correcting the round-30 bundle's BR-80 claim: `credential_health_across` still carries an orphaned `@param login`/`@param cb` block, and `superseded_comment_spec` cannot see it because `is_annotation` filters `@`-bearing paragraphs out. The `---@param`-vs-signature lint BR-80 asked for is complementary to the verbatim-span guard, not superseded by it.
- An entry recording BR-95 as a scoped decision that did **not** fix its own site (the source prefix is still emitted), so the next round does not read it as closed.

```findings
dispose:
  - id: BR-17
    disposition: addressed
    note: |
      adopt_agent (init.lua:1247) is the one writer; both paths route through it. The chosen clobber rule itself is unpinned, but the DRY ask is delivered.
  - id: BR-18
    disposition: not-addressed
    note: |
      plan.md:1502-1506 still emits the identical command four times and :1551-1552 twice; the "emit once, enumerate in prose" rule was not applied.
  - id: BR-29
    disposition: not-addressed
    note: |
      is_managed gate and repaint-under-cursor fixed; cliproxy_conformance_spec.lua:235,254 still use pending() where five siblings print "SKIP:".
  - id: BR-35
    disposition: not-addressed
    note: |
      keybinding_registry.lua:759 moved global -> parley_buffer, which is an ancestor of chat, so the row still renders in a chat buffer's help under "Buffer" where <C-a> is Vim's increment. No agent_picker scope was added and agent_picker_mappings is still absent from config.lua.
  - id: BR-69
    disposition: addressed
    note: |
      Both named claims now match the code: cliproxy.lua:1726/1744/1757 resolve declined branches with catalog_cached(), and the BR-58 call-site test reddens on deletion.
  - id: BR-71
    disposition: addressed
    note: |
      float_picker.lua:1706-1710 is one paragraph now.
  - id: BR-72
    disposition: addressed
    note: |
      Mutation-verified: moving _force_stale = false back above io.open reddens "keeps an invalidation owed when the write fails" and nothing else. Write failure logs and the boolean is honoured at cliproxy.lua:1739.
  - id: BR-80
    disposition: not-addressed
    note: |
      cliproxy.lua:496-504 still stacks credential_health_for_login's docstring (ending @param login / @param cb) above credential_health_across(channels, choose, cb) at :517, and that function has a second block of its own. The @param prefer half is gone; this half is the site the finding opened with. Two NEW instances shipped in the fix commits: init.lua:1240 leaves refresh_state's "@param update" orphaned above adopt_agent's block (refresh_state at :1259 now has no doc), and init.lua:4346-4348 inserts a blank line between register_live_agent's @param model and its definition. superseded_comment_spec cannot see any of the three: is_annotation() drops every paragraph containing an @ line, and none share a six-gram. The @param-vs-signature lint the finding asked for is complementary to the span guard, not replaced by it.
  - id: BR-86
    disposition: addressed
    note: |
      Task 4.2 stages the alias hunk by path; *.parley-backup.* is gitignored. The operator's config.lua trim and docs/parley.nvim.md remain uncommitted by declared choice and are outside this issue's deliverable.
  - id: BR-87
    disposition: addressed
    note: |
      plan.md:1355 strikes the phrase and :1358-1367 carries the superseding callout in place.
  - id: BR-95
    disposition: not-addressed
    note: |
      init.lua:4410 improved the message but is still a bare error(...), so the operator still gets an "init.lua:4410:" prefix — the defect the finding named. The Revisions entry scopes the sweep out, which is a defensible decision, but it does not close this site: error(msg, 0) here costs one token.
  - id: BR-96
    disposition: not-addressed
    note: |
      The recovery_e2e stray space and the TOOL_AGENT block are fixed, but chat_respond_spec.lua:1309 "local function open_simple_chat" is still at column 0; the base at 42d72b9 had it at 4. The finding named both halves.
  - id: BR-102
    disposition: addressed
    note: |
      lessons.md:1037-1116 records the BR-90 and BR-93 rules plus four more, each with measured prevalence.
  - id: BR-103
    disposition: addressed
    note: |
      atlas/providers/agents.md:6-11 stops restating the roster and points at config.lua as the source.
  - id: BR-104
    disposition: not-addressed
    note: |
      The resolver half is delivered and pinned (reverting as_model_table reddens two unit cases). The RULE the finding stated — "normalize model_config once at the resolver's entry ... instead of type-guarding at each consumer" — was not swept: providers.lua:1106 (cliproxyapi.format_payload) and providers.lua:1359 (has_feature) still do `type(model_config) == "table" and model_config.model or nil` in the same file. One of them REGRESSED as a result. Measured headlessly at HEAD vs. with as_model_table reverted: has_feature("cliproxyapi", "web_search", "claude-opus-5") returns FALSE at HEAD and returned TRUE before commit 6cda59a, while the table form returns true both times. highlighter.lua:456-457 passes the raw agent.model, so a string-configured cliproxy claude agent now renders the "web search unsupported" badge (🌎?) in the picker, the buffer-top extmark and lualine — for a model the same commit just routed to the wire where search works. The enumeration is `grep -n 'type(model[_a-z]*) == "table"' lua/parley/providers.lua lua/parley/tools/wire.lua`; sweep it in one round.
  - id: BR-105
    disposition: addressed
    note: |
      cliproxy.lua:31-37 states preference order and matches OWNER_CHANNELS; :372-380 derives the multiplier from MAX_CANDIDATE_CHANNELS instead of naming a count.
  - id: BR-106
    disposition: addressed
    note: |
      definition_pattern is extracted and driven through real grep -E over synthetic text with four planted false positives (comment, comparison, like-named key, call site) and five definition forms.
findings:
  - id: new
    severity: Important
    family: missing-test-for-shipped-behavior
    title: |
      The tools/wire.lua half of the BR-104 fix is unpinned — reverting it leaves the ENTIRE suite green
    detail: |
      This is the 7th finding in family `missing-test-for-shipped-behavior`, and it is
      specifically the BR-68 rule ("a fix that lands as a call, or a new argument at an
      existing call, must be pinned AT THAT SITE") re-broken by the commit that closed the
      round which restated it. Measured, not asserted: I replaced
      `providers.cliproxy_strategy(model)` at tools/wire.lua:107 with the pre-fix
      `providers.cliproxy_strategy(type(model) == "table" and model or nil)` and ran the
      full `make test` in a clean worktree — exit 0, all 193 specs pass, including
      tests/unit/cliproxy_catalog_spec.lua, which is where the fix's tests live. Those
      tests call `providers.cliproxy_strategy` directly; nothing exercises `wire.resolve` /
      `wire.name_for` with a bare-string model, which is the production wiring the change
      exists for. By contrast the providers.lua half IS pinned — reverting `as_model_table`
      reddens "derives for a bare string model" and "treats the two shapes identically",
      which is what makes the asymmetry legible. Cheapest close: one assertion beside the
      existing shape cases — `assert.equals("anthropic", wire.name_for("cliproxyapi",
      "claude-opus-5"))` under the same `with_default("openai_tools_route", …)` — and
      confirm it reddens on revert before recording it as fixed.
```
