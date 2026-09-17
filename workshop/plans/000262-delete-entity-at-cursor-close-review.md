# Boundary Review — parley.nvim#262 (whole-issue close)

| field | value |
|-------|-------|
| issue | 262 — Delete entity at cursor — markdown section, paragraph, or chat question |
| repo | parley.nvim |
| issue file | workshop/issues/000262-delete-entity-at-cursor.md |
| boundary | whole-issue close |
| milestone | — |
| window | 85e116c2da14c941735c7d7e67bb023aaff3aa00..420d046a2e907dbad1d930c786078f95ddb7f65b |
| command | sdlc close --issue 262 |
| reviewer | claude |
| timestamp | 2026-09-16T17:04:38-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The M1/M2 core is real work and the pure/IO split holds up: `entity_range.range` is a genuine pure function over `(parsed, lines, row, opts)` with 45 mock-free unit tests, the two surfaces share one range function and one classifier, the parity spec now runs to completion (I measured `make test-spec SPEC=chat/entity_delete` at exit 0 — parity 11/11, textobj 15/15, entity_range 45/45, conformance 1/1, heading 4/4), and BR-15's header-floor fix is pinned with real regression evidence (scratch-reverting the front-matter branch reds the spec 43/2 on the exact assertion). Eight of the nineteen open findings genuinely close this round. What blocks SHIP is that **BR-32 is still live and this is the last gate**: `range(p, L, 11, {scope="to_end"})` on a real `parse_chat` returns `paragraph 11..15`, which deletes the closing fence at row 13 while the opener at row 10 survives — `daE`/`<C-g>K`/`:ParleyDeleteToEnd` inside a code block strands a fence and renders the rest of the transcript as code. I wrote the odd-fence invariant BR-30 specified and it fails **10 times across four fixtures (chat backtick, chat tilde, indented, plain markdown), all on `to_end`, zero on `entity`** — so the class guard named in two consecutive rounds still has not shipped, and `atlas/chat/entity_delete.md:94` ("a range never spans one") is measurably false about behavior the code ships. The `entity` scope, the header floor, and the exchange-crossing rule are all clean: a six-fixture property sweep over floor / anchor-crossing / cursor-containment returned **0 violations**.

## 1. Strengths

- **`entity_range.lua` is a real pure core.** Every rule is a function of `(parsed, lines, row)`; `tests/unit/entity_range_spec.lua` drives 45 cases over literal Lua arrays with no buffer, no `nvim_*`, no mocks. ARCH-PURE passes cleanly.
- **One classifier, genuinely shared.** `init.lua:4536` calls `entity_textobj.parsed_for` rather than re-asking `not_chat` — the BR-2 divergence is structurally impossible now, not just tested away.
- **The header floor is derived from document shape, and the conformance test is the right shape of guard.** `entity_range_spec.lua:366-392` renders *both* `defaults` templates through the real `render.template` and `new_chat`'s `gsub("_", "\\_")`, then asserts a non-nil terminator — verified red (43/2) with the front-matter branch reverted. The negative side (`# Recipe: soup` stays editable) is asserted in the same block.
- **The heading dialect is single-sourced and pinned.** `markdown_heading.lua` + `markdown_heading_conformance_spec.lua` (agrees with `document.lexical` over a corpus), with `outline.lua:54-60` and `:254` both folded onto it. Exactly the ARCH-DRY consolidation the plan promised.
- **The `starter_config` carve-out is scoped, not widened** (`starter_config.lua:25-35`), and the negative test pinning that a bare `gf` is *still* excluded (`starter_config_spec`, 7/7) is the right way to prove a filter relaxation didn't leak.
- **The parity spec's axis enumeration is written down** (`entity_delete_parity_spec.lua:47-62`), including why in-flight generation is deliberately *not* an axis. That is the artifact that stops the next axis from being rediscovered.

## 2. Critical findings

None.

## 3. Important findings

- **`lua/parley/entity_range.lua:279-291` — `to_end` bypasses the fence wall (BR-32, not-addressed).** Measured: `range(p, L, 11, {scope="to_end"})` → `paragraph 11..15` over a real two-exchange `parse_chat` with a fence at 10-13. Ten odd-fence violations across four fixtures, all on `to_end`. Fix per BR-32's own spec: one post-condition at `M.range`'s single exit (`:296-299`) — the returned `[first,last]` may not contain an unmatched `lexical.is_fence_delim` line — plus the odd-fence invariant over a fenced corpus in `entity_range invariants`. Resolve the contract conflict first: `atlas/chat/entity_delete.md:94` vs issue `Done when` ("through the end of the current exchange").
- **`lua/parley/entity_range.lua:102/:111/:285` — BR-30's class was not swept.** The three named instances are fixed and pinned, but the guard the finding specified was never written, and "the effective heading level at row *i*" is still spelled three ways, two carrying an `in_code and` nil-guard that no call site can reach (`:256` and `:286` both pass the always-built memo) against one unguarded read. One `heading_at(lines, in_code, i)` is both the ARCH-DRY consolidation and the mechanical form of "classify once".
- **`workshop/plans/...-plan.md:7/:53/:852` — four file:line refs still do not resolve (BR-20, 5th round).** `:7` lists `fence.open_len` as a reused primitive (`entity_range` requires `parley.fence` nowhere since `a3fcf7ea`); `:53` says ChatPrune `4255` (actual `4271`) and ExchangeCut `4423` (actual `4439`); `:852` cites `init.lua:2803-2812` as `chat_exchange_cut` (`2803` is `chat_search`; `chat_exchange_cut` is `2811-2821`). The file-set half now holds — all 16 changed `lua/`+`tests/` paths appear in the plan.

## 4. Minor findings

- BR-13 — plan `:87`/`:938` still say `DeleteEntity` is "`ExchangeCut`'s preamble verbatim"; the code uses `entity_textobj.parsed_for`. Line numbers were corrected; the prose claim was not.
- BR-23 — `atlas/chat/entity_delete.md:105-116` still states 13.6/24.7/97.8 ms with its own admission that nothing guards them. No `tests/perf` or `tests/arch` file references `entity_range`.
- BR-24 — `entity_delete_parity_spec.lua:80` (`shape`) and `:86` (`did_setup`) are module-scope mutables that `fresh()` reads; correct only under sequential execution.
- BR-25 — `keybinding_registry.lua:483/:493/:503` unchanged: "(dae/yae/cae)", "(die/yie/cie)", then "(daE)" alone.
- BR-27 — `atlas:94-95` verbatim unchanged; measured, `range()` returns **nil** on an in-fence `# heading` (a no-op, not "content"), and the Precedence table still has no row for it. `entity_range.lua:10` and `plan.md:66` both still say "Five rules" over six.
- BR-31 — the named dead assignment is fixed at `420d046a`; the siblings inside the fix (above) are not.
- BR-33 — `entity_delete_parity_spec.lua:108-110` writes a chat file per `fresh()`; `run()` at `:135-139` frees only the buffer.
- Housekeeping: my scratch worktree's metadata dir `.git/worktrees/wt` survived removal (the working tree itself is gone, `git status` clean at `420d046a`). Run `git worktree prune` if it lingers.

## 5. Test coverage notes

The mapped set is green with a real summary and exit 0 on every file; `outline_spec` 20/20, `starter_config_spec` 7/7, `keybinding_agreement_spec` 33/33 also pass, so the `outline`/`config`/`starter_config` changes carry no regression. Coverage of the `entity` scope is strong — my independent sweep over six document shapes (two-exchange, tagged preface, all-markers, question-only, deep headings, front-matter) × every row × {entity,to_end} × {inner,outer} found **zero** floor, anchor-crossing or cursor-containment violations. The one hole is the one BR-30 named and BR-32 measured: the `entity_range invariants` block (`:530-556`) asserts only not-inverted / in-range, and `"to_end from inside a fence still stops at the exchange bound"` (`:524-528`) asserts `r.last <= #lines` and `r.first >= 11` — both tautologies over any `to_end` result. That test passes while the bug it names is live.

