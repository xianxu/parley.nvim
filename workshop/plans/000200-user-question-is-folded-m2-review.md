# Boundary Review — parley.nvim#200 (milestone M2)

| field | value |
|-------|-------|
| issue | 200 — user question is folded |
| repo | parley.nvim |
| issue file | workshop/issues/000200-user-question-is-folded.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | dc5ee17994443c4bbd663675f17fe8ca32adaa60..c76b8c088f4a69dbdd1ae79d9b3d3702a5ab05d0 |
| command | sdlc milestone-close --issue 200 --milestone M2 |
| reviewer | claude |
| timestamp | 2026-08-21T11:47:17-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The grammar extraction itself is well done — `lua/parley/fence.lua` has a clean, length-carrying API, the property test pins the invariant rather than literals, the `%1`-backreference reader bug in `serialize` was real and is now fixed with teeth, and all four claimed conversions go red when reverted (I checked each). What blocks SHIP is that two of the four conversions introduced correctness regressions against the base commit, both reproduced, and both landing squarely on the invariant M2 exists to defend ("`🔧:`/`📎:`/`📝:` blocks are always folded, each anchored on its own marker line"). In `answer_structure`, the new unterminated-fence rewind misfires on a *correctly closed* fence when the close is the last line of the reduced span — I measured real Neovim fold state showing the tool body leaking out of its fold and a fold anchored on an in-body `📝:` line. In `chat_parser`, the in-body suppression is unbounded: an opener with no matching close swallows every structural marker to EOF, taking a 3-exchange chat to 1. Reachable from an ordinary answer that quotes a `📎:` line inside a markdown code block — i.e. a chat about parley's own format. Both are exactly the "silent, permanent, whole-file mis-parse" pathology #200 was opened to remove, and neither has a test.

## 1. Strengths

- **`lua/parley/fence.lua:29-47`** — `open_len` returning a length and `closes(line, n)` taking one is the right decomposition; it makes "the same pair" a value the consumers pass around rather than a rule each re-derives. Surface is stable for downstream work.
- **`tests/unit/fence_spec.lua:29-47`** — the property test ("always picks a fence that its own content cannot close") pins the guarantee over 13 generated shapes instead of asserting three literals. This is the right instinct for a grammar that scans arbitrary model output.
- **The `%1` backreference finding is genuine and pinned.** I reverted `fenced_body` in `lua/parley/tools/serialize.lua:41-43` to the two-pattern backreference; `tools_serialize_spec` went 16 pass / 2 fail. Teeth confirmed.
- **All four claimed conversions have teeth** (verified by reverting each in a scratch copy): chat_parser suppression → 3/5 fail; answer_structure → 2/7 fail; fold_projection interior scan → 2/24 unit + 1/13 integration fail; serialize reader → 2/18 fail.
- **`lua/parley/chat_parser.lua:526` reuses the existing `cb_append_line` tracker** rather than adding a second state machine — the smallest diff that could deliver the behavior, and correct on ARCH-DRY. The `workshop/lessons.md:713-722` entry generalizes the M1/M2 interaction accurately.

## 2. Critical findings

### C1 — `lua/parley/answer_structure.lua:114`: the unterminated-fence rewind fires on a correctly-terminated fence

`cursor > #lines` is true both when the fence never closed *and* when it closed on the last line of the span. Combined with `boundary_before_close`, a properly closed tool body whose content contains a `📝:`/`💬:`/`🤖:`/`🔒:` line at column 0 gets truncated at its opener.

Reproduced against the current tree (`reduce` on a 4-line span):

```
input:  📎: read_file id=r1 / ```` / 📝: quoted-in-body / ````
HEAD:    tool_result 1..2   summary 3..3   text 4..4
dc5ee17: tool_result 1..4                                  <- correct before M2
```

And with real fold state through `hydrate_window` + `zM` on a transcript ending in that block:

```
10 foldclosed= 10 | 📎: read_file id=a1
11 foldclosed= 10 | ````
12 foldclosed= 12 | 📝: a summary marker quoted inside the body   <- fold anchored on content
13 foldclosed= -1 | some more output                              <- body leaks out, unfoldable
14 foldclosed= -1 | ````
```

Reachable on the streaming path (`chat_respond.lua:1704` reduces `current_lines` ending at an arbitrary `last_written_line_0`) and on cold parse of any chat whose last answer ends at a tool-result fence (`chat_parser.lua:484`, `body_lines` runs to `end_line_no`).

Fix sketch: distinguish "closed" from "ran out of lines".

```lua
local closed = false
...
elseif fence.closes(line, open_len) then
    last = cursor; cursor = cursor + 1; closed = true; break
...
if open_len and not closed and boundary_before_close then
```

### C2 — `lua/parley/chat_parser.lua:526`: the in-body suppression has no terminator, so one unclosed fence swallows the rest of the chat

