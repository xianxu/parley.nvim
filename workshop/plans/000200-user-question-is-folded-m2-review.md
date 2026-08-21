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

---

## Re-review — 2026-08-21T13:14:08-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 200 — user question is folded |
| repo | parley.nvim |
| issue file | workshop/issues/000200-user-question-is-folded.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | ca3c8bb05bac3763d3c489faa1eee1f3cebdcc04..ca3c8bb05bac3763d3c489faa1eee1f3cebdcc04 |
| command | sdlc milestone-close --issue 200 --milestone M2 |
| reviewer | claude |
| timestamp | 2026-08-21T13:14:08-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

M2's two Critical fixes are unequal: BR-29's `closed` flag is correct and revert-verified, but BR-30's replacement — a precomputed `in_tool_body[]` — bounds only the narrow case its two new tests encode ("no matching close exists anywhere") and leaves the general defect intact. The body scan at `chat_parser.lua:536-550` accepts an opener *anywhere* after a tool marker and, once it has one, ignores every structural boundary until a matching bare close. `answer_structure.lua:90-97` has the same opener rule. I reproduced the issue's headline symptom on HEAD from a transcript containing no tool use at all — an answer that shows the transcript format inside an ordinary ` ```text ` block — where the user question at row 20 comes back `foldclosed=20→13`, i.e. **folded**, while the same file at `dc5ee17` (M1 close) folds nothing. The flagship harness reports **0 violations** on that file, because its oracle enumerates exchanges from the same parse that lost the exchange (BR-39, still open, now demonstrably load-bearing). A milestone that reintroduces the exact defect the issue is named for, in a form its own regression harness structurally cannot see, is not ready to cross the boundary.

## 1. Strengths

- **`lua/parley/fence.lua`** is a genuinely good extraction: small, nvim-free, and `fence_spec.lua:36-56` pins the writer/reader contract as a *property* ("every fence `for_content` picks is one its own content cannot close") over 13 adversarial bodies rather than a handful of literals. `fence_spec.lua:58-65` pinning the new grammar against the legacy `chat_parser` pattern is exactly the right way to prove an extraction is behaviour-preserving.
- **`serialize.lua`'s reader fix is real.** Replacing the `%1` backreference with `fence.extract_body` fixes a genuine truncation (a backreference matches a *prefix* of a longer run), and `fence_spec.lua:84-89` pins it directly.
- **BR-29 is properly fixed and properly pinned.** I reverted the gate to `cursor > #lines` in a scratch copy: both new tests at `answer_structure_spec.lua:115` and `:129` go RED (`2` vs `7`). That is the standard this issue's own new lessons entry sets, met.
- **BR-40 is fully repaired** — `config.lua:640` is back to `42`, and the commit message states the provenance (a consumed operator stash) rather than papering over it.
- **`fold_projection.lua:110-131`** is the one consumer that got the body scan right: tool kinds only, opener required at `start_0 + 1`, with the comment naming the `render_buffer` rejected-opener hazard by name. It should be the template for the other two.

## 2. Critical findings

**C1 — `answer_structure.lua:90-97` / `chat_parser.lua:536-550`: the tool-body scan treats the *first fence it sees after the marker* as the body opener, so a rejected opener or a quoted marker turns a closing fence into an opening one.**

*This is the 2nd finding in family `drift-guard-blinded`* (BR-33 was the 1st, in `fold_projection`). Per protocol I am not asking for these two instances to be patched — the rule is statable and belongs in one place:

> A tool body's extent is not "the next fence pair after the marker." It is: **(a)** the marker must be at fence depth 0 — a marker inside any enclosing fenced block is content, not a marker; **(b)** the opener must be the line immediately following the marker (the serialized shape, already enforced at `fold_projection.lua:121`); **(c)** `open_len` must recognise every CommonMark opener (` ``` ` + any info text containing no backtick), because an opener the grammar *rejects* leaves its closer to be misread as an opener — one desync poisons the rest of the scan. Exactly one function computes this span; every consumer calls it.

`fence.extract_body` is the natural home and already exists, but it implements none of (a)/(b)/(c) — hence four scanners with three semantics.

Measured (all against `dc5ee17` = M1 close as the control):

