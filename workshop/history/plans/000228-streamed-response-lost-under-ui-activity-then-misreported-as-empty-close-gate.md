---
gate: boundary-review
issue: 228
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-10T10:25:48-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Important
          title: The cap diagnosis only recognizes Anthropic's max_tokens; OpenAI length and Gemini MAX_TOKENS get labelled "finished normally"
          detail: 'Probe: gpt-5.6 finish_reason=length with no text logs "openai returned no assistant text (body_bytes=435, stop_reason=length)", which is the docstring''s "finished normally, worth a bug report" branch. Gemini''s camelCase finishReason is never extracted, so stop_reason is always nil. Map each wire''s stop words to one set of meanings (cap/refusal/paused/done/unknown), extract finishReason, key the message on that, and use wire-neutral wording. Add J7e-style tests for openai and googleai.'
          family: stop-reason-vocabulary-per-wire
          round: 1
        - id: BR-2
          severity: Important
          title: An answer cut off at the output cap after some text streamed is still silent, though stop_reason is already known
          detail: The Revisions name this as the truncated-mid-answer symptom. The terminal closure only reports when qt.response is empty. Warn when the stop reason means the cap and text is non-empty; this reuses the mapping from the other finding, and a text-then-max_tokens fixture can pin it.
          family: detected-loss-must-surface
          round: 1
        - id: BR-3
          severity: Minor
          title: The ^claude%- 64000 default has no per-model ceiling check for claude-* ids served with lower output limits
          detail: First-party models served today all allow at least 64K. Vertex/Bedrock-served claude-3-5-haiku (8K), copilot claude limits, and the catalog fixture's claude-opus-4-20250514 (32K) would get HTTP 400 where 4096 worked. Pin the assumption in a test or add lower-ceiling entries.
          family: model-ceiling-envelope
          round: 1
        - id: BR-4
          severity: Minor
          title: The test comment says non-Claude models "cannot honour" a higher cap, which is false for gpt-5.x (128K output)
          detail: The 4096 pin for cliproxyapi gpt-5.6 locks in the same reasoning-eats-the-cap exposure for gpt-5. Record the real reason, or treat gpt-5 as a sibling instance.
          family: rationale-matches-fact
          round: 1
        - id: BR-5
          severity: Minor
          title: J7c lists message wordings by hand, so a rewording or new branch makes it vacuous again
          detail: Wrap dispatcher._empty_response_reason in the test and assert it is never called on a failed request.
          family: vacuous-negative-assertion
          round: 1
        - id: BR-6
          severity: Minor
          title: The atlas raw_logging.md example still shows max_tokens 4096 for claude-sonnet-4-6; the new spec is mapped under modes/raw_mode
          family: atlas-drift
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-09-10T10:41:19-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: not-addressed
          note: Vocabulary fixed and unit-pinned; but removing the finishReason extraction at dispatcher.lua:372 leaves all specs green, no openai/googleai J7e rows exist, and dispatcher.lua:216 still says "On Claude" to openai/googleai users.
          round: 2
        - id: BR-2
          disposition: addressed
          note: J7f goes red when the dispatcher.lua:590 branch is reverted; also probed working for openai length and googleai MAX_TOKENS.
          round: 2
        - id: BR-3
          disposition: not-addressed
          note: Untouched in 55b1d66; no test or lower-ceiling entry. skill_invoke's raise_output_cap already sends 100000 to every claude-* id, so that path had the exposure before this change.
          round: 2
        - id: BR-4
          disposition: not-addressed
          note: provider_params_spec.lua:299 unchanged. Live in the committed default (live_models codex:gpt-5.6 at 4096), and dispatcher.lua:216's "On Claude" restates the same premise to users.
          round: 2
        - id: BR-5
          disposition: not-addressed
          note: J7c (dispatcher_query_spec.lua:1086-1087) unchanged; it now names 2 of the 3 diagnostic wordings, so the new-branch drift it predicted has already happened.
          round: 2
        - id: BR-6
          disposition: not-addressed
          note: atlas/infra/raw_logging.md:82 still shows max_tokens 4096; empty_response_reason_spec is still mapped under modes/raw_mode.
          round: 2
      findings:
        - id: BR-7
          severity: Important
          title: Truncation is surfaced only for the cap; refusal/content_filter after partial text and an in-band SSE error after HTTP 200 still end silently
          detail: '2nd finding in this family; BR-2 fixed an instance. Rule: classify each response''s terminal state per wire into one closed set (done, cap, filtered, paused, error, none) with one pure function, and surface every class except done; _is_output_cap becomes the cap row. Probed at HEAD via dispatcher.query: anthropic text+refusal, openai text+content_filter, and anthropic text+event:error overloaded_error (stop_reason nil) all log nothing; pause_turn has zero hits in lua/. Pin with one table-driven wire-by-class test. If deferred, the Revisions'' "one cause, both symptoms" must say the truncation case was inferred, not measured, and link the tracking issue.'
          family: detected-loss-must-surface
          round: 2
      blocked: true
    - "n": 3
      timestamp: "2026-09-10T10:56:59-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: 'Pinned by revert: dropping the finishReason match reddens "googleai: finishReason" and J7i; restoring "On Claude" reddens 2 unit cases and J7h.'
          round: 3
        - id: BR-3
          disposition: not-addressed
          note: provider_params.lua:159-166 unchanged; no lower-ceiling entry and no test pinning the >=64K assumption.
          round: 3
        - id: BR-4
          disposition: not-addressed
          note: '"cannot honour" still at provider_params.lua:158, provider_params_spec.lua:299 and issue Revisions line 196.'
          round: 3
        - id: BR-5
          disposition: not-addressed
          note: J7c (dispatcher_query_spec.lua:1086-1087) unchanged; J7g and J7j now repeat the shape, see the new vacuous-negative-assertion finding.
          round: 3
        - id: BR-6
          disposition: not-addressed
          note: atlas/infra/raw_logging.md:82 still shows 4096; empty_response_reason_spec still mapped under modes/raw_mode (traceability.yaml:307-314).
          round: 3
        - id: BR-7
          disposition: not-addressed
          note: 'The allowlist is delivered and pinned (revert reddens J7j and the reject-list unit case). But the in-band error BR-7 probed is still silent: anthropic event:error, openai and cliproxy data:{"error":...} after text + HTTP 200 all give stop_reason nil, and _is_normal_finish(nil) returns true (dispatcher.lua:199-204), while :189 and :639 claim that case is covered.'
          round: 3
      findings:
        - id: BR-8
          severity: Important
          title: atlas update appears missing for the end-of-response diagnosis and the model-keyed Claude max_tokens default
          detail: '2nd in family. Rule: every surface this issue adds lands in its owning atlas page, and every example showing a value the window changed is corrected, in one sweep. Sweep: providers/architecture.md (stop-reason extraction per wire, no-text cap diagnosis, TRUNCATED warning); providers/anthropic.md (64000 default for every claude-* id on every transport, counts thinking); infra/raw_logging.md:82 and the traceability mapping (both BR-6). The only atlas edit in the window is traceability.yaml.'
          family: atlas-drift
          round: 3
        - id: BR-9
          severity: Minor
          title: 'Prose claims written this window disagree with the code: in-band error "covered", nil stop_reason "non-streaming", "finished normally", three spellings'
          detail: '2nd in family (BR-4 is the 1st). Rule: re-check every behavioral claim this issue wrote against code or fixtures in the same round the code changes. Sweep at HEAD: dispatcher.lua:189 and :639 (in-band error said to be surfaced; probed silent); :200-202 (all builders set stream = true and every stream fixture carries a stop reason); :244 ("finished normally" branch also gets refusal/SAFETY with no text); :223-228 (docstring lists 3 spellings, code accepts a dead 4th, maxtokens); provider_params.lua:150 ("documented default"); :158 and spec:299 (BR-4); issue lines 182, 189, 245.'
          family: rationale-matches-fact
          round: 3
        - id: BR-10
          severity: Minor
          title: 'J7g and J7j repeat J7c''s shape: they assert an emission is absent by matching the current wording'
          detail: '2nd in family (BR-5 is the 1st). Rule: assert that something was not emitted by counting calls at the emitter, not by matching the current wording. J7g (dispatcher_query_spec.lua:1184) captures only warnings, so assert.equals(0, #logged) works; J7j (:1231) should reject any case-insensitive max_tokens mention; J7c should wrap _empty_response_reason and assert zero calls. Rewording TRUNCATED makes J7f go red, and after J7f is fixed J7g passes vacuously.'
          family: vacuous-negative-assertion
          round: 3
        - id: BR-11
          severity: Minor
          title: The cap branch of _empty_response_reason puts the body-parsed stop_reason into the format string itself
          detail: dispatcher.lua:262-266 concatenates qt.stop_reason before :format(bytes); this is safe only because _is_output_cap uses exact equality. If that check is widened, a % in the value raises inside the terminal closure and skips legacy_complete. Pass it as a %s argument, as the fallthrough branch does (ARCH-SECURE).
          family: untrusted-value-in-format-string
          round: 3
      blocked: true
    - "n": 4
      timestamp: "2026-09-10T11:14:06-07:00"
      agent: claude
      dispose:
        - id: BR-3
          disposition: not-addressed
          note: 'Unchanged: ^claude%- sets 64000 for every claude-* id on every provider incl. copilot, no ceiling table or pinning test; deprecated-but-served claude-opus-4-20250514 is in the catalog fixture; clamp to the model''s declared cap (Models API max_tokens) or a per-model table.'
          round: 4
        - id: BR-4
          disposition: not-addressed
          note: provider_params.lua:155-158 and provider_params_spec "cannot honour" unchanged, and atlas/providers/architecture.md now repeats it.
          round: 4
        - id: BR-5
          disposition: not-addressed
          note: J7c still hand-lists two of the three renderings (it omits the cap wording); wrap _empty_response_reason and assert zero calls.
          round: 4
        - id: BR-6
          disposition: not-addressed
          note: atlas/infra/raw_logging.md:82 still shows max_tokens 4096 for claude-sonnet-4-6; empty_response_reason_spec is still mapped only under modes/raw_mode, not providers/architecture.
          round: 4
        - id: BR-7
          disposition: not-addressed
          note: 'J7j/J7k pin the three probed instances (both red on revert) but the rule was not adopted: the empty path consults only _is_output_cap, so an anthropic event:error before any text logs "returned no assistant text (body_bytes=290, stop_reason=unknown)" and drops "Overloaded"; the none class is still treated as done though every recorded stream fixture carries a terminal reason.'
          round: 4
        - id: BR-8
          disposition: addressed
          note: atlas/providers/architecture.md now maps the stop-reason predicates and the model-keyed 64000 default; the example/mapping residue is BR-6.
          round: 4
        - id: BR-9
          disposition: not-addressed
          note: Non-streaming premise, the "finished normally" bucket (refusal lands there), dead maxtokens spelling, BR-4 and issue lines 182/245 unchanged; drop the "documented default" item (Anthropic does recommend ~64000 for streaming; say "documented recommendation").
          round: 4
        - id: BR-10
          disposition: not-addressed
          note: J7g and J7j still assert absence by matching TRUNCATED / Raise max_tokens.
          round: 4
        - id: BR-11
          disposition: not-addressed
          note: The cap branch still concatenates tostring(qt.stop_reason) into the format string before :format(bytes).
          round: 4
      findings:
        - id: BR-12
          severity: Minor
          title: 'The #228 atlas section and the _inband_error docstring, written after BR-9, add new claims the code contradicts'
          detail: 'This is the 3rd finding in family rationale-matches-fact. Do NOT fix these instances. Rule: prose names a predicate and its purpose and links its test; it does not restate value lists or premises the code owns (ARCH-DRY for prose). Every remaining factual claim cites the test or fixture that checks it, in the commit that writes it. New at head: atlas/providers/architecture.md says the four predicates each have their own test, but _inband_error has none. It lists the whitelist as four spellings where the code has six. It repeats that every successful non-streaming shape has no stop reason, but all builders stream and every recorded stream fixture carries one. dispatcher.lua:671-676 says that branch covers in-band errors, but the branch above catches them first. Measured prevalence: about 11 such claims at head across dispatcher.lua, provider_params.lua, provider_params_spec.lua, the atlas and the issue; 4 were written in 0a56977, after BR-9 stated the rule.'
          family: rationale-matches-fact
          round: 4
        - id: BR-13
          severity: Minor
          title: Each wire's terminal vocabulary is pinned only by hand-written bodies, and _inband_error has no per-wire test
          detail: 'This is the 2nd finding in family stop-reason-vocabulary-per-wire. Rule: every wire''s terminal vocabulary (stop key, cap spelling, in-band error frame, and a non-error body that quotes one) is pinned by one table-driven per-wire test fed by recordings from make fixtures. A max_tokens:5 request per wire in scripts/record_fixtures.lua would capture the cap spellings live (ARCH-MOCK). At head, J7h and J7i use synthetic bodies. J7i''s googleai body is an SSE data: frame, but the googleai wire is a pretty-printed JSON array. _inband_error''s two frame shapes are covered only end to end by J7k. Nothing pins that an answer quoting error JSON is not flagged (probed: it is not, today). An escaped quote cuts the provider message short (probe logged: Internal \).'
          family: stop-reason-vocabulary-per-wire
          round: 4
        - id: BR-14
          severity: Minor
          title: J7e-J7k pass only because earlier groups leaked the anthropic and googleai endpoints
          detail: dispatcher.providers anthropic and googleai are nil at require time. Only Groups C, D and G set them (dispatcher_query_spec.lua:247, :328, :455), and nothing cleans up. With the endpoint unset, dispatcher.query raises dispatcher.lua:524 attempt to index a nil value (probed). So the new J7 tests fail if Group J runs alone or the earlier groups move. Register both endpoints in the top-level before_each next to openai.
          family: test-order-independence
          round: 4
      blocked: false
