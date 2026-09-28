# Boundary Review — parley.nvim#291 (whole-issue close)

| field | value |
|-------|-------|
| issue | 291 — Close the column-0 marker hazard in tool results (ls/find/stderr) |
| repo | parley.nvim |
| issue file | workshop/issues/000291-tool-result-marker-hazard.md |
| boundary | whole-issue close |
| milestone | — |
| window | 18f4e6dc2b8c44b401f124b97939dbeac36d6199..1e5a014c114e0bbe4b426d065736595055e6cb58 |
| command | sdlc close --issue 291 |
| reviewer | claude |
| timestamp | 2026-09-27T17:29:12-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The escape design is sound. A flagged block gets a leading `\` on each structural line and on each line that already starts with `\`. It round-trips exactly, leaves unflagged and old blocks byte-for-byte unchanged, and every reader goes through `parse_result`. All four touched specs pass locally:

| Spec | Passed |
|---|---|
| `tools_serialize_spec` | 28 |
| `chat_parser_tools_spec` | 36 |
| `tool_output_prefix_spec` | 10 |
| `chat_respond_spec` | 53 |

One real gap keeps the invariant from being total, which the atlas and the comments now claim it is. The escape predicate reads the **default** config (`require("parley.config")`), but the chat parser runs under the user's config (`M.config = vim.deepcopy(config)`, `init.lua:549`). With a custom prefix, results are not protected. I reproduced it: with `chat_user_prefix = "Q:"`, an `ls` line `Q: notes.md` is written unescaped, and `parse_chat` returns 3 exchanges instead of 2.

## 1. Strengths
- **One fix covers every tool.** The escape lives in `serialize.render_result` (`lua/parley/tools/serialize.lua:111-141`), so no producer has to know about markers (ARCH-DRY).
- **Old transcripts are safe by construction.** Only blocks that need it get the flag. The byte-identity test and the "old unflagged block with `\` lines unchanged" test both pin this (`tests/unit/tools_serialize_spec.lua:252-260`).
- **The flag is only read after `id=`.** It is never taken from the name field, and a test covers a tool named `escaped=true` (`serialize.lua:166`).
- **`tool_output_prefix_spec` is stronger.** It now runs each tool's real output through the serializer and checks the round-trip. `ls`/`find` are tested with a marker-named file.
- **End-to-end test.** `chat_respond_spec.lua:604-639` confirms the provider payload contains the unescaped listing and no `\💬`.

## 2. Critical findings
None.

## 3. Important findings
**The escape uses the default prefixes, not the configured ones.**
- `serialize.lua:107` calls `structure.patterns(require("parley.config"))`. That table is the pristine defaults (`discovery/init.lua:17` documents this).
- `parse_chat` receives `parley.config`, so a custom `chat_*_prefix` on any structural kind (user, assistant, local, branch, summary, tool_use, tool_result) re-opens the fork.
- Instances of this problem in the window:
  1. `serialize.lua:107`, the predicate itself.
  2. `atlas/providers/tool_use.md:284`, which says "under the configured prefixes"; that's false.
  3. `serialize.lua:37`, which says "PURE apart from reading the configured marker prefixes"; that's also false.
  4. Neither `tools_serialize_spec` (`:218`, patterns from defaults) nor `tool_output_prefix_spec` tests a custom prefix, so nothing would catch this.
- Outside the window, the same pattern appears at `tool_folds.lua:33` and `init.lua:4220,4255`. Those predate this change, but the fix should use the same helper.
- **Fix:** resolve the live config the way `discovery/init.lua:41` does: `(package.loaded.parley and require("parley").config) or require("parley.config")`. Ideally move that into one shared helper. Build `patterns` once per `escape()` call, and add a test that renders with a custom `chat_user_prefix` and parses with the same config.

## 4. Minor findings
- `serialize.lua:105-121`: `structural()` rebuilds `patterns()` for every line (about 20 `gsub`s each), and runs twice on escaped lines. A long `read_file` result pays this every time it's rendered. Hoist the patterns out; that goes naturally with the fix above.
- `fence.lua:98-100`: the doc comment on `M.scan` still says to "see body_close_of for … where it is not total". `body_close_of` now says the opposite, so this is a stale neighbouring comment.

## 5. Test coverage notes
Every `## Done when` clause is covered:
- **Hostile fixtures:** a marker-named `ls`/`find` file, `📎:` in stderr, and escape-led lines. Each is rendered, re-parsed and rebuilt into provider messages.
- **Exceptions removed:** the two accepted exceptions are gone from `tool_output_prefix_spec`.
- **Old transcripts:** the unflagged-block tests, plus the existing "forks on a column-0 question marker" case.
- **Atlas:** updated.

