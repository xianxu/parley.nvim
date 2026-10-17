# move-orphan

submitted: design.md
outcome: ok
move: design.md spec.md

Row 29. The same rename as move-rename, but a spec.side/ folder already exists: an orphan, left by a spec.md that
was deleted (a spec.md still present would have stopped the move). The orphan takes the suffix (spec_1.side/) and
the moving document takes spec.side/, since every tool finds a document's side docs from its file name.

This case is a fixture for parley's mover too (exported in `export.json`).

## Reply

- spec.side/ was taken by an orphan (no spec.md); it is now spec_1.side/.
- Moved design.md to spec.md with design.side/ (now spec.side/); rewrote spec.md's link and index entry and
  spec.side/01-why-per-file.md's parent and backlink.
