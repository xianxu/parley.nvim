---
id: 000274
status: working
deps: []
github_issue:
created: 2026-09-23
updated: 2026-09-23
estimate_hours:
started: 2026-09-23T10:34:00-07:00
flow: {kind: quick, provenance: inferred, spec: "51264e50", done: "381e00aa"}
---

# Record Ariadne remote acquisition source

## Problem

The existing Ariadne substrate row has no acquisition source, so a fresh private environment cannot restore it (ariadne#243).

## Spec

Add the canonical recorded remote https://github.com/xianxu/ariadne.git to the existing substrate ../ariadne declaration. Preserve the destination and all other rows. ARCH-DRY: use existing construct/deps source syntax and acquisition semantics. Work from a fresh origin/main clone; do not publish the operator checkout's unrelated history.

## Done when

- construct/deps contains substrate ../ariadne https://github.com/xianxu/ariadne.git, with no other metadata changes.
- The production dependency parser accepts the row and dry-run reports the expected missing remote source.
- The isolated branch is reviewed and published through the normal SDLC PR flow.

## Plan

- [x] Add the recorded remote and verify parser/dry-run evidence; publication follows the close gate.

## Log

### 2026-09-23

Approved ariadne#243 metadata subtask; canonical Ariadne origin verified as https://github.com/xianxu/ariadne.git. The clone was made directly from origin/main in /tmp, leaving operator branches and working files untouched.

Production `weave dependencies --dry-run` parsed the source and exited 1 with the expected incomplete graph diagnostic naming the missing sibling Ariadne and https://github.com/xianxu/ariadne.git. No dependency clone or package install occurred. Exact construct/deps content checked; the production diff is one line.