| shape | `dc5ee17` | `b2bf1d5` | `ca3c8bb` (HEAD) |
|---|---|---|---|
| rejected opener ` ```json {"type": "request"} ` then a later code block | 3 exchanges | 2 | **2** |
| unclosed body fence + any later bare ` ``` ` | 3 | 2 | **2** |
| answer shows the format inside a ` ```text ` block, later code block | 3 | 2 | **2** |

And end-to-end on real Neovim fold state for the third shape:

```
HEAD:     exchanges=2   raw 💬: row 20  foldclosed=13   <<< FOLDED
dc5ee17:  exchanges=3   raw 💬: row 20  foldclosed=-1   ok
```

`answer_structure` fails the same way within a single answer, and it breaks the Spec's *second* invariant rather than the first — a `📝:` gets swallowed instead of being its own foldable block:

```
HEAD:     tool_result[1..7] text[8..9]
dc5ee17:  tool_result[1..4] summary[5..5] text[6..9]
```

Reachability is not theoretical: the operator's live corpus contains 5 grammar-rejected ` ``` ` openers (` ```python file="analyze_repos.py" `, ` ``` description="test" stage="test" `, ` ```# frozen_string_literal: true `) and 3 structural markers quoted inside plain fenced blocks. I re-parsed all 115 live transcripts at HEAD vs `dc5ee17` and the exchange counts are **identical** — because that corpus has zero `🔧:`/`📎:` markers, as the plan's own census records. The defect is gated purely on tool use, which is a shipped feature and the thing this issue is named for.

Fix sketch: one `fence.tool_body_span(lines, marker_row, depth_state)` implementing (a)+(b), a CommonMark-correct `open_len` for (c), called from `chat_parser`'s precompute, `answer_structure.reduce`, and `fold_projection.verify_anchors`. `answer_structure`'s existing bounded-rewind fallback stays as the "opener present, close absent" arm.

*(Disposes BR-30 `not-addressed`: the chat_parser half of this is BR-30 unfixed. C1 additionally covers the `answer_structure` site and states the shared rule.)*

## 3. Important findings

**I1 — `chat_parser.lua:529-556` introduces a second in-tool-body tracker; plan line 44 states none was added, and the two disagree.**

*3rd in family `shadow-consumer-not-derived`.* `cb_state.tool_fence_len` / `tool_body_complete` (`chat_parser.lua:460-466`) still drives block finalisation while `in_tool_body[]` drives main-loop classification. They compute the same fact by different rules and diverge on exactly the C1 shapes — in the case-D transcript, the main loop treats row 12 as `tool_result` (starting a tool block via `cb_state`) while the precompute assigns the body to a different span. The plan says: *"No second fence tracker is introduced (PQ-3)"* — a Core-concepts claim the code contradicts, which the review checklist rates Critical by default. I am filing it Important because C1 already carries the behavioural weight and this is cheap to fold into C1's shared-helper fix; it does need a `## Revisions` entry either way. Rule: **one fact, one computation, injected into both consumers** — a second derivation of "am I inside a tool body" is the same DRY violation M2 exists to remove, relocated one layer up. (Same rule, lower stakes: `log_emit.lua:253-272` and `skills/review/journal.lua:14` still hand-pick fence strings; the latter's comment even documents the unsound case — *"a doc using 4-backtick fences is the rare exception"* — that `fence.for_content` solves exactly.)

**I2 — the precompute reclassifies every line, making `parse_chat` ~48% slower.**

*2nd in family `redundant-computation`* (BR-37 was `fence.open_len` twice on one line). Rule, stated once: **a per-line grammar/classification predicate is computed once per parse into a shared array and read from there — never recomputed inside a scan.** `answer_structure.reduce:29` already does this (`local kinds = {}` … `classify` once); `chat_parser` now calls `highlight_structure.classify` in the precompute row loop (`:533`), again in every inner scan (`:538`), and a third time in the main loop (`:561`). Measured best-of-10 on a 10,104-line tool-heavy transcript (100 exchanges × `🔧:`+`📎:` with 40-line bodies): **24.49 ms → 36.22 ms**. `parse_chat` runs at `tool_folds.lua:150` (hydrate and every drift re-derive) and 8 times across `chat_respond.lua`. The issue's own Done-when commits to the streaming path not regressing, and M1 spent real effort getting per-chunk reconcile from 3.705 ms to 0.067 ms; M2 gives ~12 ms back at a different seam. Fixing I2 is the same edit as C1 — build `kinds[]` once and hand it to the shared span helper.

**I3 — the rule from BR-41 was written and then not applied by the commit that wrote it.**

*4th in family `ticked-without-evidence`.* `lessons.md:733-742` now correctly states that a fix-pin claim requires the **revert going red**, plus the "never tick a gate step from inside the gate" corollary — that is BR-41's remedy, delivered. In the same commit: the new `describe("unterminated tool body (#200 BR-30)")` block presents two tests as pinning BR-30, and against `b2bf1d5` the suite is 17 pass / 1 fail — `chat_parser_tools_spec.lua:485` ("prose quotes a tool marker") is **green on revert**, so it is characterization wearing a fix-pin label, unlabelled. And plan line 1338 still reads `- [x] **Step 4: Milestone close**` while this review *is* that milestone-close (line 1352 was correctly unticked). Prevalence in this issue alone: BR-34, BR-41 (×2), and now these two — five instances, the last three occurring *after* the rule was written down. Escalation: the rule cannot be fixed by restating it a third time in prose. It needs a mechanical gate — e.g. a `Pinned-by:` trailer that `milestone-close` refuses without a recorded red-on-revert run, and a close-gate check that no plan step naming `sdlc milestone-close`/`sdlc close` is ticked at the moment that command runs. Record the family and its prevalence in the finding; do not patch line 1338 in isolation.

