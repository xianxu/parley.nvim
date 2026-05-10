---
name: xx-issues
description: "Use when editing issues in workshop/issues/."
---

# Issues

Create and manage issues in `workshop/issues/` with consistent format.

## Usage

```
/xx-issues create <slug>
/xx-issues close <id>
```

Or invoked automatically when you are about to create an issue file.

## Issue File Format

Every issue file MUST follow this structure:

### Filename

`workshop/issues/NNNNNN-<slug>.md` — zero-padded 6-digit ID, kebab-case slug.

To determine the next ID, find the highest existing ID in `workshop/issues/` and `workshop/history/` and increment by 1.

### Template

```markdown
---
id: NNNNNN
status: open
deps: []
github_issue:
created: YYYY-MM-DD
updated: YYYY-MM-DD
estimate_hours:    # optional at create; required when status flips to working
actual_hours:      # required when status flips to done
---

# <Title>

## Problem

<What's wrong or what's needed>

## Spec

<Desired behavior, constraints, design decisions>

## Plan

- [ ] <step>

## Log

### YYYY-MM-DD — session summary
<one paragraph per major sitting (or milestone close): what was
attempted, what landed, what got deferred, in-flight design
decisions worth remembering. Replaces "you'd have to read
transcripts" with explicit handoff to future-you / future agent.>

### YYYY-MM-DD
<dated entries for individual decisions, discoveries, side-quests
that don't fit a session-summary block>

## Side quests
<optional; recommended for multi-day issues. One line per
unbudgeted-but-shipped piece of work — name + ~time + commit ref.
Example:

  - Makefile dev-unsign rule (~30 min) — `802c1bf`
  - OSC 8 hyperlinks on catalog URLs (~40 min) — `cb98234`

Pairs with the `side-quest:` commit verb (see ariadne AGENTS.md
§12). Lets retrospective + velocity calibration count effort that
otherwise dissolves into the diff.>
```

### Frontmatter Fields

| Field | Required | Values |
|-------|----------|--------|
| `id` | Yes | 6-digit zero-padded integer matching filename |
| `status` | Yes | `open`, `working`, `blocked`, `done`, `wontfix`, `punt` |
| `deps` | Yes | List of issue IDs this depends on, e.g. `[000005]` |
| `github_issue` | No | GitHub issue number if linked |
| `created` | Yes | ISO date |
| `updated` | Yes | ISO date |
| `estimate_hours` | When status≥working | Single integer (P50 of estimate range). Pulled from a `## Estimate` section if one exists; produced by the velocity skill or equivalent. Empty when an estimate hasn't been done yet (e.g., status=open). |
| `actual_hours` | When status=done | Required at close. Feel-time across the issue's commit window, including side-quests it triggered. Without this the velocity calibration loop cannot close — see ariadne AGENTS.md §4 + §5 closing checklist. |

### Required Sections

- **Problem** — what's wrong or needed (for bugs/features) or **Context** (for tasks)
- **Spec** — desired behavior, can start empty with `*(to be filled)*`
- **Plan** — checkable items, update as work progresses
- **Log** — dated entries tracking decisions, discoveries, progress. Use a `### YYYY-MM-DD — session summary` heading for major-sitting wrap-ups (one paragraph each); plain `### YYYY-MM-DD` for individual entries.

### Optional Sections

- **Estimate** — present when the issue was estimated. Carries the headline range, provenance string (which version-pair of the estimator produced it), and decomposition. See ariadne AGENTS.md §4 for the paired-versioned-files pattern.
- **Side quests** — recommended for multi-day issues that trigger unbudgeted work. One line per item: name + ~time + commit ref. Pairs with the `side-quest:` commit-verb convention (ariadne AGENTS.md §12).

## Process

### Creating an issue

1. Scan `workshop/issues/` and `workshop/history/` for the highest existing ID
2. Increment by 1 for the new ID
3. Create the file using the template above
4. Fill in Problem/Context section at minimum

### Updating an issue

