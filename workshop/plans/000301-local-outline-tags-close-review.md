# Boundary Review — parley.nvim#301 (whole-issue close)

| field | value |
|-------|-------|
| issue | 301 — Keep outline tags out of model context |
| repo | parley.nvim |
| issue file | workshop/issues/000301-local-outline-tags.md |
| boundary | whole-issue close |
| milestone | — |
| window | 4539950f811407dc477b5064b043631cea2b760c..faee549a44f898e00f373d3f3515340aa5c167d8 |
| command | sdlc close --issue 301 |
| reviewer | codex |
| timestamp | 2026-09-29T11:11:28-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The shared projection preserves raw text and handles the tested tag, reference, and tool-payload cases. However, two reproduced correctness defects block shipping: projection can emit empty provider text blocks, and fences opened on a question’s speaker line lose literal content.

1. **Strengths**

   - Source-row projections preserve local `content`, spans, and tool payloads.
   - Parsed, live, and ancestor regressions exercise actual message builders.
   - README and atlas document the new behavior; stacked outline tests cover default and custom prefixes.

2. **Critical findings**

   - **Empty projected text reaches the provider** — `lua/parley/chat_respond.lua:797`. An answer containing only `@@only@@` before a tool call becomes `{type="text", text=""}`. I reproduced this through `build_messages` and `dispatcher.prepare_payload`; the live builder correctly omits that block. Empty text blocks violate Anthropic’s request contract. Drop empty projected text blocks and handle entirely empty projected messages consistently across builders, preserving tool ordering. Add regressions for tag-only questions, answers, and text surrounding tools. **ARCH-PURPOSE**.

   - **Speaker-line fence openers are missed** — `lua/parley/question_tags.lua:19`. Parsing the three question rows `💬: ````, `@@literal@@`, and ` ``` ` (bare closing fence, without surrounding spaces) retains the fenced example in raw content but produces `context_content = "```\n```"`. The scanner examines only the original physical line for a fence opener, so it never enters the fence after the speaker prefix. Track fence syntax in the question’s content while retaining original-row provenance for tag classification. Test both parsed and live paths with default/custom prefixes. **ARCH-PURPOSE**.

3. **Important findings**

   - **Changed topic consumers lack regression coverage** — `lua/parley/chat_respond.lua:1673` and `lua/parley/init.lua:4450`. The added tests exercise parsed/live/ancestor messages, but do not capture automatic-topic or ChatPrune topic requests. Add caller-level tests proving local tags disappear while inline/fenced examples remain, with assertions that fail when each caller’s projection is removed. The issue explicitly requires coverage of every changed context consumer.

4. **Minor findings**

   None newly raised.

5. **Test coverage notes**

   Passed `make test-spec` for `chat/format`, `chat/memory`, `ui/outline`, and `chat/exchange_model`. Both correctness defects were reproduced separately in headless Neovim. The harness reported that orphan-process checks were skipped because `ps` was unavailable. The packaged completion smoke was not rerun.

6. **Architectural notes**

   | Principle | Assessment |
   |---|---|
   | ARCH-DRY | Pass: consumers share tag classification and projection. |
   | ARCH-PURE | Pass: projection logic remains separate from buffer IO. |
   | ARCH-PURPOSE | **Flag:** empty-output handling and fenced-literal preservation are incomplete. |
   | ARCH-MOCK | Pass: no new external-service boundary. |
   | ARCH-CONSTRAINTS | Pass: projection is linear, with no new fan-out. |
   | ARCH-SECURE | Pass: no new credential or execution boundary. |
   | ARCH-ORDER | Pass: scanner state is invocation-local; no new cross-event lifecycle. |
   | ARCH-FUNERAL | Pass: projections add no durable artifacts or handles. |

7. **Plan revision recommendations**

   Append a timestamped `## Revisions` entry recording the empty-projection policy, speaker-line fence handling, and topic-consumer regression matrix. Reconcile the completed Plan checkbox after those corrections pass.

