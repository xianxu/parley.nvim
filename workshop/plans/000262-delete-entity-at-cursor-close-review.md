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
