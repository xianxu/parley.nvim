# Tool Input Safety Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `ls`, `grep`, `find`, and installed optional `ack` familiar to agents while eliminating shell injection and cwd/read-root escapes.

**Architecture:** Add one shared pure argv-validation module for builtin read commands, then keep each tool handler as a thin IO wrapper that calls the real binary with an argv list. Reuse dispatcher path confinement by exposing structured `path`/`paths` fields instead of hiding path text inside a shell fragment (`ARCH-DRY`, `ARCH-PURE`, `ARCH-PURPOSE`).

**Tech Stack:** Lua, Neovim `vim.fn.system`, Plenary tests via `make test-spec` or `make test`.

---

## Core Concepts

### Pure Entities

| Name | Lives in | Status |
|------|----------|--------|
| `BuiltinArgv` | `lua/parley/tools/builtin/argv.lua` | new |
| `LsInput` | `lua/parley/tools/builtin/ls.lua` | modified |
| `GrepInput` | `lua/parley/tools/builtin/grep.lua` | modified |
| `FindInput` | `lua/parley/tools/builtin/find.lua` | modified |
| `AckInput` | `lua/parley/tools/builtin/ack.lua` | modified |

- **BuiltinArgv** — shared pure helpers for validating positive flag allowlists, compact `ls` flags, bounded integers, and argv assembly errors.
  - **Relationships:** 1:N with builtin command handlers; each handler owns a local tool-specific allowlist constant and calls the shared helper.
  - **DRY rationale:** Avoids three separate ad hoc flag validators and gives the security-sensitive argv boundary one small module to audit.
  - **Future extensions:** If safe pipeline composition is later added, it can reuse this module for per-stage validation before composing stages.

- **LsInput** — structured input contract for listing one confined path with allowlisted display flags.
  - **Relationships:** 1:1 with `ls` handler; dispatcher owns path canonicalization before the handler runs.
  - **DRY rationale:** Uses the shared helper for flags and relies on dispatcher path policy rather than duplicating cwd checks.
  - **Future extensions:** Add a structured `glob` field if users need shell-glob-like filtering without shell expansion.

- **GrepInput** — structured input contract for searching confined paths with `pattern`, optional `glob`/`type`, context counts, and safe matching/output flags.
  - **Relationships:** 1:1 with `grep` handler; maps to `rg` when present, otherwise a smaller `grep` argv.
  - **DRY rationale:** Keeps pattern/path separation explicit so shell metacharacters cannot become syntax.
  - **Future extensions:** Additional read-only `rg` options can be added to the allowlist with tests.

- **FindInput** — structured input contract for file discovery by path, name/iname, type, and depth. It deliberately has no generic `flags` array.
  - **Relationships:** 1:1 with `find` handler; intentionally narrower than arbitrary `find` expressions.
  - **DRY rationale:** Reuses shared flag/depth validation while preventing duplicated rejection logic for dangerous actions.
  - **Future extensions:** Add more predicates one at a time when they are read-only and testable.

- **AckInput** — structured input contract for optional `ack` search using pattern/path/type/context fields. It deliberately removes the raw `command` string and has no generic `flags` array.
  - **Relationships:** 1:1 with `ack` handler when `ack` is installed; dispatcher owns path canonicalization before the handler runs.
  - **DRY rationale:** Reuses shared argv/path helpers so optional search tools do not become a second safety policy.
  - **Future extensions:** Add explicit read-only ack options one at a time with regression tests.

### Integration Points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `BuiltinCommandHandlers` | `lua/parley/tools/builtin/{ls,grep,find,ack}.lua` | modified | system `ls`/`rg`/`grep`/`find`/`ack` binaries |
| `DispatcherPathPrelude` | `lua/parley/tools/dispatcher.lua` | modified | cwd/read-root path resolution |

- **BuiltinCommandHandlers** — thin handlers that validate input, build argv, run the detected binary, and format results.
  - **Injected into:** Tool registry as existing builtin definitions.
  - **Future extensions:** Later safe-pipeline support should compose validated handler argv lists, not raw shell strings.

- **DispatcherPathPrelude** — extends existing `path`/`file_path` checks to structured `paths` arrays so multi-path read tools inherit cwd/read-root confinement.
  - **Injected into:** Every tool call before handler execution.
  - **Future extensions:** Other tools with array path inputs can reuse the same prelude.

## Chunk 1: Tests First

### Task 1: Add failing safety tests

