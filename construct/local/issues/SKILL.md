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
---

# <Title>

## Problem

<What's wrong or what's needed>

## Spec

<Desired behavior, constraints, design decisions>

## Plan

- [ ] <step>

## Log

### YYYY-MM-DD
<dated entries as work progresses>
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

### Required Sections

- **Problem** — what's wrong or needed (for bugs/features) or **Context** (for tasks)
- **Spec** — desired behavior, can start empty with `*(to be filled)*`
- **Plan** — checkable items, update as work progresses
- **Log** — dated entries tracking decisions, discoveries, progress

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

- Set `status` to `done` (or `wontfix`/`punt`)
- Update the `updated` date
- Do NOT move to `workshop/history/` — that happens during periodic cleanup

## Rules

- Always use the YAML frontmatter — it enables tooling and search
- Keep slugs short and descriptive (3-5 words)
- Use `deps` to express blocking relationships between issues
- Log section is append-only — don't edit past entries