- Set `updated` date in frontmatter when making changes
- Mark plan items complete as work finishes
- Add dated log entries for significant progress or decisions
- Update `status` field to reflect current state

### Closing an issue

Run `make close-issue` and follow the script's prompts:

```
make close-issue ISSUE=<N> [MILESTONE=Mx] ACTUAL=<hours> VERIFIED='<one-line evidence>'
```

The script enforces ariadne AGENTS.md §5: `status: done`, `actual_hours: <N>`, atlas/ change in the commit window, log entry. It refuses without ACTUAL or VERIFIED — its missing-arg explainer prints the exact `active-time-v3.py` command tailored to this issue's commit window (with peer issues auto-discovered, so the v3 attribution doesn't fall into mention-fallback). Run that command, read the `# per-issue totals` line for `#<N>`, re-run `make close-issue` with ACTUAL filled in.

What the script doesn't do — judgment steps the agent owns:
- Inspecting the per-segment table to spot misclassified work
- Deciding whether a discovered peer issue is real work or a stray mention
- Choosing the rounded ACTUAL value
- Writing the VERIFIED one-liner (behavior evidence, not "code written")

What the script does do automatically when invoked from a clean close:
- Tick the milestone in the issue's `## Plan` (milestone close) or `status: done` flip (issue close)
- Set `actual_hours`, `updated`
- Append a `## Log` entry with VERIFIED
- For project-tracked issues: tick the corresponding task in the parent project file, fill in the detail block's `**actual:**` and `**closed:**`
- Refuse close if a milestone has unchecked plan items, or if no atlas/ change touched the commit window (set `FORCE=1` to bypass with VERIFIED rationale)

Do NOT move the file to `workshop/history/` — that happens during periodic cleanup, not at close.

The full v3 attribution method (commit-anchored segment-local, why we ditched v2.1's session-wide mention-weighting, calibration data points) lives in `brain/data/life/42shots/velocity/baseline-v3.md` for when you want the deep-dive.

## Cross-repo references

When referencing an issue **outside the current repo** (e.g., a brain
note pointing at a parley issue, a parley issue depending on work in
ariadne), use the qualified form `<repo>#<NNN>`:

- `parley.nvim#123` — issue 123 in the `parley.nvim` repo
- `brain#42` — issue 42 in the `brain` repo

Within the current repo, keep using bare `#NNN`. The qualifier exists
to disambiguate cross-repo references; using it everywhere is just
noise.

This mirrors GitHub's `owner/repo#NNN` convention for cross-repo issue
references — readers already parse it correctly. The repo slug is the
directory name (and matches the workspace layout where peers live as
sibling directories).

**Why the bare form needs disambiguation across repos:** issue numbers
restart at 1 in every repo, so `#42` is ambiguous when context spans
multiple repos. It also collides badly with **forked-upstream history**
— a fork's git log can contain commits from before the fork-point that
mention the upstream's old `#42` (a different issue entirely). Tools
like `close-issue.py` work around this with a 1-month window cap, but
qualified references are the principled fix going forward.

**Where qualified refs apply:**

- `deps:` frontmatter for cross-repo dependencies: `deps: [parley.nvim#119]`
- Issue body / plan / log when pointing at peer-repo work
- Brain notes, project files, and roadmaps that span multiple repos
- Commit subjects on cross-repo work (rare — usually the commit lives
  in the repo whose issue it advances, so bare `#NNN` is correct there)

**Transition note:** existing bare `#NNN` references across the
codebase remain valid. Tools that grep for issue references should
match both `#NNN` and `<repo>#<NNN>` during the transition. Over time,
qualified refs accumulate naturally in cross-repo contexts without a
flag day.

## Rules

- Always use the YAML frontmatter — it enables tooling and search
- Keep slugs short and descriptive (3-5 words)
- Use `deps` to express blocking relationships between issues; use
  qualified `<repo>#<NNN>` form when the dependency lives in a peer repo
- Log section is append-only — don't edit past entries