## 6. Architectural notes

- **ARCH-DRY — flag.** One heading dialect and one fence predicate are genuine wins; three spellings of the effective-heading-level read (BR-30/BR-31) are the regression.
- **ARCH-PURE — pass.** Pure core, thin shell, unit tests with no IO.
- **ARCH-PURPOSE — flag.** Fifth consecutive round where the disposition delivers the named site and not the enumerable class. The `range-splits-a-structure` slug repeating five times *is* the ledger reporting that the enumeration was never written.
- **ARCH-MOCK — N/A**, correctly declared: no external binary or service; Neovim is exercised for real.
- **ARCH-CONSTRAINTS — flag (BR-23).** The declared `< 16 ms @ 5000 lines` was missed, and the accepted replacement numbers have no executable check.
- **ARCH-SECURE — pass.** Buffer text is treated as untrusted: `parse_chat` is `pcall`-wrapped at the one classifier seam, `M.range` type-guards `lines` and `row`, and a failed parse degrades to a visible refusal rather than unclamped semantics or a fabricated range. No credentials; test files live under the harness `TMPDIR`.
- **ARCH-ORDER — pass with a note.** `entity_range` holds no state between events because every call re-derives from `(parsed, lines, row)`. The one unblockable ordering — an edit landing while a response streams — is enumerated, the surfaces' asymmetry is deliberate, documented in both atlas and plan, and tested at the `buffer_edit` seam (`entity_textobj_spec:196`). The parity spec's scoping to a quiescent document is stated with its reason.
- **ARCH-FUNERAL — flag (BR-33).** New per-iteration file family with no removal path.

## 7. Plan revision recommendations

- `## Revisions` entry: **"fence handling is not yet complete on `to_end`"** — the plan's rule list (`:66-71`) and the atlas both assert a fence invariant the `to_end` path does not hold. Record the carve-out decision (exception vs. post-condition) once it is made.
- `## Revisions` entry correcting `:7` (drop `fence.open_len`, which `entity_range` no longer calls), `:53` (`4271`/`4439`), and `:852` (`2811-2821`), and fixing `:87`/`:938`'s "ExchangeCut's preamble verbatim" to name `entity_textobj.parsed_for`.
- `:66` — renumber "Five rules" to six (header floor, fence wall), matching the same fix in `entity_range.lua:10`.

```findings
dispose:
  - id: BR-5
    disposition: addressed
    note: |
      section_range is now (lines, row, bounds, in_code) - the floor parameter is gone, and :106-107 documents why a second floor test could not change the outcome.
  - id: BR-8
    disposition: addressed
    note: |
      README.md:16-25 now names ae, ie, aE, dae/yae/cae, Ctrl+g k, Ctrl+g K and both :ParleyDelete* commands.
  - id: BR-13
    disposition: not-addressed
    note: |
      Line refs corrected to 4439, but plan.md:87 and :938 still say DeleteEntity is "ExchangeCut's preamble (verbatim)"; init.lua:4529-4540 uses entity_textobj.parsed_for, not ExchangeCut's not_chat preamble.
  - id: BR-14
    disposition: addressed
    note: |
      This gate's base 85e116c2 is merge-base(main,HEAD); stat and name-status both return 31 files, so the window is real.
  - id: BR-15
    disposition: addressed
    note: |
      Front-matter branch at chat_parser.lua:108-115 plus a conformance test rendering both defaults templates through the real renderer and new_chat's underscore escape; scratch-reverting the branch reds entity_range_spec 43/2 on "chat_template must yield a header terminator". Negative side (# Recipe: soup) asserted too.
  - id: BR-16
    disposition: addressed
    note: |
      No occurrence of "and 2 or 2" remains anywhere under lua/ or tests/.
  - id: BR-17
    disposition: addressed
    note: |
      entity_delete_parity_spec.lua:186-195 - the no-header branch now asserts that the two surfaces agree on rows 1-3, a property of the code rather than of the SHAPES literal.
  - id: BR-18
    disposition: addressed
    note: |
      "In a plain markdown buffer there is no exchange kind..." stands as its own paragraph again, and the header table row now points at the "What counts as a header" paragraph, which states the contiguous-run qualifier in full.
  - id: BR-20
    disposition: not-addressed
    note: |
      File-set half holds (all 16 changed lua/ and tests/ paths appear in the plan). File:line half does not - plan.md:7 still lists fence.open_len though entity_range requires parley.fence nowhere; :53 says ChatPrune 4255 (actual 4271) and ExchangeCut 4423 (actual 4439); :852 cites init.lua:2803-2812 as chat_exchange_cut when 2803 is chat_search and chat_exchange_cut is 2811-2821. 5th round open.
  - id: BR-22
    disposition: addressed
    note: |
      The close gate's base is the true branch point, so M2's deliverable (e007f6c5, 49064ec4, cb17a0a6) appears in a reviewed range for the first time. The milestone-boundary derivation fix lives in sdlc, outside this repo's tree.
  - id: BR-23
    disposition: not-addressed
    note: |
      Nothing under tests/perf or tests/arch references entity_range; atlas/chat/entity_delete.md:105-116 still states 13.6/24.7/97.8 ms alongside its own admission that no spec guards them.
  - id: BR-24
    disposition: not-addressed
    note: |
      entity_delete_parity_spec.lua:80 (shape) and :86 (did_setup) are both module-scope mutables that fresh() reads; still no seam to run the it() bodies in any other order.
  - id: BR-25
    disposition: not-addressed
    note: |
      keybinding_registry.lua:483/:493/:503 verbatim unchanged - "(dae/yae/cae)", "(die/yie/cie)", then "(daE)" alone.
  - id: BR-27
    disposition: not-addressed
    note: |
      atlas:94-95 verbatim unchanged; re-measured, range() returns nil on a `# x` inside a fence (neither section nor content) and the Precedence table still has no row for it. entity_range.lua:10 and plan.md:66 both still say "Five rules" over six. The same passage's "a range never spans one" is now measurably false via to_end - see BR-32.
  - id: BR-28
    disposition: addressed
    note: |
      420d046a appends "### 2026-09-16 - M2 boundary review (four rounds)" to plan.md:1113-1138, recording the fence wall, the single fence predicate, the in_code threading, the parity-spec abort and the Integration-points/line-ref deltas.
  - id: BR-30
    disposition: not-addressed
    note: |
      Instances remain fixed and pinned, but the class guard the finding specified was never shipped - I wrote the odd-fence invariant and it fails 10 times over four fenced fixtures, all on to_end. Separately the fix still spells "the effective heading level at row i" three ways at :102, :111 and :285, two of them behind an `in_code and` nil-guard no call site can reach (:256 and :286 both pass the always-built memo).
  - id: BR-31
    disposition: not-addressed
    note: |
      The named dead assignment in entity_range_spec is fixed at 420d046a, but the sibling instances the round-8 disposition named inside the fix survive - the unreachable `in_code and` nil-guards at entity_range.lua:102/:111 against the unguarded read at :285. Instance fixed, class not swept; 5th in family.
  - id: BR-32
    disposition: not-addressed
    note: |
      Reproduced on a real parse_chat - range(p, L, 11, {scope="to_end"}) returns paragraph 11..15 with the closing fence at row 13 inside the range and the opener at row 10 outside it. entity_range.lua:279-291 still assigns found.last from bounds.last with no fence check, and the single exit at :296-299 still has no post-condition. Odd-fence invariant fails 10 times across chat-backtick, chat-tilde, indented and plain-markdown fixtures, all on to_end, zero on entity.
  - id: BR-33
    disposition: not-addressed
    note: |
      entity_delete_parity_spec.lua:108-110 still writes a chat file per fresh() call; run() at :135-139 deletes the buffer only.
