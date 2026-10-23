# Document Review

Headless LLM-powered review workflow for markdown files. Users annotate
documents with `🤖[comment]` markers, then an agent rewrites the document
to address the comments — or run a **mode** (see Review Modes below) for a
whole-document pass that needs no markers at all.

**Run flow.** A *mode* run always proceeds, even with zero markers
(the no-marker general review). A legacy no-mode run still needs ≥1 ready `[]`
marker. Pending `{}` markers no longer **block** submission — ready markers are
processed, `{}` ones skipped, and pending markers surface via the **on-save**
quickfix (`BufWritePost`), not at submission. The resubmit loop re-runs only
while a *ready* marker remains and the ready count shrank, so a whole-doc mode
round is effectively one-shot (inserting `{}` findings is not "stuck"). Applied
edits are oriented by span highlights (#386: the edited text only, never the whole line; #387: `ParleyEditChange`, or `ParleyEditAdd` for an edit whose old text is empty, by `presentation.kind`) + INFO gutter diagnostics that
**ride** subsequent edits until the next round or an explicit dismiss; a pure
deletion leaves no trace — no highlight and no diagnostic (#387).

The same marker family is also used inside chat buffers for
[drill-in discussions](../chat/drill_in.md) (different keybindings + a chat-
side gather/strip on respond). The section parser is shared.

## Marker Syntax

Single marker `🤖`. Three section types:

- `<>` = quoted body (optional, at most one, must be the first slot)
- `[]` = human turns
- `{}` = agent turns

After an optional `<>`, `[]` and `{}` may appear in any order.

```
🤖[human comment]{agent question}[human reply]...
🤖{agent finding}[human response]{agent follow-up}...
🤖<the exact phrase>[fix this]
🤖<paragraph snippet>{suggested rewrite}
```

- Ready for agent = last section is `[]` (human spoke last)
- Pending (quickfix) = last section is non-empty `{}` (agent asked, needs human reply)
- Markers inside fenced code blocks are ignored
- `<text>` disambiguates "which text the marker refers to" — use it whenever the surrounding-text rule would be ambiguous (added in #123)
- (Legacy, #125 — superseded for writers by single-line markers, #312) `<>`/`[]`/`{}` sections may span **multiple lines**, each bounded to ~50 lines (per-section budget) so a stray opener can't swallow the document; `~D~` strike stays single-line (added in #125). `parse_markers` parses over the whole buffer joined (offset→line/col map) rather than line-by-line; `find_matching_bracket` takes an optional `{budget, is_excluded}` so the shared `_parse_marker_sections` (highlighter, drill_in) keeps its single-text behavior. Unterminated openers fall back to silent non-recognition.

## Marker rendering (#312, #386)

Markers render in full in every parley markdown and chat buffer (#386; #312's
compact view hid each turn behind `…`, which left near-empty lines because
Neovim can't shrink a line whose text it hides). The file's bytes never change,
only the colors. Markers are **single-line** in everything parley writes (a
newline inside a turn is `<br>`, see `comment/codec.lua`); the parser still
tolerates #125 multi-line markers so old documents keep resolving.

| Raw | Colored |
|---|---|
| `🤖[H]{R}` | each turn by speaker (`ParleyReviewUser` / `ParleyReviewAgent`) |
| `🤖<X>[H]` | `X` with `ParleyReviewQuoted` |
| `🤖~D~{N}` | `D` struck (`ParleyReviewStrike`) |
| doesn't close on its line | `ParleyReviewBroken` |

- **Geometry**: `lua/parley/comment/view.lua` (pure) — `layout(line)` gives each
  marker's extent, anchor and turns; the highlighter's decoration provider turns
  it into ephemeral extmarks (viewport-bounded, fenced code skipped), and the
  `<CR>` lookup reads the same layout. Each turn bracket is re-asserted as itself,
  so treesitter's shortcut-link conceal (`[text]`) never eats it where
  conceallevel is above 0.
- **conceallevel**: `lua/parley/comment/init.lua` `attach(buf, kind)` sets it per
  buffer kind. A markdown buffer gets 0, so it shows literally, links included,
  overriding a global 2 such as LazyVim's. A chat buffer gets 2, for parley's own
  inline branch links and model-header params. Treesitter is stopped in chats
  unless `chat_treesitter = true` (#294), so markdown links there show in full
  by default. With it on they conceal under the chat's 2. Nothing moves the
  cursor: with nothing hidden, #312's cursor snap and `concealcursor` forcing are
  gone.

- **Thread float**: `lua/parley/comment/float.lua` opens the chain like a
  parley chat (`comment/thread.lua`, pure): `💬: ` human turns, `🤖: ` robot
  turns, unprefixed lines continue the turn above (a `<br>`), on
  `ParleyCommentUser` / `ParleyCommentAgent` backgrounds; it opens in insert mode
  on the trailing `💬: ` reply slot. Title `🤖 comment` / `🤖 on "X"`, footer
  with the controls. Text that would unbalance the marker's brackets is refused
  on save. Plain nvim semantics: `:w` writes the thread back as one line over
  the marker's original bytes (refused, text kept in `"`, if the marker changed
  underneath or a turn's brackets don't balance), `:x` / `q` write and close, `:q!`
  discards. An empty trailing reply is dropped.
- **Single-line writers**: `<M-q>` refuses a selection spanning lines (an anchor
  quotes one line). Turn text encodes a line break as `<br>` and a literal `<br>`
  as `\<br>` (`comment/codec.lua`; a backslash run before `<br>` doubles, so
  odd = literal, even = newline). In the float, a continuation line that would
  read as a `💬: ` / `🤖: ` prefix carries one extra leading `\`. Resolution (`drill_in.resolve`) and chat
  gathering decode **turn text only** — an anchor's X / D is the document's own
  prose, kept verbatim. Canonical grammar: ariadne#316 (review-convention §3, §5).

## Keybindings (non-chat markdown only)

| Binding         | Action                                                          |
|-----------------|-----------------------------------------------------------------|
| `<M-q>` / `<C-g>q` | Insert `🤖<sel>[]` (visual) or `🤖[]` (normal/insert). Shared with chat — see [drill-in](../chat/drill_in.md). |
| `<M-a>`         | Accept the marker at cursor (rules below) |
| `<M-r>`         | Reject the marker at cursor (rules below)            |
| `<CR>`          | On a marker: open its thread float (#312). Elsewhere: native `<CR>` (count kept). Chat buffers too. |
| `<C-g>ve`       | Run the review skill (agent edits per ready markers, legacy no-mode) |
| `<C-g>vf`       | Open the review finder (jump to files with pending markers)     |
| `<M-s>`         | Open the **skill picker** (review is one of the skills) |
| `<M-CR>`        | Submit the document in a Couch pane; run the existing instruction-based review outside Couch (below). |

## Accepting and rejecting markers

A quoted `🤖<text>` anchor keeps its text on either action. A bare
`🤖{proposal}` inserts its text when accepted and disappears when rejected.
For `🤖~old~{new}` (or a single human replacement section), acceptance keeps
`new`, rejection keeps `old`; a bare strike accepts deletion. A strike with a
longer dialogue also accepts deletion because no single replacement is selected.
Unanchored commentary disappears on either action. These rules are implemented
by `drill_in.resolve` and tested with the shared marker parser.

## Alt+Return: process-instruction and the slot send (#316)

Inside a Couch pane, Alt+Return in a named Markdown document follows
[agentic document submission](session_sync.md) (#332): save, register on first
submission, attach the existing turn engine and send `submitted: <absolute
path>`. It adds no frontmatter and does not prompt for a process instruction.
Ariadne's `xx-universal-review` skill reads `process-instruction:` from the
submitted file and computes changes since its last read through Couch. Parley
sends no instruction prose or editor diff, and keeps no review-send baseline.
The pane's agent is the default owner; explicit `couch-owner:` overrides it,
while a business `owner:` field does not. Confirmed membership survives header
edits. Unknown offline membership stays editable with `Couch unavailable:
agentic state unknown`; known attached/cached identities keep turn protection.

Outside a Couch pane, the existing review behavior remains: the standing
instruction lives in the document's frontmatter, one line the operator edits
per round. The review-mode menu float (#133 M4) is gone.

```yaml
process-instruction: "[copy-edit] keep the voice"
```

- **Grammar** (`skills/review/instruction.lua`, PURE): each leading `[name]`
  names a stock prompt — a `modes/<name>.md` file, or a unique prefix of one
  (`[copy-edit]` → `copy-editing`); the rest is free text added to it. No
  `[name]` means `free-form`. Several names contribute their briefs; the first
  one's knobs (`scope`, `deletions`, `frontier`) give the round's directives.
  The local source passes neutral mode data to the canonical round's flag
  table (`source(ctx)` takes `args.modes`).
- **Quoting:** `[copy-edit] keep` is not valid YAML (sdlc's yaml.v3 rejects it in
  issue frontmatter), so parley writes the value double-quoted when it needs it
  (`frontmatter.needs_quote`) and reads either form. Typing `[` in the value
  completes the mode names (from the modes directory); accepting one quotes the
  line.
- **Where it goes** (`lua/parley/review_send.lua`): without a Couch thread,
  the instruction runs `run_via_invoke` here. Typed legacy session-sync files
  keep their dedicated submit path.
- **No line yet:** outside Couch, Alt+Return asks once and writes the answer
  into the frontmatter (creating one), then runs the review.

The sidecar (`*.parley-journal.md`) is excluded from review attachment
(`is_journal_sidecar`). `<M-CR>` is free here — chat-respond's `<M-CR>` is
chat-buffer-only.

## Architecture

Review is implemented as a **skill** in the unified skill system (see the [skill system](../skills/skill-system.md)).

- **Skill module**: `lua/parley/skills/review/init.lua` — marker parsing, `run_via_invoke` (marker pre-check + resubmit), keybindings
- **System prompt**: `lua/parley/skills/review/SKILL.md`
- **Driver**: `lua/parley/skill_invoke.lua` — one tool-use exchange on the existing dispatcher, shared with other skills
- **Rendering**: `lua/parley/skill_render.lua` — diagnostics + edit highlights
- **No shim**: callers require `parley.skills.review` directly (the `parley.review` re-export shim was removed in #236)
- **Headless**: Direct API call, no chat buffer, no exchange model
- **Stateless**: Each submit sends full document; markers carry conversation history
- **Tool**: `propose_edits` tool with `{old_string, new_string, explain}` triples (forced via `tool_choice`)
- **Edits**: Applied to file on disk via the `propose_edits` builtin, buffer reloaded via `:edit!`
- **Feedback**: Highlights on edited spans (`ParleyEditAdd` / `ParleyEditChange`), diagnostics from explain fields (INFO), quickfix for pending agent questions
- **Provider**: Requires a client tool wire: Anthropic or an OpenAI-compatible provider, including CLIProxyAPI routes. Direct Google AI has no wire. Agent choice follows the [skill agent cascade](../skills/skill-system.md).

## Review Modes

Review runs in a selectable **mode** (a stage of document construction). A mode is
a sub-markdown file `lua/parley/skills/review/modes/<name>.md` = YAML frontmatter
(behavior flags) + a prompt body. One skill owns all modes; there is no parallel
engine. The review skill's `source(ctx)` composes the canonical round and
grammar and optional collaboration modes in `SKILL.md`, selected mode bodies/flag values and operator instruction,
then `local-adapter.md`. The adapter requires `propose_edits` for all responses.
With no mode selected, explicit parser defaults retain marker-only review.
A local invocation uses its supplied full snapshot; it introduces no editor
change baseline.

- **`lua/parley/skills/review/mode.lua`** — `parse(content)` (PURE: frontmatter →
  `{name,scope,deletions,frontier,order,body}`) and the thin IO seam `load(dir,name)`/`list(dir)` (sorted by
  `order` then name). Canonical name == file basename (kebab), so `load` resolves
  by the selected name; the menu prettifies for display.
- **Behavior flags:** `scope` (`whole-doc` | `markers-only`), `deletions`
  (`apply-with-gutter-why` | `propose-strike` | `apply`), `frontier` (`on` | `off`
  — when on, treat text above the topmost `🤖[]` as settled). `deletions` is
  optional with no default (#383): export v3 (ariadne#437) retires it, and the
  document's own `presentation:` is then the one proposal knob, copied into no
  flag. A v2 mode file carries it. Plus `order:` — the
  editorial-sequence position that orders the menu (developmental=1 … free-form=6).
- **Six shipped modes:** developmental, line-editing, copy-editing, proofreading,
  fact-check (inserts `🤖{}` findings only — no edits; resolution handed to the
  main agent), free-form (operator instruction governs).
- **`ctx.skill_dir` injection** (`skill_providers.lua`): the disk provider injects
  the skill's own absolute dir into `source(ctx)` (alongside `ctx.skill_md`) so the
  review skill reads its `modes/` subdir without re-deriving the path.

### Canonical prompt snapshot

Ariadne's `construct/local/universal-review/` owns the round, marker grammar
and stock modes. `scripts/sync-review-protocol.py --source DIR --output
lua/parley/skills/review` validates the versioned export and every resolved
member's byte count and SHA256 before updating the fixed package snapshot.
Add `--check` for a read-only freshness check. The plugin runs from its packaged
files, with no sibling Ariadne checkout or runtime peer lookup required.
`export.json` records the source manifest; generated `SKILL.md` combines the
round, grammar and the optional `collaboration-modes.md` member in that order.
That role is a singleton in version 1; older exports without it remain valid
and the sync CLI prints a notice that the resulting prompt lacks collaboration
modes. The shipped snapshot includes it; package tests require its presence.
Version 2 also exports the canonical move fixtures as `fixture` members under
`examples/<case>/`; the sync snapshots and hashes those trees but excludes them
from prompt composition and mode discovery. Version 1 remains accepted with a
notice that move fixtures are absent. Version 3 drops `deletions` from every
mode record and mode file; a v3 record still carrying it is refused, and v1/v2
records still require it. With no mode selected, the brief's default
`deletions: propose-strike` line follows the snapshot's version: v2 keeps it,
v3 writes none. The shipped snapshot requires both move
cases, and the mover's projection checks load their before/after bytes through
the manifest. Recursive generated-output preflight rejects symlinks and special
files; stale files are reported for explicit removal. `local-adapter.md` stays Parley-owned and is appended last.
The Couch file-edit adapter is excluded from local composition. The mapped
bundle fixture tests exercise deterministic output and validation failures.

### Local collaboration compatibility

`review/collaboration_value.lua` decodes the collaboration-mode field's scalar,
block/flow map and heading-list forms without a runtime YAML dependency.
Unsupported YAML constructs and malformed values refuse visibly.
Root frontmatter must be a closed block mapping; uniformly indented and
quoted/escaped keys are decoded. Root flow maps, sequences, complex keys,
tags/anchors/aliases and merge keys refuse instead of becoming absent routing.
Unrelated nested metadata and literal blocks do not define root routing. The pure
parser splits a root key from its value before scanning comments: a quote opens
a quoted root scalar only at the value's first character. Literal quotes after
punctuation in unrelated plain text cannot hide a legacy chat declaration (#418).
The existing flow-map/list grammar keeps its own quote context. The pure
`review/collaboration.lua` resolver handles normalized heading names, repeated
headings, ATX levels 1–6, fenced code, nearest named ancestors and dangling-name
warnings. Unknown modes and cross-mode heading conflicts refuse before local
generation; review_send also checks them before prompting for an instruction.

`review.run_via_invoke` uses that plan for admission and resubmission, excluding
chat markers. Discussion/default and collaboration answer in place; chat
sections are skipped. Deterministic vim.notify notices report in-place routing
and that the hub agent answers chat, including all-chat/no-marker rounds. A
whole-document review mode can still review eligible non-chat text without
markers. The invocation-owned validate_edits hook rejects a proposed edit that
touches chat bytes, their boundary newlines or frontmatter before tool execution.
Other skills preserve their existing behavior when no validator is supplied.

The local adapter overrides shared discussion routing explicitly. Side-doc and
chat answer creation, cross-file folds/actions and previous-read baselines
remain with the agent-side skill; local review creates none of those resources.

## Journal

Each review round is recorded to a Markdown sidecar beside the document,
`<doc>.parley-journal.md`. It records attributed diffs and rationale without
changing branches. The sidecar can be version-controlled with the document;
Parley does not commit it automatically. Native undo handles interactive text
changes, while the journal preserves a durable record across sessions.

- **`lua/parley/skills/review/journal.lua`** — PURE `serialize_entry` /
  `serialize_base` / `parse` / `diff` (`vim.diff`, unified) / `is_drift`
  (`vim.fn.sha256` compare), plus the thin IO seam `sidecar_path` / `read` /
  `append`. 4-backtick fences wrap the journal's own blocks so a 3-backtick code
  fence inside the doc or diff can't break parsing.
- **Per round** it stores: round number (derived), mode, side, ISO timestamp,
  content hash, rationale (the per-edit `explain`s), and the unified diff. Round 0
  is the base snapshot (written once, on the first round).
- **Wiring**: `skill_invoke`'s `on_done` payload carries `original` /
  `new_content` / `decorations` (pure-fed); review's `on_done` builds the entry
  and calls `journal.append` (skips no-op rounds + path-less buffers).
- **Drift**: `is_drift(recorded_hash, current)` detects an external edit (e.g.
  Claude Code resolving markers) since the last recorded round.
- **Not implemented**: durable "revert/show round N" (reconstruct via base +
  replayed diffs). The journal stores the **diff + rationale** per round, not a structured
  decoration set.

## Decoration projection — undo/redo coherence

nvim's undo reverts **text only**; review decorations are drawn once per round
and otherwise ride, so without help they go stale after an undo (esp. across the
round's `:edit!` reload). `lua/parley/skills/review/projection.lua` keeps style
coherent: a per-buffer record `{ content-hash → decoration snapshot }`, and on
each text change it **projects** the right style onto the current state —

- **undo/redo** lands on a recorded content-hash → re-render that snapshot (via
  `skill_render.snapshot`/`apply_snapshot`);
- a **novel forward edit** (manual tweak / `<M-a>` accept — behavior B) keeps the
  live decorations riding, and snapshots them under the new state so a later undo
  restores them.

A round records its **pre** state (base → empty style, so undoing across the
round clears it) and its **post** state (its decorations); records persist across
rounds for multi-round undo. `set_applying` suppresses the watcher during the
round's own reload; the watcher is attached lazily (only after the first round).
The decide rule (`projection.decide`) is pure. Session-scoped (matches nvim's
session-scoped undo); per-state snapshots aren't journaled.

## Diagnostic display

The edit "why" (the per-edit `explain`) is an INFO diagnostic on parley's
`parley_skill` namespace. `lua/parley/skills/review/diag_display.lua` controls how
it shows — scoped to that namespace, so the user's LSP/global diagnostics are
untouched. Default **on**: Parley's custom `parley/virtual_lines` diagnostic
handler renders a text-column virtual-line block headed `Diagnostics:` for the
current line. It avoids both gutter anchoring and Neovim's stock virtual-lines
indentation-by-diagnostic column, which can hide messages on long wrapped prose. The hard-wrapped why
(`skill_render.format_diagnostic_message`) **auto-expands below an edit when the
cursor is in that edit's region** (`attach_diagnostics` spans
`lnum..end_lnum`) and hides otherwise. `:ParleyShowDiagnostics` toggles it. The
built-in `]d`/`[d` (jump) and `<C-W>d` (float, wraps) still work on these
diagnostics because the underlying diagnostic spans remain unchanged. Composes
with decoration projection — re-renders on undo/redo. Virtual lines anchor at
column zero, including empty/short lines; cached diagnostics whose start row is
outside the current buffer are skipped after rewrites. Publication, cursor/resize
refresh and deferred rewrap share one failure boundary: a failed refresh clears
its display, logs one warning per module lifetime, and retries on the next
refresh. It does not change the underlying diagnostics or document text.

The same controller also renders managed footnote diagnostics; those use a
centered non-focusable float instead of virtual lines, and show only while the
cursor is inside the term/`[^footnote]` diagnostic span.

## Progress bar

A review round runs without a chat buffer and shows a **detached progress
bar** — `lua/parley/progress.lua`, a floating bar pinned just above the
statusline with an animated spinner + message + elapsed seconds. It's a **general
reusable mechanism** (`progress.start/update/stop/is_active`, one active at a
time; pure `frame`/`format` + thin float/timer IO), not review-specific — review
is just its first user. `skill_invoke` starts it when the LLM query launches and
stops it on exit/abort/cancel (guarded by the same generation counter as the
in-flight cancel). Concurrency: triggering a review while one runs gives the
kill-or-cancel prompt (no two concurrent rounds).

## Config

```lua
review_agent = nil,             -- legacy optional pin; prefer skills config
review_highlight_duration = 2000, -- highlight fade time in ms
review_shortcut_edit   = { modes = { "n" }, shortcut = "<C-g>ve" },
review_shortcut_finder = { modes = { "n", "i" }, shortcut = "<C-g>vf" },
review_shortcut_menu   = { modes = { "n" }, shortcut = "<M-s>" },   -- skill picker
review_shortcut_next   = { modes = { "n", "i" }, shortcut = "<M-CR>" }, -- submit in Couch; review elsewhere
-- Marker insertion: see drill_in_callbacks in lua/parley/init.lua
-- (shared <M-q> / <C-g>q binding)
```

## Key Files

- `lua/parley/skills/review/init.lua` — skill definition (+ `source(ctx)` mode composition, `mode` arg), marker parsing, `run_via_invoke` (marker pre-check + resubmit), keybindings
- `lua/parley/skills/review/mode.lua` — Mode parse (PURE) + load/list IO seam
- `lua/parley/skills/review/modes/*.md` — the six review-mode prompt files
- `lua/parley/skills/review/journal.lua` — per-round journal: PURE serialize/parse/diff/drift + sidecar IO seam
- `lua/parley/review_send.lua` — `<M-CR>` dispatch to agentic submission in Couch; existing in-editor fallback, add-instruction prompt and `[` completion outside Couch
- `lua/parley/agentic_document.lua` — named-document registration/admission and native rename hooks; see [session-sync](session_sync.md)
- `lua/parley/skills/review/instruction.lua` — `process-instruction` grammar, mode expansion and neutral context (PURE)
- `lua/parley/frontmatter.lua` — shared frontmatter reader (hyphenated keys, raw values, quoting; PURE)
- `lua/parley/couch.lua` — the `couch` seam: send, query, this editor's own actor. Every child gets a deadline: a caller that names none gets `couch.deadline_ms()` (the user's `agentic_submit_timeout_ms`, through `document_registry.config_ms`); a send gets `couch.send_deadline_ms()`, three of them (`document_registry.lost_ms`, #359), so a press past the submit deadline can still join it. Expiry kills the child and reports `couch.timed_out`; a killed send logs one line and says it may have arrived (#400). Only `document_registry`, which runs its own deadline timer, opts out with `timeout = false`
- `lua/parley/skills/review/projection.lua` — decoration projection: re-render style on undo/redo per content-state
- `lua/parley/skills/review/diag_display.lua` — inline "why" display toggle (`:ParleyShowDiagnostics`, cursor-region auto-show)
- `lua/parley/progress.lua` — detached progress bar (general reusable long-op feedback; review is the first user)
- `lua/parley/skills/review/SKILL.md` — system prompt (light edit + heavy revision sections)
- `lua/parley/skill_invoke.lua` — the P2 driver (one tool-use exchange via the existing dispatcher)
- `lua/parley/skill_render.lua` — diagnostics + edit highlights
- `lua/parley/tools/builtin/propose_edits.lua` — batch edit-apply (inline `.parley-backup`)
- `lua/parley/highlighter.lua` — `ParleyReviewUser`/`ParleyReviewAgent` groups
- `lua/parley/config.lua` — default keybindings and config
- `tests/unit/review_spec.lua` — unit tests for the marker parser
- `tests/integration/skill_invoke_review_spec.lua` — review's marker pre-check + resubmit
- `tests/unit/skill_edits_spec.lua` / `tests/unit/tools_builtin_propose_edits_spec.lua` — batch edit-apply