---

# Gate ledger — parley.nvim#228 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-10T10:25:48-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `stop-reason-vocabulary-per-wire` The cap diagnosis only recognizes Anthropic's max_tokens; OpenAI length and Gemini MAX_TOKENS get labelled "finished normally"
  Probe: gpt-5.6 finish_reason=length with no text logs "openai returned no assistant text (body_bytes=435, stop_reason=length)", which is the docstring's "finished normally, worth a bug report" branch. Gemini's camelCase finishReason is never extracted, so stop_reason is always nil. Map each wire's stop words to one set of meanings (cap/refusal/paused/done/unknown), extract finishReason, key the message on that, and use wire-neutral wording. Add J7e-style tests for openai and googleai.
- **BR-2** [Important] `detected-loss-must-surface` An answer cut off at the output cap after some text streamed is still silent, though stop_reason is already known
  The Revisions name this as the truncated-mid-answer symptom. The terminal closure only reports when qt.response is empty. Warn when the stop reason means the cap and text is non-empty; this reuses the mapping from the other finding, and a text-then-max_tokens fixture can pin it.
- **BR-3** [Minor] `model-ceiling-envelope` The ^claude%- 64000 default has no per-model ceiling check for claude-* ids served with lower output limits
  First-party models served today all allow at least 64K. Vertex/Bedrock-served claude-3-5-haiku (8K), copilot claude limits, and the catalog fixture's claude-opus-4-20250514 (32K) would get HTTP 400 where 4096 worked. Pin the assumption in a test or add lower-ceiling entries.