```

---

## Re-review — 2026-09-16T17:23:21-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 262 — Delete entity at cursor — markdown section, paragraph, or chat question |
| repo | parley.nvim |
| issue file | workshop/issues/000262-delete-entity-at-cursor.md |
| boundary | whole-issue close |
| milestone | — |
| window | 85e116c2da14c941735c7d7e67bb023aaff3aa00..1a9cd92cdbac04eb4c623c02b3c92e8a33c398c9 |
| command | sdlc close --issue 262 |
| reviewer | claude |
| timestamp | 2026-09-16T17:23:21-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

BR-30 and BR-32 — the two Important findings that blocked the last round — are genuinely fixed with real regression evidence: `heading_level_at` (`lua/parley/entity_range.lua:104`) is now the one heading classification that the dispatch, the section forward scan and the `to_end` backward scan all consume, and `balance_fences` (`:192`) is a result-level post-condition that I scratch-reverted and watched go red (45 pass / 1 fail, exactly `entity_range invariants never returns a range that splits a fenced block`). BR-31 and BR-33 are closed with measurement (parity-spec residue: 489 files / 1.9 MB per run → 1 file / 4 KB), and BR-20's mechanical half now holds — all 16 changed `lua/`+`tests/` paths appear in the plan and **zero** `lua/*.lua:NNN` refs survive. What blocks SHIP is that the post-condition's own comment claims it is "checked once, after every path has had its say", and `M.range` has **two** exits, not one: the `question` branch returns at `:284`, twelve lines above the guard. Measured on a real `parse_chat` — a transcript whose answer was cut off mid-code-block (opener in exchange 1, closer in exchange 2, which is what a stopped generation produces) — `range(p, L, 5)` returns `question 5..10` carrying **one** fence delimiter, and `dae` on the `💬:` line leaves a bare ` ```lua ` opener so every following line renders as code. That is BR-21's exact corruption, on its fifth round, at the last gate. Test suite is otherwise clean for this diff: `make test-spec SPEC=chat/entity_delete` is 77/77; the two suite failures I saw (`document_dependencies_spec`, `perf_document_spec`) both pass in isolation and are 8-way-parallel flakes, and `parley_harness_golden_spec` fails 11/11 **at the base commit too** (golden drift from `baa2b77e`, an ancestor of base) — neither is this diff's.

## 1. Strengths

- **The classification collapse is the right consolidation.** `heading_level_at` (`entity_range.lua:104-109`) replaced three spellings of "effective heading level at row *i*", two of them behind an unreachable nil-guard. Measured: BR-30's plain-markdown case (`# Top / alpha / "" / ```lua / # fake / code / ``` / omega`) now returns `section 1..8` where it returned `1..4`, and the chat form is pinned at `entity_range_spec.lua:503-522`.
- **The guard is stated over the result and verified red.** `balance_fences` + the property test at `entity_range_spec.lua:545-577` (4 fixtures × every row × {entity,to_end} × {inner,outer}) is the class-level artifact two rounds asked for, not another wall at another call site. Reverting the call reds exactly that test and nothing else.
- **BR-32's measured instance is really gone.** `range(p, L, 11, {scope="to_end"})` on the two-exchange fixture with a fence at 10-13 returns `11..12`, not `11..15`; the opener survives.
- **Citation policy is enforced, not just declared.** I checked every `file:line` the plan names: all resolve, and no `lua/` line refs remain at all (`plan.md:9-15` states the policy; `lessons.md` records the why).
- **The app carve-out is scoped and negatively pinned.** `starter_config.lua`'s `object_only` plus `starter_config_spec.lua`'s "still refuses a bare normal-mode key" is the right shape for a filter relaxation.

## 2. Critical findings

None.

## 3. Important findings

- **`lua/parley/entity_range.lua:284` — the fence post-condition is skipped on the `question` exit, and is stated as delimiter *parity* rather than block *coverage*.** **This is the 5th finding in family `range-splits-a-structure`.** Do not patch the question branch. THE RULE, in two parts, both structural:
  1. **The post-condition must be unavoidable.** BR-32's spec said "`M.range` has exactly one exit"; that premise was false, so the guard landed on one of two. Split the body into a private `compute(...)` and make `M.range` = `compute` → `balance_fences` → final clamp, so no `return` can reach a caller without passing it. Measured instance: fixture `# topic: t / - file: t.md / --- / "" / 💬: q one / "" / 🤖: [A] / ```lua / a = 1 / "" / 💬: q two / "" / 🤖: [A] / ``` / tail prose` — `range(p,L,5)` → `question 5..10`, one fence delimiter; after `dae` the buffer is `… / 💬: q two / "" / 🤖: [A] / ``` / tail prose`, i.e. an unterminated opener. `range(p,L,11)` → `question 11..15`, same class, mirrored.
  2. **Parity is a weaker predicate than the invariant the atlas states.** `atlas/chat/entity_delete.md:94` says "a range never spans one"; the shipped check only forbids an *odd* delimiter count. Measured: fixture `… 🤖: [A] / ``` / x / ``` / "" / ~~~ / y / ~~~ / z`, `range(p,L,9,{scope="to_end"})` → `9..13`, two delimiters, passes the invariant, and deletes the closer of block A and the opener of block B. Under Parley's own `code_block_memo` (a flat toggle that ignores delimiter char and width) the result reconciles, which is why this half is lower-consequence — but the check should be expressed over the `in_code` memo `M.range` already computes at `:268` ("no fenced block partially covered") rather than re-scanning delimiters and counting them. Extend the property corpus with one fixture whose fence is unbalanced *within* an exchange span; the current four cannot see either half.

## 4. Minor findings

- **`lua/parley/entity_range.lua:10` / `atlas/chat/entity_delete.md:94-95` — docs describe behavior the code does not have (BR-27, still open, now worse).** `:10` opens "Five rules, each stated once" over six numbered rules, and this round added a "Rule 7" at `:186`. The atlas still says an in-fence `# heading` "is content rather than a section" — measured, `range()` returns `nil` there (neither) — and now also says "a fence line is never deleted, a range never spans one", which the `9..13` range above falsifies.
- **`workshop/plans/000262-…-plan.md` — the de-line-numbering pass damaged five passages.** **This is the 3rd finding in family `docs-edit-mangles-prose`.** THE RULE: a mechanical substitution over prose must be read back as prose, not diffed as tokens. The enumeration: `:945` "`ExchangeCut`'s preamble verbatim ()" (empty parens); `:956` "allow-list's allow-list"; `:860` "`prep_chat` calls `tool_folds.setup(buf)` (`prep_chat`)"; `:107` "`document.exchange(doc,row)` (`document.exchange`)"; `:804` "`outline.lua`'s in-code guard's existing ruling". The fifth is a factual inversion, not a typo: `:1131` now reads "The first cut used `lexical.is_fence_delim` for the wall and `code_block_memo` for the in-block test; they recognise different fences" — the first cut used `fence.open_len`, and as rewritten the Revisions entry says the bug and its fix are the same predicate, erasing the record BR-26 exists to keep.
- **`tests/integration/entity_textobj_spec.lua:220` — `cae` is claimed and never executed.** **This is the 3rd finding in family `checkbox-without-artifact`.** THE RULE: a test whose name enumerates behaviors must exercise each one; an enumeration in a Done-when bullet becomes a loop or one assertion per item, never prose in a title. Done-when says `d`/`y`/`c`/`v` "at minimum"; `dae`/`yae`/`vae`/`die` are all driven, and `c` appears nowhere in `tests/` — the test named "die and cae work, as Done-when claims for every operator" runs only `die`. `cae` over a linewise object leaves insert mode open, which is exactly the kind of thing the other three tests exist to catch.

## 5. Test coverage notes

The mapped set is green and exits 0: parity 11/11, textobj 15/15, entity_range 46/46, conformance 1/1, heading 4/4. The new property test is the right artifact and I confirmed it red under scratch revert. Its blind spot is the one the new Important names — every FENCED fixture is fence-balanced within a single exchange span and chat-classified, so neither the question exit nor an unbalanced-within-exchange document is reachable from it (BR-32 asked for a plain-markdown fixture among the four; all four are chat-shaped, though the plain-markdown regression is covered separately at `:503-522` and I verified it independently). BR-24 remains: `entity_delete_parity_spec.lua:78` declares `shape` at module scope, each `it()` assigns it, and `fresh()` reads it — correct only because busted runs bodies sequentially. I re-measured the ARCH-CONSTRAINTS figures with the atlas's own recipe: 12.8 / 25.5 / 101.7 ms against the published 13.6 / 24.7 / 97.8, so the numbers are accurate *today* despite two whole-buffer passes (`code_block_memo`, `balance_fences`) landing after they were taken — BR-23's risk is silent future drift, exactly as it was stated, and nothing in `tests/perf` or `tests/arch` references `entity_range`.

## 6. Architectural notes for upcoming work

ARCH-DRY: **pass**, with one observation — `M.range` builds `in_code` at `:268`, which already encodes the fenced-block structure, and `balance_fences` then re-derives fence positions by rescanning with the same predicate. One derivation, two consumers, is the shape the Important above asks for. ARCH-PURE: **pass** — `entity_range` is a value function over `(parsed, lines, row, opts)`; 46 unit cases run with no buffer and no mocks. ARCH-PURPOSE: **pass** — shadow-sweep of the "one ATX dialect" claim: `entity_range` derives, `outline` derives on both its line-based and token-based paths, `document/lexical` keeps its hot scanner and is *enforced* by `markdown_heading_conformance_spec`, not merely documented. `exporter.lua:537-541` still hand-maps `^# `/`^## `/`^### `, but that is a level→CSS-class rendering table rather than a heading test, and the plan names it explicitly as the next consumer if the dialect widens. ARCH-MOCK: **N/A** (no external binary or service); the one substitution, `buffer_edit.replace_user_lines` at `entity_textobj_spec.lua:208`, is an internal seam with its scope argued in place. ARCH-CONSTRAINTS: **pass with the standing miss** — 25.5 ms against a 16 ms budget at 5 000 lines, a documented and operator-accepted miss, with `document.exchange` named as the escape hatch. ARCH-SECURE: **pass** — the transcript is the untrusted input, `transcript_header_end` and `M.range` both type- and bound-guard, the malformed corpus is property-tested, and tests write only under the harness `TMPDIR`. ARCH-ORDER: **pass** — the module carries no state between events; the one latch that does (`_parley_bufs` vs. a buffer edited after classification) is the `separator-edited-away` axis and is refused rather than degraded. ARCH-FUNERAL: **pass** — production code creates only buffer-local keymaps; the test residue is now one directory + a 4 KB `state.json` per run, collected by `test-clean-env`.

## 7. Plan revision recommendations

- A `## Revisions` entry recording that the de-line-numbering pass of `1a9cd92c` corrupted five passages, listing them, and correcting `:1131` back to "the first cut used `fence.open_len`" — the entry currently reads as though the bug and its fix were the same predicate.
- Apply the `:1110` Revisions delta ("both surfaces go through one classifier, `entity_textobj.parsed_for`") to the body it contradicts: `:98` and `:945` still say `DeleteEntity` is "`ExchangeCut`'s preamble". That is BR-13's stated rule — a Revisions entry must be applied to the body in the same edit — on its second miss.
- A `## Revisions` entry recording that the fence contract was resolved in favour of the invariant over "`to_end` runs through the end of the exchange", since `daE` inside a fenced block now stops inside it. The issue's Done-when still states the unqualified form.

```findings
dispose:
  - id: BR-13
    disposition: not-addressed
    note: |
      Line numbers were stripped; the false claim was not. plan.md:98 and :945 still say DeleteEntity is "ExchangeCut's preamble" (":945" now reads "verbatim ()"), while init.lua's delete_entity_range calls entity_textobj.parsed_for and the plan's own Revisions at :1110 says so.
  - id: BR-20
    disposition: addressed
    note: |
      Both halves of the stated mechanical rule verified: all 16 changed lua/+tests/ paths appear in the plan, every file:line the plan names resolves, and zero lua/*.lua:NNN refs remain. plan:7 now names lexical.is_fence_delim + code_block_memo, both genuinely required by entity_range. Its BR-13 instance is disposed separately.
  - id: BR-23
    disposition: not-addressed
    note: |
      Atlas untouched this round; no tests/perf or tests/arch file references entity_range. I re-derived via the page's own recipe: 12.8/25.5/101.7 ms vs the published 13.6/24.7/97.8, so the numbers are accurate today and the exposure is silent future drift, as stated.
  - id: BR-24
    disposition: not-addressed
    note: |
      entity_delete_parity_spec.lua:78 still declares `shape` at module scope, each it() assigns it, fresh() reads it.
  - id: BR-25
    disposition: not-addressed
    note: |
      keybinding_registry.lua:483/:493/:503 unchanged - "(dae/yae/cae)", "(die/yie/cie)", "(daE)".
  - id: BR-27
    disposition: not-addressed
    note: |
      atlas:94-95 unchanged and measured still wrong (range() returns nil on an in-fence heading, no Precedence row for it); entity_range.lua:10 still says "Five rules" and this round added a "Rule 7" at :186, so the header is now two short. atlas:94's "a range never spans one" is additionally falsified - see the new Important.
  - id: BR-30
    disposition: addressed
    note: |
      heading_level_at (entity_range.lua:104) is the one classification consumed by the dispatch, the section forward scan and the to_end backward scan. Measured: BR-30's plain-markdown case now returns section 1..8 (was 1..4); chat form pinned at entity_range_spec.lua:503-522.
  - id: BR-31
    disposition: addressed
    note: |
      420d046a: `local closer = delim:match("~") and "~~~" or "```"` computed once with one consumer; the discarded initializer is gone.
  - id: BR-32
    disposition: addressed
    note: |
      balance_fences (entity_range.lua:192) runs at :326; range(p,L,11,{scope="to_end"}) now returns 11..12, not 11..15. Class guard at entity_range_spec.lua:545-577, verified red in a scratch copy with the call commented out (45 pass / 1 fail, exactly that test). Residual coverage of a second exit is raised as a new finding rather than a reversal.
  - id: BR-33
    disposition: addressed
    note: |
      run() now deletes the file as well as the buffer. Measured per-run residue under the harness scratch root dropped from 489 files / 1.9 MB to 1 file (state/state.json) / 4 KB.
findings:
  - id: new
    severity: Important
    family: range-splits-a-structure
    title: |
      the fence post-condition is skipped on M.range's question exit, and states parity rather than block coverage
    detail: |
      5th in this family - do NOT patch the question branch. THE RULE, both halves structural. (1) The post-condition must be UNAVOIDABLE. BR-32's spec asserted "M.range has exactly one exit"; there are two, and the guard landed on one. entity_range.lua:284 returns the question range twelve lines above balance_fences at :326. Split the body into a private compute(...) so M.range = compute -> balance_fences -> clamp and no return can bypass it. Measured on a real parse_chat over a transcript whose answer was cut off mid-code-block (opener in exchange 1, closer in exchange 2 - what a stopped generation produces): range(p,L,5) returns question 5..10 carrying ONE fence delimiter, and dae on the question line leaves a bare ```lua opener so every following line renders as code. range(p,L,11) is the mirror image. This is BR-21's corruption, undo-recoverable, hence Important on the same calibration BR-21/BR-26/BR-32 were given. (2) Parity is weaker than the stated invariant. atlas/chat/entity_delete.md:94 says "a range never spans one"; the check only forbids an ODD count. Measured, fixture with adjacent backtick and tilde blocks: range(p,L,9,{scope="to_end"}) returns 9..13, two delimiters, passes, and deletes block A's closer plus block B's opener. Express the check over the in_code memo M.range already builds at :268 - "no fenced block partially covered" - instead of rescanning and counting delimiters. This half is lower-consequence because Parley's own code_block_memo is a flat toggle that ignores delimiter char and width, so the post-delete document reconciles internally while a CommonMark renderer would not. The property corpus at entity_range_spec.lua:547-556 cannot see either half: all four fixtures are chat-classified and fence-balanced within a single exchange span. Add one whose fence is unbalanced within an exchange.
  - id: new
    severity: Minor
    family: docs-edit-mangles-prose
    title: |
      the de-line-numbering pass damaged five plan passages, one of which inverts the record it keeps
    detail: |
      3rd in this family. THE RULE - a mechanical substitution over prose must be read back AS PROSE, not diffed as tokens; BR-27 stated the same rule for docs accompanying a behavior change and it repeated on a pure-prose edit, so the enforceable form is that the author reads the changed paragraphs end-to-end before committing. The enumeration, all in workshop/plans/000262-delete-entity-at-cursor-plan.md - :945 "ExchangeCut's preamble verbatim ()" (empty parens where the ref was); :956 "buffer_mutation_spec.lua's allow-list's allow-list"; :860 "prep_chat calls tool_folds.setup(buf) (prep_chat)"; :107 "document.exchange(doc,row) (document.exchange)"; :804 "outline.lua's in-code guard's existing ruling". The fifth is a factual inversion rather than a typo - :1131 now reads "The first cut used lexical.is_fence_delim for the wall and code_block_memo for the in-block test; they recognise different fences", but the first cut used fence.open_len, so as rewritten the Revisions entry says the bug and its fix were the same predicate, erasing exactly the record BR-26 exists to keep.
  - id: new
    severity: Minor
    family: checkbox-without-artifact
    title: |
      cae is claimed by Done-when and by a test's own name, and is executed nowhere
    detail: |
      3rd in this family. THE RULE - a claim of coverage must name the artifact that would go red without it; an enumeration in a Done-when bullet becomes a loop or one assertion per item, never prose in a test title. Done-when says ae/ie work "with every operator (d/y/c/v at minimum)". Measured - dae, daE, yae, vae and die are all driven in tests/integration/entity_textobj_spec.lua, and the string "cae" appears in tests/ only inside two comments; the test at :220 is titled "die and cae work, as Done-when claims for every operator" and runs only die. cae over a linewise object leaves insert mode open, which is precisely the class of editor-state surprise the vae and closed-fold tests exist to catch.
```

---

## Re-review — 2026-09-16T17:35:08-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 262 — Delete entity at cursor — markdown section, paragraph, or chat question |
| repo | parley.nvim |
| issue file | workshop/issues/000262-delete-entity-at-cursor.md |
| boundary | whole-issue close |
| milestone | — |
| window | 85e116c2da14c941735c7d7e67bb023aaff3aa00..febdb67b2910f1db0c1f84d0e2442c225a9d6532 |
| command | sdlc close --issue 262 |
| reviewer | claude |
| timestamp | 2026-09-16T17:35:08-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The feature itself is well-built and the pure/IO split is real: `entity_range.range` is a genuine pure function over `(parsed, lines, row, opts)` with 46 mock-free unit cases, the two surfaces share one range function *and* one classifier, and every suite I ran is green by exit code (entity_range 46/46, markdown_heading 4/4, conformance 1/1, starter_config 7/7, entity_textobj 15/15, parity 11/11, keybinding_agreement 33/33, outline 20/20; luacheck clean; working tree clean). What blocks SHIP is that **`range-splits-a-structure` is live again — this time introduced by the fix for it**. `confine_to_blocks`' "begins part-way into a block" loop advances `first` *onto* the closing fence instead of past it, so `daE` with the cursor inside a code block deletes the block's closer and strands its opener. I reproduced this end-to-end on the parity spec's own FIXTURE (cursor on `{}` at row 16 → buffer left with a bare ```` ```json ````), and an independent oracle over the property test's own five fenced fixtures fails **16 combinations**, every one of them `to_end`. The existing property test cannot see any of it because its two assertions are character-for-character the predicate the guard implements. Additionally, BR-34's *structural* half was declined: there are still two exits and two `confine_to_blocks` call sites, while the new docstring asserts "M.range's single exit". Seven of the eight open findings are carried forward untouched.

## 1. Strengths

- **`entity_range.lua` is a real pure core.** Every rule is a function of `(parsed, lines, row)`; `tests/unit/entity_range_spec.lua` drives 46 cases over literal Lua arrays — no buffer, no `nvim_*`, no mocks. ARCH-PURE passes cleanly.
- **One classifier, structurally shared.** `init.lua:4536` calls `entity_textobj.parsed_for` rather than re-asking `not_chat`; the BR-2 divergence is impossible by construction, not merely tested away.
- **The heading dialect is genuinely single-sourced.** `markdown_heading.lua` + `markdown_heading_conformance_spec.lua` pin it against `document/lexical.lua`, with both `outline.lua` consumers folded on (`outline.lua:57-58`, `:254`). The indent ladder survives the collapse exactly (`("  "):rep(level)` = the old 2/4/6). Textbook ARCH-DRY.
- **`transcript_header_end` states the right rule** (`chat_parser.lua:78-133`): a contiguous run of header-shaped lines, reusing `parse_header_key_value` rather than adding a fourth hardcoding of the transcript shape, with the front-matter branch explicitly widened to accept what `defaults.chat_template` actually writes.
- **The `starter_config` carve-out is scoped, not widened** (`starter_config.lua:25-35`), and the negative test proving a bare `gf` is *still* excluded is the correct shape of evidence for relaxing a filter.
- **The parity spec's axis enumeration is written down** (`entity_delete_parity_spec.lua:47-61`), including why in-flight generation is deliberately not an axis. That artifact is what stops the next axis being rediscovered.

## 2. Critical findings

None.

## 3. Important findings

**`lua/parley/entity_range.lua:218-221` — `daE` inside a code fence deletes the closer and strands the opener. This is the 6th finding in family `range-splits-a-structure`; do not patch this instance.**

Measured end-to-end on the parity spec's own FIXTURE, cursor on `{}` (row 16, inside the ```json block at 15-17), `normal daE`:

```
14  🔧: tool call
15  ```json
16  {}
17  📝: a summary        ← closer at 17 and the blank at 18 deleted
```

The fence is now unterminated and everything below renders as code — BR-21's exact corruption, reproduced through the guard added to prevent it.

Root cause: `code_block_memo` sets `in_code` **false** on a closer line. The begin-advance loop's condition `in_code[first] and in_code[first-1]` therefore terminates *on* the closer rather than after it, so a range that started inside a block is relocated to start at that block's closing delimiter. Trace on `prose / "" / ```lua / a / "" / b / ``` / tail`: row 11, `to_end` → paragraph 11..12 → `last = bounds.last` (15) → advance 11→12→13→**14** (the closer) → returns 14..15.

**The rule, and why the family keeps recurring: the post-condition and its test assert the same expression, so the test is structurally incapable of failing.** `entity_range_spec.lua:579` and `:582` are `assert.is_false(memo[r.last])` and `assert.is_false(memo[r.first] and memo[r.first-1])` — character-for-character `confine_to_blocks`' own loop conditions. A guard tested by its own predicate reports "I did what I did." The oracle has to be stated over the **effect**: apply the range, recompute `code_block_memo` over the surviving lines, and assert (a) no surviving line changes its `in_code` value and (b) no block is left open at EOF that was closed before. I ran exactly that over the spec's five `FENCED` fixtures × every row × both scopes × both `inner` values: **16 failures, all `to_end`** — fixture 1 rows 11/13, fixture 2 rows 9/13, fixture 3 row 10, fixture 4 row 9, fixture 5 rows 9/13. Every one of those fixtures is already in the suite and already green. `entity_range_spec.lua:524` ("to_end from inside a fence still stops at the exchange bound") is green on the corrupt `14..15` because it only asserts `r.first >= 11`.

Fix sketch: advance on `in_code[first - 1]` (walk forward while the *previous* line is inside a block, which clears the closer), and replace both assertions with the surviving-document oracle above. That oracle also reds BR-21/BR-26/BR-30/BR-32 with their fixes reverted, which is the property the family has never had.

## 4. Minor findings

- `lua/parley/init.lua:4518` — `M.cmd.ExchangePaste` lost its docstring: `--- Paste previously cut exchanges after the exchange at cursor.` now heads the new `delete_entity_range` comment block. **4th in family `docs-edit-mangles-prose`** (BR-18, BR-27, BR-35); sweep it with those rather than as a one-off — the rule BR-35 already stated (read the changed passage back as prose, not as tokens) is the fix, and this is the first instance of it landing in `lua/` rather than in a plan.

## 5. Test coverage notes

- The green suites are green by exit code, verified: entity_range 46/46, markdown_heading 4/4, conformance 1/1, starter_config 7/7, entity_textobj 15/15, parity 11/11, keybinding_agreement 33/33 (with `"o"` inside both guards), outline 20/20.
- **No test drives `daE` from inside a fenced block.** The fixture that would catch it is already in `entity_delete_parity_spec.lua` (rows 15-17), but parity compares two surfaces that share one range function, so parity is the wrong instrument — this needs a unit assertion over the surviving document.
- `cae` remains executed nowhere (BR-36); the only artifact naming it is a test *title*.
- The streaming-refusal test substitutes `buffer_edit.replace_user_lines` with `error(...)` — a function stub, not a stateful fake. Acceptable here and correctly justified in the comment (the real guard lives in `document_user_guards_spec`), but it is the one place ARCH-MOCK's seam is a monkeypatch rather than an injection.

## 6. Architectural notes

Per-marker, at-review:

- **ARCH-DRY — pass.** One heading dialect (pinned by conformance test), one fence predicate, one exchange-span definition, one classifier, keymaps through the registry. Minor observation only: `confine_to_blocks` re-scans lines with `is_fence_delim` to compute `touches` when the `in_code` memo it already receives encodes the same information.
- **ARCH-PURE — pass.** All dispatch, bounds, blank and 📝 policy are functions over `(parsed, lines, row)`; `entity_textobj` is a genuinely thin shell (cursor read, fold-state toggle, `normal! V`).
- **ARCH-PURPOSE — flag.** Two counts. (a) `to_end` is the scope the issue's own framing calls the point ("I've read enough, drop the rest of this answer"), and it is the scope that corrupts. (b) BR-34 named the *class* fix — "do NOT patch the question branch; split the body into a private `compute(...)` so no return can bypass" — and the round patched the named branch instead. That is the instance, not the class, and `entity_range.lua:194` now asserts the class fix was made ("M.range's single exit") when `M.range` has two `confine_to_blocks` call sites at `:304` and `:347` and nine `return` statements.
- **ARCH-MOCK — N/A** (no external binary or service; Neovim exercised for real), with the monkeypatch noted in §5.
- **ARCH-CONSTRAINTS — flag (= BR-23).** The keystroke budget missed (24.7 ms vs < 16 ms at 5 000 lines) and the miss is honestly recorded, but the declared envelope has no executable check, and the atlas page says so about itself. A number the suite cannot re-derive is a claim.
- **ARCH-SECURE — pass.** Transcript input is treated as untrusted: `range` returns `nil` rather than a partial range, bounds are re-asserted at the exit, and `parse_chat` is `pcall`-wrapped in `parsed_for` with "not a chat" and "will not parse" kept distinct. No secrets touched.
- **ARCH-ORDER — flag, and this is where the blocking finding lives.** The component is correctly stateless, and the one unblockable ordering (an edit landing mid-stream) is handled by inheriting `buffer_edit`'s refusal with the asymmetry documented. But the entry's highest-leverage lens — *tests that restate the transition implementation rather than an independently stated invariant* — is exactly what `entity_range_spec.lua:579/:582` do. The guard and its oracle are one expression.
- **ARCH-FUNERAL — pass.** Only keymaps are created, ended by the existing buffer-local lifecycle; the parity spec now releases both buffer and file per iteration.

## 7. Plan revision recommendations

The plan needs one `## Revisions` entry this round, and it should carry the four prose repairs together rather than one at a time:

- **"The fence post-condition, third statement."** Record that `balance_fences` (delimiter parity) was replaced by `confine_to_blocks` (block coverage), that the replacement still admits a range starting on a closer, and that the property test's assertions were the guard's own predicate. Correct the body at the same time: `entity_range.lua:10` and `plan.md:66` both say "Five rules, each stated once" over six listed and seven implemented (BR-27), and `plan.md:1131` still inverts the BR-26 record — the first cut used `fence.open_len`, not `lexical.is_fence_delim` (BR-35).
- **Apply the deltas to the body they contradict.** `plan.md:98` and `:945` still describe `DeleteEntity` as "`ExchangeCut`'s preamble" (`:945` reads "verbatim ()") while `init.lua`'s `delete_entity_range` calls `entity_textobj.parsed_for`, and the plan's own Revisions already says so (BR-13). Same edit should repair `:956` ("allow-list's allow-list"), `:860`, `:804` and `:107`.

```findings
dispose:
  - id: BR-13
    disposition: not-addressed
    note: |
      plan.md:98 and :945 still say DeleteEntity is "ExchangeCut's preamble" (":945" reads "verbatim ()"); init.lua's delete_entity_range calls entity_textobj.parsed_for.
  - id: BR-23
    disposition: not-addressed
    note: |
      Nothing under tests/perf or tests/arch references entity_range; atlas/chat/entity_delete.md:105-116 still states 13.6/24.7/97.8 ms beside its own admission that no spec guards them.
  - id: BR-24
    disposition: not-addressed
    note: |
      entity_delete_parity_spec.lua:78 still declares `shape` at module scope with fresh() reading it; :85 `did_setup` is a second module-level mutable on the same path.
  - id: BR-25
    disposition: not-addressed
    note: |
      keybinding_registry.lua:483/:493/:503 verbatim unchanged - "(dae/yae/cae)", "(die/yie/cie)", then "(daE)" alone.
  - id: BR-27
    disposition: not-addressed
    note: |
      atlas:94-95 verbatim unchanged and re-measured still wrong - range() returns nil on a `# x` inside a fence (neither section nor content), with no Precedence row for it; entity_range.lua:10 still says "Five rules" over six listed and seven implemented.
  - id: BR-34
    disposition: not-addressed
    note: |
      Half (1) declined: the question branch was patched (entity_range.lua:304) rather than made unavoidable, so there are still two exits and two call sites while :194 claims "M.range's single exit". Half (2): parity was replaced by a coverage check that itself lets a range begin on a closer - measured, see the new finding.
  - id: BR-35
    disposition: not-addressed
    note: |
      All five passages verbatim: plan.md:945 "verbatim ()", :956 "allow-list's allow-list", :860, :804, :107, and the :1131 inversion of the BR-26 record.
  - id: BR-36
    disposition: not-addressed
    note: |
      "cae" still appears in tests/ only inside comments and the title of entity_textobj_spec.lua:220, whose body runs only die.
findings:
  - id: new
    severity: Important
    family: range-splits-a-structure
    title: |
      daE inside a code fence deletes the block's closer and strands its opener - the guard's own test asserts the guard's own predicate
    detail: |
      6th in this family; do NOT patch the instance. Measured end-to-end on entity_delete_parity_spec.lua's own FIXTURE: cursor on `{}` (row 16, inside the ```json block at 15-17), `normal daE` leaves a bare ```json and every line below renders as code - BR-21's corruption, reproduced through the fix for it. Root cause at entity_range.lua:218-221: code_block_memo marks a CLOSER as in_code=false, so the loop condition `in_code[first] and in_code[first-1]` stops ON the closer instead of past it, relocating the range to start at the closing delimiter. THE RULE - a post-condition tested by its own predicate cannot fail. entity_range_spec.lua:579 and :582 are character-for-character confine_to_blocks' loop conditions. The oracle must be stated over the EFFECT - apply the range, recompute code_block_memo over the surviving lines, and assert no surviving line changes its in_code value and no block is left open at EOF that was closed before. I ran that oracle over the spec's own five FENCED fixtures x every row x both scopes x both inner values - 16 failures, all to_end (fx1 rows 11/13, fx2 9/13, fx3 10, fx4 9, fx5 9/13), while the shipped assertions are green on all of them. entity_range_spec.lua:524 is green on the corrupt 14..15 because it only asserts r.first >= 11. Fix sketch - advance on `in_code[first - 1]` alone, and replace both assertions with the surviving-document oracle, which also reds BR-21/BR-26/BR-30/BR-32 with their fixes reverted.
  - id: new
    severity: Minor
    family: docs-edit-mangles-prose
    title: |
      M.cmd.ExchangePaste lost its docstring to the inserted delete_entity_range comment block
    detail: |
      4th in this family (BR-18, BR-27, BR-35). init.lua:4518 - "--- Paste previously cut exchanges after the exchange at cursor." now heads delete_entity_range's comment block, and ExchangePaste at :4563 has none. Sweep it with BR-27 and BR-35 as one enumeration under the rule BR-35 already stated; this is the first instance of that rule breaking in lua/ rather than in a plan.
```

---

## Re-review — 2026-09-16T17:55:03-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 262 — Delete entity at cursor — markdown section, paragraph, or chat question |
| repo | parley.nvim |
| issue file | workshop/issues/000262-delete-entity-at-cursor.md |
| boundary | whole-issue close |
| milestone | — |
| window | 85e116c2da14c941735c7d7e67bb023aaff3aa00..b4ebed68ca17a3632d27a502b7f558db47b3f0bc |
| command | sdlc close --issue 262 |
| reviewer | claude |
| timestamp | 2026-09-16T17:55:03-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

This round did exactly two things — BR-34 (fence post-condition stated as block coverage, run at both exits) and BR-37 (advance past the closer instead of stopping on it) — and both are genuinely fixed and genuinely regression-tested: I reverted BR-37's fix in a scratch tree and `entity_textobj_spec.lua:288` went red ("daE at row 11 left 1 fence lines (odd)") while the unit invariant stayed 46/46 green, confirming both the bug and the commit's diagnosis of why it had survived. An effect-stated oracle of my own (apply the range, recompute `code_block_memo` over the survivors, require no surviving line's `in_code` to change) is clean over eight fenced fixtures × every row × both scopes × both inner values, and a 400-document fuzz found zero out-of-bounds ranges, zero header-floor violations and zero errors. What blocks SHIP is that the BR-34 fix introduced a new defect of the same family: `confine_to_blocks` reads `in_code[range.last]` as a proxy for "ends part-way into a block", but Parley's memo also closes a block at a partition line, so a range that covers a partition-closed block *completely* is judged part-way-in and silently truncated — measured end-to-end, `dae` on the `💬:` line of an exchange whose answer was cut off mid-code-block deletes only the question stanza and strands the code block under no question. The eight other open Minors (BR-13, BR-23, BR-24, BR-25, BR-27, BR-35, BR-36, BR-38) were not touched this round and remain exactly as reported.

### 1. Strengths

- `lua/parley/entity_range.lua` is genuinely pure — 400 randomly generated documents × every row × both scopes × both inner values produced zero errors, zero inverted/out-of-bounds ranges and zero ranges reaching into a header the shape test recognises. The ARCH-SECURE claim in the plan is backed by behavior, not assertion.
- `tests/integration/entity_textobj_spec.lua:249-296` is a real independent oracle: it drives `dae`/`daE` through the real keymaps on a real buffer and counts fences with a pattern that shares nothing with `lexical.is_fence_delim`. I verified it fails on the reverted build and the unit invariant does not — the commit's "both demonstrated on the same tree" claim holds.
- `tests/unit/markdown_heading_conformance_spec.lua` is enforcement rather than documentation: it drives `lex_start`/`lex_step` over a corpus that straddles the cap, the required space, indentation and structural markers, so the second copy of the dialect cannot drift silently (ARCH-DRY).
- `entity_textobj.parsed_for` as the single classifier consumed by both `M.select` and `init.lua:4529 delete_entity_range` is the right seam — it is what makes the parity claim structural rather than coincidental.
- `workshop/lessons.md` gained eleven entries that are rule-shaped and specific ("read the exit code, not the Success lines"; "a test that computes its expectation with the implementation's own predicate cannot detect a wrong predicate"), which is what AGENTS.md §4 asks for.

### 2. Critical findings

None.

### 3. Important findings

**The fence post-condition truncates ranges that completely cover a partition-closed block** — `lua/parley/entity_range.lua:213`, applied at both `:314` and `:357`.

This is the **7th finding in family `range-splits-a-structure`**, and per the escalation rule I am naming the rule, not the site. Measured end-to-end through the real keymaps on a transcript whose answer was cut off mid-code-block (the stopped-generation shape BR-34 itself named):

```
5  💬: q one      7  🤖: [A]     10  ```lua      13  💬: q two
6               8  text        11  partial     ...
                9              12              17  ```
```

`dae` on row 5 yields `question 5..9`, not `5..12`. The surviving buffer is header, then a bare ` ```lua ` at line 5 with `partial` under it — answer content orphaned under no question, which is the one thing the Spec says the exchange span exists to prevent. Not question-specific: on the sibling fixture `dae` on a `## heading` at row 8 yields `section 8..10` instead of `8..12`, and `daE` from row 8 yields the same — so "I've read enough, drop the rest of this answer", the feature's headline use case, demonstrably does not drop the rest precisely when the answer ended mid-block.

The rule, both halves:

1. **The post-condition must be stated over the EFFECT of the delete, not over a proxy read from the pre-delete memo.** `in_code[last]` is not "ends part-way into a block" — `code_block_memo` closes a block at a partition (`💬:`/`🤖:`/…) as well as at a delimiter, so a range covering an implicit block *whole* reads as part-way-in. The enforceable form is the one BR-37 asked for and this round did not adopt: recompute `code_block_memo` over the surviving lines and require that no surviving line's `in_code` changes, shrinking only when that fails and only by the minimum. That property is a function of the outcome, cannot agree with itself, and catches both the corruption direction and this over-truncation direction. `tests/unit/entity_range_spec.lua:577-584` still restates `confine_to_blocks`' own two loop conditions character-for-character; the new integration oracle at `:288` is independent but asserts fence-line *parity* — the exact property `febdb67b` established is too weak — so neither assertion can see this.
2. **One unavoidable exit.** BR-34 asked for `M.range = compute → post_condition → clamp` with `compute` private. Instead the call was added at the second exit by hand (`:314` and `:357`), which is fixing the instance; and the defect above is precisely what that hand-added call does at the question exit. A third kind added later skips it again.

Measured prevalence for the family: 7 findings across 5 rounds — paragraph wall, then section forward scan, then `to_end`'s overwrite, then fence flavour, then parity-vs-coverage, then stranded opener, now the guard itself. Every earlier fix moved or added a guard at a call site; this is the first defect caused by the guard.

### 4. Minor findings

- Plan body edited substantially in `1a9cd92c` (a new "Citation policy" block, 12+ rewritten passages) with no `## Revisions` entry for that round — the last entry is still "M2 boundary review (four rounds)". Same AGENTS.md rule BR-28 named.
- `tests/unit/tool_resources_spec.lua` dies silently mid-run under the parallel runner at HEAD (2 of 4 `make test-unit` runs; nvim exits nonzero after the 6th test with no traceback, Success lines already printed). Passes in isolation and with `JOBS=1`; 0 of 3 failures at base. Same signature BR-29 named, in a spec this diff does not touch.

### 5. Test coverage notes

- `make test` exits 2 at HEAD. Two failing files: `tests/unit/parley_harness_golden_spec.lua` (11 failures, **pre-existing** — identical 11 failures at base `85e116c2`, a system-prompt golden mismatch, environmental) and `tests/unit/tool_resources_spec.lua` (the flake above). No new deterministic failure is attributable to this window. A close `--verified` string should say this rather than claim a green suite.
- `entity_range` 46/46, `entity_textobj` 15/15, `entity_delete_parity` and the rest pass in isolation; the parity spec now completes and releases both its buffers and its files.
- `cae`/`cie` still execute nowhere (BR-36). I confirmed `cae` works end-to-end, so the gap is coverage, not behavior.
- The unit fence invariant and the new integration oracle would both stay green through the Important above. The surviving-document oracle is the assertion that closes that gap, and it reds BR-21/BR-26/BR-30/BR-32/BR-37 with their fixes reverted as a bonus.

### 6. Architectural notes

- **ARCH-DRY — pass.** One heading dialect, extracted and *enforced* by a conformance test; one fence predicate shared by the wall and the in-block test; one exchange-span definition. The 8-line entity dispatch block is duplicated in `prep_chat` and `setup_markdown_keymaps`, but the entire surrounding table already is — extracting only these five would be inconsistent. `exporter.lua:539,541` still hand-maps `^## `/`^### ` independently; pre-existing, out of diff, and recorded in the plan's Revisions for whoever widens the dialect.
- **ARCH-PURE — pass.** `entity_range` and `markdown_heading` take `(parsed, lines, row)` and return values; their specs use literal line arrays and no mocks. I ran both through a headless harness with no buffer at all.
- **ARCH-PURPOSE — flag.** Shadow-sweep of the single-source dialect is clean (entity_range derives, both outline paths derive, lexical is pinned by conformance). The flag is the Important above: the round answered BR-34's measured instances and skipped its structural half, which is the instance rather than the class — the same pattern the family has now shown seven times.
- **ARCH-MOCK — N/A.** No external binary or service; Neovim is exercised for real.
- **ARCH-CONSTRAINTS — flag (BR-23, unchanged).** `atlas/chat/entity_delete.md:105-116` declares 13.6 / 24.7 / 97.8 ms and then states in its own prose that no spec guards them. A declared envelope with no executable check is a claim.
- **ARCH-SECURE — pass.** The transcript is treated as untrusted: `range` returns `nil` rather than a partial range, and the fuzz confirms no inverted, out-of-bounds or header-reaching range over 400 malformed documents. The unparsable-header path refuses with a message on both surfaces rather than degrading to unclamped markdown.
- **ARCH-ORDER — pass.** `entity_range` carries no state between events; the one unblockable ordering (an edit landing while a response streams) is documented, scoped out of the parity claim, and tested at the `buffer_edit` seam.
- **ARCH-FUNERAL — pass.** The parity spec now deletes both the buffer and the file per iteration. The five new `workshop/plans/000262-*-{review,gate}.md` ledgers are archived with the issue.

### 7. Plan revision recommendations

- A `## Revisions` entry for the close-review round recording the citation-policy change and the fence-rule restatement (`1a9cd92c`), since the body was edited without one.
- Once the Important is fixed, an entry correcting the fence rule's statement in the body: the post-condition is over the delete's effect, not over `in_code` at the range edges.
- Repair the five passages BR-35 enumerated, including the factual inversion at `:1131` — the diff of `1a9cd92c` shows the substitution turned `fence.open_len` into `lexical.is_fence_delim`, so the entry now says the bug and its fix were the same predicate.

```findings
dispose:
  - id: BR-13
    disposition: not-addressed
    note: |
      plan.md:945 still reads "ExchangeCut's preamble verbatim ()" while delete_entity_range uses entity_textobj.parsed_for; unchanged this round.
  - id: BR-23
    disposition: not-addressed
    note: |
      tests/perf/ has no entity_range spec; atlas/chat/entity_delete.md:113 still states in its own prose that nothing guards the numbers.
  - id: BR-24
    disposition: not-addressed
    note: |
      entity_delete_parity_spec.lua:78 still declares module-level `shape`, assigned in each it() body and read by fresh().
  - id: BR-25
    disposition: not-addressed
    note: |
      keybinding_registry.lua:483/:493/:503 still read "dae/yae/cae", "die/yie/cie", "(daE)".
  - id: BR-27
    disposition: not-addressed
    note: |
      Measured - range() returns nil on a fenced "# heading" row while atlas:94-96 still calls it content; entity_range.lua:10 still says "Five rules" over six, with a separate "Rule 7" at :186.
  - id: BR-34
    disposition: addressed
    note: |
      Both halves verified - range(p,L,5) on the stopped-generation fixture now carries zero delimiters, and the coverage check catches the adjacent-block case parity misses; the structural half (private compute, one unavoidable exit) was not adopted, and the new Important is its consequence.
  - id: BR-35
    disposition: not-addressed
    note: |
      All five passages unchanged; the 1a9cd92c diff shows the fence.open_len -> lexical.is_fence_delim substitution that inverted the :1131 record.
  - id: BR-36
    disposition: not-addressed
    note: |
      "cae" still appears in tests/ only inside comments; entity_textobj_spec.lua:220 is still titled for die and cae and runs only die.
  - id: BR-37
    disposition: addressed
    note: |
      Reverted the fix in a scratch tree - entity_textobj_spec.lua:288 goes red while the unit invariant stays 46/46 green, and an effect-stated oracle over eight fenced fixtures is clean on the shipped build.
  - id: BR-38
    disposition: not-addressed
    note: |
      init.lua:4518 still heads delete_entity_range's comment block with ExchangePaste's docstring; ExchangePaste at :4563 still has none.
findings:
  - id: new
    severity: Important
    family: range-splits-a-structure
    title: |
      the fence post-condition truncates ranges that completely cover a partition-closed block, so a whole-exchange delete strands answer content
    detail: |
      7th in this family - do NOT patch the question exit. entity_range.lua:213 reads
      in_code[range.last] as a proxy for "ends part-way into a block", but code_block_memo
      also closes a block at a partition line, so a range covering a partition-closed block
      WHOLE reads as part-way-in and is silently shrunk. Measured end-to-end through the real
      keymaps on a transcript whose answer was cut off mid-code-block: dae on the question line
      returns 5..9 instead of 5..12 and leaves a bare ```lua orphaned under no question,
      contradicting Done-when's "deletes that whole question/answer exchange" and the Spec's
      "does not leave orphaned answer text". Not question-specific - dae on a heading gives
      section 8..10 instead of 8..12, and daE from the same row gives 8..10, so the "drop the
      rest of this answer" case fails exactly when a stopped generation produced the document.
      THE RULE, both halves. (1) State the post-condition over the EFFECT, not over a proxy
      read from the pre-delete memo: recompute code_block_memo over the surviving lines and
      require no surviving line's in_code to change, shrinking only when that fails and only
      by the minimum. That is the oracle BR-37 asked for; entity_range_spec.lua:577-584 still
      restates confine_to_blocks' own loop conditions, and the new independent oracle at
      entity_textobj_spec.lua:288 asserts fence-line PARITY - the property febdb67b itself
      established is too weak - so neither assertion can see this. (2) One unavoidable exit:
      split the body into a private compute(...) so M.range = compute -> post_condition ->
      clamp; the call was instead added by hand at the second exit (:314 alongside :357), which
      is the instance again, and a third kind added later skips it.
  - id: new
    severity: Minor
    family: plan-edit-unrecorded
    title: |
      the close-review round edited the plan body with no "## Revisions" entry recording it
    detail: |
      1a9cd92c added a "Citation policy" block and rewrote a dozen passages across the plan;
      the last Revisions heading is still "2026-09-16 - M2 boundary review (four rounds)".
      AGENTS.md: revising a plan artifact mid-stream appends a Revisions entry (timestamp +
      reason + delta) rather than overwriting. Same rule BR-28 named one boundary earlier.
  - id: new
    severity: Minor
    family: silent-spec-abort
    title: |
      tests/unit/tool_resources_spec.lua dies silently mid-run under the parallel runner at HEAD
    detail: |
      make test-unit failed 2 of 4 runs at b4ebed68 with nvim exiting nonzero after the 6th
      test, no traceback, Success lines already printed - the BR-29 signature. 0 of 3 failures
      at base 85e116c2; passes in isolation and with JOBS=1. The spec is untouched by this diff,
      so the likely trigger is the four added unit spec files changing scheduling pressure.
      Separately, tests/unit/parley_harness_golden_spec.lua fails 11/11 at BOTH base and head -
      pre-existing and environmental, not this window's - but it means make test exits 2 here,
      and the close's --verified string should say so rather than claim a green suite.
```
