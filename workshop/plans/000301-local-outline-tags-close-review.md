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
