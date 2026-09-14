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
`@@` references, and ordinary local Markdown links. If there is no recognized
reference it falls back to [smart gf](artifact_refs.md). A recognized but missing
target reports its own error and does not fall through.

Relative Markdown `.md` links resolve from the source buffer's directory,
independent of shell cwd. For `@@` links, relative or bare names are resolved
against the buffer directory and chat roots; timestamp-first chat lookup tolerates
renamed slugs. A missing chat timestamp can be a forward reference that creates
the chat. Directory references open netrw in chat buffers, preferring the other
window in a two-split layout.

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
- `lua/parley/init.lua` — editor opening chain and remote-context cache.
- `lua/parley/chat_respond.lua` — request inclusion.
- `tests/unit/build_messages_spec.lua`, `tests/unit/remote_references_spec.lua` — context assembly and caching.
- `tests/integration/open_reference_spec.lua` — navigation and one fallback boundary.
- `tests/arch/untrusted_path_spec.lua`, `tests/integration/untrusted_path_spec.lua` — expansion sinks and end-to-end inert path handling.