- **BR-4** [Minor] `rationale-matches-fact` The test comment says non-Claude models "cannot honour" a higher cap, which is false for gpt-5.x (128K output)
  The 4096 pin for cliproxyapi gpt-5.6 locks in the same reasoning-eats-the-cap exposure for gpt-5. Record the real reason, or treat gpt-5 as a sibling instance.
- **BR-5** [Minor] `vacuous-negative-assertion` J7c lists message wordings by hand, so a rewording or new branch makes it vacuous again
  Wrap dispatcher._empty_response_reason in the test and assert it is never called on a failed request.
- **BR-6** [Minor] `atlas-drift` The atlas raw_logging.md example still shows max_tokens 4096 for claude-sonnet-4-6; the new spec is mapped under modes/raw_mode

## Round 2 — 2026-09-10T10:41:19-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — not-addressed — Vocabulary fixed and unit-pinned; but removing the finishReason extraction at dispatcher.lua:372 leaves all specs green, no openai/googleai J7e rows exist, and dispatcher.lua:216 still says "On Claude" to openai/googleai users.
- BR-2 — addressed — J7f goes red when the dispatcher.lua:590 branch is reverted; also probed working for openai length and googleai MAX_TOKENS.
- BR-3 — not-addressed — Untouched in 55b1d66; no test or lower-ceiling entry. skill_invoke's raise_output_cap already sends 100000 to every claude-* id, so that path had the exposure before this change.
- BR-4 — not-addressed — provider_params_spec.lua:299 unchanged. Live in the committed default (live_models codex:gpt-5.6 at 4096), and dispatcher.lua:216's "On Claude" restates the same premise to users.
- BR-5 — not-addressed — J7c (dispatcher_query_spec.lua:1086-1087) unchanged; it now names 2 of the 3 diagnostic wordings, so the new-branch drift it predicted has already happened.
- BR-6 — not-addressed — atlas/infra/raw_logging.md:82 still shows max_tokens 4096; empty_response_reason_spec is still mapped under modes/raw_mode.

