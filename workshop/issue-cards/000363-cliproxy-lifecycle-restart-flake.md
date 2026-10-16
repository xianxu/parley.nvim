---
id: 000363
status: open
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
github_issue:
---

# Cliproxy credential-restart lifecycle cases intermittently time out and probe the killed port

## Problem

First seen 2026-10-16 during #353's required suite on `aa8a3408fd3338402eb949a7c275335bd9c9966f`. `tests/integration/cliproxy_lifecycle_spec.lua` failed two credential-restart cases under parallel load; the other453 spec files passed, lint760 clean, no surviving test processes. The same lifecycle spec passed earlier full runs on the preceding #353 source/integrated heads. This module, test and await helper have no branch diff against main.
