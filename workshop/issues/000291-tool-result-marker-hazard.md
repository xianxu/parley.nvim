---
id: 000291
status: working
deps: []
github_issue:
created: 2026-09-27
updated: 2026-09-27
estimate_hours:
card_mirror: '722e583dc774753d47df52c81b858ca16b917583' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-09-27T17:15:59-07:00
flow: {kind: quick, provenance: inferred, spec: "3fc96155", done: "48107c15"}
---

# Close the column-0 marker hazard in tool results (ls/find/stderr)

## Problem

A column-0 structural marker (`💬:`, `🔧:`, `📎:` …) inside a tool result ends
the result's body early (`fence.lua:148-154`), so a well-formed chat can parse
as a forked or truncated answer. Producers prevent this by prefixing their
lines (`read_file` `%5d  `, `grep`/`ack` `-H`, `chat_history_search`
`label/path:line:`), but two exceptions are recorded and deliberately
accepted (`atlas/providers/tool_use.md:283-301`, `fence.lua` comment):
- `ls`/`find` echo paths, so a file *named* `💬: notes.md` emits a marker;
- `grep`/`ack`/`ls`/`find` splice raw stderr after a prefixed first line.

#281 decided to keep tool payloads inline (design A), so this remaining gap
in inline results is worth closing instead of bounding.

## Spec

- **This reverses a recorded decision** ("bounded rather than chased"). The
  cost that decision avoided was per-tool prefix discipline. Fix the class
  once, in the serializer instead: `serialize.render_result` escapes any body
  line that `is_structural` would recognise (for example by prefixing a
  reserved escape that `parse_result` strips), so no producer needs to know
  about markers (ARCH-DRY). This also covers future tools and hand-written
  results.
- The escape must round-trip exactly: `parse_result(render_result(x)).content
  == x.content` for hostile content, including lines that already begin with
  the escape (the escape must escape itself).
- The context sent to the LLM gets the original content (unescaped), not the
  escaped text.
- Existing chats: results written before this change are unescaped. Parsing
  stays as it is for them (the degradation direction is unchanged); only new
  writes are protected. State this compatibility rule in the atlas.
- Update `atlas/providers/tool_use.md` and the `fence.lua` comment: the
  invariant becomes total for results written by Parley.

## Done when

- Fixtures with hostile result content (a file named `💬: notes.md` from
  `ls`/`find`, stderr containing `📎: x id=1`, a line that starts with the
  escape itself) render, re-parse and rebuild provider messages with the
  original content byte-for-byte, and don't fork the answer.
- `tests/integration/tool_output_prefix_spec.lua` stops recording the two
  exceptions as accepted and asserts they're safe.
- Old unescaped transcripts parse exactly as before (regression fixture).
- Atlas updated.

## Core concepts

| Entity | Status | Where | Role |
|---|---|---|---|
| `render_result` | changed | `tools/serialize.lua` | escapes structural body lines, flags the block `escaped=true` |
| `parse_result` | changed | `tools/serialize.lua` | strips one leading `\` per line of a flagged block |
| `live_config` | new | `highlight_structure.lua` | the user's config after setup, else the defaults module |
| `live_patterns` | new | `highlight_structure.lua` | marker patterns under `live_config`; the one resolver for writers |

## Plan

Design:
- **Escape = a leading `\`, flagged per block.** `render_result` escapes a body line when
  the shared lexer classifies it as structural (`lexical.is_structural_kind`, the same
  predicate `fence.scan` bounds bodies with, under the configured prefixes). When any
  line is escaped, the header gains ` escaped=true`, and inside that block every line
  that is structural **or already starts with `\`** gets one `\` prepended; with the flag,
  `parse_result` strips one leading `\` from each line that has one. This round-trips
  exactly, including lines that start with the escape.
- **Compatibility by construction:** a block without the flag is written byte-for-byte as
  today and parsed as today (no unescaping), so every old transcript and every harmless
  result is unchanged. Only results that would have forked carry the flag.
- Every reader goes through `parse_result` (`chat_parser`, `chat_respond`, `init`), so
  the provider context gets the original content; live rounds use frozen results.
- Creates nothing durable (ARCH-FUNERAL): a header token and a byte per escaped line.

- [x] Round-trip property tests in `tools_serialize_spec` (hostile lines, lines starting
      with `\`, no-flag byte-identity, old unflagged block with `\` lines unchanged)
- [x] `render_result` escape + flag; `parse_result` unescape under the flag
- [x] `tool_output_prefix_spec`: assert every tool's *rendered* block has no column-0
      structural line and round-trips; `ls`/`find` exercised with a marker-named file;
      stderr-shaped fixture; the two exceptions removed
- [x] Chat-level fixture: hostile results parse without forking, rebuild provider
      messages with the original content; an old unescaped transcript parses as before
- [x] Atlas (`providers/tool_use.md`) and `fence.lua` comment: invariant total for
      results written by Parley

## Log

### 2026-09-27
- Filed from #281 (design decision A).
- 2026-09-27: implemented as planned (flagged `\` escape; user approved the scheme).
  Tests: `tools_serialize_spec` round-trips six hostile shapes (marker-named listing,
  spliced stderr, every structural marker, escape-led lines, last line, trailing
  newline), no-flag byte identity, an old unflagged block with `\` lines unchanged, and
  a tool named `escaped=true`. `tool_output_prefix_spec` now runs every tool's real output
  through the serializer; `ls` and a stderr fixture go red without the escape. `find`
  stays green either way: it echoes full paths, which never start with a marker.
  `chat_parser_tools_spec`: rendered hostile results don't fork and parse to the original
  bytes. `chat_respond_spec` e2e: a real `ls` of a marker-named file in a tool round is
  written escaped, the answer doesn't fork, and the follow-up question's provider payload
  carries the unescaped listing (red without the escape). The existing "forks on a
  column-0 question marker" case pins old unflagged transcripts.
- 2026-09-27: close review round 1 → FIX-THEN-SHIP. BR-1 (Important): `render_result` read
  prefixes from `require("parley.config")`, the pristine defaults, while `parse_chat` runs
  under the user's `parley.config`; with `chat_user_prefix = "Q:"` an `ls` line
  `Q: notes.md` went unescaped and forked. Fixed as a class: `highlight_structure.live_patterns()`
  (via `package.loaded`, so pure modules need not load the plugin) now serves the
  serializer, `tool_folds` foldtext and document attach, and `diagnostic_refresh`'s attach;
  `init.lua`'s two debug `parse_chat` calls use `M.config`. Custom-prefix test in
  `tools_serialize_spec` (red with the defaults read). Minors: patterns built once per
  `render_result`; `fence.lua` `scan` doc updated.