**I4 — atlas is still short of what the plan's Task 11 Step 3 claims (BR-32, still open).** `atlas/chat/format.md` was fixed. Not fixed: `atlas/chat/parsing.md` has no in-body-content rule and line 17 still asserts structural markers *"always terminate either mode"*, which M2 made false; `atlas/traceability.yaml` adds `fence.lua` under `chat/exchange_model` (:115) and `providers/tool_use` (:448) but not under `chat/parsing` (:95-105), which is where the plan directed it and where `chat_parser.lua` lives. Step 3 remains ticked.

## 4. Minor findings

- **BR-35** — `chat_parser.lua:267` `local fence = require("parley.fence")` is at column 0 inside a tab-indented function body. Unchanged.
- **BR-36** — `chat_parser.lua:456-459` still restates the fence grammar ("Opening fence: any run of 3+ backticks optionally followed by an info string…") the module no longer owns. Unchanged.
- **BR-38** — `fence.lua` is still absent from `PURE_FILES` at `tests/arch/buffer_mutation_spec.lua:62`. Its purity claim and the plan's PURE row remain unenforced. One line.
- `tests/fixtures/fold_adversarial.md` is thorough about nesting but contains **none** of the three shapes that actually break: no grammar-rejected opener, no unclosed fence, no marker quoted inside a plain (non-tool) code block. The plan calls it "the adversarial fixture"; it is the well-formed-tool-body fixture.
- `highlight_structure.lua:61` classifies a fence as `^%s*` + ` ``` ` — a 4th, strictly more permissive restatement not derived from `fence`. `answer_structure.reduce` now mixes both notions in one scanner (`kinds[]` for BOUNDARY, `fence` for openers).
- `fence.closes` runs `line:match("^(`+)")` twice on the matching path.

## 5. Test coverage notes

- `make lint` clean (0/0 across 333 files). `make test-unit` fully green. `make test-integration`: 3 failures — `git_markdown_source_spec` and `markdown_finder_async_spec` both fail on `git init` exit 128 under `.test-tmp` (the environment cause the issue Log describes, still present here even unsandboxed), and `chat_progress_process_spec` fails in-suite but passes in isolation (order-dependent). None touch #200's surface, but the Log should not be read as "make test exit 0" on this machine.
- **The regression harness cannot see the defect this milestone shipped.** `fold_invariants_spec.lua:80-99` enumerates subjects from `chat_parser.parse_chat` and asserts on `foldclosed`. When the parse drops an exchange, its question is simply never a subject. Demonstrated: on the case-D transcript the harness reports `exchanges=2 subjects=2 violations=0` while an independent raw-text sweep finds `💬:` at row 20 with `foldclosed=13`. The `checked > 0` floor does not help — it fires only on a total wipeout. BR-39 asked for a header comment admitting this; the measurement above argues for the stronger fix: **add a raw-text oracle** (every line literally matching the user prefix at column 0 and outside a fenced body must have `foldclosed == -1`) alongside the model-derived one. That single addition would have caught C1.
- The three shapes in C1's table are the missing unit cases; each is 8-12 lines in `chat_parser_tools_spec.lua` and `answer_structure_spec.lua`, and each is currently red.

## 6. Architectural notes

- **ARCH-DRY — flag** (C1, I1, I2). The milestone extracted the *token* grammar (`open_len`/`closes`/`for_content`) and stopped there. The *body-span algorithm* — the part every bug in this issue lives in — is still written four times: `fold_projection.lua:121` (correct), `answer_structure.lua:90` (opener anywhere, bounded fallback), `chat_parser.lua:536` (opener anywhere, unbounded once open), `fence.extract_body` (opener anywhere, no boundary awareness). Extracting the cheap half of a duplicated rule and leaving the expensive half duplicated is how a DRY refactor ships a regression: `fold_projection` learned the right rule at BR-33 and the other two never received it.
- **ARCH-PURE — pass.** `fence.lua` is genuinely pure, `answer_structure` and `fold_projection` stay nvim-free, and every unit test here runs without mocks. The one gap is enforcement, not design (BR-38).
- **ARCH-PURPOSE — flag.** The Done-when says *"A `💬:`/`🤖:`/`📎:` line inside a tool body is content, not a turn"* and is ticked. What shipped is: a marker inside a *well-formed* tool body is content, and a marker inside a *plain code block* now silently deletes an exchange and folds a question. The shadow sweep over the declared consumer set (serialize writer + both readers, answer_structure, chat_parser, fold_projection) does confirm each derives from `fence` for tokens — but the sweep was run at the wrong granularity, and the plan's own PQ-3 constraint ("no second tracker") was reversed in implementation without a revision.
- **ARCH-MOCK — pass, with a note.** M2 adds no external dependency. `fold_invariants_spec.lua:16` shells out to `git ls-files` directly and documents that it is deliberately not an injection seam; the explicit tracked-fixture list plus the `#corpus >= 8` floor is a reasonable substitute for a fake at this scale.
- **For upcoming work:** `fence.lua`'s public surface will be consumed by everything downstream, so settle it now. Adding `tool_body_span(lines, row)` and making `open_len` CommonMark-correct are both breaking-ish changes to a module that is one milestone old — much cheaper here than after the next consumer lands.

