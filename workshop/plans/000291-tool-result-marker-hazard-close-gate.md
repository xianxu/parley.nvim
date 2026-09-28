---
gate: boundary-review
issue: 291
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-27T17:29:12-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Important
          title: render_result escapes under DEFAULT prefixes while the chat parser uses the user's config
          detail: 'serialize.lua:107 reads require("parley.config") (pristine defaults), but parse_chat runs under parley.config, so a custom chat_*_prefix leaves marker lines unescaped. Reproduced with chat_user_prefix "Q:", where an ls line "Q: notes.md" was written unflagged and parse_chat returned 3 exchanges instead of 2. Instances in this window: serialize.lua:107 (the predicate), atlas/providers/tool_use.md:284 ("under the configured prefixes"), serialize.lua:37 ("reading the configured marker prefixes"), and no custom-prefix test in tools_serialize_spec or tool_output_prefix_spec. The same pattern exists outside the window at tool_folds.lua:33 and init.lua:4220,4255. Fix: resolve the live config the way discovery/init.lua:41 does, via one shared helper, and add a custom-prefix round-trip plus parse_chat test.'
          family: config-source-divergence
          round: 1
        - id: BR-2
          severity: Minor
          title: structural() rebuilds the lexer patterns for every body line, twice for escaped lines
          detail: serialize.lua:105-121 builds patterns once per line; hoist to once per escape() call.
          family: per-line-invariant-recompute
          round: 1
        - id: BR-3
          severity: Minor
          title: fence.lua:98-100 still says body_close_of documents where the bound is not total
          detail: body_close_of's comment now states the invariant is total for Parley-written results; update the M.scan doc to match.
          family: stale-neighbour-doc
          round: 1
      recipe: small-diff-review
      blocked: true
    - "n": 2
      timestamp: "2026-09-27T17:39:27-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: live_patterns() used by serialize, tool_folds x2, diagnostic_refresh; init.lua passes M.config; custom-prefix test fails when the fix is reverted (28/1), passes at HEAD.
          round: 2
        - id: BR-2
          disposition: addressed
          note: escape() builds the predicate once and classifies each line once (marked[] reused).
          round: 2
        - id: BR-3
          disposition: addressed
          note: fence.lua:99-100 now says the bound is safe because Parley-written results are escaped.
          round: 2
      findings:
        - id: BR-4
          severity: Minor
          title: Two live_config resolvers exist - highlight_structure.lua:14 and discovery/init.lua:40
          detail: '2nd finding in family config-source-divergence. Rule - the live config comes from one helper, and no module decides on its own between parley.config and the defaults module. Instances: highlight_structure.live_config (package.loaded) and discovery live_config (injected _parley). Make discovery call the shared helper (ARCH-DRY).'
          family: config-source-divergence
          round: 2
      recipe: small-diff-review
      blocked: false
---

# Gate ledger — parley.nvim#291 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-27T17:29:12-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `config-source-divergence` render_result escapes under DEFAULT prefixes while the chat parser uses the user's config
  serialize.lua:107 reads require("parley.config") (pristine defaults), but parse_chat runs under parley.config, so a custom chat_*_prefix leaves marker lines unescaped. Reproduced with chat_user_prefix "Q:", where an ls line "Q: notes.md" was written unflagged and parse_chat returned 3 exchanges instead of 2. Instances in this window: serialize.lua:107 (the predicate), atlas/providers/tool_use.md:284 ("under the configured prefixes"), serialize.lua:37 ("reading the configured marker prefixes"), and no custom-prefix test in tools_serialize_spec or tool_output_prefix_spec. The same pattern exists outside the window at tool_folds.lua:33 and init.lua:4220,4255. Fix: resolve the live config the way discovery/init.lua:41 does, via one shared helper, and add a custom-prefix round-trip plus parse_chat test.
- **BR-2** [Minor] `per-line-invariant-recompute` structural() rebuilds the lexer patterns for every body line, twice for escaped lines
  serialize.lua:105-121 builds patterns once per line; hoist to once per escape() call.
- **BR-3** [Minor] `stale-neighbour-doc` fence.lua:98-100 still says body_close_of documents where the bound is not total
  body_close_of's comment now states the invariant is total for Parley-written results; update the M.scan doc to match.

## Round 2 — 2026-09-27T17:39:27-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — live_patterns() used by serialize, tool_folds x2, diagnostic_refresh; init.lua passes M.config; custom-prefix test fails when the fix is reverted (28/1), passes at HEAD.
- BR-2 — addressed — escape() builds the predicate once and classifies each line once (marked[] reused).
- BR-3 — addressed — fence.lua:99-100 now says the bound is safe because Parley-written results are escaped.

### Raised

- **BR-4** [Minor] `config-source-divergence` Two live_config resolvers exist - highlight_structure.lua:14 and discovery/init.lua:40
  2nd finding in family config-source-divergence. Rule - the live config comes from one helper, and no module decides on its own between parley.config and the defaults module. Instances: highlight_structure.live_config (package.loaded) and discovery live_config (injected _parley). Make discovery call the shared helper (ARCH-DRY).

## Open findings

- **BR-4** [Minor] `config-source-divergence` Two live_config resolvers exist - highlight_structure.lua:14 and discovery/init.lua:40
