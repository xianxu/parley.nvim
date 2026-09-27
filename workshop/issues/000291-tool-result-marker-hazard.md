---
id: 000291
status: open
deps: []
github_issue:
created: 2026-09-27
updated: 2026-09-27
estimate_hours:
card_mirror: '1e7e43fcf2710f1819fee4897c58844945ef0932' # card fields mirrored from issue-cards; edit via sdlc
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

## Plan

- [ ] Choose the escape; round-trip property tests in `tools_serialize_spec`
- [ ] Serializer escape plus parser unescape; context rebuild uses the original content
- [ ] Hostile-content fixtures through the parser, message building and folds
- [ ] Atlas and `fence.lua` comment

## Log

### 2026-09-27
- Filed from #281 (design decision A).