### Raised

- **BR-7** [Important] `detected-loss-must-surface` Truncation is surfaced only for the cap; refusal/content_filter after partial text and an in-band SSE error after HTTP 200 still end silently
  2nd finding in this family; BR-2 fixed an instance. Rule: classify each response's terminal state per wire into one closed set (done, cap, filtered, paused, error, none) with one pure function, and surface every class except done; _is_output_cap becomes the cap row. Probed at HEAD via dispatcher.query: anthropic text+refusal, openai text+content_filter, and anthropic text+event:error overloaded_error (stop_reason nil) all log nothing; pause_turn has zero hits in lua/. Pin with one table-driven wire-by-class test. If deferred, the Revisions' "one cause, both symptoms" must say the truncation case was inferred, not measured, and link the tracking issue.

## Round 3 — 2026-09-10T10:56:59-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — addressed — Pinned by revert: dropping the finishReason match reddens "googleai: finishReason" and J7i; restoring "On Claude" reddens 2 unit cases and J7h.
- BR-3 — not-addressed — provider_params.lua:159-166 unchanged; no lower-ceiling entry and no test pinning the >=64K assumption.
- BR-4 — not-addressed — "cannot honour" still at provider_params.lua:158, provider_params_spec.lua:299 and issue Revisions line 196.
- BR-5 — not-addressed — J7c (dispatcher_query_spec.lua:1086-1087) unchanged; J7g and J7j now repeat the shape, see the new vacuous-negative-assertion finding.
- BR-6 — not-addressed — atlas/infra/raw_logging.md:82 still shows 4096; empty_response_reason_spec still mapped under modes/raw_mode (traceability.yaml:307-314).
- BR-7 — not-addressed — The allowlist is delivered and pinned (revert reddens J7j and the reject-list unit case). But the in-band error BR-7 probed is still silent: anthropic event:error, openai and cliproxy data:{"error":...} after text + HTTP 200 all give stop_reason nil, and _is_normal_finish(nil) returns true (dispatcher.lua:199-204), while :189 and :639 claim that case is covered.

