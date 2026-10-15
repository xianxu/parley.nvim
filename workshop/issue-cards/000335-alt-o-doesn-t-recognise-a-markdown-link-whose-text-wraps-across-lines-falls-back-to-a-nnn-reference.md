---
id: 000335
status: done
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
github_issue:
started: 2026-10-15T14:41:15-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 1.50
tracker:
    version: 1
    completion:
        token: close-8594e217aa47
        repository: github.com/xianxu/parley.nvim
        reviewed_head: bedfe98eba1d827d1aad6ac2fac7db796a5198f6
        evidence_commit: 64eb0414c257c5b21760c542f074260911507309
        landed_commit: 28c26519b544c659e0692cf37f9dd0fc2ef4429a
---

# Alt+o doesn't recognise a markdown link whose text wraps across lines (falls back to a #NNN reference)

## Problem

2026-10-15: the operator pressed Alt+o on the second line of a markdown link whose **link text wraps across two lines**:

```
… stateful fakes. → [discussion: is this a new
"landing" workflow?](000390-test-economy-pattern-plan.side/01-landing-admission.md)
```

Instead of opening the side doc, parley showed "Resolve #370" (an issue picker): the reference scanner didn't recognise
the wrapped link at all, so #327's enclosing-entity fallback found only the paragraph's `#370` reference and resolved
that. A link with a line break inside its text is valid CommonMark, and agents' hard-wrapped prose produces them.