The only mode not tested is custom marker prefixes (the Important finding).

## 6. Architectural notes
- **ARCH-DRY: pass.** One escape point in the serializer. The predicate reuses `lexical.is_structural_kind` rather than listing kinds by hand.
- **ARCH-PURE: flag (folded into the Important finding).** `escape`/`unescape` are pure, but the config is read inside the serializer instead of being passed in. Accepting `patterns` from the caller, or resolving the live config once, would fix both the purity and the correctness issue.
- **ARCH-PURPOSE: flag.** The point of the issue is a *total* invariant for results Parley writes. It isn't total yet, because the predicate doesn't use the configuration the parser uses.

## 7. Plan revision recommendations
- Add a `## Revisions` entry saying the escape predicate must use the live (user) config's prefixes, with a custom-prefix regression test. Also correct the Core concepts row wording if the signature changes (for example, if `render_result` starts accepting `patterns`).

```findings
findings:
  - id: new
    severity: Important
    family: config-source-divergence
    title: |
      render_result escapes under DEFAULT prefixes while the chat parser uses the user's config
    detail: |
      serialize.lua:107 reads require("parley.config") (pristine defaults), but parse_chat runs under parley.config, so a custom chat_*_prefix leaves marker lines unescaped. Reproduced with chat_user_prefix "Q:", where an ls line "Q: notes.md" was written unflagged and parse_chat returned 3 exchanges instead of 2. Instances in this window: serialize.lua:107 (the predicate), atlas/providers/tool_use.md:284 ("under the configured prefixes"), serialize.lua:37 ("reading the configured marker prefixes"), and no custom-prefix test in tools_serialize_spec or tool_output_prefix_spec. The same pattern exists outside the window at tool_folds.lua:33 and init.lua:4220,4255. Fix: resolve the live config the way discovery/init.lua:41 does, via one shared helper, and add a custom-prefix round-trip plus parse_chat test.
  - id: new
    severity: Minor
    family: per-line-invariant-recompute
    title: |
      structural() rebuilds the lexer patterns for every body line, twice for escaped lines
    detail: |
      serialize.lua:105-121 builds patterns once per line; hoist to once per escape() call.
  - id: new
    severity: Minor
    family: stale-neighbour-doc
    title: |
      fence.lua:98-100 still says body_close_of documents where the bound is not total
    detail: |
      body_close_of's comment now states the invariant is total for Parley-written results; update the M.scan doc to match.
```

---

## Re-review — 2026-09-27T17:39:27-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 291 — Close the column-0 marker hazard in tool results (ls/find/stderr) |
| repo | parley.nvim |
| issue file | workshop/issues/000291-tool-result-marker-hazard.md |
| boundary | whole-issue close |
| milestone | — |
| window | 18f4e6dc2b8c44b401f124b97939dbeac36d6199..80f10ce3fe13fb77ba783f101bbc5b2964e6c27c |
| command | sdlc close --issue 291 |
| reviewer | claude |
| timestamp | 2026-09-27T17:39:27-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