### Raised

- **BR-8** [Important] `atlas-drift` atlas update appears missing for the end-of-response diagnosis and the model-keyed Claude max_tokens default
  2nd in family. Rule: every surface this issue adds lands in its owning atlas page, and every example showing a value the window changed is corrected, in one sweep. Sweep: providers/architecture.md (stop-reason extraction per wire, no-text cap diagnosis, TRUNCATED warning); providers/anthropic.md (64000 default for every claude-* id on every transport, counts thinking); infra/raw_logging.md:82 and the traceability mapping (both BR-6). The only atlas edit in the window is traceability.yaml.
- **BR-9** [Minor] `rationale-matches-fact` Prose claims written this window disagree with the code: in-band error "covered", nil stop_reason "non-streaming", "finished normally", three spellings
  2nd in family (BR-4 is the 1st). Rule: re-check every behavioral claim this issue wrote against code or fixtures in the same round the code changes. Sweep at HEAD: dispatcher.lua:189 and :639 (in-band error said to be surfaced; probed silent); :200-202 (all builders set stream = true and every stream fixture carries a stop reason); :244 ("finished normally" branch also gets refusal/SAFETY with no text); :223-228 (docstring lists 3 spellings, code accepts a dead 4th, maxtokens); provider_params.lua:150 ("documented default"); :158 and spec:299 (BR-4); issue lines 182, 189, 245.