**Files:**
- Create: `tests/unit/tools_builtin_ls_spec.lua`
- Create: `tests/unit/tools_builtin_find_spec.lua`
- Modify: `tests/unit/tools_builtin_grep_spec.lua`
- Modify: `tests/unit/tools_dispatcher_spec.lua`

- [ ] **Step 1: Write failing tests for `ls`**

Add tests proving:
- `handler({ path = ".", flags = { "-l" } })` succeeds.
- `handler({ path = ".", flags = { "-lah" } })` succeeds because every compact character is allowlisted.
- `handler({ path = ".", flags = { "-l; echo INJECTED" } })` returns `is_error=true`.
- `handler({ path = ".", flags = { "|", "wc" } })` returns `is_error=true`.
- `handler({ path = ".", flags = { "--color=always" } })` returns `is_error=true`; no `--` long flags or `=value` forms are accepted for `ls`.

- [ ] **Step 2: Write failing tests for `grep`**

Update existing grep tests to use the new shape:
- `handler({ pattern = "function M.new", path = "lua/parley/exchange_model.lua" })`.
- `handler({ pattern = "function M", path = "lua/parley", glob = "*.lua" })`.
- Injection attempts in `flags` and `pattern` do not execute a second command. Use a sentinel string and assert it is absent from output.
- `handler({ pattern = "x", path = ".", flags = { "--pre", "echo BAD" } })` returns `is_error=true`.
- `handler({ pattern = "x", path = ".", flags = { "--pre-glob", "*.lua" } })` returns `is_error=true`.
- `handler({ pattern = "x", path = ".", flags = { "--hostname-bin", "echo BAD" } })` returns `is_error=true`.
- `handler({ pattern = "x", path = ".", flags = { "-f", "/etc/passwd" } })` and `--file` return `is_error=true`.
- Omitting `path`/`paths` defaults to `"."` so the dispatcher still confines the search root.

- [ ] **Step 3: Write failing tests for `find`**

Add tests proving:
- `handler({ path = ".", name = "*.lua", type = "f" })` succeeds.
- `handler({ path = ".", flags = { "-exec", "echo", "BAD", ";" } })` returns `is_error=true` because `flags` is not a supported input.
- Inputs attempting to express `-exec`, `-execdir`, `-ok`, `-okdir`, `-delete`, `-fprint`, `-fprintf`, or `-fls` return `is_error=true` when supplied through `predicate`/`flags`-like unknown fields.
- `handler({ path = ".", name = "$(echo BAD)" })` treats command substitution as data and does not execute it.

- [ ] **Step 4: Write failing dispatcher tests for `paths` arrays**

Add tests proving:
- read tools with `input.paths = { "inside.txt" }` get canonicalized.
- read tools with a path outside cwd in `paths` are rejected with the existing `tool_read_roots` hint.
- every element in `paths` is rewritten to its resolved absolute path and the call is rejected if any element escapes.

- [ ] **Step 5: Run focused tests and verify RED**

Run:
```bash
make test-spec SPEC=providers/tool_use
make test
```

Expected: targeted `providers/tool_use` tests FAIL because the new input contracts and `paths` prelude do not exist yet; `make test` also catches the new `ls`/`find` specs before traceability is updated.

## Chunk 2: Shared Validation

### Task 2: Implement pure argv helper

**Files:**
- Create: `lua/parley/tools/builtin/argv.lua`
- Test: `tests/unit/tools_builtin_ls_spec.lua`, `tests/unit/tools_builtin_find_spec.lua`, `tests/unit/tools_builtin_grep_spec.lua`

- [ ] **Step 1: Add `argv.lua`**

Implement small pure helpers:
- `validate_flags(flags, allowed)` returns normalized flags or `(nil, err)`.
- `validate_ls_flags(flags, allowed_chars)` accepts compact forms like `-lah` only when every char is allowlisted.
- `append_path_args(argv, path_or_paths)` appends one string or an array of strings.
- `positive_int(value, name)` validates depth/context counts.

Hard-code these positive allowlists as local constants in the handlers:

- `ls`: compact short flags only, chars `aAlhRtrS1dF`. Reject all `--*`, `*=*`, and unknown compact chars.
- `rg`/`grep`: only `-n`, `--line-number`, `-w`, `--word-regexp`, `-F`, `--fixed-strings`, `--hidden`, and `--no-ignore` in `flags`. Structured fields own `glob`, `type`, `ignore_case`, and context counts. Do not allow `--pre`, `--pre-glob`, `--hostname-bin`, `-f`, `--file`, `-z`, or `--search-zip`.
- `find`: no free `flags`; the only accepted query fields are `path`, `name`, `iname`, `type`, `maxdepth`, and `mindepth`.

