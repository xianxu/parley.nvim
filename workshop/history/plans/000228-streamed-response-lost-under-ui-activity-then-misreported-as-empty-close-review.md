# Boundary Review — parley.nvim#228 (whole-issue close)

| field | value |
|-------|-------|
| issue | 228 — streamed response lost under UI activity, then misreported as empty |
| repo | parley.nvim |
| issue file | workshop/issues/000228-streamed-response-lost-under-ui-activity-then-misreported-as-empty.md |
| boundary | whole-issue close |
| milestone | — |
| window | e4052dd860c879b4f817311a417a2e97afc42bc6..c3754c55b2d2e39007c12d3227840175121a4d55 |
| command | sdlc close --issue 228 |
| reviewer | claude |
| timestamp | 2026-09-10T10:25:48-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

Both fixes #228 claims are delivered, and a test pins each one. I checked this by reverting in a scratch copy of HEAD:
- Reverting the new message wiring turns J7d and J7e red.
- Setting the Claude cap back to 4096 turns the new provider_params test and all 7 Claude goldens red.

All changed specs pass at HEAD: dispatcher_query 62/62, dispatcher 64/64, golden 11/11, plus provider_params and empty_response_reason. I also ran J7e's fixture through `cliproxyapi` + `claude-sonnet-5`, the operator's actual provider. That isn't what the committed test uses, and it produces the correct cap diagnosis.

What keeps this from SHIP is ARCH-PURPOSE: the fix covers one case of a wider problem. The new diagnostic only recognises Anthropic's `max_tokens` stop word. I probed the other two wires:
- **OpenAI:** a gpt-5.6 body that stops with `finish_reason: "length"` and no text reports `openai returned no assistant text (body_bytes=435, stop_reason=length)`. That is the branch the docstring calls "finished normally… the only one worth a bug report", so it sends the user the wrong way, as #228 set out to stop.
- **Gemini:** the stop reason is never extracted at all.

A cap hit after some text has streamed is still silent, and the issue itself names that as the truncation symptom.

1. **Strengths**
   - The investigation rejected the UI-contention hypothesis by reading the code: `qt.response` fills on the libuv callback (`dispatcher.lua:329-332`) before anything is deferred. The raw log then confirmed the real cause. The Revisions section records this honestly and does not rewrite the Problem section.
   - The cap is keyed on the model, not the provider (`provider_params.lua:159-166`). Overrides apply all-match, so this doesn't hide the `claude-sonnet-4-6` exclusive-group entry. The cliproxy Anthropic route goes through `anthropic.format_payload`, so both transports get the new cap (tested).
   - `_empty_response_reason` is a pure function with direct unit tests, including nil `raw_response` and nil `stop_reason` (ARCH-PURE).
   - The fixture was rebuilt to the same shape instead of committing 55 KB of private transcript (ARCH-SECURE). The J7e comment explains why.
   - The J7c comment spots that the old literal would now pass vacuously. Plan rows are marked done / moved / withdrawn rather than blank-ticked, and #229 exists with the moved rows and a stated oracle.

2. **Critical:** none.

3. **Important**
   - **I1 — The cap diagnosis only knows Anthropic's stop word** (`dispatcher.lua:192`, `:346-347`). The same "cap reached before any text" condition shows up as `length` on the OpenAI family (openai, copilot, ollama, cliproxy's openai route for `gpt-*`), and as `finishReason: "MAX_TOKENS"` on Gemini. The Gemini field is camelCase, so the extractor never captures it; even the repo's own `googleai_stream.txt` gives `stop_reason=nil`. The fallthrough branch then calls these "finished normally", which contradicts the function's own docstring. The Claude-specific wording ("On Claude the cap counts thinking tokens") would also be wrong for these wires. This is live for the operator, whose `live_models` includes `codex:gpt-5.6` at a 4096 `max_completion_tokens` cap.
     - *Fix sketch:* map each wire's stop words to one small set of meanings, per adapter (like `parse_usage`) or in one pure table: `cap | refusal | paused | done | unknown`. Extract `finishReason` too, and key the message on the normalized value with wire-neutral wording.
     - *Tests:* one J7e-style case each for `openai`/`length` and `googleai`/`MAX_TOKENS`.
   - **I2 — A cap hit after some text still truncates silently.** The Revisions say "the same cap hit after some text has streamed is the truncated-mid-answer symptom". Parley already has `qt.stop_reason` at the terminal closure but only reports when `qt.response == ""`. Raising the cap makes this rarer for Claude, but every non-Claude agent is still at 4096 or 8192. With no signal, the next truncation will again look like "it happens when I scroll".
     - *Fix sketch:* in the terminal closure, when the normalized stop reason is `cap` and `qt.response ~= ""`, warn that the answer was cut off at the output cap (N tokens). This reuses I1's mapping, so it's a few lines.
     - *Test:* a text-then-`max_tokens` fixture asserting the warning.

4. **Minor**
   - The `^claude%-` 64000 default has no per-model ceiling check. All first-party models served today allow at least 64K output, but a `claude-*` id served through another channel with a lower ceiling would now get HTTP 400 where 4096 worked. Examples: Vertex/Bedrock-served `claude-3-5-haiku` (8K), or copilot's own limits. The repo's cliproxy catalog fixture still advertises `claude-opus-4-20250514` (32K) and `claude-3-5-haiku-20241022`. Either pin the assumption in a test or add lower-ceiling entries (ARCH-CONSTRAINTS). I checked the current rate-limit docs: `max_tokens` doesn't count toward OTPM, so there's no rate-limit cost.
   - The test comment at `provider_params_spec.lua:295-297` says non-Claude models "cannot honour" a higher cap. That is false for gpt-5.x (128K output). The 4096 pin for `cliproxyapi gpt-5.6` locks in the same thinking-eats-the-cap exposure for gpt-5.
   - J7c's negative check lists two of the three message wordings by hand (`dispatcher_query_spec.lua:1086-1087`). A rewording or a fourth branch makes it vacuous again, which is the trap its own comment describes. Wrapping `dispatcher._empty_response_reason` and asserting zero calls would be robust.
   - The `atlas/infra/raw_logging.md:82` example still shows `max_tokens: 4096` for `claude-sonnet-4-6`.
   - `empty_response_reason_spec.lua` is mapped under `modes/raw_mode` in traceability. `providers/architecture` fits better.
   - The comment's claim that 64000 is "Anthropic's documented default" is really the SDK guidance's recommended streaming value; the API itself has no default.

