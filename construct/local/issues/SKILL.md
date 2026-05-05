---
name: xx-issues
description: "Use proactively when creating, updating, or closing issues in workshop/issues/. Ensures consistent frontmatter, section structure, and numbering."
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

Run the **closing checklist** from ariadne AGENTS.md §5 in one sweep — partial closure causes status drift across artifact layers. Specific to this skill:

- Set `status` to `done` (or `wontfix`/`punt`)
- Update the `updated` date
- **Record `actual_hours: <N>` in the frontmatter.** REQUIRED at `done`. Feel-time across the issue's commit window, including side-quests the issue triggered. Without this the velocity calibration loop cannot close. (`wontfix`/`punt` issues don't need this — there's no work to record.)
- Add a final `### YYYY-MM-DD — session summary` entry to the `## Log` if the closing session covered more than the last commit's worth of work.
- If a `## Side quests` section exists, double-check it's complete — grep `git log --grep "side-quest:" <commit-range>` to confirm.
- Do NOT move the file to `workshop/history/` — that happens during periodic cleanup, not at close.

If the issue is part of a multi-issue project (see `construct/datatype/project.md`), also update the parent project file: tick the corresponding task, fill in the detail block's `**actual:** <N>` and `**closed:** <date>`. The project file is the portfolio view; if it lags the issue, the operator can't see real status when they reopen the project days later.

## Rules

- Always use the YAML frontmatter — it enables tooling and search
- Keep slugs short and descriptive (3-5 words)
- Use `deps` to express blocking relationships between issues
- Log section is append-only — don't edit past entries
