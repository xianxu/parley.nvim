---
id: '000042'
status: done
created: 2026-03-31
updated: 2026-04-01
actual_hours: N/A
---

# inspect chat finder performance

## Problem

can you start by describe existing cost. it should be:

1/ one pass in all files in the folder, read first 10 lines (for front matter), build index of things we need.
2/ store file last update time, avoid reading again if not changed.
3/ async prewarm cache, e.g. upon nvim start, kick off to populate chat/note finder.
4/ if lua support async/multithreading, kick multiple threads (configurable) to read, (assuming good SSD performance here)

any other ideas?