5. **Test coverage notes**
   - Both fixes are verified by revert-to-red.
   - The operator's `cliproxyapi` path is only covered by my probe, not by a committed test. A second J7e row with `provider = "cliproxyapi"` would pin the transport that actually failed.
   - No test exercises any non-Anthropic cap word; that gap is what I1 names.

6. **Architecture notes**
   - **ARCH-DRY:** pass. One helper, one schema entry. The rationale paragraph is repeated in four places; tolerable.
   - **ARCH-PURE:** pass.
   - **ARCH-PURPOSE:** flag (I1, I2).
   - **ARCH-MOCK:** pass with a note. The fixture is built by hand and isn't in `make fixtures`, so nothing checks it against a live body. A live capture with a tiny `max_tokens` and adaptive thinking would give one.
   - **ARCH-CONSTRAINTS:** pass with the ceiling note above. Parley always streams (`stream = true` everywhere), so the 64K streaming rationale holds.
   - **ARCH-SECURE:** pass. There's no secret exposure, and a missing `stop_reason` shows up as `unknown` rather than an invented value.
   - **ARCH-ORDER:** pass. `stop_reason` is written in `finish_stdout` before `empty_response`, so every read of the new field comes after its write. The single tested interleaving is structurally guaranteed.
   - **For upcoming work:** parley has no handling for `refusal` (possible with HTTP 200 on the default `claude-opus-5` agent) or `pause_turn` (server web_search). The stop-reason mapping from I1 is the right place to add both.

7. **Plan revision recommendations**
   - Add a `## Revisions` entry: the cap diagnosis now normalizes per-wire stop words (`max_tokens` / `length` / `MAX_TOKENS`) and warns on cap-truncated non-empty answers. If instead that's deferred, the entry should say so and link a tracking issue, because it is the issue's second symptom, not a separate extension.
   - If the gpt-5 cap stays at 4096 on purpose, record why in Done-when; the current reason ("cannot honour") doesn't hold for gpt-5.x.

```findings
findings:
  - id: new
    severity: Important
    family: stop-reason-vocabulary-per-wire
    title: |
      The cap diagnosis only recognizes Anthropic's max_tokens; OpenAI length and Gemini MAX_TOKENS get labelled "finished normally"
    detail: |
      Probe: gpt-5.6 finish_reason=length with no text logs "openai returned no assistant text (body_bytes=435, stop_reason=length)", which is the docstring's "finished normally, worth a bug report" branch. Gemini's camelCase finishReason is never extracted, so stop_reason is always nil. Map each wire's stop words to one set of meanings (cap/refusal/paused/done/unknown), extract finishReason, key the message on that, and use wire-neutral wording. Add J7e-style tests for openai and googleai.
  - id: new
    severity: Important
    family: detected-loss-must-surface
    title: |
      An answer cut off at the output cap after some text streamed is still silent, though stop_reason is already known
    detail: |
      The Revisions name this as the truncated-mid-answer symptom. The terminal closure only reports when qt.response is empty. Warn when the stop reason means the cap and text is non-empty; this reuses the mapping from the other finding, and a text-then-max_tokens fixture can pin it.
  - id: new
    severity: Minor
    family: model-ceiling-envelope
    title: |
      The ^claude%- 64000 default has no per-model ceiling check for claude-* ids served with lower output limits
    detail: |
      First-party models served today all allow at least 64K. Vertex/Bedrock-served claude-3-5-haiku (8K), copilot claude limits, and the catalog fixture's claude-opus-4-20250514 (32K) would get HTTP 400 where 4096 worked. Pin the assumption in a test or add lower-ceiling entries.
  - id: new
    severity: Minor
    family: rationale-matches-fact
    title: |
      The test comment says non-Claude models "cannot honour" a higher cap, which is false for gpt-5.x (128K output)
    detail: |
      The 4096 pin for cliproxyapi gpt-5.6 locks in the same reasoning-eats-the-cap exposure for gpt-5. Record the real reason, or treat gpt-5 as a sibling instance.
  - id: new
    severity: Minor
    family: vacuous-negative-assertion
    title: |
      J7c lists message wordings by hand, so a rewording or new branch makes it vacuous again
    detail: |
      Wrap dispatcher._empty_response_reason in the test and assert it is never called on a failed request.
  - id: new
    severity: Minor
    family: atlas-drift
    title: |
      The atlas raw_logging.md example still shows max_tokens 4096 for claude-sonnet-4-6; the new spec is mapped under modes/raw_mode
```

---

## Re-review — 2026-09-10T10:41:19-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 228 — streamed response lost under UI activity, then misreported as empty |
| repo | parley.nvim |
| issue file | workshop/issues/000228-streamed-response-lost-under-ui-activity-then-misreported-as-empty.md |
| boundary | whole-issue close |
| milestone | — |
| window | e4052dd860c879b4f817311a417a2e97afc42bc6..55b1d66ef28f5ae829c10d7275285bdc261006e8 |
| command | sdlc close --issue 228 |
| reviewer | claude |
| timestamp | 2026-09-10T10:41:19-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The round-2 commit `55b1d66` fixes what BR-2 asked for, and a test proves it. I reverted the truncation branch at `dispatcher.lua:590` in a scratch copy and J7f went red. The cap vocabulary is also pinned: narrowing `_is_output_cap` to `max_tokens` only fails the spelling test. I also drove bodies through `dispatcher.query`. openai `length` and googleai `MAX_TOKENS` now get the cap diagnosis when no text arrived, and the TRUNCATED warning when some did.

