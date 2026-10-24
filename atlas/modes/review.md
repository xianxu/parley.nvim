# Document Review

Documents use one collaborative policy (#419). Direct operator edits are
content; a ready `🤖[...]` marker is a question or a command. In Couch, the
agent answers questions in linked side documents and applies commands in their
stated scope. A standalone `@@chat@@` above a heading gives that section chat
items whose answers also live in side documents.

Parley's local review applies command asks in the current file and leaves
question markers unchanged, reporting
`questions are answered in a side doc by Couch review; left unchanged`.
It creates no side documents or multi-file writes. Ready markers inside chat
remain ordinary asks; the surrounding operator-owned chat items stay intact.
Pure chat items and documents without ready asks launch no provider work.

A local run requires at least one ready marker, even when an old caller supplies
mode or standing-instruction arguments. Pending agent turns do not block other
ready work. After command progress, the owner may resubmit only while the ready
count shrinks, at most three times; a deferred question ends that loop. A
question-only no-op writes no journal or decoration projection. New local edits
use span highlights and INFO explanations; deletions leave no painted span.

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
| `<C-g>ve`       | Run local review for ready robot asks |
| `<C-g>vf`       | Open the review finder (jump to files with pending markers)     |
| `<M-s>`         | Open the **skill picker** (review is one of the skills) |
| `<M-CR>`        | Submit the document in a Couch pane; request a mode-free local review outside Couch (below). |

## Accepting and rejecting markers

A quoted `🤖<text>` anchor keeps its text on either action. A bare
`🤖{proposal}` inserts its text when accepted and disappears when rejected.
For `🤖~old~{new}` (or a single human replacement section), acceptance keeps
`new`, rejection keeps `old`; a bare strike accepts deletion. A strike with a
longer dialogue also accepts deletion because no single replacement is selected.
Unanchored commentary disappears on either action. These rules are implemented
by `drill_in.resolve` and tested with the shared marker parser.

## Alt+Return: pane submission and local review (#322)

Inside a Couch pane, Alt+Return in a named Markdown document follows
[agentic document submission](session_sync.md) (#332): save, register on first
submission, attach the existing turn engine and send `submitted: <absolute
path>`. It adds no frontmatter and does not prompt for a process instruction.
The agent-side review skill reads the submitted document and the changes since
its last read. Parley sends no instruction prose or editor diff and keeps no
review-send baseline. The pane's agent is the default owner; explicit
`couch-owner:` overrides it, while a business `owner:` field does not.
Confirmed membership survives header edits. Unknown offline membership stays
editable with `Couch unavailable: agentic state unknown`; known attached/cached
identities keep turn protection.

Outside Couch, the same binding requests the local owner without a prompt or a
standing instruction. The manifest has no selectable mode arguments.
`process-instruction:`, other retired keys and their existing bytes stay in the
file; they select no work. The old instruction completion/requoting hooks and
mode popup are removed. Frontmatter `status:` completion still belongs to the
issue vocabulary.

An unnamed buffer reports save-first. Pure chat items are left unchanged with
`chat items are answered in a side doc by Couch review; left unchanged`.
Pending-only documents ask for the operator's reply; no-ask documents report
`read your edits; no asks`. Legacy metadata produces compatibility notices,
not a mode gate. Typed legacy session-sync files keep their dedicated submit
path. Dispatch, registration, save and failure handling stay with the existing
[session-sync owners](session_sync.md).

`review_notice.show` stores each exact notice in Neovim's message history and
shows one short caption pointing to `:messages`. The caption uses the shared
editor display units, at most 48 cells and the available width minus 16;
whitespace is normalized only in that caption. Captured `unsilent echomsg`
receives a JSON-encoded string as data, so newlines, quotes and pipes remain
literal. No separate message store, watcher or queue is introduced. Native
Normal/Insert tests retain the builtin notifier and prove subsequent typing
continues without hit-enter.

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

## One policy and named editing briefs (#419)

`review.skill.source` composes the packaged canonical round, marker grammar and
collaboration policy, the five named editing briefs, then Parley's
`local-adapter.md` and exact ready-marker identities. `brief.lua` reads only
version-4 manifest members in manifest order. A brief is task context with a
matching `name:` and body; it carries no behavior flags. The operator's ask
selects the work and its scope. There is no standing instruction, inferred mode,
frontier flag or markerless whole-document review.

The shipped briefs are developmental, line-editing, copy-editing, proofreading
and fact-check. The local provider receives one captured source snapshot; the
invocation owner validates question/command classifications against that
snapshot's exact ready-marker identities before any tool writes. Question-only
results are no-ops. In mixed results, commands can apply while the original
question markers remain. Other skills keep their existing driver behavior.
Local review admits at most 1 MiB before reading/parsing the snapshot; larger
local requests refuse visibly and leave Couch submission available.

### Canonical package

The shipped source is pinned to ariadne#581, Git
`5a17f789619d3dcaafec62ae51b350833836a3e7`, whose
[collaboration contract](https://github.com/xianxu/ariadne/blob/5a17f789619d3dcaafec62ae51b350833836a3e7/construct/local/universal-review/collaboration-modes.md)
owns the agent-side outcomes. `scripts/sync-review-protocol.py --source DIR
--output lua/parley/skills/review` validates export version 4, roles, safe member
paths, byte counts and SHA256 before updating the finite package. `--check`
checks freshness without writing. Versions 1–3 are refused by this synchronizer;
flagless briefs cannot be interpreted as the earlier mode format.

`export.json` identifies the canonical round, review convention, collaboration
policy, named briefs and example fixtures. Generated `SKILL.md` composes the
policy members; fixtures are validation data and never prompt prose. The v4 pin includes the
closed unreadable-header and malformed answer-link cases: header declarations
have no effect, body asks remain eligible, and an answer destination must be
nonempty with no whitespace or parentheses. The package
runs without a sibling checkout or runtime peer lookup. Parley's Lua adapter and
`local-adapter.md` remain locally owned; stale generated mode members are removed
explicitly. `tests/integration/review_protocol_bundle_spec.lua` is the executable
Lua wrapper for the Python export/CLI tests, including packaged cold-copy checks.

### Chat metadata and ownership

A line containing only `@@chat@@` (surrounding whitespace allowed) immediately
above an ATX heading outside code starts a chat section. Its items follow the
pinned contract: numbered items for tag-declared chat, with supported legacy
bullet forms retained where legacy metadata declares chat. A robot marker
inside chat is still a normal ask. `chat_structure.snapshot` owns Markdown
structure; pure `chat_policy` owns tag association, sections, item extents and
notices. `collaboration` combines them with exact marker positions and protects
frontmatter, chat metadata and operator-owned item text during local proposals.

Valid chat metadata survives context preparation and is not a file reference or
an extra outline row. Section operations carry a supported heading's tag with
it, including native undo. Rendering leaves standalone `@@chat@@` visible as
ordinary source: no badge, conceal, section/body tint or semantic parse on the
redraw path. A misplaced tag stays ordinary text and is reported when reviewed.

### Historical document compatibility

Before #419, selectable runtime modes could run without markers, consumed
`process-instruction:`, and used `scope`, `frontier`, `deletions` and `order`
flags. Those authoring paths are retired, not migration instructions for old
files. Current code writes no replacement mode key.

Readable legacy `collaboration-mode: chat`, supported chat section maps and
heading comments still identify chat sections with a notice. Other retired
collaboration values, presentation/instruction keys and unsupported closed
frontmatter produce notices and do not select a mode. A leading fence without a
closing fence is ordinary Markdown rather than a frontmatter block. Unknown
legacy bytes are retained. `collaboration_value.evidence` is the bounded
compatibility reader; it does not add a general YAML dependency. Ignored scalar
and list values in a supported map cannot erase recognized chat/default
evidence. If an explicit legacy collaboration map is unreadable, local source
mutation refuses visibly with use-Couch recovery; it never guesses partial
protection. This exception applies to the local adapter. A closed unreadable
header without such a declaration keeps its notice and ordinary body commands.
Unsupported YAML aliases/tags are not interpreted as map declarations.

Older journals retain their recorded mode fields. Older Couch rounds retain
stored round/span presentation, described in
[session-sync history](session_sync.md#historical-round-presentation-419).
Those fields describe historical output; current document presentation keys do
not change it. The landed Pair#823 fixture at Git
`aba41239d6473e2da5d3f0ce00e82129a47a2ba3` is historical codec compatibility data,
not the authoring policy for new review work.

### Side documents

Couch review owns side/answer documents, follow-ups, decisions, folds and index
writes. New links use `<name>.side/YYYY-MM/YYYY-MM-DD-NN-slug.md`; a discussion
opened from a side document stays under the same owning `.side` root and names
its actual immediate parent in `parent:`. Parley follows those paths and
[confirms inherited ownership](session_sync.md#side-documents-and-owner-inheritance-378-419)
through the existing Couch model. It adds no allocator or second writer.

Flat side documents and historical nested side folders remain readable. Older
`qa/` links continue to open without inventing Couch ownership from the filename.
The shared `side_document_path` relation and the
[attention scan](../ui/attention_finder.md#side-docs) understand flat and one-month
layouts while keeping actual parenthood separate from the owning root.

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
- **Per round** it stores: round number (derived), side, ISO timestamp,
  content hash, rationale (the per-edit `explain`s), and the unified diff. Round 0
  is the base snapshot (written once, on the first round). Historical `mode`
  fields remain readable; new mode-free local entries use the existing neutral
  journal representation rather than inventing a new format.
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

- `lua/parley/skills/review/init.lua` — packaged source composition, marker admission, deferred-question completion and bounded resubmit.
- `lua/parley/skills/review/brief.lua` — filesystem integration for version-4 named brief listing/loading; `briefs/` holds flagless task context.
- `lua/parley/skills/review/chat_structure.lua` / `chat_policy.lua` — Markdown facts and pure chat/tag/item policy.
- `lua/parley/skills/review/collaboration.lua` / `collaboration_value.lua` — snapshot permissions and readable legacy evidence.
- `lua/parley/skills/review/local_proposal.lua` — pure exact-identity classifications, protected ranges and local question deferral.
- `lua/parley/review_send.lua` — existing Couch/session dispatch or local marker review.
- `lua/parley/review_notice.lua` / `display_text.lua` — exact message history with one bounded display caption.
- `lua/parley/side_document_path.lua` — owning-root and actual-parent projection; no IO or ownership grant.
- `lua/parley/agentic_document.lua` / `couch.lua` — existing registration, confirmation and bounded Couch requests.
- `lua/parley/skills/review/journal.lua` / `projection.lua` — durable attributed diffs and per-content undo/redo style.
- `lua/parley/skills/review/diag_display.lua` / `skill_render.lua` — inline explanations and span highlights.
- `lua/parley/skill_invoke.lua` — snapshot-bound tool exchange through the existing dispatcher.
- `lua/parley/skills/review/SKILL.md` / `local-adapter.md` — pinned canonical policy and the explicit local single-file boundary.
- `scripts/sync-review-protocol.py` — versioned package validation and synchronization.

The owning entries in [the traceability map](../traceability.yaml) route brief,
policy, native input, proposal, codec and export tests through executable Lua
specs. Python validation runs through the existing bundle wrapper.
