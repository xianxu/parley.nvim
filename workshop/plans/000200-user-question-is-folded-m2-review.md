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