The suppression holds for as long as `tool_fence_len` is set and `tool_body_complete` is false — with no bound. If the opener never gets a matching bare close, every subsequent `💬:`/`🤖:`/`📎:`/`🌿:`/`🔒:` in the buffer is reclassified as `text` and no further exchange is ever forked. `answer_structure` got a bounded fallback for exactly this case in the same milestone; `chat_parser` did not.

Two reproductions, both 3 exchanges before M2 and 1 after:

```
(a) aborted / hand-edited tool result:  📎: read id=r1 / ``` / <no close> / 💬: q2 ... 💬: q3
(b) an answer QUOTING the format:       ``` / 📎: read_file id=x / some output / ``` / 💬: q2 ... 💬: q3
```

(b) is the reachable one and needs no malformed file: ordinary answer prose is deliberately fence-naive (a stated non-goal, pinned by `chat_parser_tools_spec.lua:94`), so the quoted `📎:` still opens a `tool_result` block — and its "body" is the prose fence, whose close was already consumed. Any chat discussing parley's own marker format triggers it. I diffed old-vs-new parser exchange counts over all 23 in-repo transcripts and fixtures: only the intended `fold_adversarial.md` differs, so the in-repo corpus does not cover this shape — but the operator's live `chat_dir` is precisely where such a chat lives.

This also feeds M1's destructive path: exchange starts install `exchange_anchors` identity, and the plan's own round-6 note (`workshop/plans/000200-fold-reconciliation-plan.md`) records that too-few anchors make the last one own to end-of-buffer and clear every exchange after it.

Fix sketch: bound the window the way `answer_structure` does. A pre-pass over `lines` marking `in_tool_body[i]` only for lines between a tool marker's opener and a *found* matching close (reuse `fence.extract_body`'s scan shape), and suppress on that, gives the same behavior on well-formed input and degrades to today's fence-naive parse on malformed input instead of collapsing the file.

## 3. Important findings

### I1 — `tests/unit/chat_parser_tools_spec.lua`: 11 pre-existing tests deleted, undeclared

The file went from 11 `it()` cases to 5; the diff replaces it wholesale (`@@ -1,344 +1,108 @@`). Gone: the whole #81 `content_blocks` contract (shape, backward-compat `.content`, tool_use/tool_result recognition, `is_error=true`, multi-pair ordering, per-exchange independence, `🔒:` interaction) and — directly relevant to C2 — *"a tool_use prefix without a fenced body still produces a tool_use block with empty input"*, the only malformed-tool-tolerance test in the repo. None of them were moved elsewhere (grep across `tests/` finds no relocation); `parse_chat_spec.lua:320-420` overlaps only on tool_use recognition. The M2 Log reports "`chat_parser_tools_spec` 5/5" without noting it was 11. This is the rule at `workshop/lessons.md:706-713`, added by this very issue, going unapplied to this file.

Fix: restore the deleted cases from `dc5ee17` and keep the five new ones.

### I2 — atlas gate: `atlas/chat/format.md:12` still names the superseded owner

Plan Task 11 Step 3 explicitly says "Update `atlas/chat/format.md` — the tool-body fence rule … is now normative and single-sourced in `lua/parley/fence.lua`" and the step is ticked `[x]`. The file was not touched: line 12 still reads *"Single source of truth for the schema: `lua/parley/tools/serialize.lua`"*. `atlas/chat/parsing.md` (the chat_parser doc) never mentions the in-body-content rule and line 17 still asserts structural markers "always terminate either mode". And `atlas/traceability.yaml` adds `fence.lua` under `chat/exchange_model` + `providers/tool_use`, not under `chat/parsing` as the plan directed. `atlas/providers/tool_use.md:150-174` is good work — it is just not the whole sweep (ARCH-PURPOSE).

### I3 — `lua/parley/fold_projection.lua:120-126`: the interior drift scan can be blinded by an asymmetric fence

The scan enters "body" mode on *any* line `open_len` accepts, for *any* foldable range kind, and leaves it only on an exact-length close. A bare ` ``` ` is indistinguishable from an opener, so a range containing an odd/unmatched fence run stops checking for `💬:` for the rest of the range — silently disabling the guard that defends "a question is never inside a fold". Concretely, `fence.open_len` rejects info strings with non-word characters (```` ```json {"x":1} ````, as emitted by `render_buffer.lua:104`), so the *opener* is skipped and the matching bare close is read as an opener — desyncing a multi-line `thinking` range from that point on.

Fix sketch: only fence-track for `tool_use`/`tool_result` ranges, and require the body to open on `range.start_0 + 1` (which is what the writer guarantees) rather than on any fence anywhere in range.

### I4 — plan Task 11 Step 2 ticked with no recorded evidence

"Re-run the three audit scans from the issue Log against the operator's live `chat_dir` (127 transcripts) and confirm 0 violations" is `[x]`, but the M2 `## Log` entry records only spec counts, `make test`, lint, and the six M1 drift probes. That audit is exactly the evidence that would have surfaced C2 on real data, since the in-repo corpus provably lacks the shape (I diffed it: 0 exchange-count changes across 23 files).

## 4. Minor findings

- `lua/parley/chat_parser.lua:267` — `local fence = require("parley.fence")` sits at column 0 inside a tab-indented function body.
- `lua/parley/chat_parser.lua:457-459` — the comment still spells out the opening/closing fence grammar the module no longer owns (ARCH-DRY residue); point at `parley.fence` instead.
- `lua/parley/fold_projection.lua:122-123` — `fence.open_len(line)` evaluated twice; assign once.
- `lua/parley/fence.lua` is not in `PURE_FILES` (`tests/arch/buffer_mutation_spec.lua:62`), so the header's "Pure: no Neovim API, no state" is documentation, not enforcement — one line to add (ARCH-PURE).
- `lua/parley/skills/review/journal.lua:14` hardcodes `FENCE = "````"` with a comment restating the longer-fence nesting rule — a residual hand-maintained restatement of the model. Outside the plan's declared scope; noting for the shadow sweep.

## 5. Test coverage notes

- **Teeth verified for every claimed fix** (revert-and-run, each in a scratch copy, restored after): chat_parser 3/5 red, answer_structure 2/7 red, fold_projection 2/24 + fold_invariants 1/13 red, serialize 2/18 red. `fence_spec`'s parity/round-trip block stays green under the reverted serialize reader — the M2 Log already flags one of those three as vacuous; `tools_serialize_spec` is what actually holds.
- **`tests/integration/fold_invariants_spec.lua` is structurally blind to segmentation bugs.** The oracle walks the parsed model and asserts fold state against it — both sides derive from the same parse, so a mis-segmentation is asserted as correct. C1 and C2 both pass this harness. It validates fold *application*, not *segmentation*; worth saying so in the header comment so it isn't credited with coverage it can't have. The adversarial fixture caught the M1/M2 interaction only because `verify_anchors` is an independent check.
- **Missing, and both would have caught a Critical:** an `answer_structure` case where a correctly-closed fence containing a boundary marker is the last line of the span; a `chat_parser` case asserting exchange count is preserved after an unterminated tool-body fence and after an answer that quotes a `📎:` inside prose.
- Suite state as I measured it: `make test-unit` green, `make lint` 0/0 across 333 files, `fold_invariants_spec` 13/13.

## 6. Architectural notes

- **ARCH-DRY — pass, with residue.** The grammar is genuinely single-sourced: serialize's three restatements (writer + two `%1` readers) are gone, `answer_structure`'s "any ≥3 run" matcher is gone, and `chat_parser` derives without a second tracker. Residue is comment-level (`chat_parser.lua:457-459`) plus `journal.lua:14`.
- **ARCH-PURE — pass.** `fence.lua` is deterministic, stateless, no `vim.*`; `fence_spec`'s grammar cases need no mocks. Flagged only that the repo's existing purity guard doesn't cover it.
- **ARCH-PURPOSE — flag.** Shadow sweep incomplete on two axes: the atlas still names the superseded owner (I2), and the issue's paired Done-when — "a `💬:` inside a tool body is content" *and* "`🔧:`/`📎:`/`📝:` blocks are always folded" — is delivered on the first half while C1 regresses the second. The easy win landed; the invariant did not.
- **ARCH-MOCK — n/a.** No external binary or service in this diff; the existing `_model_provider` / `_observer` seams remain the boundary for the integration side.
- **For upcoming work:** the recurring shape across C1, C2 and I3 is that a fence *opener* and a fence *close* are the same token, so any consumer that scans forward from an unknown position can desync. `fence.extract_body` already encodes "an opener only counts if its close is found." The three line-scanners should be expressed on top of that lookahead rather than each running an ad-hoc open/close state machine — that would collapse all three findings into one implementation.

## 7. Plan revision recommendations

Append a `## Revisions` entry to `workshop/plans/000200-fold-reconciliation-plan.md` (there is currently **no M2 entry at all**; the last one is round 7 of M1), covering:

1. **A fourth consumer.** Core concepts line 33 says *"1:N — one grammar, three consumers (`serialize`, `answer_structure`, `chat_parser`)"*. `fold_projection.verify_anchors` (`fold_projection.lua:5,120-126`) is a fourth, discovered mid-M2 when the adversarial fixture broke the interior drift scan. `atlas/providers/tool_use.md:162-163` already lists four; the plan does not.
2. **Module surface wider than declared.** Core concepts line 32 names `open_len` / `closes` / `for_content`. The shipped module also exports `MIN`, `longest_run`, and `extract_body` — the last added by Step 3b and load-bearing for both serialize readers.
3. **Task 11 Step 3 scope.** Record that `atlas/chat/format.md` and the `chat/parsing` traceability entry were named in the step but not delivered (or deliver them and leave the tick honest).

```findings
findings:
  - id: new
    severity: Critical
    family: failure-fallback-misgated
    title: |
      answer_structure's unterminated-fence rewind fires on a correctly closed fence, truncating the tool block
    detail: |
      lua/parley/answer_structure.lua:114 gates the rewind on `cursor > #lines`, which is
      equally true when the fence closed on the last line of the span. A tool body containing
      a BOUNDARY-classified line (📝:/💬:/🤖:/🔒:) whose close is that last line is truncated
      at its opener: reduce returns tool_result 1..2 / summary 3..3 / text 4..4 where dc5ee17
      returned tool_result 1..4. Measured on real fold state, the body leaks out of its fold
      and a fold is anchored on the in-body marker. Reachable on the streaming path
      (chat_respond.lua:1704) and on cold parse of a chat ending at a tool-result fence.
      Fix: track a `closed` flag set in the close branch and gate the rewind on `not closed`.
  - id: new
    severity: Critical
    family: unterminated-fence-degradation
    title: |
      chat_parser's in-body suppression is unbounded, so one unclosed fence swallows the rest of the chat
    detail: |
      lua/parley/chat_parser.lua:526 suppresses structural classification while tool_fence_len
      is set and tool_body_complete is false, with no terminator. An opener that never gets a
      matching bare close reclassifies every later marker to text and forks no further
      exchange: 3 exchanges before M2, 1 after. Reachable without a malformed file — an answer
      quoting a 📎: line inside ordinary markdown prose (fence-naive by design) opens a tool
      block whose body never closes. Exchange starts feed exchange_anchors identity, which
      drives the M1 destructive fold clear. answer_structure got a bounded fallback for this
      case in the same milestone; chat_parser did not. Fix: precompute in_tool_body[] with a
      lookahead that requires the close to exist, and suppress on that.
  - id: new
    severity: Important
    family: spec-surgery-loses-tests
    title: |
      11 pre-existing tests deleted from chat_parser_tools_spec.lua, undeclared
    detail: |
      The file was replaced wholesale (344 -> 108 lines), dropping the entire #81
      content_blocks contract plus "a tool_use prefix without a fenced body ... empty input" —
      the only malformed-tool-tolerance test, and the class of the C2 regression. None were
      relocated. The M2 Log reports "chat_parser_tools_spec 5/5" without noting it was 11.
      This is the rule at workshop/lessons.md:706-713, added by this issue.
  - id: new
    severity: Important
    family: shadow-consumer-not-derived
    title: |
      atlas/chat/format.md still names tools/serialize.lua as the fence single source
    detail: |
      Plan Task 11 Step 3 names atlas/chat/format.md explicitly and is ticked, but the file is
      untouched: line 12 still reads "Single source of truth for the schema:
      lua/parley/tools/serialize.lua". atlas/chat/parsing.md never mentions the in-body-content
      rule and line 17 still says structural markers "always terminate either mode".
      traceability.yaml adds fence.lua under chat/exchange_model + providers/tool_use, not
      chat/parsing as the plan directed. ARCH-PURPOSE shadow sweep incomplete.
  - id: new
    severity: Important
    family: drift-guard-blinded
    title: |
      fold_projection's interior scan enters body mode on any fence, disabling the question guard
    detail: |
      lua/parley/fold_projection.lua:120-126 treats any open_len-matching line as a body opener
      for any foldable range kind. A bare run is indistinguishable from an opener, so one
      unmatched or grammar-rejected fence (e.g. an info string with non-word characters, as
      render_buffer.lua:104 emits) desyncs the scan and it stops checking for user markers for
      the rest of the range — silently disabling the guard that defends "a question is never
      inside a fold". Fix: fence-track only for tool_use/tool_result and require the body to
      open at range.start_0 + 1.
  - id: new
    severity: Important
    family: ticked-without-evidence
    title: |
      Plan Task 11 Step 2 (127-transcript audit re-run) is ticked with no evidence in the Log
    detail: |
      The M2 Log records spec counts, make test, lint and the M1 drift probes, but no re-run of
      the three audit scans against the operator's live chat_dir. That audit is the only
      evidence covering the C2 shape: the in-repo corpus provably lacks it (old-vs-new parser
      exchange counts differ on 0 of 23 in-repo transcripts).
  - id: new
    severity: Minor
    family: style-consistency
    title: |
      chat_parser.lua:267 require is unindented in a tab-indented function body
  - id: new
    severity: Minor
    family: shadow-consumer-not-derived
    title: |
      chat_parser.lua:457-459 comment still restates the fence grammar the module no longer owns
  - id: new
    severity: Minor
    family: redundant-computation
    title: |
      fold_projection.lua:122-123 calls fence.open_len twice on the same line
  - id: new
    severity: Minor
    family: purity-claim-unenforced
    title: |
      fence.lua declares itself pure but is absent from the PURE_FILES arch guard
    detail: |
      tests/arch/buffer_mutation_spec.lua:62 lists the modules whose purity is enforced. The
      new module's header claim ("Pure: no Neovim API, no state") and the plan's PURE
      classification are documentation until it is added there. One line.
  - id: new
    severity: Minor
    family: oracle-derives-from-subject
    title: |
      fold_invariants_spec's oracle derives from the same parse it validates, so segmentation bugs pass
    detail: |
      Both the expectations and the fold state come from one parse, so a mis-segmentation is
      asserted as correct — C1 and C2 both pass this harness. It validates fold application,
      not segmentation; the header comment should say so rather than let the harness be
      credited with coverage it cannot have.
```

---

## Re-review — 2026-08-21T12:36:09-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 200 — user question is folded |
| repo | parley.nvim |
| issue file | workshop/issues/000200-user-question-is-folded.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | b2bf1d51cedafc00dc93dd547e4e036f39cb2c3b..b2bf1d51cedafc00dc93dd547e4e036f39cb2c3b |
| command | sdlc milestone-close --issue 200 --milestone M2 |
| reviewer | claude |
| timestamp | 2026-08-21T12:36:09-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

Both prior-round Criticals (BR-29, BR-30) are untouched at HEAD and I reproduced both end-to-end; the fix commit `b2bf1d5` addressed only BR-31/32/33/34 and additionally shipped an undeclared production default change (`max_full_exchanges` 42 → 999) that has nothing to do with #200. The M2 work that *did* land is good — `fence.lua` is a clean pure module, the `%1`-backreference reader bug it exposed in `serialize` was real and is fixed with teeth, the 11 destroyed tests are genuinely restored (16/16, zero duplicates), and the BR-33 desync fix is real and pinned by one test that goes red without it. But two of the milestone's own `Done when` bullets — "a `💬:`/`🤖:`/`📎:` line inside a tool body is content, not a turn" and "tool blocks are always folded, anchored on their own marker" — are demonstrably false at HEAD, and the parser defect is a *regression this milestone introduced* (pre-M2 the same input parsed correctly). That blocks the boundary.

---

## 1. Strengths

- **`lua/parley/fence.lua` is the right module.** Genuinely pure (loads and runs with `_G.vim` nil), small surface (`open_len` / `closes` / `for_content` / `longest_run` / `extract_body`), and the header states the invariant it exists to guarantee rather than restating the code. `fence_spec` 13/13.
- **The `%1`-backreference discovery in `serialize` was real and material.** `lua/parley/tools/serialize.lua:125` — a Lua backreference matches a *prefix* of a longer run, so `parse_result` truncated any body containing a run longer than its opener. Converting the reader (not just the writer) was the correct ARCH-PURPOSE read of "every consumer derives".
- **BR-31 restoration verified independently.** `tests/unit/chat_parser_tools_spec.lua` now carries all 11 names from `9a6e939~1` plus the 5 new ones, wired to the file's existing `parser`/`test_config()` helpers rather than a second set; 16/16, zero duplicate `it()` names.
- **BR-33's fix has teeth.** I reverted `lua/parley/fold_projection.lua` to `b2bf1d5~1` in a scratch tree: the rejected-opener case flips `ok=true → ok=false`. The fix is reachable and the reasoning (`render_buffer.lua:104` emits an info string the grammar rejects) checks out.
- **The lessons entries are honest and rule-shaped**, including one written against the author's own second test deletion (`workshop/lessons.md:713-726`).

## 2. Critical findings

### C-1 — BR-29 is unfixed; I reproduced it end-to-end through the production parse path

`lua/parley/answer_structure.lua:114` still gates the unterminated-fence rewind on `cursor > #lines`, which is equally true when the fence closed *on the last line of the span* (the close branch does `cursor = cursor + 1` then `break`).

Measured through `chat_parser.parse_chat` → `exchange_model` → `fold_projection.desired_folds` on a well-formed transcript ending at a tool-result close:

```
  section tool_result  10..11    ← want 10..14
  section text         12..12    "💬: a question inside the file"
  section summary      13..13    "📝: a summary marker inside the file"
  section text         14..14    "```"
  FOLD tool_result  rows 10..11
  FOLD summary      rows 13..13  ← a fold anchored on an in-body marker
```

Two Done-when bullets fail here at once: the tool body leaks out of its fold, and a fold is anchored on a `📝:` line that is content. Adding one trailing blank line makes it correct (`tool_result 1..4`), which is the tell.

Also reachable *per streamed chunk*, not just at EOF: `lua/parley/chat_respond.lua:1704` reduces `current_lines` up to `last_written_line_0`, so every chunk that lands a body-closing fence hits the same gate.

Fix sketch: set a `closed = true` flag in the close branch and gate the rewind on `open_len and not closed and boundary_before_close`.

### C-2 — BR-30 is unfixed, and it is a regression this milestone introduced

`lua/parley/chat_parser.lua:526` suppresses structural classification while `tool_fence_len` is set and `tool_body_complete` is false, with no terminator. Measured, same input against `9a6e939~1` (pre-M2) and HEAD:

| input | pre-M2 | HEAD |
|---|---|---|
| answer quoting `📎:` inside a prose ```` ```markdown ```` block | 3 exchanges | **1** |
| tool result whose fence never closes (truncated / mid-stream) | 3 exchanges | **1** |
| well-formed tool result | 3 exchanges | 3 |

One unclosed opener swallows the rest of the chat. Exchange starts feed `exchange_anchors`, which drives M1's destructive fold clear — so a collapsed model makes one span own the whole buffer. It also changes what is sent to the provider (`chat_respond.lua:788` preserves by exchange index).

`atlas/providers/tool_use.md:170` documents the naive-prose behavior as a bounded "deliberate exception". It is not bounded — that is the defect.

Fix sketch: `fence.extract_body` already does the lookahead that proves a matching close *exists*. Precompute `in_tool_body[]` from it and suppress on that, instead of on "we opened and haven't closed yet".

**Both C-1 and C-2 are the same rule:** *"unterminated" must be a positive fact derived from the grammar, never inferred from running out of input or from not-yet-having-closed.* The grammar module owns the lookahead primitive and neither consumer uses it — that is also an ARCH-DRY miss.

### C-3 — undeclared production default change shipped in the boundary commit

`lua/parley/config.lua:640` — `max_full_exchanges` 42 → 999, introduced solely in `b2bf1d5` (`git log -S` confirms), unmentioned in that commit's message, the issue, or the plan. It is consumed at `lua/parley/chat_respond.lua:737`: at 999 the chat-memory summarisation effectively never fires, so every prior exchange is sent in full to the provider instead of being replaced by its `📝:` summary. That is a user-visible cost/context-window change with no relationship to fence grammar or folding. Fix sketch: revert to 42, or split it into its own issue with a stated rationale and a README/atlas note.

## 3. Important findings

### I-1 — `ticked-without-evidence`, second and third instances

> **This is the 2nd finding in family `ticked-without-evidence`.** Earlier rounds fixed instances (BR-34, Task 11 Step 2). Do NOT fix these instances — fix the rule.

Measured prevalence, all three in this issue:

1. BR-34 — Task 11 Step 2 ticked, audit unrun (fixed last round).
2. `workshop/plans/000200-fold-reconciliation-plan.md:1338` Step 4 (`sdlc milestone-close --issue 200 --milestone M2`) and `:1352` Step 6 (`sdlc close`) are **ticked now**, while this review *is* that milestone-close, there is no `closed M2` line in `## Log`, and `status: working`. A step cannot be ticked from inside the gate that produces its evidence.
3. `workshop/issues/…:189` records "**Two tests pin it**" for BR-33. Reverting `fold_projection.lua` to `b2bf1d5~1` shows `keeps guarding a thinking block, which has no fenced body` (`tests/unit/fold_projection_spec.lua:184`) already passes **without** the fix — its fence is balanced, so the pre-fix scanner closes it correctly. One test pins BR-33, not two.

**The rule that covers all three:** *a tick, or a written claim that a test pins a fix, is a claim of evidence — it may only be written by the same action that produced the evidence, and for a regression test the evidence is the revert going red, not the suite going green.* Mechanically: (a) never tick a step whose command has not returned, and in particular never tick the gate steps from inside the gate; (b) before writing "test X pins fix Y", revert Y and confirm X fails. The existing `workshop/lessons.md:722-726` entry states half of this ("tick a step only in the same action that produced its evidence") and was violated in the same commit that wrote it — extend it with the regression-test-revert half.

### I-2 — BR-32 remains partly open

`atlas/chat/format.md:12` is fixed and correct. Two named parts are not:
- `atlas/traceability.yaml:98` — the plan (Task 11 Step 3) says "add `lua/parley/fence.lua` … under `chat/parsing` and `providers/tool_use`". It went into `chat/exchange_model` and `providers/tool_use`. `chat/parsing` lists `answer_structure.lua` and `chat_parser.lua`, both of which now require `fence`, so `make test-spec SPEC=chat/parsing` under-selects.
- `atlas/chat/parsing.md` still contains no statement of the in-body-content rule, which is M2's user-visible parsing semantics change. `atlas/providers/tool_use.md:164` has it, but the parsing page is where a reader looks for "what starts a turn".

Both are two-line edits.

## 4. Minor findings

- **BR-35 not-addressed** — `lua/parley/chat_parser.lua:267` `local fence = require("parley.fence")` still at column 0 inside a tab-indented body (verified byte-wise).
- **BR-36 not-addressed** — `lua/parley/chat_parser.lua:456-459` still restates the fence grammar the module no longer owns. (`lua/parley/tools/serialize.lua:14-28` restates it too, though there it doubles as the schema doc.)
- **BR-38 not-addressed** — `fence.lua` still absent from `PURE_FILES` at `tests/arch/buffer_mutation_spec.lua:62`. Its purity claim is documentation until it is listed. One line.
- **BR-39 not-addressed** — `tests/integration/fold_invariants_spec.lua:4-11` justifies the model-derived oracle but never states its limit: it validates fold *application*, not *segmentation*, so C-1 and C-2 both pass it green.
- **New, `serialized-shape-assumed`** — `lua/parley/fold_projection.lua:121` requires the body to open at exactly `range.start_0 + 1`. That matches `serialize.render_call`/`render_result` today, but a hand-edited or LLM-emitted transcript with a blank line between marker and fence loses the guard's fence-awareness and an in-body marker refuses the whole exchange. Worth a comment naming the coupling, or accepting the first non-blank line.
- **BR-37 addressed** — single `fence.open_len` call now.

## 5. Test coverage notes

- All M2 specs green at HEAD: `fence_spec` 13/13, `answer_structure_spec` 7/7, `chat_parser_tools_spec` 16/16, `fold_projection_spec` 26/26, `tools_serialize_spec` 18/18. `luacheck` 0/0 on the four changed modules.
- **Neither Critical is covered by anything.** No fixture ends on a tool-body close (C-1) and none contains an unclosed fence or a prose-quoted `📎:` (C-2). `tests/fixtures/fold_adversarial.md` deliberately closes every fence and ends on prose. The two cheapest pins: append `fold_adversarial.md` with a transcript that terminates at a closing fence after an in-body `📝:`, and add a `chat_parser_tools_spec` case asserting exchange count is unchanged when a tool fence never closes.
- The corpus harness cannot cover either — the operator audit (115 files / 463 exchanges) recorded **zero tool blocks**, and the in-repo corpus likewise. The Log is admirably explicit about this; it means fixtures are the only coverage and should be treated as load-bearing.

## 6. Architectural notes

- **ARCH-DRY — flag.** The grammar is single-sourced and every listed consumer derives (shadow sweep: `serialize` writer + both readers ✓, `answer_structure` ✓, `chat_parser` ✓, `fold_projection` ✓; `highlight_structure.lua:61`, `skills/review/init.lua:201-209`, `journal.lua:14` are different domains and correctly left alone). The miss is one level up: `fence.extract_body` is the module's *lookahead* primitive — "does a matching close exist?" — and the two consumers that most need it hand-roll a proxy for it instead (C-1, C-2). Consolidate on it.
- **ARCH-PURE — pass.** `fence` is pure with no vim reference at all; `answer_structure` and `fold_projection` stay pure and are pinned nvim-free at call time. `serialize`'s `fenced_body` uses `vim.split` at the boundary, which is the right side of the seam.
- **ARCH-PURPOSE — flag.** The single-source half is delivered. The *behavioural* purpose — "a marker inside a tool body is content, not a turn" — is not: C-1 makes an in-body `📝:` a fold anchor, C-2 makes an in-body `📎:` collapse the whole chat into one exchange. The Done-when bullet asserting it is ticked. Both are the point of M2, not separable follow-ups.
- **ARCH-MOCK — pass for this window.** No external binary or service surface is introduced. Pre-existing note (out of scope, already disposed in M1): `tests/integration/fold_invariants_spec.lua:16` shells `git ls-files` directly with no seam or fake — if that harness grows, it wants one.
- **For upcoming work:** the M1 note at `chat_parser.lua:623` warning that a completeness scan over question lines must consume the `fence` grammar rather than a raw regex is now *more* load-bearing, because C-2 shows the fence-derived "am I in a body?" predicate is itself not yet trustworthy. Fix C-2 before anything else consumes that predicate.

## 7. Plan revision recommendations

Add a `## Revisions` entry to `workshop/plans/000200-fold-reconciliation-plan.md`:

- **Untick Task 11 Steps 4 and 6** and state that gate steps are ticked by the gate's own completion, never in advance (I-1).
- **Task 8 outcome correction.** The plan's Core-concepts line for `answer_structure` ("stops a never-closed fence at the last line before the first following boundary") describes the intent; the shipped gate also fires on a *closed* fence at end-of-span. Record the defect and the `closed`-flag fix.
- **Task 9 outcome correction.** Record that consulting the existing tracker is necessary but not sufficient — the tracker has no terminator, so the plan's "two changes, no second state machine" understated the work; the suppression needs a close-exists lookahead.
- **Task 11 Step 3 correction.** `fence.lua` landed under `chat/exchange_model`, not `chat/parsing` as the step directs; either fix the traceability entry or amend the step to say both.
- **Record the `config.lua` change or back it out.** If `max_full_exchanges = 999` is intentional it needs its own issue and a scope note here; otherwise revert (C-3).

```findings
dispose:
  - id: BR-29
    disposition: not-addressed
    note: |
      Unchanged at answer_structure.lua:114; reproduced end-to-end — tool_result truncated to 2 rows and a fold anchored on an in-body 📝:.
  - id: BR-30
    disposition: not-addressed
    note: |
      Unchanged at chat_parser.lua:526; measured 3 exchanges pre-M2 vs 1 at HEAD on two independent reachable inputs.
  - id: BR-31
    disposition: addressed
    note: |
      All 11 names from 9a6e939~1 present plus 5 new; 16/16 green, zero duplicate it() names.
  - id: BR-32
    disposition: not-addressed
    note: |
      format.md fixed; traceability.yaml still omits fence.lua from chat/parsing and atlas/chat/parsing.md still lacks the in-body-content rule.
  - id: BR-33
    disposition: addressed
    note: |
      Fix verified by revert — rejected-opener case flips true→false. Only one of the two claimed tests has teeth (see the new ticked-without-evidence finding).
  - id: BR-34
    disposition: addressed
    note: |
      Audit run and recorded with the census bounding it (115 files, 1155 assertions, zero tool blocks).
  - id: BR-35
    disposition: not-addressed
    note: |
      chat_parser.lua:267 still at column 0 in a tab-indented body.
  - id: BR-36
    disposition: not-addressed
    note: |
      chat_parser.lua:456-459 comment unchanged.
  - id: BR-37
    disposition: addressed
    note: |
      fold_projection.lua:121 now calls fence.open_len once.
  - id: BR-38
    disposition: not-addressed
    note: |
      fence.lua still absent from PURE_FILES at tests/arch/buffer_mutation_spec.lua:62.
  - id: BR-39
    disposition: not-addressed
    note: |
      Header comment still justifies the oracle without stating that it validates fold application, not segmentation.
findings:
  - id: new
    severity: Critical
    family: undeclared-scope-change
    title: |
      max_full_exchanges default changed 42 to 999 in the M2 fix commit, unrelated and undeclared
    detail: |
      lua/parley/config.lua:640, introduced solely in b2bf1d5 (git log -S confirms) and
      unmentioned in that commit message, the issue, or the plan. Consumed at
      chat_respond.lua:737, so chat-memory summarisation effectively never fires and every
      prior exchange is sent to the provider in full instead of as its 📝: summary. A
      user-visible cost and context-window change with no connection to fence grammar or
      folding. Revert, or split into its own issue with a rationale and a README note.
  - id: new
    severity: Important
    family: ticked-without-evidence
    title: |
      Gate steps ticked from inside the gate, and a regression test claimed to pin a fix that it does not
    detail: |
      This is the 2nd (and 3rd) finding in family ticked-without-evidence. Do NOT fix the
      instances — fix the rule. Prevalence, all in this issue: BR-34 (Task 11 Step 2, fixed
      last round); plan lines 1338 and 1352 tick "sdlc milestone-close M2" and "sdlc close"
      while this review IS that milestone-close, no "closed M2" log line exists and status is
      still working; and the Log's "Two tests pin it" for BR-33 is false — reverting
      fold_projection.lua to b2bf1d5~1 leaves fold_projection_spec.lua:184 green, so only the
      rejected-opener test pins anything. Rule: a tick, or a written claim that a test pins a
      fix, is a claim of evidence and may only be written by the action that produced it — for
      a regression test that evidence is the revert going RED, not the suite going green.
      Corollary: never tick a gate step from inside the gate. workshop/lessons.md:722-726
      states half this rule and was violated by the same commit that wrote it; extend it with
      the revert half.
  - id: new
    severity: Minor
    family: serialized-shape-assumed
    title: |
      The fence-aware interior scan requires the body to open at exactly start_0 + 1
    detail: |
      fold_projection.lua:121 keys on the shape serialize.render_call/render_result emit today.
      A hand-edited or LLM-emitted transcript with a blank line between the marker and its
      opening fence loses fence-awareness, so an in-body marker refuses the whole exchange.
      Either name the coupling in the comment or accept the first non-blank line after the
      marker.
```
