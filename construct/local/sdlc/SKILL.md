---
name: sdlc
description: Use when at an SDLC checkpoint — closing an issue or milestone, opening/merging a PR, starting work, running a principle check, or recovering workflow state after compaction. The `sdlc` binary owns the gates between workflow stages; checkpoint guards refuse transitions that lack required evidence.
---

# sdlc — SDLC checkpoint binary

This skill is provided by the `sdlc` binary. The prose below is regenerated
from the binary itself — do not hand-edit. To refresh after the binary
changes:

    sdlc --index > construct/local/sdlc/SKILL.md

For interactive help:

    sdlc --help                top-level: this prose + the verb list
    sdlc <verb> --help         depth on one checkpoint

## What this skill is

sdlc collects ariadne's SDLC checkpoint guards into one binary. Each
subcommand owns one checkpoint: it requires evidence at the gate, mutates
state, logs the transition. The binary refuses transitions that lack the
evidence — that is the shape of "checkpoint guard."

We do not model the SDLC as a state machine. We name the stages in prose
and codify the gates between them where drift recurs. Subcommands are added
incrementally; prose remains the substrate.

## Workflow stages

The ariadne SDLC flows through these stages. The `sdlc` binary owns the
checkpoints *between* stages; the stages themselves stay prose and human-driven:

1. **Ideation** — `workshop/parley/`, `docs/vision/` (pensives)
2. **Brainstorming** — `superpowers-brainstorming`
3. **Planning** — `superpowers-writing-plans` → inline in `workshop/issues/` or separate in `workshop/plans/`
4. **Build** — `superpowers-executing-plans`, milestones in `workshop/issues/`
5. **Milestone review** — `sdlc judge` (auto-dispatched from `sdlc milestone-close`)
6. **Close / ship** — `sdlc close` → `sdlc push` (main) or `sdlc pr` → `sdlc merge` (branch)
7. **Postmortem** — `sdlc postmortem` (ariadne#35; auto-dispatched from close), `xx-introspect` (cross-session taste mining), `workshop/lessons.md`

**Target authoring is not a stage** — promoting a pattern into a target (`workshop/targets/`) is a datatype operation, not a workflow phase. It can happen anytime recognition fires: a pensive crystallizes when the thought stabilizes into a commitment worth defending against drift; postmortem (stage 7) surfaces "crystallization candidates" as one of its LLM-judgment sections; direct authoring is also fine. The trigger is recognition, not procedure. See `construct/datatype/target.md` for the full authoring contract.

**Testing is not a stage** — it threads through Planning (Core concepts table names PURE / INTEGRATION entities, implying test surface), Build (TDD red-green-refactor in-line; tests next to entities; verification-before-completion gates each step), and Milestone review (judge cross-checks "PURE entities test without IO; if tests need mocks, promote to INTEGRATION"). When a feature needs test infrastructure (process-level fake for an external service: GitHub, Gmail, Anthropic API), that infrastructure is itself a feature and runs through stages 1-5 like any other.

## Conventions

**Flag convention** — `--issue N` always refers to an ariadne workshop issue
(6-digit ID, in `workshop/issues/` or `workshop/history/`). `--github-issue N`
refers to a GitHub issue number. The bare `--issue` flag never means a GitHub
issue. The convention applies across all subcommands.

**Form vs essence** — Checkpoint guards (`close`, `milestone-close`, `push`,
`merge`) defend against *omission* via required-evidence flags. The `judge`
subcommand defends against *theater* via fresh-context LLM review
(anti-collusion: the judge sees no doer state). Form runs first because it's
deterministic; judge runs second on what survived form.

**State recovery** — `sdlc state` is the canonical "where am I" surface; after
a compaction the agent reads it instead of re-inferring from issue files. The
binary owns the mutating path (`close`, `set-status`, `milestone-close`);
reads remain free-form, so drift is detectable by `sdlc state`.

## Subcommands

| Verb              | Stage              | What it guards |
|-------------------|--------------------|----------------|
| `close`           | close / ship       | Evidence (`--actual`, `--verified`), atlas/ touched, plan ticked |
| `state`           | (recovery)         | (reads only; surfaces drift) |
| `judge`           | milestone review   | Fresh-context LLM check against the diff |
| `fetch`           | ideation / planning | Issue file shape, ID assignment, frontmatter |
| `start`           | build              | One-untracked-issue auto-detect, pre-commit before branch |
| `lock`            | build              | Issue file on main before parallel work |
| `set-status`      | build              | Status transitions (`working` needs estimate; `done` delegates to `close`) |
| `push`            | close / ship       | Clean tree, pre-merge judges, archive done issues |
| `pr`              | close / ship       | Branch ≠ main, links touched issues into PR body |
| `merge`           | close / ship       | Upstream synced, undone-issue scan, irreversible-action confirm |
| `milestone-close` | milestone review   | Plan ticked, atlas touched, judge milestone-review dispatched |

## When to invoke

- At a known SDLC commit moment (closing, shipping, opening a PR, starting work) — invoke the matching verb.
- After compaction or session resume — run `sdlc state` to recover.
- Before manual `git push` to main — run `sdlc push` instead (it bundles the checks).
- When in doubt about a flag — `sdlc <verb> --help`.

## What this skill is not

- **Not a workflow driver.** The agent decides *when* to invoke; the binary decides whether the transition is *valid*.
- **Not a state machine.** Stages stay prose. Only the gates are codified.
- **Not a substitute for review.** Checkpoint guards raise the floor (omission); the judge subcommand raises the ceiling (theater). Both layers needed.

## Verb reference (generated)

Reproduced from cobra at build time. Drift between this table and
the live binary is impossible — both render from the same registry.

- `sdlc close` — Close an issue or milestone (records ACTUAL + VERIFIED, mutates issue + project files)
- `sdlc fetch` — Fetch a GitHub issue and create a local workshop/issues/ file
- `sdlc judge` — Run an LLM-as-judge check against the current diff (fresh context, anti-collusion)
- `sdlc lock` — Sync workshop/issues/ changes to origin/main (workstream-claim primitive)
- `sdlc merge` — Merge the current worktree branch via GitHub, archive done issues, clean up worktree
- `sdlc milestone-close` — Close one milestone of an issue + auto-dispatch post-milestone review (AGENTS.md §3)
- `sdlc pr` — Open a PR for the current worktree branch (scans touched issues for fixes)
- `sdlc push` — Ship from main: auto-commit, run pre-merge judges, push, archive done issues
- `sdlc set-status` — Flip an issue's status: with transition guards
- `sdlc start` — Create a new git worktree on a fresh branch (auto-detects from untracked issue file)
- `sdlc state` — Inspect SDLC workflow state (read-only, JSON optional)

For each verb's full contract:

    sdlc <verb> --help

────────────────────────────────────────────────────────────
Regenerated from `sdlc --index`. Edit helptext/index.md (the
narrative source) or this binary's subcommand registry, then re-run.
