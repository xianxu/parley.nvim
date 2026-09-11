# Chat Lifecycle

## Creation (`:ParleyChatNew` / `<C-g>c`)
Creates timestamped `.md` in primary `chat_dir`. Multi-root: all roots scanned for discovery; new chats always in primary.

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
Moves entire chat tree (root + descendants) to another chat root; rewrites all `🌿:` references.

## Branching / Pruning (`<M-p>`, legacy `<C-g>b`)
Splits current exchange + following into a new child chat with `🌿:` links. Async LLM topic generation.

The tool-fold toggle remains configurable as
`chat_shortcut_toggle_tool_folds`, but has no default mapping. A configured
non-empty shortcut is registered and shown through the shared keybinding
registry.

## Response (`:ParleyChatRespond` / `<C-g><C-g>`)
Assembles context (with memory summarization), streams LLM response into buffer. The [exchange model](exchange_model.md) is the single source of truth for all transcript mutations during the response lifecycle — streaming text growth, tool block insertion, and prompt append all go through the model. [Response progress](response_progress.md) is cosmetic extmark state that begins at the response header (or a recursive leg's last visible block), then follows the current generation tip; it never becomes a model block. A per-buffer pending-session guard prevents duplicate calls.

Semantic folds are a pure projection of one exchange's positive-size thinking,
summary, tool-use, and tool-result blocks (`lua/parley/fold_projection.lua`).
Streaming still reduces only the active insertion span; a late explicit
thinking terminator may widen that bounded read to its recorded provisional
opener. Before a known exchange mutation, Parley removes that exchange's old
projected folds in every window showing the buffer; afterward it creates the
updated projection in those same windows. Tool-loop appends use the same
transaction. Unchanged exchanges receive no fold commands, unrelated user folds
remain untouched during live reconciliation.

Initial setup and window-entry events parse once and hydrate every exchange in
the entering window. Hydration first clears restored/manual fold state in that
window, then renders the complete semantic projection. This makes initial fold
state a pure function of the parsed exchange model: stale blank-line folds and
a live transaction that beats scheduled hydration cannot survive as duplicate
nesting. Fold ranges
come only from item bounds; inter-item and inter-exchange gaps are never fold
targets. A lightweight `(buffer, window)` initialization registry
prevents duplicate manual folds and is cleared with window/buffer teardown.
Successful live transactions use the current model without reparsing; failure
recovery reparses only to restore prepared folds while preserving the original
error.

Inline-comment submission follows the same preservation boundary. Drill-in
marker/anchor transformations are planned as original-coordinate byte edits and
applied from bottom to top; end and branch destinations use narrow line edits.
The submission path never replaces the whole chat, so completed semantic folds
and unrelated user folds migrate only with their covered logical text.

Pending responses also hold a per-buffer chat lease (`lua/parley/chat_lease.lua`) anchored on an `invalidate=true` extmark on the response's `🤖:` agent-header line (#138). Each async callback validates the lease before mutating the transcript; ordinary edits and streaming move the anchor and stay valid, while deleting that line — undo/redo of the inserted response, or removing the header — invalidates the lease, stops/suppresses late stream/tool/progress/topic writes, and prevents recursive tool resubmit from using a stale live model. The pending extmark and its staged output are discarded on lost ownership. (Pre-#138 the lease keyed on buffer `changedtick`, which mis-read Parley's own writes as drift; the extmark anchor makes `commit` a no-op.)

While a response is pending, the chat buffer's standard `u` and `<C-r>` keys
ask for default-No confirmation before changing history. Approval stops only
that buffer's transport, performs the counted native history operation once,
then synchronously retires its pending presentation and lease. With no pending
response the keys remain native and do not prompt. Ex commands such as `:undo`,
`:redo`, `:earlier`, and `:later`, plus custom mappings that bypass these keys,
remain outside this interception seam; the structural lease rejects their late
callbacks and emits one bounded generic cancellation notice.

## Editing, Diagnostics, and Decoration Convergence

`lua/parley/buffer_lifecycle.lua` is the neutral owner of buffer convergence
events. It invokes diagnostics and highlight structure independently on
`InsertLeave`, normal `TextChanged`, `BufWritePost`, `BufEnter`, and `WinEnter`;
chat-response finalization enters the same coordinator after a mutated API leg.
The production `BufEnter` classifier installs the lifecycle synchronously, so a
new chat or Markdown buffer is fully converged before its first entry event
returns; unrelated helper-managed UI events may remain scheduled.
`BufUnload`/`BufDelete` tears down lifecycle, structure, and LineReader state so
obsolete callbacks and reused buffer handles are harmless.

Ordinary insert keystrokes do not rebuild document-wide timezone or managed
footnote diagnostics. Those diagnostics may remain stale during `TextChangedI`
and are synchronously current before the next convergence event returns.
Every edit splices the decoration structure in bounded work, so decorations
never drop out while typing. Ordinary typing, Enter included, keeps it exact;
a structural-marker edit leaves it approximate but still rendering, and one
rebuild follows 250 ms after the burst — or at the next convergence event,
whichever comes first (see [ui/highlights](../ui/highlights.md)).

`lua/parley/highlight_structure.lua` owns the pure canonical prefix/fence/tool/
reasoning structure. `lua/parley/highlighter.lua` keeps one buffer-owned
structure snapshot and per-window viewport decorations. A redraw reads only
the visible rows plus its fixed context/reasoning allowances, never scans the
whole document for a managed footer, and recomputes separately for scrolling or
multiple windows. `lua/parley/line_reader.lua` is the observable adapter for all
performance-sensitive buffer reads; the report-only `make perf` suite asserts
structural work bounds while treating elapsed timings as evidence rather than
CI budgets.

## Follow Cursor (`:ParleyToggleFollowCursor` / `<C-g>l`)
Toggles auto-follow of streaming insertion point.

## Resubmit All (`:ParleyChatRespondAll` / `<C-g>G`)
Resubmits all questions from start to cursor, replacing existing answers. Stop with `<C-g>x`.

## Context Assembly (Tree of Chat)
Child chats inject ancestor context by walking parent chain to root. Summaries replace full answers when available.

## Review (`:ParleyChatReview`)
Creates a new chat pre-filled with a proof-read prompt for the current file. Inserts a `🌿:` back-link into the source file's front matter pointing to the review chat.

## Deletion (`:ParleyChatDelete` / `<C-g>d`)
Deletes current file only (not children). Purges associated memory and cached metrics.
