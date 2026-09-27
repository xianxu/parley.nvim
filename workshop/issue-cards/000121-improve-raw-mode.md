---
id: '000121'
status: done
created: 2026-05-06
updated: 2026-05-06
actual_hours: 5
---

# improve raw mode

## Problem

Raw mode is not useful, as it operates within the buffer. it's purpose is for debugging and learning, and it should be logged to a side file. basically what is sent and what's received each turn, at two levels, the exchange level, and the raw request/response level. log them into two different files with proper formatting for both human and machine's inspection. sort of mirror structure to parley chat's transcript.