## 7. Plan revision recommendations

The plan needs a `## Revisions` entry — `### 2026-08-21 — M2 boundary review round 7` — covering:

1. **Core concepts, `chat_parser` (line 44).** Strike *"No second fence tracker is introduced (PQ-3)"*. The M2 fix for BR-30 replaced the `cb_state`-consulting design with a precomputed `in_tool_body[]`, so two trackers now coexist; PQ-3's constraint was reversed for a real reason (the `cb_state` approach had no terminator) and the plan must say so rather than assert the opposite.
2. **Core concepts, `fence` (line 32).** The entity as shipped owns token predicates only. Either widen its stated scope to include the body-span algorithm (the C1 fix) or state explicitly that span computation stays per-consumer — the current text implies a completeness the code does not have.
3. **Task 11 Step 3 (line 1334).** Untick, or narrow the step text to `atlas/chat/format.md` only. As written it names `atlas/chat/parsing.md` and `chat/parsing` in `traceability.yaml`, neither of which was touched.
4. **Task 11 Step 4 (line 1338).** Untick — the milestone-close it names is this review, which is returning REWORK.
5. **Issue Done-when**, third-from-last bullet. *"A `💬:`/`🤖:`/`📎:` line inside a tool body is content, not a turn"* should not be ticked while C1 stands, and the last bullet's *"durable corpus harness asserts both invariants"* should be qualified with what the harness cannot assert (BR-39).

```findings
dispose:
  - id: BR-29
    disposition: addressed
    note: |
      Revert-verified — restoring the `cursor > #lines` gate turns answer_structure_spec.lua:115 and :129 RED (2 vs 7).
  - id: BR-30
    disposition: not-addressed
    note: |
      Bounded only the no-close-anywhere case; 3 shapes still swallow exchanges at HEAD (3 -> 2) and one folds a user question on real fold state. See C1.
  - id: BR-32
    disposition: not-addressed
    note: |
      format.md fixed; atlas/chat/parsing.md line 17 and traceability.yaml chat/parsing (:95-105) untouched since round 6, while Task 11 Step 3 stays ticked.
  - id: BR-35
    disposition: not-addressed
    note: |
      chat_parser.lua:267 still at column 0 in a tab-indented body.
  - id: BR-36
    disposition: not-addressed
    note: |
      chat_parser.lua:456-459 comment unchanged.
  - id: BR-38
    disposition: not-addressed
    note: |
      fence.lua still absent from PURE_FILES at tests/arch/buffer_mutation_spec.lua:62.
  - id: BR-39
    disposition: not-addressed
    note: |
      Header unchanged, and now proven load-bearing — the harness reports 0 violations on a transcript where row 20's question has foldclosed=13.
  - id: BR-40
    disposition: addressed
    note: |
      config.lua:640 restored to 42; no test pins config defaults, so the same accident stays undetectable by the suite.
  - id: BR-41
    disposition: addressed
    note: |
      lessons.md:733-742 carries the revert half plus the gate corollary. Plan line 1338 is still ticked and the new BR-30 tests repeat the pattern — recorded in I3, not re-raised.
  - id: BR-42
    disposition: withdrawn
    note: |
      The remedy asked for is already present — fold_projection.lua:118-121 names the immediately-after-the-marker coupling verbatim, unchanged since b2bf1d5.
