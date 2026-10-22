# File References (@@)

Write `@@./file.lua@@` inside a question to include a file's content in the
model's context. The original question stays readable; the assembled request
adds a filename header and line-numbered content. This is separate from opening
a reference in the editor.

## Inclusion syntax

- `@@https://example.com/file@@` — remote context; see [Google Drive](google_drive.md) for authenticated documents.
- `@@/absolute/path@@`, `@@~/path@@`, `@@./relative@@`, `@@../parent@@` — local paths.
- A closing `@@` is required. Bare filenames and `@@path: topic@@` are accepted
  by parts of editor navigation, but are not the canonical content-inclusion form.
- References work inline: `Review @@./file.lua@@ and improve it`.
- Exchanges containing file references are preserved in full during memory
  management rather than summarized. Chat branches use
  [branch links](../chat/inline_branch_links.md).

## Inclusion paths and permissions

When assembling a question's explicit `@@` references, the file-content reader
expands the supplied path and reads it with Neovim's filesystem access. Relative
paths in this inclusion step follow Neovim's current working directory, unlike
editor navigation's buffer-relative lookup below. Use an absolute path when that
distinction matters.

Explicit inclusion does not pass through the model file-tool dispatcher, so
`tool_read_roots` does not restrict what an `@@` reference can include. The
backtick guard prevents command execution during path expansion; it is not a
read-root permission check. Include only content you intend to send. This describes
the explicit-reference assembly in `chat_respond.build_messages`, not a promise
that every recursive tool round rereads those files.

## Opening a reference

`<M-o>` (alias `<C-g>o`) opens the reference under the cursor in chat and Markdown
buffers. It handles `src:` links, inline branch links, `🌿:` reference lines,
`@@` references, and ordinary local Markdown links. Direct references, including
artifact references under the cursor, take priority.
Inline Markdown link labels may wrap across lines within a paragraph: any part
of the label or destination still opens that link. The shared scanner retains
the complete byte span and destination row for opening and fallback; nested
artifact/@@ spellings inside the label are not separate entity choices. Blank
rows, headings, new list items, fences and entity range edges stop a wrapped span.
With no direct reference,
it looks in the enclosing entity: a heading owns its section through the next
same-or-higher heading; anywhere in a top-level numbered item owns that whole
multi-line item. Interior blanks belong to the item, trailing blanks do not;
the next numbered anchor or real heading ends it. Fenced examples contribute
neither boundaries nor targets, and transcript headers/exchanges stay protected.
Other body text uses its existing paragraph entity. Reference-bearing annotation
prefixes remain numbered-item content; only real user/assistant turns bound an
item in a transcript. Plain-Markdown navigation keeps chat-looking sample lines
inside fences, while transcript navigation retains the shared turn-reset policy.

One occurrence opens immediately. Several show a reference picker in document
order (repeated destinations remain separate choices). Canceling leaves the
source alone; edited/deleted sources, a different active buffer/window, or a
newer invocation invalidate retained choices and delayed resolver results.
With no occurrences, navigation falls back to [smart gf](artifact_refs.md).
A recognized but missing target reports its own error and does not fall through.
Unordered bullet items, including tight siblings and nested continuations,
form their own navigation range. This does not change editing textobjects.
Local `.md#anchor` links resolve the file first, then match an ATX heading
(levels 1–6). Bundled treesitter `markdown_inline` supplies visible text spans
through emphasis/code/link-label structure, omitting markup, destinations and
titles. The adapter parses strings only; it creates no buffers or persistent
parser cache. If the grammar is unavailable, use raw heading content and the
same key rather than a second inline parser.
Keys lowercase/keep ASCII letters and digits, drop other ASCII and U+2000–206F/U+3000–303F, and preserve all other non-ASCII codepoints unchanged, on both sides.
This preserves CJK/accented text; non-ASCII case is unchanged. A fragment that
GitHub stripped of other non-ASCII symbols can miss with the existing notice.
The first heading takes the bare key, subsequent equal keys use `-1`, `-2`, etc.
A complete fragment key has priority over a trailing duplicate suffix, retaining
natural numeric headings. Empty keys never match. Raw HTML headings/inline HTML
and character-reference decoding remain outside scope; unsupported or unmatched
anchors open at the top with a notice. Fenced examples define no anchors. Shared
fence containment requires matching delimiter characters and a sufficiently
long, whitespace-only closer. The occurrence scanner owns shared block-opener
metadata: headings, thematic/Setext walls, quotes, lists and fences outside an
item’s content indentation end its navigation range. Indented blocks stay inside
the item; plain lazy continuations remain valid until a blank or outside block. Missing
anchors open at the top with a short notice. Plain file links retain their
existing cursor behavior; URL destinations keep their existing fallback policy.

