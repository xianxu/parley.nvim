# Boundary Review — parley.nvim#155 (whole-issue close)

| field | value |
|-------|-------|
| issue | 155 — enforce tool_use→tool_result invariant at message-emission (synthesize error results for dangling calls) |
| repo | parley.nvim |
| issue file | workshop/issues/000155-enforce-tool-use-tool-result-invariant-at-message-emission-synthesize-error-results-for-dangling-calls.md |
| boundary | whole-issue close |
| milestone | — |
| window | d71bf7a78def79559c609e475d5cd0585e8837a9..HEAD |
| command | sdlc close --issue 155 |
| reviewer | claude |
| timestamp | 2026-07-01T00:42:15-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The implementation is correct and cleanly delivers #155's purpose: a single pure emitter (`_emit_content_blocks_as_messages`) now enforces the tool_use→tool_result invariant by construction, both build paths route through it, the empty-dict divergence is closed at one source, and the inline duplicate in `build_messages_from_model` is gone. I traced the `pending`-id state machine through single-dangling, dangling-then-text, partial-parallel, multi-round, and dangling-in-round-1 cases — the synthetic always lands in the immediately-following user batch, and `pending` never leaks across assistant batches (the mutual exclusion of `current_assistant`/`current_user` guarantees it). I independently ran the spec: **44/44 pass, 0 failures**. The one thing keeping this from a clean SHIP is a test-coverage gap on the live/recursion path (`build_messages_from_model`), which is a first-class Spec deliverable but has zero end-to-end coverage — non-blocking but worth closing.

### 1. Strengths
- **Genuine single choke point (ARCH-DRY confirmed).** Grep for `tool_use_id` across `lua/parley/` returns only lines 486-487 (synth) and 538-539 (real) — both inside the one emitter. `chat_respond.lua:415` and `chat_parser.lua:381` produce the *normalized* `id` shape feeding it, not the payload shape. The shadow-sweep is clean: parse path (`build_messages:774`) and live path (`build_messages_from_model:362`) both derive from the emitter.
- **Invariant is correct under partial parallel resolution.** `flush_user` draining `pending` into the *open* real-result batch (`chat_respond.lua:520-528`) is the subtle-but-right choice — the synthetic for the dangling call shares the same user message as the real result (test at `build_messages_spec.lua:1362`), which is exactly the HTTP-400 shape being prevented.
- **Empty-dict fix lives at one source** (`chat_respond.lua:554-557`) and is asserted via `vim.json.encode` producing `"{}"` (`build_messages_spec.lua:1428`) — real serialization, not a reassertion of the branch.
- **Reason-agnostic vs reason-specific split is well-reasoned** (`chat_respond.lua:466-471`): build-time synthetic stays neutral, stop-time repair keeps `"(cancelled by user)"`. The two never collide — a real repaired `📎:` resolves `pending`, so no double-result.
- **Atlas updated in-range** (`atlas/providers/tool_use.md:68`) documenting the new invariant + `DANGLING_TOOL_RESULT_TEXT` + the "buffer repair is now a UX nicety" reframing. Atlas gate satisfied.

### 2. Critical findings
None.

### 3. Important findings
- **Missing live-path integration test (ARCH-PURPOSE / test coverage).** `tests/unit/build_messages_spec.lua` — the new tests cover the pure emitter directly (6 cases) and the parse path via `_build_messages` (1 case), but **nothing exercises `build_messages_from_model`** with a dangling call (grep confirms it appears only in a comment, `:1298`). This is the more operationally-relevant path — the "crash/kill mid-loop" scenario that motivated the issue surfaces on the live recursion path — and its normalization seam (`chat_respond.lua:369-427`: read block text, `parse_call`/`parse_result`, malformed→text degradation, the defensive `flush_answer` on `question`) was freshly rewritten with **zero coverage before or after**. The invariant logic itself is safe (tested in the emitter), so this is non-blocking, but a regression in the normalization (dropped/mis-ordered block never reaching the emitter) would ship silently. *Fix sketch:* one test building a real buffer + `exchange_model` with a dangling `🔧:` in a past exchange, calling `M.build_messages_from_model`, asserting the synthetic `is_error` `tool_result` appears in the user message after the assistant. This directly pins Spec item #2.

### 4. Minor findings
- `pending` stores id-only (`chat_respond.lua:564`), but the plan's algorithm text (issue §Spec, line 59) says `pending = ordered list of {id, name}`. The id-only form is a benign YAGNI simplification (the synthetic only needs `tool_use_id`) — code is better than the plan here; the plan text is now slightly stale.
- Orphan `tool_result` (a `📎:` with no preceding `🔧:`) is still appended verbatim (`chat_respond.lua:535-542`) and would itself trigger an Anthropic 400 (user `tool_result` with no matching assistant `tool_use`). Out of scope for #155 (which is titled for *dangling tool_use*) and **pre-existing** (old emitter behaved identically), but it's the symmetric residual gap in the same invariant — worth a future issue.
- `next(input)` at `chat_respond.lua:555` assumes `input` is a table; safe for all current callers (`serialize.parse_call` always returns `input` as a table, `chat_parser` likewise), but the emitter is `M.`-exported, so an external caller passing a non-table `input` would throw rather than coerce. Undefended contract, not a live bug.

### 5. Test coverage notes
- Pure emitter: thoroughly covered — the six Done-when cases map 1:1 to tests, and they pin real serialization (`vim.json.encode`) rather than reasserting branches. This is the highest-risk logic and it's well-nailed (ARCH-PURE: tests run with no buffer/IO).
- Parse path: one solid integration test (`build_messages_spec.lua:1411`) with a real `parsed_chat` and a dangling `tool_use` in a *past* exchange — exactly the crash/reload scenario.
- Gap: live path (see Important). Also no explicit regression test that a stop-repaired `📎: (cancelled by user)` suppresses the build-time synthetic (I verified by trace that it does — real result resolves `pending` — but it's asserted nowhere).

### 6. Architectural notes for upcoming work
- **ARCH-DRY — pass.** One emitter; normalization seams feed it. Verified by grep, not just by reading the diff narrative.
- **ARCH-PURE — pass.** The emitter is a pure `content_blocks → messages` function, tested directly without a buffer. IO (buffer reads, `serialize.parse_*`) stays in the `build_messages_from_model` normalization seam. `vim.empty_dict()` is a deterministic factory, consistent with how the codebase treats `vim.*` helpers — not injected IO.
- **ARCH-PURPOSE — pass.** The shadow-sweep confirms *every* consumer derives from the single emitter (both build paths + empty-dict coercion), the inline duplicate is deleted, and the empty-dict fix was done here rather than deferred. Nothing that "is the point" was left as follow-up. The only under-delivery is test depth on the live path (§3), not scope.
- The orphan-`tool_result` symmetric gap (§4) is the natural next hardening if payload-validity-by-construction is to be fully closed.

### 7. Plan revision recommendations
The plan matches the code substantively; both notes below are optional cosmetic reconciliations, not required:
- Optional `## Revisions` entry noting `pending` stores **id-only** (not `{id, name}` as the Spec algorithm states) — a deliberate simplification since only `tool_use_id` is needed for the synthetic.
- The Plan's four checkboxes are all genuinely delivered (verified against the diff + a live test run); no traceability gaps. If the §3 live-path test is added, tick it under the existing test-coverage checkbox rather than adding a new milestone (this is single-pass atomic work — no `Mx` split needed).
