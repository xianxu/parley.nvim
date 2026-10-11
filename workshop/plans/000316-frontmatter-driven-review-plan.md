# Frontmatter-driven review (#316) Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Alt+Return in any markdown file sends the document to the actor in this nvim's own Couch slot, steered by a `process-instruction:` frontmatter line (`[mode]` stock prompts + free text); outside pair it runs today's in-editor review with the same instruction; the review-menu float is deleted.

**Architecture:** Two pure modules (a frontmatter reader shared with session-sync, and the `process-instruction` grammar + mode expansion shared by the couch message and the review skill's system prompt), one shared couch seam (extracted from `session_sync.lua`), and one IO shell (`review_send.lua`) that owns the Alt+Return dispatch, the per-file send baseline, and `[` completion. Session-sync keeps its turn semantics; its `owner:` becomes a check against this slot.

**Tech Stack:** Lua (Neovim 0.11), plenary busted specs, the fake `couch` shell script already used by `tests/integration/session_sync_spec.lua`.

---

## Decisions (from the issue + its Revisions)

- **Target = this nvim's own slot.** pair launches every pane with `COUCH_THREAD_SCOPE` + `COUCH_THREAD_TAG` (verified on a live draft nvim). The slot address is the `couch --actors --json` actor whose `Binding.Scope`/`Binding.Tag` equal them — the same thread match couch's own `LivenessForThread` uses (no alias/prefix spelling issues). Env unset → "outside pair" → review path. Env set but no actor resolves (couch down, slot not admitted) → error notify, nothing sent: never silently swap a slot send for an LLM call.
- **Session-sync `owner:` is a check, not a route.** In a slot: resolve own actor and `find_actor(actors, owner)`; same thread → submit as today; different → warn, no save, no lock change, no send. Outside a slot there is no "this slot" to compare, so the legacy behaviour stays (send to `owner:`); it keeps the operator's ops nvim working. `couch-owner:` is not read by parley (Revision).
- **`[name]` resolution:** exact mode-file name, else a unique prefix (`[copy-edit]` → `copy-editing`, as the Done-when spells it). Unknown/ambiguous → error naming the known modes; nothing is sent. No `[name]` → `free-form`. Several names: every brief is included; **knobs come from the first named mode** (one set of directives; mixing `apply` and `propose-strike` in one round has no coherent meaning).
- **YAML:** checked against sdlc's parser (`go.yaml.in/yaml/v3`, used by `cmd/sdlc/internal/issue/card.go`, `project/metadata.go`): `a: [copy-edit] keep the voice` → `did not find expected key`; the double-quoted form parses. So every parley writer (completion, the add-prompt) writes the value double-quoted when it needs quoting, and the reader unquotes. A hand-typed unquoted value still works in parley.
- **Change since last send:** an in-memory baseline per absolute path (content at the last successful send). First send in a session says so ("first send this session: read the whole file"). Diff is unified (`vim.text.diff or vim.diff`), capped at 200 lines with a truncation note.
- **No `process-instruction:`:** Alt+Return prompts once (`vim.ui.input`), writes the answer into the frontmatter (creating one if absent), then sends. Empty/cancelled → nothing happens. Session-sync files skip this (their submit needs no instruction).
- ARCH-FUNERAL: the baseline table creates nothing durable (in-memory, one string per file sent this session, dies with nvim). No new files on disk; `review_menu.lua` and its spec are deleted.

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `parse`, `unquote`, `quote`, `needs_quote` (Frontmatter) | `lua/parley/frontmatter.lua` | new |
| `expand`, `resolve`, `brief`, `complete` (Instruction; its `parse` above-named) | `lua/parley/skills/review/instruction.lua` | new |
| `message`, `diff`, `placement`, `format_line`, `instruction_value`, `completion_start`, `requote` (SendMessage + pure send helpers) | `lua/parley/review_send.lua` | new |
| `own_actor`, `same`, `slot`, `thread` (own-slot resolution) | `lua/parley/couch.lua` | new |
| `parse_header` | `lua/parley/session_sync.lua` | modified |
| `mode_names`, `run_via_invoke` (review skill `source` takes `args.modes`) | `lua/parley/skills/review/init.lua` | modified |
| `lua/parley/review_menu.lua` (the review menu; also `session_sync.dispatch`) | `lua/parley/review_menu.lua` | deleted |

- **Frontmatter** — `parse(lines, max)` → `{ fields = {key→value without inline comment, unquoted}, raw = {key→text after colon, trimmed}, lnum = {key→1-based line}, close = closing-fence line }` or nil. Key pattern `^([%w_][%w_-]*):` (accepts `-`; lowercased). `unquote(s)` (double: `\"`/`\\`; single: `''`), `quote(s)` (double, escaping `\` and `"`), `needs_quote(s)` (leading `[ { " ' & * ! | > % @ \``, or contains `: ` / ` #`).
  - **Relationships:** used by session_sync (header) and review_send (instruction line, insertion point).
  - **DRY rationale:** session_sync's private `k: v` scan rejected hyphens; a second reader would have copied it.
- **Instruction** — `parse(value)` → `{ names, text }`; `resolve(names, modes)` → Modes or nil, err; `expand(value, modes)` → `{ modes, text }` or nil, err (free-form default); `brief(modes, text)` → prompt text (each `## Review mode: name` + body, `mode.directives(modes[1])`, `## Operator instruction`); `complete(modes)` → names.
  - **DRY rationale:** the couch message and the in-editor review's system prompt render the same brief; `source()` now calls `brief`.
- **SendMessage** — `message({ path, instruction, brief, diff, first })` → text. Pure; tests pin it.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `send`, `query`, `list`, `find_actor`, `own_slot` (couch seam) | `lua/parley/couch.lua` | new (extracted) | `couch` binary via `vim.system` |
| `submit`, `attach`, `on_text_changed`, `on_complete_done` (review send) | `lua/parley/review_send.lua` | new | buffer, `vim.ui.input`, `vim.fn.complete`, couch seam, review skill |
| `submit` (session-sync owner check) | `lua/parley/session_sync.lua` | modified | the couch seam |
| `registry_callbacks` (markdown `<M-CR>` wiring) | `lua/parley/skills/review/init.lua` | modified | keymap registry |

- **couch seam** — `send(to, message, on_exit)`, `query(argv, cb)` moved verbatim from session_sync; `own_actor(actors, env)` pure match on scope+tag; `find_actor` moved (session_sync re-exports it for its existing spec). `own_slot(cb)` = env check + actors query. Injected: tests point `PATH` at the fake couch and set/clear `vim.env.COUCH_THREAD_*`.
- **Fake:** the existing fake couch script (log of `<to>|<message>`, `FAKE_COUCH_ACTORS`) — extend the actors JSON with `Binding.Scope/Tag`.

## Tasks

### Task 1: Frontmatter reader
**Files:** create `lua/parley/frontmatter.lua`, `tests/unit/frontmatter_spec.lua`; modify `lua/parley/session_sync.lua` (`parse_header` uses it).
- [ ] Failing specs: hyphenated keys; `raw` keeps `[copy-edit] keep # the voice` whole; `fields` strips ` # c`; quoted value unquoted; `quote`/`unquote` round-trip over strings drawn from `"`, `\`, `[`, `#`, `: ` (lesson: escapes injective over their own delimiters); `needs_quote("[x] y")` true, `"keep"` false; no fence → nil; unterminated → nil.
- [ ] Implement; session_sync `parse_header` returns `{owner, operator}` from `fields` when `type == session-sync`. Run `tests/unit/session_sync_spec.lua` + new spec green.

### Task 2: Instruction grammar + expansion
**Files:** create `lua/parley/skills/review/instruction.lua`, `tests/unit/review_instruction_spec.lua`; modify `skills/review/init.lua` `source` + `run_via_invoke` (`args.modes`).
- [ ] Specs: `[copy-edit] keep the voice` → copy-editing + text "keep the voice", brief contains the copy-editing body and its directives (whole-doc scope, propose-strike); `[copy-edit][fact-check] x` both bodies, directives of copy-editing only; no bracket → free-form; `[nope]` → err listing names; ambiguous prefix → err; `complete` lists names in mode order. Modes come from `mode.list(modes_dir)` (the real files).
- [ ] `source(ctx)`: names = `args.modes` or `{args.mode}`; load each, `instruction.brief`. `run_via_invoke`: `has_mode` true when `args.modes` non-empty; journal `mode = table.concat(names, "+")`. Existing review specs stay green.

### Task 3: Couch seam extraction
**Files:** create `lua/parley/couch.lua`, `tests/unit/couch_spec.lua`; modify `session_sync.lua` to use it.
- [ ] Spec `own_actor` (scope+tag match, nil on missing env/mismatch). Move `send`/`query`/`find_actor`; `session_sync.find_actor = couch.find_actor`. Session-sync integration spec green (clear `COUCH_THREAD_*` in its `before_each`, since the suite runs inside pair).

### Task 4: Alt+Return dispatch (`review_send`)
**Files:** create `lua/parley/review_send.lua`, `tests/integration/review_send_spec.lua`; modify `init.lua` (`review_next = review_send.callback(buf)`, `review_send.attach(buf)`), `skills/review/init.lua` (drop `review_next`), `keybinding_registry.lua` / `config.lua` comments + descriptions; delete `review_menu.lua`, `tests/integration/review_menu_spec.lua`; drop `session_sync.dispatch`.
- [ ] Specs (fake couch, env set to the fake actor's scope/tag):
  1. `process-instruction: "[copy-edit] keep the voice"`, no `type` → one send to `ariadne:2`; message names the abs path, the raw instruction, the copy-editing brief, and "first send"; the buffer was saved first.
  2. edit + second Alt+Return → message carries a unified diff with the edited line; a failed send (`FAKE_COUCH_EXIT=1`) keeps the old baseline.
  3. env cleared → no couch call; `run_via_invoke` (stubbed on the module) gets `{ modes = {"copy-editing"}, instruction = "keep the voice" }`.
  4. no `process-instruction` → stubbed `vim.ui.input` answer `[fact-check] dates` is written quoted into the frontmatter (frontmatter created when absent) and sent; cancel → nothing.
  5. `[nope] x` → error, nothing sent.
  6. session-sync with `owner:` naming another slot → warn, no send, lock kept; owner = this slot → submits; env cleared → legacy send to `owner:` (`owner:` still works).
  7. env set but actors empty → error, no send, no review.
  8. completion: cursor after `process-instruction: [` in insert mode, trigger → `complete_info().items` words are `<name>]` for every mode file; after CompleteDone the line is double-quoted with the cursor after the inserted name.
- [ ] Implement; run all four new specs + session_sync + keybindings specs.

### Task 5: Docs, atlas, full suite
- [ ] Update `atlas/modes/review.md` (process-instruction, slot send, menu gone), `atlas/modes/session_sync.md` (owner check), `atlas/ui/keybindings.md`, help/README mentions of the review menu (`grep -rn "review menu\|review_menu"`), `atlas/traceability.yaml` spec mapping.
- [ ] `make test` and `make lint` green; manual e2e in a pair slot: Alt+Return on a scratch markdown delivers to this slot's agent.

## Revisions

### 2026-10-11 — Core-concepts tables name the real symbols

The arch sweep (`tests/arch/single_source_sweeps_spec.lua`) requires every exported function the branch adds to appear in a table row, and every backticked row name to be defined. The rows named concepts (`Frontmatter`, `Instruction`, `SendMessage`); they now list the symbols, with the concept in parentheses. No design change.