Relative Markdown `.md` links resolve from the source buffer's directory,
independent of shell cwd. For `@@` links, relative or bare names are resolved
against the buffer directory and chat roots; timestamp-first chat lookup tolerates
renamed slugs. A missing chat timestamp can be a forward reference that creates
the chat. Directory references open netrw in chat buffers, preferring the other
window in a two-split layout. Floating overlays (including the demo's Screenkey)
are excluded from split counting and existing-buffer destinations by the shared
`helper.is_editing_window` predicate.

When invoked from Insert mode, a chat-reference destination restores editing;
the smart-gf fallback lands in Normal mode for reading source. Pressing `gf`
directly uses smart artifact-reference resolution or native Vim go-to-file.

## Path handling and implementation

`open_reference_under_cursor` returns `"opened"`, `"none"`, or `"failed"`.
Only `"none"` invokes the shared fallback. The branch and src-link helpers use
the same status vocabulary.

Paths read from transcript text are untrusted. They pass through
`helper.expand_path`, `helper.abs_path`, or `helper.safe_glob` before any Vim
expansion/globbing that could execute backticks. All three share
`helper.would_execute`; refused paths produce diagnostics or remain inert
literals. Operator-configured paths have a separate audited allowlist.

- `lua/parley/helper.lua`, `chat_parser.lua` — reference extraction and safe path helpers.
- `lua/parley/init.lua` — editor opening chain, picker origin guard and remote-context cache.
- `lua/parley/reference_candidates.lua` — shared occurrence scanners and pure picker completion.
- `lua/parley/entity_range.lua` — navigation ranges sharing existing structural boundaries.
- `lua/parley/markdown_heading.lua` — PURE outline/editing level detection; INTEGRATION anchor lookup using bundled treesitter and codepoint decoding.
- `lua/parley/artifact_ref.lua` — selected artifact resolution with optional final-effect validation.
- `lua/parley/chat_respond.lua` — request inclusion.
- `tests/unit/build_messages_spec.lua`, `tests/unit/remote_references_spec.lua` — context assembly and caching.
- `tests/integration/open_reference_spec.lua` — navigation, direct priority and the fallback boundary.
- `tests/unit/reference_candidates_spec.lua` — occurrence identity and completion transitions.
- `tests/integration/entity_navigation_native_spec.lua` — real Normal/Insert Alt+o input.
- `tests/integration/entity_resolve_spec.lua` — filesystem-backed resolver and stale-result suppression.
- `scripts/check-sdlc-resolve-conformance.py` — opt-in real/fake resolver contract check with isolated temporary repositories; run `make -k check-sdlc-conformance` whenever the runner/fake changes and before closing that work.
- `tests/arch/untrusted_path_spec.lua`, `tests/integration/untrusted_path_spec.lua` — expansion sinks and end-to-end inert path handling.

Wrapped Markdown dispatch retains its identity for unsupported destinations: the
direct and selected paths share the Markdown-only opener and fall back at the
URL's row/byte position. Both scans receive the document-aware navigation fence
memo; transcript structural prefixes stop cross-boundary joins, while chat-like
text in plain Markdown never resets a fence.

Paragraph walls include thematic breaks (compact or spaced), Setext underlines,
all six ATX heading levels, and blockquote rows. A list/chat anchor may begin a
wrapped label but never continue a span opened in an earlier block.

ATX walls include empty and nonempty headings at levels 1–6 with up to three
leading spaces; end-of-line after the hashes is a valid heading terminator.