findings:
  - id: new
    severity: Critical
    family: drift-guard-blinded
    title: |
      The tool-body scan accepts an opener anywhere after the marker, so a closing fence is read as an opening one and a user question ends up folded
    detail: |
      2nd finding in family drift-guard-blinded (BR-33 was the 1st, in fold_projection). Do NOT
      patch the two instances — fix the rule. Rule: a tool body's extent requires (a) the marker
      at fence depth 0, (b) the opener on the immediately-following line (already enforced at
      fold_projection.lua:121), (c) an open_len that recognises every CommonMark opener, since a
      rejected opener leaves its closer to be misread as an opener. One function computes this;
      every consumer calls it. fence.extract_body is the natural home and implements none of the
      three. Sites: chat_parser.lua:536-550 and answer_structure.lua:90-97. Measured against
      dc5ee17 (M1 close): three shapes each drop 3 exchanges to 2 at HEAD - a rejected opener
      such as the ```json {"type": "request"} that render_buffer.lua:104 emits, an unclosed body
      fence followed by any later bare fence, and an answer that shows the transcript format
      inside a plain ```text block. On real Neovim fold state the third gives foldclosed=13 for
      the question at row 20 where dc5ee17 gives -1 - the issue's headline symptom, reintroduced.
      answer_structure fails the Spec's second invariant instead - a summary is swallowed into
      tool_result[1..7] where dc5ee17 emits summary[5..5]. The live 115-file corpus is unaffected
      only because it contains zero tool markers; it does contain 5 grammar-rejected openers and
      3 markers quoted inside plain fenced blocks. tests/fixtures/fold_adversarial.md covers none
      of the three shapes.
  - id: new
    severity: Important
    family: shadow-consumer-not-derived
    title: |
      A second in-tool-body tracker was introduced while the plan's Core concepts states none was
    detail: |
      3rd finding in family shadow-consumer-not-derived. Do NOT fix the instance - state the rule:
      one fact, one computation, injected into both consumers; a second derivation of "am I inside
      a tool body" is the same DRY violation M2 exists to remove, relocated one layer up.
      cb_state.tool_fence_len / tool_body_complete at chat_parser.lua:460-466 still drives block
      finalisation while in_tool_body[] at :529-556 drives main-loop classification; they compute
      the same fact by different rules and diverge on exactly the C1 shapes. Plan line 44 asserts
      "No second fence tracker is introduced (PQ-3)" - a Core-concepts contradiction the checklist
      rates Critical by default; filed Important because C1 carries the behavioural weight and the
      fix folds into C1's shared helper. Needs a "## Revisions" entry either way. Same rule at
      lower stakes: log_emit.lua:253-272 and skills/review/journal.lua:14 hand-pick fence strings,
      the latter documenting the unsound case fence.for_content solves.
  - id: new
    severity: Important
    family: redundant-computation
    title: |
      The precompute reclassifies every line two to three times, making parse_chat about 48 percent slower
    detail: |
      2nd finding in family redundant-computation (BR-37 was fence.open_len twice on one line).
      Do NOT fix the instance - the rule is: a per-line grammar or classification predicate is
      computed once per parse into a shared array and read from there, never recomputed inside a
      scan. answer_structure.reduce:29 already does this. chat_parser now calls
      highlight_structure.classify in the precompute row loop (:533), again in every inner scan
      (:538), and a third time in the main loop (:561). Measured best-of-10 on a 10,104-line
      tool-heavy transcript: 24.49 ms at dc5ee17 to 36.22 ms at HEAD. parse_chat runs at
      tool_folds.lua:150 on hydrate and every drift re-derive, and eight times across
      chat_respond.lua. The issue's own Done-when commits to no streaming regression and M1 took
      per-chunk reconcile from 3.705 ms to 0.067 ms. Same edit as C1 - build kinds[] once and pass
      it to the shared span helper.
  - id: new
    severity: Important
    family: ticked-without-evidence
    title: |
      The revert-must-go-red rule was written and then not applied by the commit that wrote it
    detail: |
      4th finding in family ticked-without-evidence. Do NOT fix the instances. BR-41's remedy did
      land - lessons.md:733-742 states the rule and the gate corollary. In the same commit,
      describe("unterminated tool body (#200 BR-30)") presents two tests as pinning BR-30; against
      b2bf1d5 the file is 17 pass / 1 fail, so chat_parser_tools_spec.lua:485 is green on revert -
      characterization wearing a fix-pin label, unlabelled. Plan line 1338 still ticks
      "sdlc milestone-close M2" while this review is that milestone-close; only line 1352 was
      unticked. Prevalence in this issue: BR-34, BR-41 twice, and these two - five instances, the
      last three after the rule was written. Escalation: a third prose restatement will not hold.
      The rule needs a mechanical gate - a Pinned-by trailer that milestone-close refuses without
      a recorded red-on-revert run, and a close-gate check that no plan step naming
      sdlc milestone-close or sdlc close is ticked at the moment that command runs.
```

---

## Re-review — 2026-08-21T16:40:13-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 200 — user question is folded |
| repo | parley.nvim |
| issue file | workshop/issues/000200-user-question-is-folded.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | 6c0132dc05ea7cb3dfae352fd249bd04027b0f9b..6c0132dc05ea7cb3dfae352fd249bd04027b0f9b |
| command | sdlc milestone-close --issue 200 --milestone M2 |
| reviewer | claude |
| timestamp | 2026-08-21T16:40:13-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

M2's core move — one `parley.fence` module, one `tool_body()` definition, three consumers deriving from it — is the right architecture, and two of its three stated requirements are real, pinned, and verified by revert. But the third, "the marker must be at fence depth 0" (BR-43(a)), was silently dropped while the issue Log claims the structural half was done "as directed", and its absence **reintroduces the issue's headline symptom**: on a buffer where an answer quotes a `📎:` line inside a plain ` ```text ` block and a later code block exists, `foldclosed()` on the user's question is **10 at HEAD and −1 at dc5ee17 (M1 close)** — the question is folded, and M1's interior guard blinds itself on the same false body. That shape is *not* the one deferred to #203 (that one is an unclosed body; here the body is closed and the marker is simply at depth 1), so the deferral does not cover it. Separately, BR-45 does reproduce under interleaved min-of-5 measurement (+23% tool-free, +53% tool-heavy vs M1 close), contradicting the commit's "does not reproduce". Those two block SHIP.

