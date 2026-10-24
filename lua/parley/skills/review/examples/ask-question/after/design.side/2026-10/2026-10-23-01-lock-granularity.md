---
type: side-doc
parent: ../../design.md
marker: "why per file and not per section?"
---

# Why per file and not per section?

_From [Design](../../design.md), section "Locking"._

A file is the unit Couch hashes for its compare-and-swap write, while a section's boundaries move as you edit.
