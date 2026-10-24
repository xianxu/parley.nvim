# Frontmatter Typeahead

Typing the value of a frontmatter key with a fixed set of values pops up the values that match what's typed (#384).
It works in Insert mode, in any markdown or chat buffer. There is one menu, never two:
- **Without nvim-cmp** (or with cmp disabled for the buffer), it uses Vim's own `complete()` through
  `helper.complete_noselect`, as the issue `status:` popup did before it moved here.
- **With nvim-cmp active,** the values are the `parley_frontmatter` cmp source instead. It sits in its own group,
  sorted before the buffer's sources, so on a frontmatter value cmp lists only the values. It is unavailable
  everywhere else, so cmp's other sources behave as before. The source is re-added on each change, because host
  configs and parley's chat setup reset buffer sources. Measured with the operator's config: when both ran, Vim's
  popup and cmp's menu opened at once.

- **Where it offers:** only on a declared key's value line inside the opening `---` block, after the colon. It
  offers nothing in the body, on undeclared keys, or once the value is typed out in full.
- **Declared keys** live in `lua/parley/frontmatter_enum.lua`. Each one's values come from the module that enforces
  them, never from a second list:
  - `status` reads the issue vocabulary, in issue files only (`applies(path)`).
  - Retired editorial keys (`collaboration-mode`, presentation and instruction keys) offer nothing (#419). They remain readable compatibility metadata, with notices in [document review](../modes/review.md), and are never rewritten by completion.
- **Adding a key** is one `M.declare(key, { values = fn, applies = fn? })` call for an actively owned enum.
- **Scope:** the scalar form `key: value` only. Historical editorial mapping forms get no typeahead.
- **Live check:** `nvim --headless -c "luafile scripts/check-frontmatter-cmp.lua" </dev/null` runs the working tree's
  code against your real nvim-cmp. It exits 0 when only cmp's menu opens, holding only the value; 1 on a mismatch;
  2 without cmp. The integration spec covers the same path with a stub cmp.
