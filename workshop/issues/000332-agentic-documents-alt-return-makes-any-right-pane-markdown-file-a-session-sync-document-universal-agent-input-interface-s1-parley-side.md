---
id: 000332
status: open
deps: []
github_issue:
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
card_mirror: '4e38f95cd7a71c67c983d6d2e4777d20ddcbdaa6' # card fields mirrored from issue-cards; edit via sdlc
---

# Agentic documents: Alt+Return makes any right-pane markdown file a session-sync document (universal-agent-input-interface S1, parley side)

## Problem

Project universal-agent-input-interface (ops `teams/devinfra/projects/universal-agent-input-interface/`, design in
`design.md`, slice S1): today only files with `type: session-sync` get the operator lock, Alt+Return submit and the
red winbar. The operator wants any markdown file opened in Couch's right-pane nvim to become an **agentic document**
at its first Alt+Return.

## Spec

- Any markdown buffer in the right-pane nvim (detected from the pane's pair environment) can be submitted with
  Alt+Return. The first submit registers the file as agentic with Couch (Couch-side registry keyed by canonical path;
  nothing is written into the file) and sends it to **the pane's own slot** ("the agent on the left"). An explicit
  `couch-owner:` in the frontmatter, if present, still wins.
- From then on the existing session-sync behaviour applies unchanged: operator lock on the first edit (parley#324),
  undo-to-baseline release (#330), the red winbar while the operator holds the lock, the band, owed pings.
- A file that was never submitted stays plain nvim: no lock, no band.
- Renaming or moving an agentic file keeps it agentic (registry follows the path) and renames its `<name>.side/`
  folder (S3 relies on this).

## Done when

- A plain note in the right pane, after one Alt+Return, is locked on the next edit (red winbar), an agent write is
  refused while it's held, and the submit reaches the pane's slot.
- A never-submitted file shows no lock or band.
- Headless tests with the real auto-save setup (as in #324) cover first submit, lock, rename, and an explicit
  `couch-owner:` override. Depends on the pair (Couch) S1 issue for the registry verbs.

## Plan

- [ ]

## Log

### 2026-10-15