### 1. Strengths

- **`fence.tool_body`'s close-must-exist rule is real and properly pinned.** Reverting it to swallow-to-end turns `tests/unit/chat_parser_tools_spec.lua:465` red (17/1 → verified in a scratch copy). BR-30 is genuinely fixed, not asserted.
- **The CommonMark widening addresses a real parley-emitted shape.** `lua/parley/render_buffer.lua:104` really does emit ` ```json {"type": "request"} `, and `fence_spec.lua:11-18` goes red on revert. Correct root-cause diagnosis.
- **`answer_structure.reduce` got materially better.** The BR-29 rewind is gone and the unterminated arm now degrades to "stop at the next boundary" — measured: `📎:` + unclosed fence + `📝:` gives `tool_result[9..11] summary[12..12]` at HEAD vs `tool_result[9..12]` (summary swallowed) at dc5ee17.
- **BR-31 restoration is complete.** Test inventory diff vs dc5ee17: 11 → 21 names, **zero** removed.
- **`tests/fixtures/fold_adversarial.md`** is the right kind of fixture — it encodes the shapes the 115-file live corpus provably cannot exercise (that corpus parses byte-identically at dc5ee17 and HEAD; I re-ran it).
- Lint clean: 0 warnings / 0 errors across 333 files. Unit suite green. (Two integration failures — `git_markdown_source_spec`, `markdown_finder_async_spec` — are environmental: `git init` returns 128 copying templates into `.test-tmp`, unrelated to this diff.)

### 2. Critical findings

**BR-43 is not addressed — a user question is folded at HEAD that was not at M1 close.**
`lua/parley/fence.lua:123` implements requirements (b) opener-adjacency and (c) close-must-exist, but not (a) *the marker must be at fence depth 0*. Measured, real Neovim fold state:

```
💬: q1 / 🤖: [A] / ```text / 📎: read_file id=x / ``` / (blank) / 💬: q2 / ...
🤖: [A] / ``` / code / ``` / 💬: q3
```
| | dc5ee17 (M1 close) | HEAD |
|---|---|---|
| `foldclosed(13)` on `💬: q2` | `-1` | **`10`** |
| exchanges | 3 | 2 |

The `📎:` at depth 1 is classified as a marker; the next line — the *closer* of the ` ```text ` block — is read as an opener; the scan latches on the code block's opener and the body spans the question. `verify_anchors` then suppresses its own user-pattern check for exactly those rows (`fold_projection.lua:134-140`), so M1's last line of defence passes. **Fix sketch:** one linear pass in `fence` producing `kinds[]` + `in_tool_body[]` together — at depth 0, a tool marker whose next line opens a body consumes to its close; any other depth-0 opener skips to its own close; everything between is depth > 0 and yields no markers. That single pass delivers (a), keeps `fold_adversarial.md` green (I traced it), and is the same edit that fixes BR-45.

### 3. Important findings

- **BR-45 reproduces.** Interleaved min-of-5 rounds, same machine, 10.3k-line transcripts: tool-free 43.01 ms (dc5ee17) → 52.83 ms (HEAD), +23%; tool-heavy 33.65 → 51.46 ms, +53%. `highlight_structure.classify` runs twice per row (`chat_parser.lua:532` and `:544`). Caching `kinds[]` across the two loops recovers tool-free to 41.79 ms and tool-heavy to 42.80 ms with `chat_parser_tools_spec` 20/20, `parse_chat_spec` 54/54 green. The commit's 174–204 ms rebuttal measures a corpus-read workload where parse time is swamped — I reproduced that noise band once (a 192 ms outlier for dc5ee17) before switching to interleaved min.
- **BR-44's divergence is now measurable at HEAD.** Same buffer, `🔧:` + blank + fenced body + prose: `content_blocks` (the `cb_state` tracker, `chat_parser.lua:460-466`) gives `tool_use[9..13] text[14..14]`; `semantic_sections` (via `fence.tool_body`) gives `tool_use[9..14]`. At dc5ee17 they agreed. The former feeds `_emit_content_blocks_as_messages` → the API; the latter feeds `exchange_model` → folds. No test covers the disagreement.
- **`fence.lua:113-117`: `stop_row` is dead API documented as the mitigation for the deferred bug.** Zero of three call sites pass it; `fence_spec` never exercises it. Its docstring asserts it prevents "an UNCLOSED body latching onto the next unrelated bare fence… swallowing every question in between" — precisely what the issue Log records as deferred to #203 after the bound was rejected as circular. The module now documents a protection it does not have.
- **The hand-maintained restatements of the fence model drifted inside the milestone.** `atlas/providers/tool_use.md:155-156` says "a bare-word info string (`json`, `lua`)" — the grammar 6c0132d replaced two commits later; `:164-165` and `:170` still name `chat_parser`'s `tool_fence_len` tracker as what the main loop consults (it consults `in_tool_body[]`); `tool_body` is not mentioned at all. Plan `Core concepts` line 33 still says "three consumers" where there are four.
- **BR-32 residual:** `atlas/chat/parsing.md` — the page traceability maps to `chat_parser.lua` + `answer_structure.lua` — is untouched; `:17` still reads "Structural markers … always terminate either mode", and the in-body-content rule appears nowhere. Plan Step 3 (ticked) directs `fence.lua` into traceability under **`chat/parsing`**; it went under `chat/exchange_model`, so `make test-spec SPEC=chat/parsing` never runs `fence_spec`.
- **BR-46 residual:** plan `:1340` `- [x] Step 4: Milestone close` is still ticked while this review *is* that milestone-close; issue status is `working` with no `closed M2` line. No mechanical gate landed — and `sdlc` lives in `../ariadne/bin`, so the gate itself is not implementable in this repo's diff and needs a cross-repo issue.