All three prior findings are fixed. BR-1 is now correct: `render_result` gets its marker patterns from the user's live config through `highlight_structure.live_patterns()`, the same config `parse_chat` runs under. The new custom-prefix test passes at HEAD. I reverted the one-line fix in a scratch edit and the test failed (28 pass, 1 fail), then restored the file. The same fix was applied to the other places that were reading the defaults module: `tool_folds.lua` (twice), `diagnostic_refresh.lua`, and `init.lua` `dump_model`/`check_buffer`. The one new finding is Minor and doesn't block: the live-config lookup now exists in two places.

1. **Strengths**
   - The fix covers the whole class, not just the site BR-1 named. After the change, a search for `require("parley.config")` finds no marker-pattern caller still falling back to defaults. The remaining users either pass the live config explicitly (`entity_range` callers pass `M.config` / `parley.config`) or only use non-prefix settings (`starter`, `vault`, `dispatcher`).
   - The regression test at `tests/unit/tools_serialize_spec.lua:268-290` checks the actual symptom: the chat parses to 2 exchanges, not 3, under `chat_user_prefix = "Q:"`. It also restores `package.loaded["parley"]` after each test.
   - `escape()` (`serialize.lua:115-128`) builds the predicate once per call and classifies each line once. Its `marked[]` array is reused for the second pass.
   - The `fence.lua:99-100` doc now matches `body_close_of`'s comment.

2. **Critical findings:** none.

3. **Important findings:** none.

4. **Minor findings**
   - `highlight_structure.lua:14` `live_config()` does the same job as `discovery/init.lua:40` `live_config()`: use parley's config if it's loaded, otherwise the defaults module. BR-1 asked for one shared helper, so there are now two ways to look up one fact (ARCH-DRY). They agree today, but they reach parley differently: one reads `package.loaded`, the other uses an injected reference. Fix: have `discovery` call `highlight_structure.live_config()`, or move the helper to a neutral module and have both use it. Only these two places in the window resolve the live config.

5. **Test coverage**
   - These specs pass at HEAD:

     | Spec | Tests passing |
     |---|---|
     | `tools_serialize_spec` | 29 |
     | `tool_output_prefix_spec` | 10 |
     | `chat_parser_tools_spec` | 36 |
     | `chat_respond_spec` | 53 |
     | `entity_range_spec` | 47 |

   - Every `## Done when` clause is covered: hostile content round-trips, the prefix spec now asserts these results are safe instead of logging them as accepted exceptions, an old unflagged block still parses the same way, and the atlas is updated. The escaping is exercised under both the default and a custom prefix.

6. **Architecture notes**
   - ARCH-DRY: flagged — the second `live_config` above; it's Minor.
   - ARCH-PURE: pass. `serialize` stays pure apart from reading config through one small function.
   - ARCH-PURPOSE: pass. Every writer and reader that builds marker patterns was moved to the live config in the same round.

7. **Plan revision recommendations:** none. The Core concepts table (`live_config` / `live_patterns` in `highlight_structure.lua`) matches the code.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      live_patterns() used by serialize, tool_folds x2, diagnostic_refresh; init.lua passes M.config; custom-prefix test fails when the fix is reverted (28/1), passes at HEAD.
  - id: BR-2
    disposition: addressed
    note: |
      escape() builds the predicate once and classifies each line once (marked[] reused).
  - id: BR-3
    disposition: addressed
    note: |
      fence.lua:99-100 now says the bound is safe because Parley-written results are escaped.
findings:
  - id: new
    severity: Minor
    family: config-source-divergence
    title: |
      Two live_config resolvers exist - highlight_structure.lua:14 and discovery/init.lua:40
    detail: |
      2nd finding in family config-source-divergence. Rule - the live config comes from one helper, and no module decides on its own between parley.config and the defaults module. Instances: highlight_structure.live_config (package.loaded) and discovery live_config (injected _parley). Make discovery call the shared helper (ARCH-DRY).
```
