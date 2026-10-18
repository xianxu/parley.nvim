# S4 presentations: show the agent's round by `presentation:` — Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After an agent writes an agentic document, parley shows that write's round, which Couch keeps, according to the document's `presentation:`. The round is cleared on the operator's next confirmed submit.

**Architecture:**
- Couch (pair#661 M1) derives a round on every agent write and serves it as `couch --session-sync round FILE --json`.
- parley reads the round after each reload, through the bounded registry client.
- A pure module turns the round plus the buffer's current lines into decorations: spans, with re-anchoring when the file moved on.
- `skill_render` draws them in a round-kind slice of the shared diagnostic namespace, as footnotes already do, so `diag_display` shows them and other diagnostics are untouched.
- A confirmed submit clears them; that is the single chokepoint every submit goes through.

**Tech Stack:** Lua (Neovim 0.11), plenary/busted specs, and the Python Couch registry fake.

**Design:** `ops:teams/devinfra/projects/universal-agent-input-interface/design.side/10-s4-edit-path.md`, sections 3, 4, 6 and 8. It was operator-reviewed on 2026-10-17.

**Gate:** coding starts only after pair#661 M1 lands. Before Task 1, check the real `round --json` envelope against the assumption in Task 1 (see "Contract assumption"), and fix this plan if it differs.

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `presentation.value` | `lua/parley/presentation.lua` | new |
| `presentation.decorations` | `lua/parley/presentation.lua` | new |

- **`presentation.value(lines)`** reads the frontmatter's `presentation:` scalar, using `frontmatter.parse(lines).fields`.
  - It returns `"direct"`, `"highlight"` or `"propose"`. A missing or unknown value returns `"highlight"`.
  - **Relationships:** one per document, read fresh on each round, because the operator may edit the key.
  - **DRY rationale:** this is the only reader of the key. `edit_round` and any later caller (for example the finder) ask it rather than parsing.
  - **Future extensions:** a per-section mapping in `collaboration-mode:`'s shape (design Q5, deferred). The signature then widens to `(lines, lnum)`.
- **`presentation.decorations(round, lines, current_hash)`** turns a round's spans into a list of `{lnum, col, end_lnum, end_col, message, deletion}`.
  - When `current_hash == round.result_hash`, the positions are taken as given.
  - Otherwise each span is re-anchored by its `new` text, choosing the occurrence nearest its old position. A deletion is re-anchored by the text around it: the 40 characters before its position in the result.
  - A span it can't find is dropped.
  - The message is `explain`, or "changed by the agent" when there is none. A deletion's message is `deleted: <old>`, cut to one line.
  - **Relationships:** consumes 1 round and N spans. Its tests run with no vim buffer, only plain `lines` tables.
  - **DRY rationale:** this is the one place that interprets the round's positions. The fake and the real Couch feed the same function.
  - **Future extensions:** the revert-one-span key (dropped in the design's review) would read `old` from this same list.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `edit_round` | `lua/parley/edit_round.lua` | new | the round fetch, the generation guard, and drawing |
| `document_registry.request("round", …)` | `lua/parley/document_registry.lua` | modified | `couch --session-sync round FILE --json` |
| `skill_render.publish_round` / `clear_round` | `lua/parley/skill_render.lua` | new | extmarks and vim.diagnostic |
| `session_sync` reload and confirmed-submit hooks | `lua/parley/session_sync.lua` | modified | the existing reload paths and `release_and_send` |
| fake `round` verb + `--round` seed | `tests/fixtures/fake_couch_registry.py` | modified | Couch's sidecar and its `cleared` |

- **`edit_round`** has three entry points:
  - `refresh(buf)` is called after a reload and on attach. It reads `presentation.value`. For `direct` or `propose` it clears and returns; under `propose` the markers are already in the text. Otherwise it bumps `generation[buf]`, requests the round, and on the reply draws only if the generation is unchanged, the buffer is valid and `cleared` is false. It computes the decorations from the buffer's lines at reply time, never at request time, so an edit in between is handled by re-anchoring.
  - `clear(buf)` bumps the generation, which drops any reply in flight, and calls `skill_render.clear_round`.
  - A buffer-local `on_lines` re-derives the diagnostics from the span extmarks, so a diagnostic follows its span while the operator edits (row 30). vim.diagnostic positions do not move with the text; extmarks do.
  - **Operating envelope (ARCH-CONSTRAINTS, plan-quality minor 4):** `on_lines` is a per-keystroke hot path. It coalesces: a `pending[buf]` flag means at most one scheduled re-derive per buffer, however many keystrokes arrive before it runs. A re-derive costs one `nvim_buf_get_extmarks` over the round namespace, O(spans), and it reads no buffer text. The growth drivers are keystrokes K and spans S. The cost is O(S) per scheduled run and O(1) per keystroke beyond the first. Re-anchoring runs only once per reply, not per keystroke, at O(S × document bytes) with plain `string.find`. The budget is S ≤ 200 spans and documents up to Couch's 4 MiB read cap. Past 200 spans, `refresh` draws the first 200 rather than stalling the editor. It also says so visibly, once per round (keyed by `result_hash`), with a single `vim.notify` at WARN: `parley: showing 200 of N agent changes`. The operator must never take a partly highlighted round for the whole round (hub, 2026-10-18). A counted spec (Task 4) feeds 8 and then 16 keystrokes before the scheduler runs and asserts exactly one re-derive each time.
  - **Injected into:** nothing pure. It is the shell around `presentation.decorations`.
- **`document_registry.request("round", {path})`** adds one entry to `shapes` and its own reply classifier. The registry classifier `model.classify_reply` is specific to registrations, so round replies don't go through it. They still get the client's queue, child lifetime and deadline bounds (ARCH-DRY: one bounded Couch client, not a second `couch.run` with its own timer).
  - Its result is `{kind = "round", round = …, cleared = bool}`, `{kind = "absent"}` when there is no round yet, or `unavailable`.
- **`skill_render.publish_round(buf, decorations)` / `clear_round(buf)`** follow the `publish_footnotes` / `clear_footnote_diagnostics` pattern exactly.
  - They use their own highlight namespace, `parley_round_hl`.
  - Diagnostics go in the shared diagnostic namespace with `source = "parley-round"` and `user_data.parley_kind = "round"`.
  - Each preserves every other kind. That keeps footnotes and review-skill explanations safe on submit, which the existing `clear_decorations` would not, since it clears footnotes too.
- **`session_sync`** gets two hooks.
  - Reload: `edit_round.refresh(buf)` at the end of `reload()` (`session_sync.lua:319`) and in the `FileChangedShellPost` branch (`:683`). Both paths run for legacy session files and registered documents, because `agentic_document.adopt` attaches `session_sync`. It also runs on attach, so a reopened file shows an uncleared round.
  - Confirmed submit: `edit_round.clear(buf)` in `release_and_send`'s `obj.code == 0` branch (`:850`), next to `attention.record`. This is the single send path for both kinds of document (`send_registered` calls it).
- **The fake's round.** `fake_couch_registry.py` gains:
  - the verb `round PATH --json`, which returns `{"Code":"ok","Error":"","Round":<sidecar or null>,"Cleared":bool}`;
  - a test-side seed, `--round PATH FILE.json`, the same kind of non-Couch ledger edit as `--owe`. The seed is stored under the registration ID (or under the path, for legacy files).
  - `--owe` now also stamps `LastSubmit` on the key. `Cleared` is `LastSubmit > Round.at`, the same rule as Couch's (a submit recorded after the round).
  - The fake `--send-to` already calls `--owe`, so a real Alt+Return in a spec clears the round with no extra wiring.
  - `fake_couch.lua` gains `M.round(registry, path, round_table)`.

**Contract agreed with pair:2 (2026-10-18), building M1:** positions are 0-based `[line, col]` with `col` a **byte** offset within the line (what `nvim_buf_set_extmark` takes). A deletion has `start == end`. A missing sidecar gives `Round = null, Cleared = false`, which draws nothing. A malformed one gives `Code = "round-invalid"`, which parley treats as `unavailable`: nothing is drawn and the case is logged at debug. Confirmed by pair:2: `result_hash` is `hex(sha256(exact file bytes)[:8])`, the `read --all` function, and Couch normalizes nothing. parley's newline-joined buffer hash matches for LF files that end in a newline, and re-anchoring covers the rest. **Timestamps are compared as instants, never as strings:** the round's `at` is RFC3339 UTC (`Z`), while the ledger's submit `At` is RFC3339Nano with a local offset (for example `-07:00`). The fake parses both with `datetime.fromisoformat` (after mapping `Z` to `+00:00` and cutting the nanoseconds to microseconds) and compares the instants. Task 1's spec includes a submit stamped with a local offset that is earlier as text but later as a time.

**Original contract assumption:** the reply envelope is `{Code, Error, Round, Cleared}`, and `Round` follows the design's sidecar: `{base_hash, result_hash, at, presentation, spans:[{start:[l,c], end:[l,c], old, new, explain?}]}`, with 0-based positions in the result. `result_hash` is Couch's whole-file hash, `hex(sha256(bytes)[:8])`, so parley computes the same over the buffer's lines joined with `\n` plus the final newline. If M1 differs, the fake and Task 1 change together. `scripts/check-couch-registry-conformance.py` then gains a `round` case against the real binary (Task 6), which is the drift guard.

**ARCH-FUNERAL:**
- parley creates nothing durable. The decorations are per buffer and die with it, and the generation table is keyed by buffer and cleared on `BufUnload`.
- The round sidecar is Couch's. Each write replaces it, and `forget` removes it (pair#661).
- The fake's `rounds` live in the spec's temporary registry file.

**ARCH-concurrency:** a round reply can arrive after a newer reload or a submit. The generation counter is the single resource that makes "draw only the latest" a one-step check. Task 4 has a spec that sends the reply after a `clear`, using the fake's `FAKE_COUCH_REGISTRY_REPLY_DELAY` seam, so both orders are tested.

---

## Tasks

### Task 1: the fake's round (fixture first)

**Files:** modify `tests/fixtures/fake_couch_registry.py` and `tests/helpers/fake_couch.lua`; test `tests/unit/fake_couch_round_spec.lua`.

- [ ] Write the spec:
  - Seed a round with `fake_couch.round`, then `round PATH --json` returns it with `Cleared=false`.
  - After `fake_couch.owe` (a submit), `Cleared=true`.
  - A path with no seed returns `Round=null`.
  - A wrong argument shape returns `Code="usage"`.
- [ ] Run it (`make test-spec SPEC=scratch` with a map naming the spec) and see it fail.
- [ ] Implement:
  - in `owe_or_fold` on `--owe`, `status["LastSubmit"] = At`, with `At` stamped at microsecond precision (`%Y-%m-%dT%H:%M:%S.%fZ`) instead of whole seconds. Specs also seed a round's `at` in the past, so the strict `>` can't tie within one second (plan-quality minor 1);
  - a `--round PATH FILE` branch storing `state["rounds"][key]`;
  - the `round` op, computing `Cleared` as `instant(LastSubmit) > instant(Round["at"])`, parsed as above, never compared as strings;
  - `M.round` in `fake_couch.lua`.
- [ ] Run until green, then commit `#383: the Couch fake keeps a round and clears it on submit`.

### Task 2: `presentation` (pure)

**Files:** create `lua/parley/presentation.lua`; test `tests/unit/presentation_spec.lua`.

- [ ] Write `value` cases: missing frontmatter, `presentation: propose`, a quoted value, an unknown value, and no closing `---`. The last three return `highlight` except for the valid `propose`.
- [ ] Write `decorations` cases:
  - the same hash takes the positions as given;
  - a line inserted above shifts a span by one line;
  - a span whose `new` text is gone is dropped;
  - with two occurrences of `new`, the one nearest the old position wins;
  - a deletion carries `deleted: <old>` (multi-line `old` cut to its first line plus "…");
  - a span without `explain` says "changed by the agent";
  - multi-line spans keep their `end_lnum`.
- [ ] **Adversarial strategy (plan-quality minors 2, 3):** Couch's positions are untrusted input, even on a hash match. A seeded loop of 500 random rounds over random lines feeds `decorations` the risky class: spans that are malformed (not integer pairs, `end` before `start`) or out of range (a line past the end, a column past the line's length), multibyte content, CR bytes, and `new` text that is empty or repeats. The mechanical guard: `decorations` never raises, and every output position lies inside `lines` (`0 <= lnum < #lines`, `0 <= col <= #lines[lnum+1]`). A span that fails the check is dropped, never clamped into a wrong place. Drawing also passes `strict = false` to extmarks, as `highlight_footnote_span` does, as a second guard.
- [ ] Watch them fail, then implement with plain string search over `table.concat(lines, "\n")` and byte-offset to (line, col) conversion. Keep the file under 120 lines, with no `vim.api`.
- [ ] Get to green, then commit `#383: presentation reads the key and places a round's spans`.

### Task 3: drawing (`skill_render.publish_round` / `clear_round`)

**Files:** modify `lua/parley/skill_render.lua`; test `tests/unit/skill_render_round_spec.lua`.

- [ ] Write the spec:
  - Publish two decorations, and see two `parley_round_hl` extmarks and two diagnostics with `parley_kind = "round"`.
  - A footnote diagnostic published before survives both `publish_round` and `clear_round`.
  - `clear_round` leaves the review-skill (`parley-skill`) diagnostics alone.
  - A deletion is a zero-width extmark with no highlight group, and its diagnostic sits on its line.
- [ ] Implement with `strict = false` on every extmark, mirroring `publish_footnotes` (`skill_render.lua:75`), with an `is_round_diagnostic` next to `is_footnote_diagnostic`. Put the new functions **after** `clear_footnote_diagnostics`'s doc block and function, not between a `---` block and its function (lessons, #204/#340/#345).
- [ ] Get to green, then commit.

### Task 4: `edit_round` and the registry's `round`

**Files:**
- create `lua/parley/edit_round.lua`;
- modify `lua/parley/document_registry.lua`;
- test `tests/integration/edit_round_spec.lua`, using the fake through `fake_couch.lua`.

- [ ] Write the spec. Each case uses a temporary registry, a registered document, a seeded round and `arrival.MS` waits:
  - **(row 29)** `refresh` draws each span with its `explain`.
  - **(33b)** a span with no `explain` reads "changed by the agent".
  - **(30)** inserting a line above moves both the highlight and its diagnostic.
  - **(34)** `presentation: direct` draws nothing.
  - **(33)** `presentation: propose` draws nothing, and the file's markers are untouched.
  - **(32)** a seeded round that is already `Cleared` draws nothing.
  - **Race:** with `FAKE_COUCH_REGISTRY_REPLY_DELAY=1` and `_OPS=round`, `refresh` then `clear` leaves nothing drawn after the reply arrives. In the reverse order the draw happens.
  - **Stale:** the buffer is edited between the request and the reply, and the span is re-anchored.
  - **Counted coalescing:** 8, then 16, keystrokes on a drawn buffer before the scheduler runs produce exactly one re-derive each time, counted through an exposed counter. That rejects a per-keystroke re-derive, which would count 8 and 16.
  - **Span cap:** a round of 201 spans draws 200 and notifies `showing 200 of 201` exactly once. A second `refresh` of the same round doesn't notify again.
- [ ] Implement `round` in `document_registry.request`:
  - add `shapes.round = 1`;
  - build the argv as for `lookup`;
  - in the child callback, classify a round reply itself: `Code == "ok"` and `Round` null gives `absent`, `Round` a table gives `{kind="round", round=…, cleared=Cleared == true}`, and anything else gives `unavailable`.
- [ ] Implement `edit_round` as in Core concepts, with the deadline `config_ms("agentic_submit_timeout_ms")`. An `unavailable` reply draws nothing and logs at debug, because a missing highlight must never block the operator.
- [ ] Get to green, then commit.

### Task 5: the hooks (reload, attach, confirmed submit)

**Files:** modify `lua/parley/session_sync.lua`; test `tests/integration/edit_round_hooks_spec.lua`.

- [ ] Write the spec:
  - **(29 end to end)** the agent's write lands on disk, with a seeded round matching the new content; parley reloads and draws.
  - **(31)** a confirmed Alt+Return through the fake `--send-to` clears the highlights before any new round.
  - **(32)** close and reopen: nothing is drawn, because the fake reports `Cleared`.
  - **Not confirmed:** a failed send (fake send exit 1) keeps the highlights.
  - Both a legacy `type: session-sync` file and a registered plain document are covered.
- [ ] Implement:
  - call `edit_round.refresh(buf)` at the end of `reload()` and in the `FileChangedShellPost` branch after `window_views.restore`;
  - call it once in `M.attach` after the first read;
  - call `edit_round.clear(buf)` in `release_and_send`'s `obj.code == 0` branch, before the `state[buf] ~= s` guard, as `attention.record` is (sent is sent);
  - clear `edit_round`'s generation on `BufUnload`.
- [ ] Get to green, then commit.

### Task 7: universal-review export v2 and v3 (scope addition, hub 2026-10-18)

ariadne#437 retires the `deletions` mode flag (propose-strike) and bumps the export to version 3. Under v3, proposals come from the document's `presentation: propose`, not from a mode. parley must load both shapes and must never let a missing `deletions` fall back to propose-strike. #383 lands first. The exact v3 shape comes from ariadne:1 before this task is coded.

**Files:** modify `scripts/sync-review-protocol.py`, `lua/parley/skills/review/mode.lua` and `lua/parley/skills/review/instruction.lua`; test `tests/unit/review_protocol_export_test.py`, `tests/unit/review_mode_spec.lua` and `tests/unit/review_instruction_spec.lua`.

- [ ] Strategy: one rule per parser, guarded by the same pair of fixtures. A v2 export and a v3 export each go through `validate_manifest`, `mode.parse` and `instruction.context`. The guard: v2's brief is byte-identical to today's, and v3's brief contains no `deletions` line. A v3 mode record that carries `deletions` is refused.
- [ ] `validate_manifest` accepts version 3. Under it, `deletions` is forbidden on mode records and fixtures are allowed. Versions 1 and 2 still require `deletions`.
- [ ] `mode.parse`: `deletions` is optional with no default. If present it is validated as now; if absent it is nil.
- [ ] `instruction.context` writes `deletions:` only when the first mode has one. With no mode selected, the default line follows the snapshot's `export.json` version: v2 keeps propose-strike, v3 writes none.
- [ ] Commit `#383: the review export loads v2 and v3; no default deletions`.

### Task 6: propose's side-doc link, conformance, atlas

**Files:**
- test `tests/integration/edit_round_proposal_link_spec.lua`;
- modify `scripts/check-couch-registry-conformance.py`, `atlas/` (the agentic-document page and `index.md`) and `workshop/lessons.md` if a lesson arises.

- [ ] Write the spec (**33a**): a parent with `→ [proposal](design.side/03-rewrite.md)`. Alt+o opens the side doc, and the side doc is registered as agentic like a `→ [discussion]` target (#373's inheritance). If it already passes, it stays as the regression.
- [ ] Add a `round` case to the conformance script, comparing real and fake: no round gives `Round=null`; after a real `write --all` there is a round with spans; after a recorded submit, `Cleared=true`. It is opt-in, like the script's existing cases.
- [ ] Atlas: document `presentation:` in the agentic-document page, the round fetch-and-clear flow, and the round-kind diagnostics.
- [ ] Run the full suite in the background with `sdlc local-check run --name suite` on the pushed head.
- [ ] Do the live check (asking the hub first; it is the operator's nvim). Stage with `sdlc stage --build`. On a real document, an agent `apply` round highlights with its reasons, `write` rounds highlight too, and the next Alt+Return clears them. `presentation: propose` gives per-line markers.

## Done when

The issue's Done when: on a document under the default presentation, an agent `apply` round shows each edit highlighted with its reason, a `write` round shows its changed lines highlighted ("changed by the agent"), the highlights follow the operator's edits, and they clear on the next confirmed submit and stay cleared on reopen. Under `presentation: propose` the same request shows per-line accept/reject markers, and a large rewrite shows as a followable `→ [proposal]` link. `direct` draws nothing. Specs against the Couch fake cover this, and there is a live check on a real document.

## Revisions

- 2026-10-18: change-code's plan-quality gate passed with 4 Minors, all folded in:
  1. microsecond `LastSubmit` stamps and a past `at` in the fake (Task 1);
  2. an adversarial seeded-random strategy for `presentation.decorations` (Task 2);
  3. untrusted span positions are checked in the pure layer and extmarks use `strict = false` (Tasks 2, 3);
  4. the `on_lines` coalescing envelope with a counted N/2N spec and a 200-span cap (Integration points, Task 4).
- 2026-10-18 (hub): the span cap must be visible. Past 200 spans, one WARN notice per round, `showing 200 of N agent changes`, instead of only a debug log.
- 2026-10-18 (hub, ariadne:1): scope addition, Task 7: load universal-review export v2 and v3, never defaulting a missing `deletions` to propose-strike.
- 2026-10-18 (close review): the shipped design differs from the Spec text in four places.
  - `ParleyAgentChange` links to `DiffAdd` rather than `DiffChange`, so a round reads apart from footnotes, which use DiffChange.
  - Clearing goes through `edit_round.clear` → `skill_render.clear_round`, not `clear_decorations`, because the latter would wipe footnotes.
  - A deletion is placed only on a matching hash: the round carries no context to re-find it by.
  - The proposal-link regression lives in `agentic_document_side_inherit_spec.lua`.

  The review also found that `attach_diagnostics` replaced the namespace wholesale and dropped round diagnostics; it now restores them. And `edit_round.clear` now resets `pending`.
- 2026-10-18 (close review round 2): the shared-namespace finding repeated as a family, so the fix is a rule, not a site. Every writer of the `parley_skill` diagnostic namespace (footnotes, round, attach_diagnostics, clear_decorations, apply_snapshot) now goes through `replace_kind(buf, owns, diagnostics)`. The round is owned by the round functions alone. `snapshot` no longer captures round diagnostics, and `clear_decorations` (the dismiss binding and every skill-round start) leaves the agent's round to its confirmed submit.