Two things keep this from SHIP:
- **BR-1 is only half pinned.** Deleting the new `finishReason` extraction leaves every affected spec green. The requested openai and googleai tests don't exist. The message still tells openai and googleai users "On Claude the cap counts thinking tokens".
- **The BR-2 fix covers one cause of truncation.** An answer cut short by a refusal or content filter still ends silently. So does one cut short by an Anthropic error event sent after HTTP 200. I checked all three. This is the second finding in the `detected-loss-must-surface` family.

BR-3 through BR-6 were not touched this round.

### 1. Strengths
- **J7f and J7g are a real pair.** J7f checks the warning appears; J7g checks it doesn't. J7g builds its body by `gsub`-ing J7f's fixture, so the two can't drift apart. J7f is confirmed by revert.
- **The warning sits only in the success branch** (`dispatcher.lua:590`). It can't fire on a failed request, which keeps #197's "only a successful request can be called empty" contract.
- **The ordering is guaranteed.** `tasker.lua` only runs `maybe_finish` after stdout is done, and stdout is marked done only after `out_reader(nil, nil)` → `finish_stdout`. So `qt.stop_reason` is always set before the terminal closure reads it.
- **`_is_output_cap` is pure** and tested directly, including nil and non-string input (`empty_response_reason_spec.lua:53-59`).
- **The new truncated fixture is synthetic**, with none of the operator's transcript in it.

### 2. Critical findings
None.

### 3. Important findings
- **BR-1, still open.**
  - The Gemini extraction at `dispatcher.lua:372` has no test. I removed it and dispatcher_query, dispatcher, empty_response_reason and golden all stayed green.
  - There is no end-to-end test for openai or googleai like J7e.
  - `dispatcher.lua:216` qualifies the advice with "On Claude". Reasoning tokens also count toward the cap on gpt-5, so the qualifier misleads.
  - *Fix:* pull the stop-reason extraction into a pure `D._extract_stop_reason(raw)` and test it per wire (ARCH-PURE). Reword the message so it doesn't depend on the wire.
- **New, 2nd finding in family `detected-loss-must-surface`.** The rule, not the instance: sort each response's final state, per wire, into one fixed set — `done | cap | filtered | paused | error | none` — with one pure function. The terminal closure then reports every state except `done`, and `_is_output_cap` becomes the `cap` row of that function.
  - Checked at HEAD, all three log nothing:
    - anthropic text followed by `refusal`;
    - openai text followed by `content_filter`;
    - anthropic text followed by an `event: error` / `overloaded_error` after HTTP 200 (here `stop_reason` is nil).
  - `pause_turn` appears nowhere in `lua/`.
  - The code's own comment at `dispatcher.lua:596` states this rule ("A truncated answer that looks finished is worse…") but applies it to the cap only.
  - Pin it with one table-driven test over wire × state.

### 4. Minor findings
- **BR-3, BR-4, BR-5, BR-6:** unchanged this round (details in the block below).
- **`_is_output_cap` accepts `maxtokens`**, a fourth spelling. The docstring table (`dispatcher.lua:173-175`) doesn't list it and no known wire sends it.
- **J7c–J7g repeat the same drive-and-capture block five times.** Restoring the logger isn't guarded by `pcall`, so a query that throws leaves `logger.warning` or `logger.error` stubbed for the rest of the file. One `drive_ok(...)` helper fixes both (ARCH-DRY, minor).

### 5. Test coverage notes
- Results at HEAD, run in a scratch clone:

  | Spec | Result |
  |---|---|
  | dispatcher_query | 64/64 |
  | dispatcher | 64/64 |
  | empty_response_reason | 8/8 |
  | provider_params | 35/35 |
  | golden | 11/11 |
  | sse_parsing, output_cap | green |
  | arch sweeps | green, except `destructive_recipe`, which fails in the scratch clone because it can't find the Makefile; unrelated to #228 |

  luacheck is clean.
- Revert results:
  - truncation branch removed → J7f red;
  - cap vocabulary narrowed to `max_tokens` → spelling test red;
  - `finishReason` line removed → everything green, so that line is unpinned.

### 6. Architectural notes
- **ARCH-DRY:** pass, apart from the minor test repetition.
- **ARCH-PURE:** pass for the predicate and the message builder. The stop-reason extraction is still an inline regex inside the stdout handler, which is why nothing tests it.
- **ARCH-PURPOSE:** flag, for the new finding and the BR-1 remainder.
- **ARCH-MOCK:** pass, with a note. The fixtures are hand-built, and nothing checks the error-event or refusal body shapes against the live API.
- **ARCH-CONSTRAINTS:** pass. BR-3 is still open; three regex scans of the body once per response cost nothing noticeable.
- **ARCH-SECURE:** pass. The stop reason from the untrusted body is bounded by `[^"]+` and only displayed; a missing one shows as "unknown" rather than a made-up value.
- **ARCH-ORDER:** pass. The ordering described under Strengths is the only possible one, so a single tested interleaving is enough.

### 7. Plan revision recommendations
- **Revisions entry for round 1:** the cap is now recognised in all three wire spellings, and a truncation warning was added. "Two fixes, both landed" should read three, and Done-when needs a row for "an answer cut off at the cap says so".
- **"One cause, both symptoms" is measured only for the empty case.** The truncation case was inferred. Say so, and either do the sweep above or link the issue that tracks it.
- **Reword the "cannot honour" rationale.** It is BR-4's false premise, and it appears in both the Revisions and the spec comment.
- **`## Log`:** record the round-1 verdict and how each finding was disposed.

