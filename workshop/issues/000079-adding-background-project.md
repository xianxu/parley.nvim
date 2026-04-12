---
id: 000079
status: open
deps: []
created: 2026-04-07
updated: 2026-04-07
---

# adding "background" project

a background project is a project that we know we won't get to, but we want to keep it in mind, as a way pointer, or obstacle we need to address in time. they should be drawn as lighter background color in the color series, with dotted lines. They are denoted as ~ project name, e.g. start with a ~

## Done when

- `~ Project Name` in YAML is parsed as a background project
- `M.is_background(name)` returns true for `~`-prefixed names
- `parse_priority("~Foo!")` → `("Foo", 1)` (strips `~` before bangs)
- DOT export: background nodes rendered with `filled,dashed` style and a lighter `bg` color
- Allocation report: background projects excluded from `demand_weeks`, shown as `[bg]` in a separate section
- Tests pass, lint clean

## Plan

- [ ] Task 1: `is_background` + updated `parse_priority` + tests
- [ ] Task 2: Add `bg` color slot to all 10 `COLOR_SCHEMES`
- [ ] Task 3: DOT export override for background nodes
- [ ] Task 4: Allocation summary — skip demand, flag background
- [ ] Task 5: Allocation report — render `[bg]` section
- [ ] Task 6: Run tests + lint, update issue status

## Log

### 2026-04-07