```findings
findings:
  - id: new
    severity: Critical
    family: projection-preserves-message-validity
    title: |
      Drop empty text blocks and messages after local-tag projection
    detail: |
      lua/parley/chat_respond.lua:797 retains a text block whose context_text is empty. A tag-only text section before a tool call produces an empty text block in the actual Anthropic payload, whereas the live builder omits it. Normalize empty projected content consistently across builders and test tag-only questions, answers, and text sections around tools. ARCH-PURPOSE.
  - id: new
    severity: Critical
    family: projection-preserves-fenced-literals
    title: |
      Recognize fences opened after the question speaker prefix
    detail: |
      lua/parley/question_tags.lua:19 misses a fence opener on the question's speaker line. A question beginning with the user prefix followed by three backticks loses a subsequent @@literal@@ row despite its closing fence. Preserve original-row tag classification while recognizing question-content fence syntax; cover parsed/live paths and custom prefixes. ARCH-PURPOSE.
  - id: new
    severity: Important
    family: changed-consumer-regression-coverage
    title: |
      Exercise tag projection through both changed topic-request callers
    detail: |
      lua/parley/chat_respond.lua:1673 and lua/parley/init.lua:4450 change automatic-topic and ChatPrune topic inputs without caller-level regression coverage. Capture both outgoing requests and assert local-tag exclusion and literal preservation; removing either caller's projection must fail its test.
```

---

## Re-review — 2026-09-29T11:27:42-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 301 — Keep outline tags out of model context |
| repo | parley.nvim |
| issue file | workshop/issues/000301-local-outline-tags.md |
| boundary | whole-issue close |
| milestone | — |
| window | 4539950f811407dc477b5064b043631cea2b760c..c93e658571da4777470aad762320f3242c76a9fa |
| command | sdlc close --issue 301 |
| reviewer | codex |
| timestamp | 2026-09-29T11:27:42-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The projection preserves raw transcript text, and the empty-content and topic-caller fixes have meaningful regression coverage. However, two fence-classification cases still remove literal content or leak local tags. BR-2 remains partially unresolved.

1. **Strengths**

   - Parsed context projections preserve the original text for rendering.
   - Empty projected messages and tool-adjacent text blocks are omitted without changing tool order.
   - Both topic callers have outgoing-payload tests. Independently removing each projection makes its regression fail.
   - README and atlas updates cover the new behavior and stacked #300 surface.

2. **Critical findings**

   **BR-2 — not fully addressed:** [question_tags.lua:56](/Users/xianxu/workspace/parley.nvim/lua/parley/question_tags.lua:56) still uses a different fence scanner for preface association. For these consecutive rows:

   ~~~~text
   💬: ```
   @@literal@@
   💬: Next
   ~~~~

   `local_rows` correctly preserves the literal, but `associations` moves it into the next question’s preface, and `compose_question` removes it. I reproduced ancestor messages containing only `"```"` and `"Next"`. The repository explicitly supports a turn marker ending an unmatched fence. Use the same fence classification for association and projection. **ARCH-DRY, ARCH-PURPOSE.**

   **New — mixed delimiters incorrectly close fences:** [question_tags.lua:26](/Users/xianxu/workspace/parley.nvim/lua/parley/question_tags.lua:26) accepts any mixture of backticks and tildes as a closer. Given:

   ~~~~text
   ```text
   ```~~~
   @@literal@@
   ```
   @@local@@
   ~~~~

   projection removes `@@literal@@` and retains `@@local@@`. Both outcomes violate the contract. A closer must contain only the opening delimiter character, with sufficient width.

   **This is the 2nd finding in family `projection-preserves-fenced-literals`.** State and implement the shared rule across projection and association; enumerate delimiter character, width, trailing content, speaker-line openers, and turn-boundary termination. **ARCH-DRY, ARCH-PURPOSE.**

3. **Important findings**

   None beyond the blocking findings above.

4. **Minor findings**

   No substantive findings.

5. **Test coverage notes**

   - 285 tests passed across `chat/format` and the separately exercised tag, ancestor, and topic specs.
   - In-memory mutations caused the BR-1 regression, all six BR-2 speaker-fence cases, and each of the three BR-3 caller projections to fail independently.
   - Changed production Lua files pass luacheck.
   - The two remaining cases were reproduced through production parsing and ancestor-message construction. They need regression tests.
   - Checkout changes were left untouched.

6. **Architectural notes**

   - **ARCH-DRY — flag:** association and projection disagree about fence state.
   - **ARCH-PURE — pass:** projection logic is deterministic; buffer access remains at callers.
   - **ARCH-PURPOSE — flag:** fenced-literal preservation and local-tag exclusion remain incomplete.
   - **ARCH-MOCK — pass:** no new external dependency; caller tests capture requests through existing seams.
   - **ARCH-CONSTRAINTS — pass:** projection uses bounded-by-input linear scans; no new fan-out.
   - **ARCH-SECURE — flag:** malformed delimiter classification silently changes user-provided context.
   - **ARCH-ORDER — pass:** new scanner state exists only within a synchronous invocation.
   - **ARCH-FUNERAL — pass:** new context fields are transient; no new runtime persistence family.