- **BR-10** [Minor] `vacuous-negative-assertion` J7g and J7j repeat J7c's shape: they assert an emission is absent by matching the current wording
  2nd in family (BR-5 is the 1st). Rule: assert that something was not emitted by counting calls at the emitter, not by matching the current wording. J7g (dispatcher_query_spec.lua:1184) captures only warnings, so assert.equals(0, #logged) works; J7j (:1231) should reject any case-insensitive max_tokens mention; J7c should wrap _empty_response_reason and assert zero calls. Rewording TRUNCATED makes J7f go red, and after J7f is fixed J7g passes vacuously.
- **BR-11** [Minor] `untrusted-value-in-format-string` The cap branch of _empty_response_reason puts the body-parsed stop_reason into the format string itself
  dispatcher.lua:262-266 concatenates qt.stop_reason before :format(bytes); this is safe only because _is_output_cap uses exact equality. If that check is widened, a % in the value raises inside the terminal closure and skips legacy_complete. Pass it as a %s argument, as the fallthrough branch does (ARCH-SECURE).

## Round 4 — 2026-09-10T11:14:06-07:00 (claude) — passed

### Disposed

- BR-3 — not-addressed — Unchanged: ^claude%- sets 64000 for every claude-* id on every provider incl. copilot, no ceiling table or pinning test; deprecated-but-served claude-opus-4-20250514 is in the catalog fixture; clamp to the model's declared cap (Models API max_tokens) or a per-model table.
- BR-4 — not-addressed — provider_params.lua:155-158 and provider_params_spec "cannot honour" unchanged, and atlas/providers/architecture.md now repeats it.
- BR-5 — not-addressed — J7c still hand-lists two of the three renderings (it omits the cap wording); wrap _empty_response_reason and assert zero calls.
- BR-6 — not-addressed — atlas/infra/raw_logging.md:82 still shows max_tokens 4096 for claude-sonnet-4-6; empty_response_reason_spec is still mapped only under modes/raw_mode, not providers/architecture.
- BR-7 — not-addressed — J7j/J7k pin the three probed instances (both red on revert) but the rule was not adopted: the empty path consults only _is_output_cap, so an anthropic event:error before any text logs "returned no assistant text (body_bytes=290, stop_reason=unknown)" and drops "Overloaded"; the none class is still treated as done though every recorded stream fixture carries a terminal reason.
- BR-8 — addressed — atlas/providers/architecture.md now maps the stop-reason predicates and the model-keyed 64000 default; the example/mapping residue is BR-6.
- BR-9 — not-addressed — Non-streaming premise, the "finished normally" bucket (refusal lands there), dead maxtokens spelling, BR-4 and issue lines 182/245 unchanged; drop the "documented default" item (Anthropic does recommend ~64000 for streaming; say "documented recommendation").
- BR-10 — not-addressed — J7g and J7j still assert absence by matching TRUNCATED / Raise max_tokens.
- BR-11 — not-addressed — The cap branch still concatenates tostring(qt.stop_reason) into the format string before :format(bytes).

### Raised

- **BR-12** [Minor] `rationale-matches-fact` The #228 atlas section and the _inband_error docstring, written after BR-9, add new claims the code contradicts
  This is the 3rd finding in family rationale-matches-fact. Do NOT fix these instances. Rule: prose names a predicate and its purpose and links its test; it does not restate value lists or premises the code owns (ARCH-DRY for prose). Every remaining factual claim cites the test or fixture that checks it, in the commit that writes it. New at head: atlas/providers/architecture.md says the four predicates each have their own test, but _inband_error has none. It lists the whitelist as four spellings where the code has six. It repeats that every successful non-streaming shape has no stop reason, but all builders stream and every recorded stream fixture carries one. dispatcher.lua:671-676 says that branch covers in-band errors, but the branch above catches them first. Measured prevalence: about 11 such claims at head across dispatcher.lua, provider_params.lua, provider_params_spec.lua, the atlas and the issue; 4 were written in 0a56977, after BR-9 stated the rule.
- **BR-13** [Minor] `stop-reason-vocabulary-per-wire` Each wire's terminal vocabulary is pinned only by hand-written bodies, and _inband_error has no per-wire test
  This is the 2nd finding in family stop-reason-vocabulary-per-wire. Rule: every wire's terminal vocabulary (stop key, cap spelling, in-band error frame, and a non-error body that quotes one) is pinned by one table-driven per-wire test fed by recordings from make fixtures. A max_tokens:5 request per wire in scripts/record_fixtures.lua would capture the cap spellings live (ARCH-MOCK). At head, J7h and J7i use synthetic bodies. J7i's googleai body is an SSE data: frame, but the googleai wire is a pretty-printed JSON array. _inband_error's two frame shapes are covered only end to end by J7k. Nothing pins that an answer quoting error JSON is not flagged (probed: it is not, today). An escaped quote cuts the provider message short (probe logged: Internal \).
- **BR-14** [Minor] `test-order-independence` J7e-J7k pass only because earlier groups leaked the anthropic and googleai endpoints
  dispatcher.providers anthropic and googleai are nil at require time. Only Groups C, D and G set them (dispatcher_query_spec.lua:247, :328, :455), and nothing cleans up. With the endpoint unset, dispatcher.query raises dispatcher.lua:524 attempt to index a nil value (probed). So the new J7 tests fail if Group J runs alone or the earlier groups move. Register both endpoints in the top-level before_each next to openai.

## Open findings

- **BR-3** [Minor] `model-ceiling-envelope` The ^claude%- 64000 default has no per-model ceiling check for claude-* ids served with lower output limits
- **BR-4** [Minor] `rationale-matches-fact` The test comment says non-Claude models "cannot honour" a higher cap, which is false for gpt-5.x (128K output)
- **BR-5** [Minor] `vacuous-negative-assertion` J7c lists message wordings by hand, so a rewording or new branch makes it vacuous again
- **BR-6** [Minor] `atlas-drift` The atlas raw_logging.md example still shows max_tokens 4096 for claude-sonnet-4-6; the new spec is mapped under modes/raw_mode
- **BR-7** [Important] `detected-loss-must-surface` Truncation is surfaced only for the cap; refusal/content_filter after partial text and an in-band SSE error after HTTP 200 still end silently
- **BR-9** [Minor] `rationale-matches-fact` Prose claims written this window disagree with the code: in-band error "covered", nil stop_reason "non-streaming", "finished normally", three spellings
- **BR-10** [Minor] `vacuous-negative-assertion` J7g and J7j repeat J7c's shape: they assert an emission is absent by matching the current wording
- **BR-11** [Minor] `untrusted-value-in-format-string` The cap branch of _empty_response_reason puts the body-parsed stop_reason into the format string itself
- **BR-12** [Minor] `rationale-matches-fact` The #228 atlas section and the _inband_error docstring, written after BR-9, add new claims the code contradicts
- **BR-13** [Minor] `stop-reason-vocabulary-per-wire` Each wire's terminal vocabulary is pinned only by hand-written bodies, and _inband_error has no per-wire test
- **BR-14** [Minor] `test-order-independence` J7e-J7k pass only because earlier groups leaked the anthropic and googleai endpoints
