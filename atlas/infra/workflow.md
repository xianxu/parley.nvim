# Optional maintainer development workflow

This page describes development of Parley and ariadne-style repositories. It is
not required to install the app, chat, use tutorials, or run ordinary plugin tests.
The application does not install the `sdlc` command or the repository's agent
infrastructure. See [issue management](../issues/issue-management.md) for Parley's
optional issue UI and [the test harness](test_harness.md) for standalone tests.

## Current workflow contract

Maintainers use `sdlc --help` and the repository's `AGENTS.md` as the current
contract. Internal work is recorded in `workshop/issues/NNNNNN-slug.md` with
`## Spec`, checkable `## Plan`, and `## Log`; complex designs add a durable
`workshop/plans/NNNNNN-slug-plan.md`. Status vocabulary ships in
`construct/generated/vocabulary/issue.json`.

The normal sequence is `sdlc issue new`, `sdlc claim`, `sdlc start-plan`, design
and approval, then `sdlc change-code`. Sync evolving issue text with
`sdlc issue sync`. After implementation and verification, `sdlc close` runs the
required review. Publish through `sdlc pr` and `sdlc merge`; lifecycle tools own
status changes and archival. Read each command's help for required evidence,
branch/worktree choices and recovery. `sdlc state` reports the current state.

GitHub Issues are an external inbox. `sdlc issue new --from-github N` imports a
report into the internal tracker. Parley's `:ParleyIssueNew` invokes that optional
command family; creating a chat does not invoke it.

## Boundaries and evidence

The root Makefile and runtime vocabulary ship in public checkouts. Maintainer
bootstrap restores additional ignored workflow infrastructure; its commands must
not be presented as app features or standalone contributor prerequisites.
`TOOLING.md` documents portable test commands. `lua/parley/issues.lua` owns the
optional command adapter; `tests/integration/issue_command_spec.lua` verifies it
against a filesystem-backed fake rather than publishing real issues.