- [ ] **Step 2: Keep helpers IO-free**

The module must not call filesystem APIs, `vim.fn.system`, or read config. It only validates values and builds arrays.

- [ ] **Step 3: Run focused tests**

Run:
```bash
make test-spec SPEC=providers/tool_use
```

Expected: still FAIL until handlers consume the helpers.

## Chunk 3: Handler Rewrites

### Task 3: Replace shell strings with argv execution

**Files:**
- Modify: `lua/parley/tools/builtin/ls.lua`
- Modify: `lua/parley/tools/builtin/grep.lua`
- Modify: `lua/parley/tools/builtin/find.lua`
- Modify: `lua/parley/tools/dispatcher.lua`

- [ ] **Step 1: Update dispatcher path handling**

Extend the path prelude to process `input.paths` arrays in addition to `path` and `file_path`. Use the same read-vs-write root policy already present.

- [ ] **Step 2: Update `ls`**

Change schema from `command` to `path` plus `flags`. Build `{ ls_cmd, ...flags, path }` and run it with argv form. Preserve existing empty-output behavior and error formatting.

- [ ] **Step 3: Update `grep`**

Change schema to `pattern`, `path`/`paths`, `glob`, `type`, `ignore_case`, `context_before`, `context_after`, `context`, and the explicit positive `flags` allowlist. For `rg`, emit read-only argv such as `--glob`, `--type`, `-i`, `-A/-B/-C`. For fallback `grep`, support the smaller safe subset. Default missing `path`/`paths` to `"."`.

- [ ] **Step 4: Update `find`**

Change schema to `path`, `name`, `iname`, `type`, `maxdepth`, and `mindepth`. Do not accept `flags`; reject unknown fields that look like raw predicates/command fragments. Build only this narrow read-only `find` argv.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run:
```bash
make test-spec SPEC=providers/tool_use
make test
```

Expected: PASS.

- [ ] **Step 6: Rewrite tool descriptions**

Update each `build_description()` and input schema description so the agent sees the new structured fields, common safe examples, and the corrected confinement claim. The text must not say "Pass arguments as a single command string."

## Chunk 4: Docs and Full Verification

### Task 4: Update docs and run verification

**Files:**
- Modify: `atlas/providers/tool_use.md`
- Modify: `atlas/traceability.yaml` if new test files need mapping.
- Modify: `workshop/issues/000144-tool-input-safety-ls-grep-find-shell-injection-cwd-escape.md`

- [ ] **Step 1: Update atlas safety docs**

Document that `ls`/`grep`/`find` use structured argv inputs and no longer accept raw shell fragments.

- [ ] **Step 2: Update traceability**

Add new test files under `providers/tool_use` in `atlas/traceability.yaml`.

- [ ] **Step 3: Tick the issue plan**

Update #144 `## Plan` checkboxes that are complete and add a log entry with verification evidence.

- [ ] **Step 4: Run verification**

Run:
```bash
make test-spec SPEC=providers/tool_use
make lint
```

If `make test-spec` cannot address the new specs by name, run `make test` instead and record that evidence.

- [ ] **Step 5: Close through SDLC**

Run:
```bash
/Users/xianxu/workspace/ariadne/bin/sdlc close --issue 144 --verified '<commands and results>'
```

Use `--no-atlas` only if no atlas surface changed; this plan expects an atlas update, so the normal close should apply.

## Revisions

### 2026-06-26T11:45:00-0700

- Reason: boundary review found the `flags` allowlist was bypassable through
  `grep.pattern`: ripgrep/grep parse dash-leading pattern positionals as options
  unless argv includes an end-of-options separator.
- Delta: add `--` before grep pattern/path positionals, add regression tests for
  `pattern = "--files"` and `pattern = "--pre=/bin/echo"`, and route omitted
  grep paths through dispatcher `default_path = "."` confinement.

### 2026-06-26T12:08:00-0700

- Reason: boundary review found installed optional `ack` was still a registered
  raw-shell builtin with the same false confinement claim.
- Delta: extend the plan scope to `ack`: structured pattern/path/type/context
  fields, argv-list execution, `default_path = "."`, no raw `command`/`flags`
  escape hatch, and focused ack regression tests mapped into `providers/tool_use`.