7. **Plan revision recommendations**

   Append a `## Revisions` entry recording the shared fence-classification rule and its regression matrix. Correct the current BR-2 completion claim until turn-boundary association is covered.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Empty-content regression passes and fails when the projected text-block omission guard is removed in memory.
  - id: BR-2
    disposition: not-addressed
    note: |
      Balanced speaker-line fences are fixed, but a speaker-line fence terminated by the next question still loses its final literal tag through question_tags.lua:56 preface association and line 71 composition.
  - id: BR-3
    disposition: addressed
    note: |
      Both caller-level request tests pass; removing automatic-answer, prune-question, or prune-answer projection independently makes its regression fail.
findings:
  - id: new
    severity: Critical
    family: projection-preserves-fenced-literals
    title: |
      Mixed delimiter runs incorrectly close fences and invert tag projection
    detail: |
      question_tags.lua:26 accepts ```~~~ as a backtick closer, deleting a subsequent fenced literal and retaining a local tag after the real closer. This is the 2nd finding in this family: establish one fence rule across projection and association, and test delimiter character, width, trailing content, speaker-line openers, and turn-boundary termination. ARCH-DRY, ARCH-PURPOSE.
```

---

## Re-review — 2026-09-29T11:42:21-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 301 — Keep outline tags out of model context |
| repo | parley.nvim |
| issue file | workshop/issues/000301-local-outline-tags.md |
| boundary | whole-issue close |
| milestone | — |
| window | 4539950f811407dc477b5064b043631cea2b760c..9eedae23d8283b988eb47eef92478f48effd7608 |
| command | sdlc close --issue 301 |
| reviewer | codex |
| timestamp | 2026-09-29T11:42:21-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned implementation satisfies #301’s Spec and Plan. Both open fence findings are addressed, with regression tests that fail against the pre-fix module. No blocking correctness or documentation gaps found.

```findings
dispose:
  - id: BR-2
    disposition: addressed
    note: |
      Shared fence classification preserves speaker-line literals through balanced fences and turn-boundary termination. The ancestor regression passes at HEAD and fails with the pre-fix module.
  - id: BR-4
    disposition: addressed
    note: |
      Association and projection share character, width and whitespace-only closer rules. All 23 tag tests pass; restoring the pre-fix module causes 12 matrix cases to fail.
  - id: BR-1
    disposition: addressed
    note: |
      Empty projected messages and tool-adjacent text remain covered by the passing message-builder regression.
  - id: BR-3
    disposition: addressed
    note: |
      Both changed topic callers retain request-capture regressions; their integration suites pass.
```

1. **Strengths**
   - [question_tags.lua:18](/Users/xianxu/workspace/parley.nvim/lua/parley/question_tags.lua:18) shares fence classification between association and projection.
   - Parser projections preserve original text and source-row classification.
   - Tests check actual outgoing content, tool payload preservation, and default/custom prefixes.
   - README and atlas document local-only tags and literal/reference exceptions.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None requiring action.

5. **Test coverage**
   - Passed `chat/format` and `ui/outline` mapped suites.
   - Passed 98 message-builder tests, 10 ancestor tests, and 18 topic integration tests.
   - In-memory pre-fix substitution caused 12 tag tests and the ancestor reproduction to fail.
   - Changed production Lua files passed luacheck.
   - Harness process census was unavailable because sandboxed `ps` was unavailable; test execution succeeded.

6. **Architecture**
   - **ARCH-DRY — Pass:** association and projection share the corrected scanner.
   - **ARCH-PURE — Pass:** classification and projection operate on supplied text; buffer IO remains in callers.
   - **ARCH-PURPOSE — Pass:** parsed, live, ancestor and topic consumers are covered.
   - **ARCH-MOCK — Pass:** no new external dependency; topic tests capture requests through the existing seam.
   - **ARCH-CONSTRAINTS — Pass:** bounded scans of supplied rows; no new background work or fan-out.
   - **ARCH-SECURE — Pass:** original-row classification avoids promoting normalized lookalikes into local tags.
   - **ARCH-ORDER — Pass:** fence transitions are explicit within each scan; no new state survives between events.
   - **ARCH-FUNERAL — Pass:** projections are transient; no new runtime persistence or handles.

7. **Plan revisions:** None needed. Existing revisions describe the implemented shared fence rule and regression matrix.
