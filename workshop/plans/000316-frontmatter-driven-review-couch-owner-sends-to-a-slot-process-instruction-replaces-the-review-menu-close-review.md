# Boundary Review — parley.nvim#316 (whole-issue close)

| field | value |
|-------|-------|
| issue | 316 — Frontmatter-driven review: couch-owner sends to a slot; process-instruction replaces the review menu |
| repo | parley.nvim |
| issue file | workshop/issues/000316-frontmatter-driven-review-couch-owner-sends-to-a-slot-process-instruction-replaces-the-review-menu.md |
| boundary | whole-issue close |
| milestone | — |
| window | c9b45a298f28841333cf2de87b98dc43a88c5643..1fcd25a88521308110f0f7df0ca0a46de9f8ee89 |
| command | sdlc close --issue 316 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-11T14:12:53-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Let me read the new files directly.

I've read the code changes; next I'm running the new specs.

Specs are green. I'm checking one coverage gap (the review skill's `source()` with `modes`), then writing up.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The change delivers what the issue and its Revision ask for. Alt+Return in markdown now reads `process-instruction:` and sends the document to the agent in this editor's own Couch slot, matched by the `COUCH_THREAD_SCOPE`/`TAG` binding. Outside pair it falls back to the in-editor review round. The review-menu float and its spec are deleted, and a session-sync `owner:` is now a check rather than a route. I ran the eight touched spec files at the pinned head and all are green: frontmatter 7, couch 4, review_instruction 6, review_send 12, session_sync integration 39, session_sync unit 10, keybindings 80, arch buffer_mutation 10. Nothing blocks shipping. One cheap Important gap remains: no test drives the review skill's `source()` through the new multi-mode `args.modes` path. The outside-pair test stubs `run_via_invoke`, so the code that actually runs that round is untested. The other findings are Minor.

**1. Strengths**
- **One shared brief (ARCH-DRY).** `instruction.brief` (`lua/parley/skills/review/instruction.lua:85`) builds the prompt for both the slot message and the review skill's system prompt (`skills/review/init.lua:516`). The two paths cannot drift apart.
- **Couch access in one place.** `lua/parley/couch.lua` is now the only module that calls the `couch` binary; session_sync's private `send`/`query`/`list`/`find_actor` were moved into it, not copied. The own-slot match uses scope+tag rather than address strings, which avoids alias and prefix spelling problems.
- **No silent fallback.** In pair, when no actor resolves, the code reports an error and sends nothing (`review_send.lua:171`, `session_sync.lua:559`). It never quietly turns a slot send into a model call, and a test pins this (`review_send_spec.lua:123`).
- **Baseline only moves on success.** The diff baseline advances only after a delivered send (`review_send.lua:128`). The test at `review_send_spec.lua:92` proves a failed send doesn't move it.
- **YAML audit done.** The concern was checked against sdlc's real yaml.v3 parser, and `needs_quote`/`quote` exist because of it. The quote/unquote round-trip test is built from the escapes' own delimiters.

**2. Critical findings**
None.

**3. Important findings**
- **`source()` untested with `args.modes`** (`lua/parley/skills/review/init.lua:505-520`, `M.mode_names`). The only test of this path (`tests/integration/review_mode_load_spec.lua:54`) uses the single `mode` arg. The outside-pair spec replaces `run_via_invoke` with a stub, so nothing checks that:
  - `{modes={"copy-editing","fact-check"}}` renders both mode bodies plus copy-editing's directives;
  - `has_mode` is true;
  - the journal records `copy-editing+fact-check`.

  Fix: add a `review.skill.source({skill_dir=…, args={modes={…}, instruction="x"}})` case to `review_mode_load_spec.lua`.

**4. Minor findings**
- **Quoted value with a trailing comment.** `review_send.instruction_value` (`:39-43`) unquotes the raw value. For `process-instruction: "[x] y" # note`, unquote doesn't match, so the leading `"` hides the `[x]` and the round silently runs free-form with the quoted text. Fix: when raw starts with a quote, take the quoted span first.
- **Agent edits show up in the next diff.** The agent replies by editing the file in place, so the next send's "Changes since the last send" includes the agent's own edits next to the operator's. Consider a sentence in the message, or resetting the baseline on a reload from disk.
- **Unclosed quote after completion.** When completion runs inside an already-quoted value (`process-instruction: "[`), `requote` returns nil and nothing closes the quote unless one was already there.
- **Empty `process-instruction:`.** An empty value reads as present (`""`), so the user is not prompted and a bare free-form send goes out. This is probably fine, but say so in the atlas.
- **ARCH-MOCK: no conformance check.** The fake couch is driven by env variables, and nothing compares it with real couch. The new dependency on `Binding.Scope`/`Binding.Tag` in `couch --actors --json` was checked live once (Log), but no recurring check would catch drift. This gap existed before the change; this change widens it.
- **Unescaped backslash sequences.** `frontmatter.unquote` turns `\n` into `n` rather than a newline, which differs from YAML. This can't matter for a one-line value.