```findings
dispose:
  - id: BR-1
    disposition: not-addressed
    note: |
      Vocabulary fixed and unit-pinned; but removing the finishReason extraction at dispatcher.lua:372 leaves all specs green, no openai/googleai J7e rows exist, and dispatcher.lua:216 still says "On Claude" to openai/googleai users.
  - id: BR-2
    disposition: addressed
    note: |
      J7f goes red when the dispatcher.lua:590 branch is reverted; also probed working for openai length and googleai MAX_TOKENS.
  - id: BR-3
    disposition: not-addressed
    note: |
      Untouched in 55b1d66; no test or lower-ceiling entry. skill_invoke's raise_output_cap already sends 100000 to every claude-* id, so that path had the exposure before this change.
  - id: BR-4
    disposition: not-addressed
    note: |
      provider_params_spec.lua:299 unchanged. Live in the committed default (live_models codex:gpt-5.6 at 4096), and dispatcher.lua:216's "On Claude" restates the same premise to users.
  - id: BR-5
    disposition: not-addressed
    note: |
      J7c (dispatcher_query_spec.lua:1086-1087) unchanged; it now names 2 of the 3 diagnostic wordings, so the new-branch drift it predicted has already happened.
  - id: BR-6
    disposition: not-addressed
    note: |
      atlas/infra/raw_logging.md:82 still shows max_tokens 4096; empty_response_reason_spec is still mapped under modes/raw_mode.
findings:
  - id: new
    severity: Important
    family: detected-loss-must-surface
    title: |
      Truncation is surfaced only for the cap; refusal/content_filter after partial text and an in-band SSE error after HTTP 200 still end silently
    detail: |
      2nd finding in this family; BR-2 fixed an instance. Rule: classify each response's terminal state per wire into one closed set (done, cap, filtered, paused, error, none) with one pure function, and surface every class except done; _is_output_cap becomes the cap row. Probed at HEAD via dispatcher.query: anthropic text+refusal, openai text+content_filter, and anthropic text+event:error overloaded_error (stop_reason nil) all log nothing; pause_turn has zero hits in lua/. Pin with one table-driven wire-by-class test. If deferred, the Revisions' "one cause, both symptoms" must say the truncation case was inferred, not measured, and link the tracking issue.
```

---

## Re-review — 2026-09-10T10:56:59-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 228 — streamed response lost under UI activity, then misreported as empty |
| repo | parley.nvim |
| issue file | workshop/issues/000228-streamed-response-lost-under-ui-activity-then-misreported-as-empty.md |
| boundary | whole-issue close |
| milestone | — |
| window | e4052dd860c879b4f817311a417a2e97afc42bc6..c65e623da8139a5bd3a209a7728b7d10828b9e29 |
| command | sdlc close --issue 228 |
| reviewer | claude |
| timestamp | 2026-09-10T10:56:59-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

Round 3 closes BR-1. Extracting the stop reason is now a pure `D._extract_stop_reason` with one test case per wire. The cap message no longer mentions a provider, and J7h and J7i drive openai `length` and googleai `MAX_TOKENS` through `dispatcher.query`. I checked each of these by reverting it in a scratch copy, and the test went red. Switching the stop-reason check to a list of normal endings (`_is_normal_finish`) is the right fix for BR-7. Refusal, `content_filter`, `pause_turn` and `model_context_window_exceeded` after partial text now warn.

Three things keep this from SHIP:
- **An in-band error is still silent.** BR-7 probed three cases, and the error event sent after HTTP 200 is still silent on the anthropic, openai and cliproxy wires. It carries no stop reason, and `_is_normal_finish(nil)` returns true. Yet the docstring and the terminal-closure comment say this case is handled.
- **The atlas has nothing on the new surface.** No atlas page covers the new end-of-response diagnosis or the Claude `max_tokens` default, which is set per model.
- **Four findings weren't touched.** BR-3 through BR-6 are unchanged, and `c65e623` didn't edit the issue file.

### 1. Strengths
- **BR-1 is fully pinned.** Each revert turned tests red:
  - Dropping the `finishReason` match fails `empty_response_reason_spec.lua` "googleai: finishReason" and J7i.
  - Putting back the "On Claude" wording fails two unit cases and J7h.
- **Listing the normal endings is the right default** (`dispatcher.lua:198-211`). An ending nobody listed now gets a warning instead of passing as normal. Reverting to `not _is_output_cap` fails J7j and the unit case "rejects every abnormal ending".
- **Only the cap gets cap advice** (`dispatcher.lua:643-645`). J7j checks that a refusal is not told to raise `max_tokens`.
- **The warning only fires on success.** It stays in the success branch, so #197's rule holds: a failed request never gets the empty or truncated message.
- **`drive()` in J7h returns `qt`.** The tests check the extracted `stop_reason`, not just the log text.

### 2. Critical findings
None.

### 3. Important findings
- **BR-7, still open. In-band errors after HTTP 200 are silent.** I ran these bodies through `dispatcher.query` with HTTP 200. Each logs nothing, with `stop_reason=nil`:
  - anthropic text, then `event: error` / `overloaded_error`;
  - anthropic text, then the stream ends with no `message_delta`;
  - openai text, then `data: {"error":…}`;
  - the same body on `cliproxyapi` with `gpt-5.6`.

  The cause is `dispatcher.lua:199-204`: a missing stop reason counts as a normal ending. Its stated reason, "every successful non-streaming shape reaches here", doesn't hold. All five payload builders set `stream = true` (`providers.lua:337,595,1086,1253`, `dispatcher.lua:103`), and every stream fixture carries a stop reason. `lua/` has no in-band error handling at all. The only mentions are the two comments claiming it exists (`:189`, `:639`).
  - *Fix sketch:* classify the whole body, not the stop-reason string. For example, `D._terminal_state(raw)` returns one of `done | cap | abnormal | error`, and `error` is detected from the wire's error event (`"type":"error"` on anthropic, a top-level `"error":{` on openai-shaped bodies). A missing stop reason can stay "done" only when no error event is present, which avoids warning on every response from a proxy that never sends one. The JSON shapes already exist in `tests/fixtures/anthropic_error.txt` and `openai_error.txt`; wrap them in SSE to make the test.
  - *If you defer it instead:* remove the "covered" claims at `:189` and `:639`, and link a tracking issue from the Revisions.