### 4. Minor findings

- `fence.lua:37` returns an undocumented second value (`info`, unused by every caller) while `:32` annotates `@return integer|nil`; in argument position that silently expands to two args.
- `answer_structure.lua:93` — `local _ = body_first` is a dead assignment left to quiet an unused warning.
- `fold_projection.lua:126-131` allocates a full `shifted` copy of every tool range on every `verify_anchors` call (per streamed chunk); `tool_body` taking an offset would avoid it. `fence.closes:50` also runs `line:match("^(`+)")` twice on the matching path — now called once per body row.
- BR-35 (`chat_parser.lua:267` require unindented in a tab-indented body) and BR-36 (`:456-459` comment restating the grammar — now also wrong about the info string) both still stand.

### 5. Test coverage notes

- Verified by revert, in a scratch tree: close-must-exist → **red** (`chat_parser_tools_spec.lua:465`, `fence_spec.lua:164`). Adjacency → red only in `fence_spec.lua:158`; **all three** `chat_parser` BR-43 tests stay green. CommonMark `open_len` → red only in `fence_spec.lua:11,20,176`; `chat_parser_tools_spec.lua:512` stays green.
- `chat_parser_tools_spec.lua:512` is therefore characterization wearing a fix-pin label. The fixture that *would* be red is the same shape with a marker **inside** the json-info body: 3 exchanges at HEAD, **4** with `open_len` reverted. That one line of fixture change converts it into a real pin.
- BR-39 confirmed by construction: `fold_invariants_spec.lua:78-88` builds its oracle from the same `parse_chat` it validates, so the Critical above — where `parse_chat` stops seeing `💬: q2` as a question — passes that harness silently. Nothing in the file says so.
- No coverage for: a marker at fence depth > 0 (the Critical), the `cb_state`/`in_tool_body` divergence, or `stop_row`.

### 6. Architectural notes

- **ARCH-DRY — flag.** The consolidation is right in shape but incomplete in fact: two "am I in a tool body" derivations inside `chat_parser` that now disagree (measured above), and two body extractors in one module (`extract_body` scans for any opener; `tool_body` requires adjacency) that both operate on a rendered tool block.
- **ARCH-PURE — pass, with BR-38.** `fence.lua` is genuinely pure and injected as data into thin callers; every test runs without IO. Its header claims purity and the plan classifies it PURE, but `tests/arch/buffer_mutation_spec.lua:61-65` does not list it, so the claim is unenforced. One line.
- **ARCH-PURPOSE — flag.** The shadow sweep is the weak axis: `render_buffer`, `serialize`, `answer_structure`, `chat_parser` and `fold_projection` all derive from `fence`, but the *documentation* consumers (atlas page, plan Core concepts) restate the model by hand and have already drifted within the milestone. Prose cannot literally derive; the enforceable substitute is to reduce those sections to pointers at `fence.lua`'s docstring and register `fence.lua` + `fence_spec.lua` under every atlas key whose page states the rule, so `make test-changed` couples them.
- **ARCH-MOCK — pass for this window.** No new external binary or service. Pre-existing and outside the diff, for a later boundary: `render_buffer.lua:100` shells to `python3 -m json.tool` with no seam or fake, and `fold_invariants_spec.lua:17` shells to `git ls-files` (the file explicitly declines to make it a seam).

### 7. Plan revision recommendations

1. `Core concepts` line 33 — "1:N — one grammar, three consumers" → **four** (`serialize`, `answer_structure`, `chat_parser`, `fold_projection`), and list `extract_body` / `tool_body` alongside `open_len`/`closes`/`for_content`.
2. New `## Revisions` entry recording that BR-43 requirement (a) — marker at fence depth 0 — was **not** delivered, with the measured `foldclosed` evidence, so the plan stops implying the structural half is complete.
3. Untick `:1340` Step 4 (Milestone close) and add an evidence line beside Step 3 stating what `traceability.yaml` actually received vs what the step directs.
4. Record that `stop_row` was rejected as a discriminator (per the Log) and either delete the parameter or give it a caller and a test — the docstring must not claim a mitigation the design declined.

