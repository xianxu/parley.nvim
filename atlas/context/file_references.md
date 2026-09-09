# File References (@@)

## Syntax
- `@@<ref>@@` — the canonical form
- Ref types: `@@https://...@@`, `@@/absolute@@`, `@@~/home@@`, `@@./relative@@`, `@@../parent@@`
- No bare filenames, no colon syntax, no end-at-whitespace **in content
  inclusion**. The *opening* chain below is more permissive than the inclusion
  parser and accepts `@@<path>: topic@@` and bare chat filenames.

## Behavior
- Inline anywhere in text: `review @@./file.lua@@ and improve it`
- Content loaded with filename header and line numbers
- Non-chat refs keep original text
- Chat-to-chat references use `🌿:` branch links (see `chat/inline_branch_links.md`)

## Opening what's under the cursor

`<M-o>` (alias `<C-g>o`) → `OpenFileUnderCursor`. One key, one chain, in chat
and markdown buffers alike (#225). It used to be two chains — a markdown one in
`open_chat_reference` and a chat one inline in the command — which had drifted
apart in four ways, three of them missing on the chat side.

`open_reference_under_cursor(buf, line, col, is_chat)` tries, in order:

1. a `src:` markdown link
2. an inline `[🌿:anchor](file)` under the cursor
3. a `🌿:` reference line
4. an `@@` reference: `@@path@@`, `@@path: topic@@`, or the nearest `@@…@@`
   on the line. A relative or bare name resolves against the buffer's directory
   and the chat roots, timestamp-first, so a renamed slug still finds its file.
   A **directory** reference opens in netrw, preferring the other window in a
   two-split layout — **chat buffers only**, the one deliberate divergence
   (`is_chat`). A missing target that names a chat timestamp is treated as a
   forward reference and the chat is created.

It answers with one of three values, and the distinction is what lets the
caller fall through safely:

| value | means | caller |
|---|---|---|
| `"opened"` | recognised and acted on | done; restore insert if it started there |
| `"none"` | nothing here looks like a reference | fall through to `ResolveRefOrGotoFile` (smart `gf`) |
| `"failed"` | recognised, could not open; already reported | done — do **not** fall through |

`"failed"` must not fall through: handing `gf` a path we already know is absent
trades a precise diagnostic ("Chat file not found: …") for a vague one.

**Landing mode follows the destination, not the origin.** A chat reference is
somewhere you went to *write*, so insert mode is restored; a `gf` destination
is source you went to *read*, so it lands in normal. Invoked from insert mode,
the two arms therefore end differently on purpose.

`open_branch_ref`, `try_open_src_link` and `try_open_inline_branch_link` return
the same three-valued status; they used to return `true` for both "opened" and
"recognised and failed", which was harmless only while every non-false answer
meant stop.

## Keybindings
- `<M-o>` / `<C-g>o`: open the reference under the cursor, else smart `gf`
- `gf`: smart go-to-file directly (see `context/artifact_refs.md`)

## Untrusted paths (#225)

`vim.fn.expand()` runs shell commands — expanding ``"`touch /tmp/x`"`` executes
it. A chat buffer holds **model output**, so every path lifted out of one is
attacker-influenced text arriving at a command-execution sink. This was
reproduced end-to-end: a chat line ``@@`touch <path>`@@`` created the file when
`<M-o>` was pressed on it.

`helper.expand_path(path)` is the **only** expansion a transcript-derived path
may go through. It refuses (returns `nil`) rather than escaping, because
`expand()` has two executing constructs (`` `cmd` `` and `` `=expr` ``) with no
reliable quoting, and no legitimate parley reference needs a backtick.

Routed through it: `read_file_content`, `is_directory`, `find_files`,
`prepare_dir`, `_resolve_chat_path_candidates`, `find_tree_root_file`,
`collect_tree_files`, `chat_respond.resolve_path`, and both `@@` sites in the
opening chain. **Config-derived** paths (`chat_dir`, `root.dir`, `src_root`)
keep plain `vim.fn.expand` — the distinction is provenance, not syntax.

`tests/integration/untrusted_path_spec.lua` drives each entry point with a real
`touch` payload and asserts the marker file was not created; every arm goes red
if the guard is removed.

## Rules
- Exchanges with `@@` refs MUST be preserved in full during memory management (never summarized)
- A path that came out of a buffer goes through `helper.expand_path`, never
  `vim.fn.expand` directly
- The fall-through has exactly ONE call site, asserted by
  `tests/integration/open_reference_spec.lua`. Appending it per buffer type is
  how the two chains diverged in the first place.