- **New, atlas-drift. This is the 2nd finding in family `atlas-drift`**, so the fix should cover the rule, not one page. The rule: every surface this issue adds goes into the atlas page that owns it, and every atlas example showing a changed value gets corrected, in one sweep. The only atlas edit in the window is `traceability.yaml`. What the sweep covers:
  - `atlas/providers/architecture.md`: the end-of-response diagnosis (stop-reason extraction per wire, the no-text cap message, the TRUNCATED warning).
  - `atlas/providers/anthropic.md`: `max_tokens` now defaults to 64000 for every `claude-*` model on every transport, and the cap counts thinking. This mirrors `openai.md:4`.
  - `atlas/infra/raw_logging.md:82` (BR-6).
  - The traceability mapping for `empty_response_reason_spec` (BR-6).

### 4. Minor findings
- **BR-3, BR-4, BR-5, BR-6:** unchanged since round 2 (details in the block below).
- **Rationale-matches-fact, 2nd in family.** The rule: re-check every claim this issue wrote about behavior against the code in the same round the code changes. Wrong at HEAD:
  - `dispatcher.lua:189` and `:639` say in-band errors are covered.
  - `:200-202` gives the "non-streaming" reason for treating a missing stop reason as normal.
  - `:244` calls a branch "finished normally", but that branch now also receives refusal and `SAFETY` with no text (probed).
  - The table at `:223-228` lists three spellings, but the code also accepts `maxtokens`. That value is dead: no wire sends it, and `MAX_TOKENS` lowercases to `max_tokens`.
  - `provider_params.lua:150` calls 64000 a "documented default". The API has no default; 64000 is SDK guidance.
  - "cannot honour" at `provider_params.lua:158` (BR-4).
  - Issue lines 182, 189 and 245.
- **Vacuous-negative-assertion, 2nd in family.** The rule: to assert something wasn't emitted, count calls at the emitter instead of matching the current wording.
  - J7g (`dispatcher_query_spec.lua:1184`) captures only warnings, so `assert.equals(0, #logged)` works there.
  - J7j (`:1231`) should reject any case-insensitive `max_tokens` mention.
  - J7c is BR-5.
- **The cap branch builds its format string from untrusted data** (`dispatcher.lua:262-266`). It concatenates `qt.stop_reason`, parsed from the body, into the format string before `:format(bytes)`. That is safe only because `_is_output_cap` uses exact equality. If that check is widened, a `%` in the value makes `string.format` raise inside the terminal closure, which skips `legacy_complete`. Pass it as a `%s` argument (ARCH-SECURE).
- **`stop_sequence` would warn as TRUNCATED.** No real request can produce it today, because `lua/` sets no stop sequences. Add it to the normal list if they are ever introduced.

### 5. Test coverage notes
I ran the specs at HEAD in a scratch `git archive c65e623`. I had to copy in the gitignored `construct/generated/vocabulary`; without it, B1 fails for environment reasons unrelated to #228.

| Spec | Result |
|---|---|
| `dispatcher_query` | 67/67 |
| `empty_response_reason` | 16/16 |
| `provider_params` | 35/35 |
| `parley_harness_golden` | 11/11 |
| `provider_params_output_cap` | 11/11 |
| `sse_parsing` | 47/47 |
| `dispatcher` | 64/64 |

- **Reverts:** all three turned tests red (listed under Strengths).
- **Probes, all through `dispatcher.query` with HTTP 200:**
  - These produce the TRUNCATED warning: text followed by `pause_turn`, `model_context_window_exceeded` or `stop_sequence` (anthropic), or `content_filter` (openai).
  - No text with `refusal` or `SAFETY` gives "returned no assistant text (… stop_reason=…)".
  - The in-band error cases stay silent (listed under BR-7).
- **No test covers an in-band error event or a stream that ends early.**

### 6. Architectural notes
- **ARCH-DRY:** pass. One extractor feeds both consumers. J7e, J7f and J7g could reuse the new `drive()` helper.
- **ARCH-PURE:** pass. Extraction is now pure and tested per wire.
- **ARCH-PURPOSE:** flag (BR-7). The classifier takes a stop-reason string, and an in-band error has no stop reason. So the `error` and `none` states that BR-7 named can't be expressed. The input needs to be the body.
- **ARCH-MOCK:** pass, with a note. The refusal, `content_filter` and error-event bodies are hand-built, and nothing checks them against a live response.
- **ARCH-CONSTRAINTS:** pass, with BR-3 still open. Three regex scans per response cost nothing noticeable.
- **ARCH-SECURE:** minor flag, the format-string item above.
- **ARCH-ORDER:** pass on ordering, since `stop_reason` is always written in `finish_stdout` before the terminal closure reads it. There is a representation note: the ending is two yes/no checks on one string, and the `error` ending can't be represented at all. The tagged state proposed under BR-7 would fix both.

### 7. Plan revision recommendations
- **Add a Revisions entry for rounds 1–3:** stop reasons in all three wire spellings, the TRUNCATED warning, and the switch to a list of normal endings.
  - Replace "Two fixes, both landed" with the four changes.
  - Mark the truncation half of "one cause, both symptoms" as inferred: no truncated raw body was captured.