```findings
dispose:
  - id: BR-30
    disposition: addressed
    note: |
      Verified by revert - making tool_body swallow to end turns chat_parser_tools_spec.lua:465 red.
  - id: BR-32
    disposition: not-addressed
    note: |
      format.md fixed; atlas/chat/parsing.md:17 untouched and fence.lua went under chat/exchange_model, not chat/parsing as ticked Step 3 directs.
  - id: BR-35
    disposition: not-addressed
    note: |
      chat_parser.lua:267 is still unindented.
  - id: BR-36
    disposition: not-addressed
    note: |
      chat_parser.lua:456-459 still restates the grammar and is now also wrong about the info string.
  - id: BR-38
    disposition: not-addressed
    note: |
      tests/arch/buffer_mutation_spec.lua:61-65 still omits lua/parley/fence.lua.
  - id: BR-39
    disposition: not-addressed
    note: |
      No comment added; the Critical below is a concrete case the oracle cannot see.
  - id: BR-43
    disposition: not-addressed
    note: |
      Requirement (a) marker-at-fence-depth-0 not implemented; question folded at HEAD (foldclosed=10) where dc5ee17 gives -1.
  - id: BR-44
    disposition: not-addressed
    note: |
      Plan Correction landed, but the two trackers now measurably disagree at HEAD (tool_use[9..13] vs [9..14]).
  - id: BR-45
    disposition: not-addressed
    note: |
      Reproduces under interleaved min-of-5 - tool-free 43.01ms to 52.83ms, tool-heavy 33.65ms to 51.46ms vs dc5ee17.
  - id: BR-46
    disposition: not-addressed
    note: |
      No mechanical gate; plan line 1340 still ticked; a new green-on-revert fix-pin claim shipped this round.
findings:
  - id: new
    severity: Important
    family: failure-fallback-misgated
    title: |
      fence.tool_body's stop_row is dead API documented as the mitigation for the bug deferred to #203
    detail: |
      This is the 2nd finding in family failure-fallback-misgated (BR-29 was the 1st - a rewind
      that fired on correctly closed input). Do NOT fix this instance; state the rule. Rule: a
      degradation path is real only when a production caller reaches it AND a test drives the
      degraded branch; an available-but-unpassed parameter, or an arm no fixture enters, is
      documentation that reads as protection. Prevalence in this issue: 2 - BR-29 fired on the
      wrong input, stop_row fires on none. fence.lua:113-117 asserts stop_row prevents an
      unclosed body latching onto a later bare fence, which is exactly what the issue Log records
      as deferred to #203 after that bound was rejected as circular. Call sites
      chat_parser.lua:534, answer_structure.lua:85, fold_projection.lua:131 all omit it; fence_spec
      never exercises it. Either delete the parameter or give it a caller and a red-on-revert test.
  - id: new
    severity: Important
    family: shadow-consumer-not-derived
    title: |
      The hand-maintained restatements of the fence model drifted from fence.lua inside the milestone
    detail: |
      This is the 4th finding in family shadow-consumer-not-derived. Earlier rounds fixed
      instances. Do NOT fix this instance - fix the rule. Rule: every consumer of a
      single-sourced model must DERIVE from it; a hand-maintained restatement is a deferred
      consumer, and prose cannot derive, so the enforceable substitute is (i) reduce the
      restating section to a pointer at the source's own docstring, and (ii) register the source
      module and its spec under every atlas key whose page states the rule, so make test-changed
      couples them. Measured drift: atlas/providers/tool_use.md:155-156 says "a bare-word info
      string (json, lua)" - the grammar replaced by 6c0132d two commits after that page was
      written; :164-165 and :170 name chat_parser's tool_fence_len tracker as what the main loop
      consults, which is in_tool_body[]; tool_body is unmentioned. Plan Core concepts line 33
      says three consumers where there are four. Prevalence in this issue: 4.
  - id: new
    severity: Minor
    family: serialized-shape-assumed
    title: |
      fence.open_len returns an undocumented second value that every caller ignores
    detail: |
      fence.lua:37 returns "#ticks, info" while :32 annotates "@return integer|nil". No caller
      uses info. In argument position the extra return silently expands the call; fence_spec's
      assert.equals calls survive only because luassert compares the first two arguments.
      Drop the second return or annotate it.
  - id: new
    severity: Minor
    family: style-consistency
    title: |
      answer_structure.lua:93 keeps a dead "local _ = body_first" assignment
  - id: new
    severity: Minor
    family: redundant-computation
    title: |
      verify_anchors copies every tool range into a shifted table on each per-chunk call
    detail: |
      fold_projection.lua:126-131 allocates a full copy of range.start_0..end_0 per tool range
      per verify, on the streaming path; an offset argument on fence.tool_body would avoid it.
      fence.closes:50 also runs line:match("^(`+)") twice on the matching path, now once per
      body row of every tool_body scan.
```