**5. Test coverage notes**
Of the plan's eight review_send scenarios, the first seven are covered. The eighth, completion, is covered through a `<Cmd>` mapping workaround, which is reasonable given the TextChangedI limitation recorded in the Log. Session-sync's new owner check is covered three ways: another slot, this slot via a prefix spelling, and an unresolvable slot. The legacy outside-pair send to `owner:` is still covered by the existing #315 cases. The pure helpers (`completion_start`, `requote`, the diff cap) have direct tests. The remaining gap is the Important finding above.

**6. Architectural notes**

| Marker | Result | Notes |
|---|---|---|
| ARCH-DRY | pass | Frontmatter reader, brief and couch seam are each shared; nothing copied. |
| ARCH-PURE | pass | `frontmatter`, `instruction`, `message`/`diff`/`placement`/`completion_start`/`requote` and `own_actor` are pure and unit-tested; `submit`/`send_to_slot` are a thin shell. |
| ARCH-PURPOSE | pass | Every Done-when row is delivered as revised; the `couch-owner` drop is an operator decision recorded in Revisions, not a deferral. |
| ARCH-MOCK | flag (Minor) | See above. |
| ARCH-CONSTRAINTS | pass | TextChangedI handler: a cheap pattern match runs before any frontmatter parse, and the parse reads at most 60 lines; diff capped at 200 lines. |
| ARCH-SECURE | pass | couch is called with an argv array (no shell); frontmatter is parsed into typed fields; unknown modes are refused visibly. |
| ARCH-ORDER | pass | Async own-slot resolution re-checks the buffer is still valid; baseline only moves on confirmed success; concurrent presses diff against the same baseline, which is harmless. |
| ARCH-FUNERAL | pass | The baseline lives in memory and dies with nvim; the completion augroup is cleaned on BufWipeout; nothing is written to disk. |

README has no review section to update; atlas `review.md`, `session_sync.md`, `keybindings.md`, `skill-system.md` and `traceability.yaml` are all updated.

**7. Plan revision recommendations**
None. The plan and its Revisions match the code.

```findings
findings:
  - id: new
    severity: Important
    family: consumer-path-untested-behind-stub
    title: |
      review skill source() with multi-mode args.modes has no test; outside-pair spec stubs run_via_invoke
    detail: |
      skills/review/init.lua:505-520 (mode_names, brief via instruction.brief, has_mode, journal mode concat) is reached only through the stubbed run_via_invoke. Add a review_mode_load_spec case with args.modes = two names, asserting both bodies plus the first mode's directives.
  - id: new
    severity: Minor
    family: frontmatter-value-reading
    title: |
      quoted process-instruction followed by an inline comment is misread as free-form
    detail: |
      review_send.instruction_value unquotes fm.raw; for `"[x] y" # note` unquote fails and the leading quote hides [x]. Take the quoted span first when raw begins with a quote.
  - id: new
    severity: Minor
    family: send-diff-semantics
    title: |
      diff since last send includes the agent's own in-place edits
    detail: |
      The baseline is the operator's copy at send time; the agent replies by editing the file, so the next diff mixes both authors. Note it in the message, or reset the baseline on reload from disk.
  - id: new
    severity: Minor
    family: completion-quoting
    title: |
      completion inside an already-quoted value never closes the quote
    detail: |
      requote returns nil when the value starts with a quote, so `process-instruction: "[` plus completion leaves an unclosed quote unless one already existed.
  - id: new
    severity: Minor
    family: fake-conformance-check
    title: |
      fake couch has no live conformance check for Binding.Scope/Tag in --actors JSON
    detail: |
      ARCH-MOCK: own-slot resolution depends on these fields; the fake is env-driven and nothing detects drift from real couch.
```