- **Done-when:**
  - Add a row: "an answer that ends abnormally after some text says so".
  - Change the "three cases" row to match the code.
  - Add a row for the in-band error, or link the issue that takes it over.
- **Log:** record the verdicts from rounds 1–3 and how each finding was disposed.
- **BR-4:** if gpt-5 stays at 4096 on purpose, record the real reason.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Pinned by revert: dropping the finishReason match reddens "googleai: finishReason" and J7i; restoring "On Claude" reddens 2 unit cases and J7h.
  - id: BR-3
    disposition: not-addressed
    note: |
      provider_params.lua:159-166 unchanged; no lower-ceiling entry and no test pinning the >=64K assumption.
  - id: BR-4
    disposition: not-addressed
    note: |
      "cannot honour" still at provider_params.lua:158, provider_params_spec.lua:299 and issue Revisions line 196.
  - id: BR-5
    disposition: not-addressed
    note: |
      J7c (dispatcher_query_spec.lua:1086-1087) unchanged; J7g and J7j now repeat the shape, see the new vacuous-negative-assertion finding.
  - id: BR-6
    disposition: not-addressed
    note: |
      atlas/infra/raw_logging.md:82 still shows 4096; empty_response_reason_spec still mapped under modes/raw_mode (traceability.yaml:307-314).
  - id: BR-7
    disposition: not-addressed
    note: |
      The allowlist is delivered and pinned (revert reddens J7j and the reject-list unit case). But the in-band error BR-7 probed is still silent: anthropic event:error, openai and cliproxy data:{"error":...} after text + HTTP 200 all give stop_reason nil, and _is_normal_finish(nil) returns true (dispatcher.lua:199-204), while :189 and :639 claim that case is covered.
