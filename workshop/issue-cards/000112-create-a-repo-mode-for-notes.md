---
id: '000112'
status: done
created: 2026-04-24
updated: 2026-04-24
actual_hours: N/A
---

# create a repo mode for notes

## Problem

Follow the setup of repo mode for parley chat, create a repo mode for note. The triggering condition is exactly the same, e.g. in a repo, where repo root contains the .parley marker file.

Investigate the features parley chat's repo mode enables, but here are the top of mind:

1. support multiple roots where notes are loaded. one root, serving as default write location, where new notes go. notes in other roots can be still found and edited in notes finder.

2. <C-n>h to change note roots. this should pop up a float_finder to change which root serve as default. that dialog also supports adding new note roots. renaming, and removing a root.

3. in repo mode, a directory in the repo serves as the default note root for writes purpose. default to workshop/notes

This way, when nvim is started in a parley enabled repo, all notes taken are stored inside the repo itself. Overall, check the chats' repo mode and follow that design.

If there are common code between chat's repo mode and note's repo mode, do extract common code and keep things DRY.
