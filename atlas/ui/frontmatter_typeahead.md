# Frontmatter Typeahead

Typing the value of a frontmatter key with a fixed set of values pops up the values that match what's typed (#384).
It works in Insert mode, in any markdown or chat buffer, and needs no completion plugin: it uses Vim's own
`complete()` through `helper.complete_noselect`, as the issue `status:` popup did before it moved here.

- **Where it offers:** only on a declared key's value line inside the opening `---` block, after the colon. It
  offers nothing in the body, on undeclared keys, or once the value is typed out in full.
- **Declared keys** live in `lua/parley/frontmatter_enum.lua`. Each one's values come from the module that enforces
  them, never from a second list:
  - `collaboration-mode` reads `skills/review/collaboration.lua`'s `M.modes`, the list its resolver checks;
  - `status` reads the issue vocabulary, in issue files only (`applies(path)`).
- **Adding a key** is one `M.declare(key, { values = fn, applies = fn? })` call (for example `presentation:`, with
  #383).
- **Scope:** the scalar form `key: value` only. The mapping form of `collaboration-mode` (`default:` and per-mode
  heading lists) gets no typeahead.