findings:
  - id: new
    severity: Important
    family: atlas-drift
    title: |
      atlas update appears missing for the end-of-response diagnosis and the model-keyed Claude max_tokens default
    detail: |
      2nd in family. Rule: every surface this issue adds lands in its owning atlas page, and every example showing a value the window changed is corrected, in one sweep. Sweep: providers/architecture.md (stop-reason extraction per wire, no-text cap diagnosis, TRUNCATED warning); providers/anthropic.md (64000 default for every claude-* id on every transport, counts thinking); infra/raw_logging.md:82 and the traceability mapping (both BR-6). The only atlas edit in the window is traceability.yaml.
  - id: new
    severity: Minor
    family: rationale-matches-fact
    title: |
      Prose claims written this window disagree with the code: in-band error "covered", nil stop_reason "non-streaming", "finished normally", three spellings
    detail: |
      2nd in family (BR-4 is the 1st). Rule: re-check every behavioral claim this issue wrote against code or fixtures in the same round the code changes. Sweep at HEAD: dispatcher.lua:189 and :639 (in-band error said to be surfaced; probed silent); :200-202 (all builders set stream = true and every stream fixture carries a stop reason); :244 ("finished normally" branch also gets refusal/SAFETY with no text); :223-228 (docstring lists 3 spellings, code accepts a dead 4th, maxtokens); provider_params.lua:150 ("documented default"); :158 and spec:299 (BR-4); issue lines 182, 189, 245.
  - id: new
    severity: Minor
    family: vacuous-negative-assertion
    title: |
      J7g and J7j repeat J7c's shape: they assert an emission is absent by matching the current wording
    detail: |
      2nd in family (BR-5 is the 1st). Rule: assert that something was not emitted by counting calls at the emitter, not by matching the current wording. J7g (dispatcher_query_spec.lua:1184) captures only warnings, so assert.equals(0, #logged) works; J7j (:1231) should reject any case-insensitive max_tokens mention; J7c should wrap _empty_response_reason and assert zero calls. Rewording TRUNCATED makes J7f go red, and after J7f is fixed J7g passes vacuously.
  - id: new
    severity: Minor
    family: untrusted-value-in-format-string
    title: |
      The cap branch of _empty_response_reason puts the body-parsed stop_reason into the format string itself
    detail: |
      dispatcher.lua:262-266 concatenates qt.stop_reason before :format(bytes); this is safe only because _is_output_cap uses exact equality. If that check is widened, a % in the value raises inside the terminal closure and skips legacy_complete. Pass it as a %s argument, as the fallthrough branch does (ARCH-SECURE).
```

---

## Re-review — 2026-09-10T11:14:06-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 228 — streamed response lost under UI activity, then misreported as empty |
| repo | parley.nvim |
| issue file | workshop/issues/000228-streamed-response-lost-under-ui-activity-then-misreported-as-empty.md |
| boundary | whole-issue close |
| milestone | — |
| window | e4052dd860c879b4f817311a417a2e97afc42bc6..0a569772497387f7b0c22302854b209c8d4e1298 |
| command | sdlc close --issue 228 |
| reviewer | claude |
| timestamp | 2026-09-10T11:14:06-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The main fixes for #228 are real and pinned by tests. `_is_normal_finish` is now a whitelist, and a new predicate (`_inband_error`) catches a provider error sent inside a 200 response. I reverted each fix in a scratch copy: J7j goes red without the whitelist, and J7k goes red without the in-band-error branch. Probes confirm that an OpenAI `content_filter` and an Anthropic `pause_turn` after some text are now reported. The cause itself (the 4096 token cap) is correctly diagnosed and fixed on the model, not the provider.

One Important gap remains: BR-7's rule was answered by fixing the three cases it probed, not by adopting the rule. The terminal state is still worked out two ways. The empty-response path checks only `_is_output_cap`. So an Anthropic `event: error` that arrives before any text is reported as "returned no assistant text (body_bytes=290, stop_reason=unknown)", and the provider's "Overloaded" is dropped. That is the same kind of misleading message this issue exists to remove. A response with no stop reason is also still treated as a normal finish, on a premise that neither the code nor the fixtures support. The remaining items are Minor: prior findings still open, plus claims written this round that the code contradicts.

**1. Strengths**
- The pure predicates are extracted and tested without IO (`empty_response_reason_spec.lua:53-122`). The whitelist test includes a stop reason nobody has enumerated yet, which checks the whitelist's actual purpose (`:88-96`).
- The whitelist inversion at `dispatcher.lua:197-207` is sound. Probes P2 (openai `content_filter`) and P5 (anthropic `pause_turn`) now log TRUNCATED, and a normal `stop` stays silent (P6).
- The model-keyed 64000 cap (`provider_params.lua:159-166`) is the right seam. The golden payloads were updated in the same change, and `raise_output_cap` still behaves (the output-cap spec passes 11/11).
- Good privacy call (ARCH-SECURE): the thinking-only fixture is synthesized rather than committing the operator's 55 KB transcript.
- Plan rows are dispositioned rather than blank-ticked, and the split-out work has a real home (#229 exists).

**2. Critical findings**
None.

**3. Important findings**
- **BR-7, still open** (`dispatcher.lua:662-683`, `:262-279`; ARCH-PURPOSE, ARCH-ORDER).
  - **What remains:** J7j and J7k fix the three probed cases. The rule BR-7 stated was one closed classification (done, cap, filtered, paused, error, none) surfaced for every class except done. What shipped is three separate signals read in a fixed if/elseif order: `qt.empty_response`, `_inband_error(raw)` and the stop-reason class.
  - **Consequence 1:** the empty-and-error combination can never be reported as an error (probe P1).
  - **Consequence 2:** no stop reason still counts as normal. The code's own policy argues against this: "an ending nobody has seen before surfaces… a spurious warning is cheap". Every recorded stream fixture (anthropic, openai, googleai, both tool streams) carries exactly one terminal reason. I flipped nil to abnormal and all 68 `dispatcher_query_spec` tests stayed green, so no test measures the "noise" the exemption claims to avoid.
  - **Fix sketch:** compute `D._classify_ending(qt) -> {class, detail}` once in `finish_stdout`, next to the existing `stop_reason` line. Render both messages from `(class, has_text)`. Pin it with one table-driven test over wire × class × has_text. This also removes the duplicated "Raise max_tokens" text (`:278` and `:678`) and the double `_inband_error` scan (`:664` and `:669`).

**4. Minor findings**
- **Prior findings still open:**
  - BR-3: no per-model output ceiling.
  - BR-4: the "cannot honour" rationale, now also repeated in the atlas.
  - BR-5: J7c lists message wordings by hand.
  - BR-6: `raw_logging.md:82` still shows 4096, and the spec mapping is unchanged.
  - BR-9: false prose claims.
  - BR-10: J7g and J7j match wording.
  - BR-11: the stop reason is concatenated into the format string.
- **New, `rationale-matches-fact` (3rd in family):** the atlas section and the `_inband_error` docstring, written after BR-9, add claims the code contradicts:
  - the atlas says each predicate has "its own test", but `_inband_error` has none;
  - it lists the whitelist as four spellings where the code has six;
  - it repeats the premise that successful non-streaming responses carry no stop reason;
  - the comment at `dispatcher.lua:671-676` says that branch covers in-band errors, but the branch above catches them first.
- **New, `stop-reason-vocabulary-per-wire` (2nd in family):** each wire's terminal vocabulary is pinned only by hand-written bodies.
  - J7i's googleai body is an SSE `data:` frame, but the googleai wire is a JSON array.
  - `_inband_error` has no per-wire test, no test that a normal answer quoting error JSON is not flagged, and it cuts the message at an escaped quote (probe P10 logged `Internal \`).
- **New, `test-order-independence`:** J7e–J7k only pass because Groups C, D and G leave the anthropic and googleai endpoints set. Without them, `dispatcher.query` raises `dispatcher.lua:524: attempt to index a nil value` (probe).

**5. Test coverage notes**
- **Specs run:** I ran them in a clean `git archive` export of 0a56977, with the untracked `construct/generated/vocabulary` copied in.
  - The three changed specs pass: 16/16, 68/68 and 35/35.
  - Neighbouring specs pass: golden 11, dispatcher_spec 64, output_cap 11, skill_invoke 16, raw_log 9, log_emit 18, sse_parsing 47.
- **Revert checks:** J7j goes red without the whitelist, and J7k goes red without the in-band-error branch. Flipping nil to abnormal leaves everything green except the unit test that asserts the premise directly.
- **Probes:**

| Probe | Case | What gets logged |
|---|---|---|
| P1 | anthropic `event: error` before any text | "returned no assistant text (body_bytes=290, stop_reason=unknown)" — "Overloaded" is lost |
| P2 | openai text, then `content_filter` | TRUNCATED ✓ |
| P3 | openai text, then an error frame | TRUNCATED, with the provider's message ✓ |
| P5 | anthropic text, then `pause_turn` | TRUNCATED ✓ |
| P6 | openai normal `stop` | nothing ✓ |
| P9 | refusal, no text | lands in the "finished normally" bucket |
| P10 | error message with an escaped quote | message cut to `Internal \` |
| P11 | answer that quotes error JSON in its text | not flagged — correct, but no test pins it |

**6. Architectural notes**
- **ARCH-DRY — flag:** two renderers for one classification, and the atlas restates the whitelist values, which had already drifted in the commit that wrote it.
- **ARCH-PURE — pass:** the predicates are pure, and the terminal closure is thin glue.
- **ARCH-PURPOSE — flag:** see BR-7.
- **ARCH-MOCK — flag (Minor):** the fixture recorder (`scripts/record_fixtures.lua`) captures no capped or mid-stream-error turn. A `max_tokens: 5` request per wire would pin the cap spellings against the live APIs.
- **ARCH-CONSTRAINTS — note:** the worst-case output per Claude turn rises 16× (4096 → 64000 tokens, about $1.60 per turn on opus-5 at list price), and no envelope is written down. There is also no per-model ceiling (BR-3). The Models API returns `max_tokens` per model, which could be the single source for the ceiling.
- **ARCH-SECURE — pass, with BR-11 open:** values parsed from the body degrade visibly rather than crashing, and the logger passes messages as a `%s` argument.
- **ARCH-ORDER — flag:** the terminal-state signals should collapse into one tagged value (see BR-7).
- The per-wire vocabulary would naturally live on each provider adapter, next to `parse_usage`, rather than as cross-wire patterns in `dispatcher.lua`.

**7. Plan revision recommendations**
- In the Revisions entry "One cause, both symptoms": state that attributing truncation-after-text to the cap was inferred, not observed in the raw log.
- Rename or split the third bucket in Done-when row 2 ("finished normally with no text"). Refusals, SAFETY and in-band errors land there too.
- Record the classification decision. If "no stop reason" stays silent, record the evidence: a successful stream fixture with no terminal reason.
- Record the 64000 cost envelope and the per-model ceiling decision.

```findings
dispose:
  - id: BR-3
    disposition: not-addressed
    note: |
      Unchanged: ^claude%- sets 64000 for every claude-* id on every provider incl. copilot, no ceiling table or pinning test; deprecated-but-served claude-opus-4-20250514 is in the catalog fixture; clamp to the model's declared cap (Models API max_tokens) or a per-model table.
  - id: BR-4
    disposition: not-addressed
    note: |
      provider_params.lua:155-158 and provider_params_spec "cannot honour" unchanged, and atlas/providers/architecture.md now repeats it.
  - id: BR-5
    disposition: not-addressed
    note: |
      J7c still hand-lists two of the three renderings (it omits the cap wording); wrap _empty_response_reason and assert zero calls.
  - id: BR-6
    disposition: not-addressed
    note: |
      atlas/infra/raw_logging.md:82 still shows max_tokens 4096 for claude-sonnet-4-6; empty_response_reason_spec is still mapped only under modes/raw_mode, not providers/architecture.
  - id: BR-7
    disposition: not-addressed
    note: |
      J7j/J7k pin the three probed instances (both red on revert) but the rule was not adopted: the empty path consults only _is_output_cap, so an anthropic event:error before any text logs "returned no assistant text (body_bytes=290, stop_reason=unknown)" and drops "Overloaded"; the none class is still treated as done though every recorded stream fixture carries a terminal reason.
  - id: BR-8
    disposition: addressed
    note: |
      atlas/providers/architecture.md now maps the stop-reason predicates and the model-keyed 64000 default; the example/mapping residue is BR-6.
  - id: BR-9
    disposition: not-addressed
    note: |
      Non-streaming premise, the "finished normally" bucket (refusal lands there), dead maxtokens spelling, BR-4 and issue lines 182/245 unchanged; drop the "documented default" item (Anthropic does recommend ~64000 for streaming; say "documented recommendation").
  - id: BR-10
    disposition: not-addressed
    note: |
      J7g and J7j still assert absence by matching TRUNCATED / Raise max_tokens.
  - id: BR-11
    disposition: not-addressed
    note: |
      The cap branch still concatenates tostring(qt.stop_reason) into the format string before :format(bytes).
findings:
  - id: new
    severity: Minor
    family: rationale-matches-fact
    title: |
      The #228 atlas section and the _inband_error docstring, written after BR-9, add new claims the code contradicts
    detail: |
      This is the 3rd finding in family rationale-matches-fact. Do NOT fix these instances. Rule: prose names a predicate and its purpose and links its test; it does not restate value lists or premises the code owns (ARCH-DRY for prose). Every remaining factual claim cites the test or fixture that checks it, in the commit that writes it. New at head: atlas/providers/architecture.md says the four predicates each have their own test, but _inband_error has none. It lists the whitelist as four spellings where the code has six. It repeats that every successful non-streaming shape has no stop reason, but all builders stream and every recorded stream fixture carries one. dispatcher.lua:671-676 says that branch covers in-band errors, but the branch above catches them first. Measured prevalence: about 11 such claims at head across dispatcher.lua, provider_params.lua, provider_params_spec.lua, the atlas and the issue; 4 were written in 0a56977, after BR-9 stated the rule.
  - id: new
    severity: Minor
    family: stop-reason-vocabulary-per-wire
    title: |
      Each wire's terminal vocabulary is pinned only by hand-written bodies, and _inband_error has no per-wire test
    detail: |
      This is the 2nd finding in family stop-reason-vocabulary-per-wire. Rule: every wire's terminal vocabulary (stop key, cap spelling, in-band error frame, and a non-error body that quotes one) is pinned by one table-driven per-wire test fed by recordings from make fixtures. A max_tokens:5 request per wire in scripts/record_fixtures.lua would capture the cap spellings live (ARCH-MOCK). At head, J7h and J7i use synthetic bodies. J7i's googleai body is an SSE data: frame, but the googleai wire is a pretty-printed JSON array. _inband_error's two frame shapes are covered only end to end by J7k. Nothing pins that an answer quoting error JSON is not flagged (probed: it is not, today). An escaped quote cuts the provider message short (probe logged: Internal \).
  - id: new
    severity: Minor
    family: test-order-independence
    title: |
      J7e-J7k pass only because earlier groups leaked the anthropic and googleai endpoints
    detail: |
      dispatcher.providers anthropic and googleai are nil at require time. Only Groups C, D and G set them (dispatcher_query_spec.lua:247, :328, :455), and nothing cleans up. With the endpoint unset, dispatcher.query raises dispatcher.lua:524 attempt to index a nil value (probed). So the new J7 tests fail if Group J runs alone or the earlier groups move. Register both endpoints in the top-level before_each next to openai.
```
