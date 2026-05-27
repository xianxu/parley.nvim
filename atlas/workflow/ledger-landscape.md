# Ledger Landscape — Where State and Evidence Live

## Principle

No single ledger answers all questions. Match the ledger to the question.

State and evidence in ariadne are distributed across many surfaces, each tuned for a specific question. Conflating ledgers (or duplicating fact across them) creates drift; respecting the separation keeps the system inspectable.

## The ledgers

| Ledger | Lives in | What it answers | Audience |
|---|---|---|---|
| Issue body (`## Spec`, `## Plan`) | `workshop/issues/<N>-*.md` (git) | What are we building, and how? | humans + agents reading the issue |
| Issue Log section | same file (git) | What happened during the work, narratively? | humans skimming the issue |
| Plan file (complex case) | `workshop/plans/<N>-*-plan.md` (git) | Detailed implementation breakdown — Core concepts, file structure, bite-sized tasks | execution sessions, milestone reviewers |
| Target file | `workshop/targets/<slug>.md` (git) | What shape do we defend against drift? | humans + agents reading the system |
| Project file | `brain/data/project/<slug>.md` (git) | Portfolio status — actuals, scope events, multi-issue progress | the operator's portfolio view |
| Atlas entries | `atlas/**.md` (git) | How is the system built — architectural map | first-level onboarding |
| Git commits (messages + trailers) | git history (immutable) | What changed, why, and what checkpoint state was crossed? | tooling, history readers, audit |
| Claude transcripts | `~/.claude/projects/<repo-id>/*.jsonl` (local) | What was the AI actually saying that day? | audit, active-time-v3, memory writers |
| Memory files | `~/.claude/projects/.../memory/*.md` (local) | What facts about user / repo / collaboration persist across sessions? | future Claude sessions (auto-loaded via MEMORY.md) |
| Lessons | `workshop/lessons.md` (git) | What patterns went wrong; rules to prevent recurrence | review agents, future sessions |
| Pensive / Parley | `docs/vision/*-pensive-*.md`, `workshop/parley/<chat>.md` (git) | What was the brainstorm before this work crystallized? | humans tracing intent |
| History archive | `workshop/history/` (git) | What we did, archived for the rare lookback | low-signal; avoid unless asked |

## Design principles

1. **Append-only.** Logs accumulate; don't mutate old entries. Git enforces this for commits and committed files; convention enforces it for Log sections. When intent shifts mid-stream, add a `## Revisions` entry (per AGENTS.md §1) — don't rewrite history.
2. **One authoritative source per fact; simple mirrors where helpful.** Drift comes from duplicated mutable state. If a fact lives in two places, designate one as authoritative.
3. **Tooling reads the authoritative; humans read the mirror.** Two surfaces is OK when the mirror is derivable.
4. **Cross-machine durability matters.** Transcripts and memory files live on individual disks — they don't ship in git. For team-shared or operator-portable state, only git-tracked surfaces are reliable.
5. **The right ledger matches the question.** "Was the checkpoint crossed?" wants a structured marker. "What was said in detail?" wants the full transcript. Different questions, different ledgers.

## Choosing a ledger — worked examples

**"Was the post-milestone code review conducted, and what was the verdict?"**
- *Authoritative:* git commit trailer on the milestone-close commit (`Review-Verdict: SHIP`). Parseable, immutable, ships in git.
- *Human mirror:* Log line in the issue file (`review verdict: SHIP`).
- *Audit:* transcript captures the full judge output if detail is needed.
- *NOT* in the project file — that tracks portfolio status, not per-milestone evidence.

**"How many hours did this issue actually take?"**
- *Authoritative:* `actual_hours:` in the issue frontmatter, derived from `active-time-v3.py` over the commit window.
- No mirror needed — frontmatter is already terse.

**"What's the current convention for human-machine markdown markers?"**
- *Authoritative:* the target file (`workshop/targets/review-convention.md`). Targets are commitments.
- *Reference:* atlas may point to the target.

**"What was the operator thinking when they proposed this feature?"**
- *Primary:* the pensive or parley file that crystallized into the issue.
- *Secondary:* `## Spec` in the issue (distilled).
- *Audit:* transcript of the brainstorming session.

**"What does this codebase look like architecturally?"**
- *Authoritative:* atlas/. Updated at milestone close per AGENTS.md §8.
- *NOT:* commit messages or Log entries — atlas is the durable map.

**"Why does this convention exist and what trade-offs were considered?"**
- *Primary:* the issue file's `## Spec` section, or the pensive/parley that fed it.
- *Audit:* commit messages along the work (per AGENTS.md §12, commit body explains why).

## Commit trailers — the structured checkpoint ledger

Conventional git trailers (`Key: Value` at the end of a commit message, preceded by a blank line) extend the commit-as-ledger pattern with machine-parseable fields. Already in use: `Co-Authored-By:`. Per-checkpoint additions over time:

- `Review-Verdict:` — milestone-review verdict (SHIP | FIX-THEN-SHIP | REWORK | not-run)
- `Review-Window:` — `<base>..<head>` SHAs the review covered
- `Review-Reason:` — when `not-run`, why (e.g., `--no-judge` + reason)

Future trailers may emerge as more checkpoints land. Tooling reads trailers via `git log --grep "Key:"`. Operators rarely need to read trailers directly; they read the Log mirror.

## Related

- [`atlas/workflow/artifact-hierarchy.md`](artifact-hierarchy.md) — narrower view focused on `workshop/` paths and their lifecycle.
- [`AGENTS.md`](../../AGENTS.md) §1 — artifact hierarchy and revisions discipline.
- [`AGENTS.md`](../../AGENTS.md) §5 — verification-before-done; testing threads through stages.
- [`AGENTS.md`](../../AGENTS.md) §8 — atlas / project file maintenance discipline.
- [`AGENTS.md`](../../AGENTS.md) §12 — commit conventions (subject shape, body for why).
- `sdlc --help` — canonical SDLC stage narrative; checkpoint guards.
