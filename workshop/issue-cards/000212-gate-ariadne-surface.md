---
id: 000212
status: open
created: 2026-09-02
updated: 2026-09-02
estimate_hours:
github_issue:
---

# gate the ariadne surface behind repo detection

## Problem

The ariadne workflow surface is registered unconditionally for every user, and
then fails *silently* for anyone without an ariadne repo — which is worse than
failing loudly.

`init.lua:851-852` passes `register_global` a **literal** scope list,
`{ "global", "repo", "note", "issue", "vision", "chat" }`, never filtered by
`.parley` presence. The seven ariadne modules are also `require`d unconditionally
at `init.lua:69,70,97,111,115,119,123`. Consequences for a plain user:

| Feature | What they see | Decided at |
|---|---|---|
| Issue finder `<C-y>f` | Empty picker, no error — `issues_dir` always resolves against git root so the guard cannot fire | `issues.lua:474-476` |
| New issue `<C-y>c` | Prompt, spinner, then `Issue creation failed:` | `issues.lua:752-776` |
| Vision finder `<C-j>f` | Empty picker, no error | `vision_finder.lua:53` |
| Vision export | Writes an empty `roadmap.csv`/`roadmap.dot` into their git root | `vision.lua:1626-1631` |
| `gf` on a plain `#42` | `sdlc` not found; native `gf` never attempted | `artifact_ref.lua:115-131` |

Additionally `<C-n>i`/`<C-n>I` are bound globally and are not rebindable
(`keybinding_registry.lua:305-318`), four `<leader>c*` maps are claimed in every
buffer with zero tests for `parley.copy`, and `<C-g>?` *hides* the repo/issue/
vision bindings outside a repo (`keybinding_registry.lua:66-68`) — so help and
reality disagree in both directions at once.

Separately, `skills/review/SKILL.md:1` links the marker grammar to
`../../../../ariadne/workshop/targets/review-convention.md` — a sibling repo that
does not ship — and that file is sent to the model as system prompt.
`drill_in.lua:31,514` names the same out-of-repo spec as normative for `<M-q>`.
