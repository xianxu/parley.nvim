---
id: '000049'
status: done
created: 2026-04-02
updated: 2026-04-03
actual_hours: N/A
---

# chat link behavior

## Problem

I want to further tune chat link behavior. at some point, I changed it such that inserting into non-chat window of new chat link, it will use absolute link, on the ground that the chat doesn't exist relative to that non-chat file. However, this makes link just too verbose I feel. Now I think on balance, in non-chat file, we should insert using "relative" path, basically file name only.

When opening it though, we should look through all current registered chat roots, starting with the default root. chat files are largely unique, and the semantic we provided would move them around, not easily cloning them. so this should work reasonably well.
