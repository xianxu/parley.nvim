---
id: '000261'
status: done
started: 2026-09-17T08:07:29-07:00
created: 2026-09-15
updated: 2026-09-19
estimate_hours: 30.07
actual_hours: 16.31
---

# Audit transcript as the complete recovery state

## Problem

After the recent generation/document refactor, a chat can become stuck in a
state that is not explained by its Markdown transcript. The observed case was a
question that could no longer be submitted and reported an error after the
transcript had been edited during generation. The intended recovery was simply
to quit Parley and reopen the transcript, but the current session did not
reliably recover that way.

This suggests that generation, pending-batch, document, or presentation state
can remain authoritative outside the transcript after an interrupted or
conflicting edit.
