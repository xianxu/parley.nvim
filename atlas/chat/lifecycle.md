# Chat Lifecycle

## Creation (`:ParleyChatNew` / `<C-g>c`)
Creates timestamped `.md` in primary `chat_dir`. Multi-root: all roots scanned for discovery; new chats always in primary. Chats are ordinary Markdown files: save edits with `:write`, and use `:ParleyChatFinder` (`<C-g>f`) to reopen them. The app also ships three stable-name tutorial transcripts.

## New Question (`:ParleyNewQuestion` / `<C-g>n` / `<M-n>`)

Opens an empty question after the exchange at the cursor. The insertion point
and its blank-line seam come from `exchange_clipboard` — the same definition
`<C-g>V` pastes against — so a pasted exchange and a new question are spaced
identically. `lua/parley/new_question.lua` decides the structure as a pure
plan; `M.cmd.NewQuestion` applies it through `buffer_edit`, which refuses
visibly while a response is streaming into the region rather than corrupting
the transcript.

If the cursor's exchange is already an empty unanswered question, the chord
focuses it instead of creating a second one. An empty question in the *next*
exchange is not adopted: the rule is about the exchange the cursor is in, so
the landing spot never depends on content off-screen.

With the cursor in the front matter — above every exchange — the new question
lands immediately below the `---`, i.e. *above* the first exchange. That is
`get_paste_line`'s header fallback and therefore the same placement `<C-g>V`
pastes into from the header.

Post-condition: the cursor sits on a line that is the configured user prefix
followed by a space, in insert mode — so typing yields `💬: text`, not
`💬:text`.

## Command preamble (`lua/parley/chat_context.lua`)

Every chat entry point runs the same three gates before it can act: is this
buffer a chat (`not_chat`), where does its header end (`find_header_end`), and
what does the body parse to (`parse_chat`). That sequence has **one owner**, and
`tests/arch/single_source_sweeps_spec.lua` fails a fourth copy of it.

The owner holds the *sequence*; each caller holds the *wording*, because the
messages genuinely differ — `NewQuestion` names the command, `respond` names the
file, and `respond_all` returns `nil, reason` to its caller for the header case.

It is **two-phase** (`chat_buffer` then `parse`) rather than one `resolve`,
because `respond_all` interleaves its own precondition — is a batch already
running? — between the chat check and the parse. Collapsing the phases would
make a chat with no `---` *and* an active batch report the header instead of the
batch. `tests/unit/chat_context_spec.lua` asserts that phase 1 does not parse,
so a later refactor cannot quietly merge them.

