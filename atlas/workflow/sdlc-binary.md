# sdlc binary

`sdlc` is the SDLC checkpoint binary — one Go binary at `cmd/sdlc/`
that collects ariadne's Makefile-target checkpoint guards into a
unified verb namespace with embedded `--help` per subcommand.

Design rationale: `docs/vision/2026-05-25-01-pensive-sdlc-checkpoint-binary.md`.
Build issue + plan: `workshop/history/000031-sdlc-checkpoint-binary.md`
(after archive) or `workshop/issues/000031-...` (during build).

## What it owns

The **checkpoints between SDLC stages** — not the stages themselves.
Stages stay prose; the binary refuses transitions that lack required
evidence. Subcommands are added incrementally when the same drift
recurs at a stage (not by formalizing the SDLC as a state machine).

## Verb surface

| Verb              | Replaces (Make target)      | Defends |
|-------------------|-----------------------------|---------|
| `close`           | `make close-issue`          | Issue close: actual + verified + atlas + plan ticked |
| `state`           | (new)                       | Workflow state inspection + drift detection |
| `judge`           | `make check-{dry,pure,plan,specs,lessons}` | Fresh-context LLM judge (anti-collusion) |
| `fetch`           | `make fetch N`              | Issue-file shape on GitHub import |
| `start`           | `make worktree`             | Branch creation from untracked issue |
| `lock`            | `make issue-sync`           | Issue-file workstream-claim onto main |
| `set-status`      | (new)                       | Status-transition guards (xx-issues contract) |
| `push`            | `make push`                 | Direct-on-main ship + pre-flight judges |
| `pr`              | `make pull-request`         | PR creation with Fixes-issue body |
| `merge`           | `make merge`                | Worktree merge + cleanup + irreversible-action confirm |
| `milestone-close` | `make close-issue MILESTONE=Mx` | Milestone close + auto-dispatched milestone-review |

## Progressive disclosure

  - `sdlc --help` — top-level skill narrative + cobra-generated verb list
  - `sdlc <verb> --help` — per-checkpoint contract + flags + examples
  - `sdlc --index` — emits SKILL.md content (helptext/index.md + auto-
    generated `## Verb reference` from the live cobra registry)
  - `sdlc state` — runtime "where am I" surface for compaction recovery

`construct/local/sdlc/SKILL.md` is regenerated from the binary via
`sdlc --index > construct/local/sdlc/SKILL.md`. Do not hand-edit;
edit `cmd/sdlc/helptext/index.md` (the narrative source) instead.

## Architecture

```
cmd/sdlc/
  main.go              cobra root, --index handler, verb registration
  term.go              cinfo / cok / cwarn / die + env helpers (shared)
  runner.go            gitRunner interface + execGitRunner impl (shared)
  ghclient.go          ghCaller interface + realGH impl (shared)
  preflight.go         runPreflightJudges (push + merge pre-flight)
  close.go             ← scripts/close-issue.py
  state.go             new (read-only inspection + drift detection)
  judge.go             ← scripts/pre-merge-checks.sh
  fetch.go             ← Makefile fetch:
  start.go             ← Makefile worktree:
  lock.go              ← scripts/issue-sync.sh
  setstatus.go         new
  push.go              ← Makefile push:
  pr.go                ← Makefile pull-request:
  merge.go             ← Makefile merge:
  milestoneclose.go    composition over close + judge milestone-review
  helptext/            //go:embed *.md — one .md per verb + root + index
  internal/
    gitx/              git invocation seam (`run` shim, Capture, DiffBase,
                       CommitWindow, DiscoverWindowIssues, RunGit)
    issue/             frontmatter parse/edit + plan-section regexes
    judge/             Category enum, prompt builder, classify, dispatch
    project/           brain project-file mutation helpers
```

## Anti-collusion + form-vs-essence

Checkpoint guards defend against **omission** (claiming done without
doing) via deterministic checks (`close` refuses without `--actual` +
`--verified`). The judge subcommand defends against **theater** (form
without substance) via fresh-context LLM review — every Dispatch call
spawns a new subprocess; the agent has no doer-session state.

`push` and `merge` auto-dispatch `judge plan|specs|lessons` as pre-
flight so the checks run consistently rather than as a remembered
manual step. `milestone-close` auto-dispatches `judge milestone-review`
as a post-action.

## Build + install

```
make sdlc-build        builds cmd/sdlc/bin/sdlc, symlinks bin/sdlc
make sdlc-bootstrap    one-shot install: verify Go, build, symlink to
                       $SDLC_INSTALL_BIN (default ~/bin)
```

`make build` also picks `sdlc` up via the cmd/*/main.go scanner.

## Makefile wrappers (transition state)

Each Make target delegates to `bin/sdlc` when built, falling back to
the original shell logic when absent:

  `make close-issue` → `sdlc close`
  `make fetch <N>`   → `sdlc fetch --github-issue N`
  `make worktree`    → `sdlc start`
  `make issue-sync`  → `sdlc lock`
  `make push`        → `sdlc push`
  `make pull-request` → `sdlc pr`
  `make merge`       → `sdlc merge`
  `make check-<cat>` → `sdlc judge <cat>`

The fallback exists so downstream repos that vendor `Makefile.workflow`
but haven't yet run `make sdlc-build` keep working. M8 (not yet started)
deprecates the shell fallbacks and removes the scripts.

## When to add a new verb

The rule from the pensive: **when the same drift gets caught at review
twice**, promote it from a `workshop/lessons.md` entry to an `sdlc <verb>`
check. The first time → prose. The second time → code.

Do not formalize the workflow into a state machine. Add checkpoint
guards for known commit moments where drift recurs; everything between
checkpoints stays prose-driven.
