# move-rename

submitted: design.md
outcome: ok
move: design.md spec.md

Rows 27 and 28: the operator renames design.md to spec.md (in parley, or by asking the agent). The whole
design.side/ tree moves and takes the new name; the side doc whose `parent:` is the document points at spec.md, and
so does its backlink; a side doc of a side doc is unchanged; the document's own link and index entry take the new
folder name.

This case is a fixture for parley's mover too (exported in `export.json`).

## Reply

- Moved design.md to spec.md with design.side/ (now spec.side/); rewrote spec.md's link and index entry and
  spec.side/01-why-per-file.md's parent and backlink.