Consumers: `ChatPrune`, `ExchangeCut`, `ExchangePaste`, `NewQuestion` (via
`init.lua`'s wording wrapper), and `chat_respond`'s `respond` / `respond_all`.
One deliberate non-consumer: `delete_entity_range`, which classifies through
`entity_textobj.parsed_for` so the `ae`/`ie`/`aE` text objects and the
`:ParleyDelete*` commands cannot disagree about what a chat is.

## Slug Rename (auto, on save)
When a chat's `topic:` header changes, the file is auto-renamed to include a slug: `YYYY-MM-DD.HH-MM-SS.mmm_slug-words.md`. The slug is derived from the topic (stop words stripped, kebab-case, max 5 words / 40 chars). The `_` separator ensures unambiguous parsing. See `lua/parley/chat_slug.lua` for the pure slug logic.

### The timestamp prefix IS the identity (#224)

The trailing slug exists so a human can read a directory listing. It carries no
meaning to resolution, and it changes *after* references to the file have been
written — a fork writes its back-link the moment it is created (it must, or a
crash orphans the child), and the parent earns its topic later. So resolution is
one rule, not a rule plus a fallback:

    reference → chat_slug.parse_filename() → timestamp → glob "<ts>*" across the roots

An exact-name hit is **not a separate tier**: it is the case where that glob
returns the name the reference already used, which `chat_slug.resolve_candidates`
prefers. Keeping it as a tier is what let an exact-match-only second resolver be
written and go unnoticed for months — it worked for every reference whose parent
had not been renamed yet.

- **One resolver.** `parley.resolve_chat_path(path, base_dir)`. **Three** modules
  defined a `local resolve_path` — `chat_respond`, `outline`, `highlighter`. Two
  resolved exact-only; the third was already correct and is gone too, because
  the shared *name* is what made the broken pair look like the working one.
  (An earlier revision of this paragraph said "six": that was the count of call
  *sites* transcribed as modules.)
  `tests/arch/single_resolver_spec.lua` enforces it: the naive
  `helper.resolve_relative_path` is reachable only from inside the real
  resolver, no module defines its own `resolve_path`, and any module that reads
  a chat reference's `.path` must reach `resolve_chat_path`.
- **Collision, handled not assumed.** Same-timestamp files pick the exact
  basename if the reference names one, else lexicographically first, and the
  ambiguity is reported. The rule this replaced sorted by *length* — "prefer the
  one with a slug" — which stops being right the moment two slugged variants
  exist.
- **An exact hit short-circuits**, before the glob. Not the tier this design
  deletes — a tier changes the answer, and this cannot, because
  `resolve_candidates` already prefers an exact basename and every existing
  exact target is in the glob set. It is there for cost: without it the common
  case (a reference whose parent has not been renamed) goes from a
  `filereadable` to O(files in the roots) — measured 0.031 ms → 2.43 ms at one
  root of 2000 files, and `<M-t>` resolves once per branch.
- **Search order is the tie-break** for non-exact matches, with the reference's
  own directories first. `resolve_candidates` preserves the order it is given;
  the caller sorts within each directory so filesystem order cannot leak in.
- **Resolution returns a resolved path**, always. The second consumer site
  compares the result against `vim.fn.resolve(current_file)` for equality; an
  unresolved return makes that comparison fail and truncates the parent to
  nothing, which looks identical to not resolving at all.

### Read-repair has exactly one trigger

Resolution is a **read** and performs no writes. A slug-stale reference resolves
correctly forever, so repair is cosmetic — it exists only so links stay
grep-able outside parley.

`CursorHold` on a line carrying a reference → `repair_reference_at_cursor`
rewrites that line **in the buffer** (undoable, visible, nothing written behind
your back). `CursorHold` rather than `CursorMoved` because cursor motion is a
keystroke path and a glob per motion is the repeated expensive work
ARCH-CONSTRAINTS forbids; it *reads* `updatetime` and does not set it.

Five guards, each with its own test: chat buffer, reference present on the line,
resolved name actually differs (a no-op must not set `modified`), not insert
mode, not busy. Busy **ignores** rather than queues — the next hold retries for
free, and queuing would land the write at the least predictable moment.

Scope is the line under the cursor, not the file: three stale references need
three visits. A whole-file rewrite triggered by resting a cursor would be the
old behaviour moved rather than removed.

## Move (`:ParleyChatMove`)
Moves the entire linked tree to another registered chat root and rewrites its
`🌿:` references. Invoking it on a child first walks to the ancestor root, so
parents and siblings move too. Chat Finder Ctrl+x uses this same tree operation.
Associated asset folders follow their chats. Destinations must already be in
the configured chat roots; pass a registered directory to `:ParleyChatMove [dir]`
or choose one from its picker. There is no `:ParleyChatDirs` command; see
[Repository Mode](../infra/repo_mode.md) for root selection.

There is no dedicated user command for moving just one chat. The Lua helper
`require("parley").move_chat(file, target_dir)` moves one file and its assets,
but does not perform tree-wide reference rewriting; it is an implementation API,
not the behavior of `:ParleyChatMove`.

## Branching / Pruning (`<M-p>`, legacy `<C-g>b`)
Splits current exchange + following into a new child chat with `🌿:` links. Async LLM topic generation.

The tool-fold toggle remains configurable as
`chat_shortcut_toggle_tool_folds`, but has no default mapping. A configured
non-empty shortcut is registered and shown through the shared keybinding
registry.

## Response (`:ParleyChatRespond` / `<M-CR>` / `<C-g><C-g>`)

`chat_respond` captures the selected question, request context, configuration and
replacement source once. `response_target` waits for confirmed document identity;
`response_submission` acquires every mutable gap before readiness or reference IO.
`response_preparation` replaces generated bytes in bounded slices, preserving raw
annotations and trailing footnotes. It reports the captured input at once, so the
request starts immediately, and writes those bytes only when the generation is
about to make its first write (#266). Earlier context changes mark the frozen input
stale; edits intersecting the selected output revoke its write grant. Explicit
model onboarding replaces only the placeholder request profile and output header,
retaining captured source geometry. The selected model and tool limits then stay
frozen for the response. Remote preparation tracks each launched fetch through
its terminal callback; cancellation or a thrown sibling launch cannot claim that
unresolved IO has finished.

`response_session` composes the pure `generation` state machine and
`generation_runner` with provider, tool, completion and presentation adapters.
Each generation has its own grants and transport identity. Several answers can
stream in one buffer while the human composes the next question; their writes are
serialized by the document's [write turn](ownership.md). Every native
write authenticates an exact receipt; saving can advance Neovim's tick without
an edit callback, so owned writes capture a fresh native frame immediately before
mutation instead of treating tick continuity as ownership.

A tool round's tools start at once; results may finish out of order, but the
blocks land in declared order, each call immediately before its own result
(#266 M2). Continuation needs every block written and every tool physically
cleaned up. A failed call — including an unknown outcome — is written as an
error result and the round continues; it is never replayed automatically. The M4
coordinator supports injected asynchronous producers; actual asynchronous builtin
tool execution and process resource scheduling remain #254 M6 work.

`response_completion` consults current indexed structure before inserting a new
question. A human next question or unmarked draft suppresses it. New prompt bytes
are released from the finishing answer's authority using finite replacement's
narrowing witness. Completion never deletes existing margins, annotations or
footnotes. `response_topic` separately owns the captured `?` header suffix and
origin markers; normal answer completion permits it to finish, while origin
edits and reload invalidate it.

Regenerating an answer replaces it in the buffer, and nothing is kept outside
the transcript (#261). The previous text is reachable through native undo; how
generated writes group into undo steps is stated once, in
[Chat Write Ownership, "Undo grouping"](ownership.md). With `undofile` set, that
history survives reopening the chat.

### Previous answer while regenerating (#261, #255)

While an answer is being regenerated, the rest of the chat still sees the
answer it replaces.
- A request whose context includes that exchange — a later question in the
  same chat, or a sub-chat whose ancestors include it — carries the previous
  answer, whole, rather than the header or partial text now in the buffer.
- It is captured from the command-time parse and held on the document
  coordinator (`D.set_previous_answer` / `D.previous_answers`) from the top of
  `prepare_input`, before preparation removes a byte.
- It is substituted in the tick the command reads the chat, because
  `build()` runs later.

It lives exactly as long as that generation holds its grant:
- it ends when the generation ends, in success or failure, since both are
  recorded in the transcript;
- an edit that revokes it, reload, detach, or deleting the question also end
  it;
- the event list is the ARCH-ORDER table in
  `workshop/plans/000261-transcript-is-the-whole-truth-plan.md`.

A generation's writes inside its own grant move other generations' captured
input ranges but never mark them stale; only human edits do
(`document/state.lua`). That covers every generated write: a regeneration, a
first answer, and a topic header.
- For a regeneration, the answer being replaced stays the valid context until
  the generation ends.
- For any generated write, a request captured before it is final: it carries
  the transcript as it was when its command ran. A later generated write
  changes what later requests read, not what an earlier one already sent.

Pending progress is presentation only, described in [Response progress](response_progress.md).
Stop cancels captured sessions for the current chat. Its processes are stopped as
process groups — SIGTERM, then SIGKILL 2 s later while one is still running
([Stopping a process](../providers/tool_execution.md#stopping-a-process)) — while
a subprocess or tool effect that has not resolved keeps its ownership until it
does: cancellation is a request, not evidence that an effect stopped.
Undo/redo stays native. Document edit
observation revokes affected grants; no pending confirmation or synthetic tool
result can replace that evidence.

## Editing, Diagnostics, and Decoration Convergence

### Transport ownership containment (#254 M1)

Each provider launch has a private attempt identity, independent of its PID and
mutable query payload. An attempt remains owned until process exit and both
output streams terminate. Successful signaling, failed probes, and missing-PID
observations do not prove completion. Unresolved attempts retain admission;
explicit reconciliation records evidence without guessing that work has ended.
Admission releases before the terminal callback so retries can launch safely.

Generation revocation cancels only its captured transport attempts. Independent
topic origin guards also stop obsolete topic work. Completion preserves human
suffix text, including unmarked drafts. See `attempt.lua`, `tasker.lua`, the
response adapters and their native/stateful-process integration tests.

`lua/parley/buffer_lifecycle.lua` is the neutral owner of buffer convergence
events. It invokes diagnostics and highlight structure independently on
`InsertLeave`, normal `TextChanged`, `BufWritePost`, `BufEnter`, and `WinEnter`;
chat-response finalization enters the same coordinator after a mutated API leg.
The production `BufEnter` classifier installs the lifecycle synchronously, so a
new chat or Markdown buffer is fully converged before its first entry event
returns; unrelated helper-managed UI events may remain scheduled.
`BufUnload`/`BufDelete` tears down lifecycle, structure, and LineReader state so
obsolete callbacks and reused buffer handles are harmless.

The shared document index owns lexical and semantic repair. Ordinary edits
splice local structure; uncertain regions repair in bounded scheduled slices.
Highlighting queries the visible range, folds consume indexed semantic ranges,
and diagnostic refreshes publish only under current captured job ownership.
Broad structural changes may require aggregate work over their affected range;
bounded slices alone are not a constant-latency guarantee. `line_reader` exposes
native read and work counters to the report-only performance suite.

## Follow Cursor (`:ParleyToggleFollowCursor` / `<C-g>l`)
Toggles following of the actual committed output byte position. Follow does not
move a cursor that the human has moved away from its last automatic position,
and does not move it while typing in Insert/Replace mode or in another window.
Fold maintenance preserves window views independently. Explicit response overrides
take precedence over the saved toggle and configuration default.

## Resubmit All (`:ParleyChatRespondAll` / `<C-g>G`)
Resubmits all questions from start to cursor, replacing existing answers. Stop with `<C-g>x`.

## Context Assembly (Tree of Chat)
Child chats inject ancestor context in root-to-parent order. At each ancestor,
only exchanges up to that ancestor's branch reference to the next child are
included (`branch.after_exchange`); exchanges after that branch point are not.
If no matching forward reference is found, that ancestor contributes no
exchanges. The question of each included exchange is retained; its answer uses
the `📝:` summary when present, otherwise the full answer.

A parent is read as the user sees it (`helper.chat_lines`): from its loaded
buffer when one is open, which is ahead of the disk while an answer streams in
or while edits are unsaved, else from the file. A parent exchange still being
regenerated contributes its previous answer, as above.

This ancestor-summary rule applies even when `chat_memory.enable=false`.
Disabling memory preserves the current chat's ordinary message window; it does
not turn ancestor summaries into full ancestor answers. The implementation is
`chat_respond.collect_ancestor_chain` / `build_ancestor_messages`. Ancestors follow
the complete system prefix, including both messages of a synthetic prefix.
Automatic topic requests use only the current-file conversation, excluding that
prefix and ancestor context.

## Review (`:ParleyChatReview`)
Creates a new chat pre-filled with a proof-read prompt for the current file. Inserts a `🌿:` back-link into the source file's front matter pointing to the review chat.

## Deletion (`:ParleyChatDelete` / `<C-g>d`)
Deletes the current file only, not children, and removes its asset folder and
cached metrics. `chat_confirm_delete` defaults to `true`; the prompt defaults to
No. `:ParleyChatDeleteTree` walks to the root and deletes the entire linked tree
(including parents and siblings of the current child) after confirmation. Chat Finder offers Ctrl+d for one file and Ctrl+g D for its tree.
These commands delete files directly; there is no Parley trash or undelete.
Recovery of a deleted chat requires your own backup or version-control copy.

## Stopping and correcting a response

`:ParleyStop` (`<C-g>x`) stops a selected response generation. Normal/Insert `<M-CR>` on a
previous answered exchange replaces that answer; visual `<M-CR>` instead defines
the selected term. Ready drill-in comments can turn resubmission into a follow-up
that preserves the original answer; see [Drill-In Markers](drill_in.md).
Undo and redo use native Neovim history. Editing an active answer revokes its
writer; edits to a disjoint question can proceed while that answer streams.
`:ParleyStop` stops the generation under the cursor. Outside an active generation,
it offers the current chat's captured generations in a picker.
`:ParleyStopDocument` cancels all generations in the current chat. Save a separate
copy or use version control when you need durable recovery beyond editor history.

### A stopped response always ends (#261)

**The invariant:** every generation that enters `stopping` reaches `terminal`
within the kill bound: 2 s, plus draining its effects. The one exception is a
process the kernel holds. `generation_runner.stats().active` counts exactly the
generations not yet terminal. So a stopped response never holds a slot, and
the next submission is admitted, whether it comes in the same buffer, after
`:e!`, or after `:bd` and reopening the file.

A generation reaches `terminal` only when every operation it started
confirms. What makes that certain:
- **Its processes die.** The first time a generation stops or ends, the runner
  kills its process scope once, through the session's `stopping` hook. That
  reaches every process started for it: the provider stream, tools, and the
  content fetches its preparation made. The scope then stays closed: nothing
  new may start in it. See
  [Stopping a process](../providers/tool_execution.md#stopping-a-process).
- **Nothing waits on a callback that cannot come.**
  - An operation whose start threw is confirmed by the runner itself.
  - A cancel with nothing left to wait for resolves at once: a readiness
    picker left open, a request whose process never started.
  - A step that throws settles its owner as failed.
  - A step of the runner's own that throws ends the generation with outcome
    `fault`.

The evidence is `tests/integration/generation_settles_spec.lua`.
- **Each wait.** Its `WAITS` list names each wait with the spec and case that
  pin it, or the reason it was dropped. The spec checks that list against the
  specs it names.
- **The reported shape, end to end.** A provider stream that ignores SIGTERM is
  stopped by each cause: Stop, an edit to its answer, `:e!`, and `:bd`. It is
  also stopped 5 times in one buffer and 17 times across reloads. Each next
  submission is admitted.

## Implementation and checks

`lua/parley/init.lua` owns creation, deletion, branch opening, and slug repair;
`lua/parley/chat_dirs.lua` owns move commands; `lua/parley/chat_respond.lua` owns
submission. See `tests/integration/branch_child_spec.lua`,
`tests/integration/chat_move_spec.lua`, `tests/unit/chat_finder_logic_spec.lua`,
and `tests/integration/chat_respond_spec.lua`.
