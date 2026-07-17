# Lessons

## 2026-07-16 (#191)

- **Moving an artifact into a typed archive subdirectory is also a consumer
  configuration migration.** The filesystem move to
  `workshop/history/issues/` landed while Parley's `history_dir` default still
  named the parent container, so non-recursive Issue Finder and next-ID scans
  silently returned no archived records. Rule: for every archive-layout move,
  shadow-sweep configured defaults, ordinary and super-repo expansion, ID
  allocation, neighborhood classification, tests, and atlas; keep one new
  canonical path rather than adding legacy fallback traversal (`ARCH-DRY`,
  `ARCH-PURPOSE`).

## 2026-07-16 (#189)

- **A finder-local comparator must stop at its actual primary fields.** Issue
  and Vision compared native IO paths after equal status/ID or file-level
  values, so the shared sorter never reached its canonical identity tie-break.
  Rule: when a shared sorter owns deterministic ties, local comparators return
  `false` after their primary fields tie; add an adversarial fixture whose
  native paths and canonical identities sort in opposite directions
  (`ARCH-DRY`, `ARCH-PURPOSE`).
- **A derived metadata view must consume the canonical grammar, not reproduce
  its convenient subset.** Chat Finder's pure record adapter copied delimiter,
  key-prefix, and tag parsing from `chat_parser`, leaving two owners that could
  drift. Rule: when a finder needs metadata from an existing document format,
  export the smallest pure parser seam from the format owner and add parity
  fixtures for legacy and current syntax (`ARCH-DRY`).
- **A joinable raw outcome needs a policy-divergence test, not only a join-count
  test.** One opener joining a prewarm proved scan reuse but did not prove that
  multiple subscribers could independently apply recency to the same records.
  Rule: shared async-result tests must bind at least two subscribers with
  different materialization policies and assert both projections.
- **A scheduled controller is INTEGRATION even when its decisions are
  deterministic.** `SliceBatcher` owns mutable progress and yields through an
  injected scheduler/clock, so classifying it as PURE hid the event-loop seam.
  Rule: classify the whole named symbol, not just its normalization policy
  (`ARCH-PURE`).
- **Async adapter and filesystem results must be validated at their consumer
  boundaries.** A `{kind="record"}` with a nil payload crashed a scheduled
  producer callback, while a successful stat could still identify a directory
  reached through a tracked symlink. Rule: validate record payload shape before
  storage and require the exact filesystem object type promised by the finder.
- **A production loading test must cross both the real process and real picker
  boundaries.** Unit lifecycle tests missed settlement running in a libuv fast
  event, where querying the prompt raised `E5560` and left `scanning…` stranded.
  Rule: for async UI, delay a real process, prove a real spinner frame advances,
  and assert the real picker replaces it after settlement.
- **Protocol coverage must instantiate every object named by the plan.** A
  nested repository is not evidence for submodule opacity. Rule: when a plan
  promises real Git edge cases, construct and assert each distinct Git object
  explicitly.
- **A process-stream error is a terminal event for that stream.** Killing the
  child does not guarantee another EOF callback, so waiting on an unretired pipe
  can strand the whole lifecycle. Rule: on read error, stop/close that side,
  mark it terminal, and test settlement after child exit for stdout and stderr.
- **A byte cap constrains retained state, not only the failure threshold.**
  Appending a whole chunk and checking afterward can retain arbitrarily more
  than the advertised maximum. Rule: parse framed chunks incrementally and
  reject before concatenation would cross the cap; ignore later callbacks from
  the retired stream.
- **Canonical comparison identity and native IO location are different path
  fields.** Separator normalization makes ordering portable but corrupts legal
  POSIX backslashes if reused for file opening. Rule: use canonical keys only
  for dedup/sort and preserve resolved/unresolved native paths for IO.
- **An asynchronous acquisition event is untrusted until its whole schema is
  validated.** Checking only the table and ordinal lets bad failure kinds or
  list shapes reach asserting reducers after the producer call has returned,
  escaping synchronous containment and stranding UI. Rule: validate ordinal,
  status, list shape, and registered kinds before any accumulator mutation;
  collapse violations to one static bounded outcome.
- **Framed protocols must reject EOF with a pending fragment.** Exit zero does
  not make a missing final NUL valid; silently dropping it converts corruption
  into empty success. Rule: at EOF, require the framing buffer to be empty and
  test a below-cap truncated record separately from overflow.
- **Compatibility tests must assert presentation, not only row cardinality.**
  Invalid super-repo labels still produced two rows, but new `{}` prefixes
  changed display/search semantics. Rule: for fallback records, pin visible and
  searchable text alongside count.

## 2026-07-15 (#190)

- **A persisted path key is an identity boundary, so its normalization must have
  one owner.** #190 initially repeated `expand → resolve → trim trailing slash`
  in toggle persistence, startup restoration, and transient-root filtering;
  the close review found that a later change could make reads and writes use
  different keys. Rule: whenever a path becomes a durable map key, centralize
  normalization before the first consumer and add an architecture check that
  forbids parallel normalization expressions (`ARCH-DRY`).

## 2026-07-14 (#187)

- **A changed user-facing command needs a README discoverability check even when
  README has no stale sentence to grep.** #187 updated Markdown Finder's facet
  and query behavior and corrected every atlas consumer, but the close review
  found that README did not mention `:ParleyMarkdownFinder` / `<C-g>m` at all.
  Rule: for every visible command or keybinding changed, search README for the
  command and key; absence is a documentation gap, not evidence that no update
  is needed.
- **A readiness file is ready only when its payload validates, not merely when
  it exists.** The close review's full suite intermittently observed the fake
  SSE server's port file after `open()` but before its write/close, producing a
  readable empty file and `port=nil`; a clean retry passed. Rule: process-fixture
  readiness polling must parse and validate the announced value inside the wait
  predicate before consumers proceed.

## 2026-07-12 (#170)
- **Making terminal failure explicit in an async callback changes every consumer contract.** `generate_topic` began calling `callback(nil, reason)` on abort/empty so the response leg could finalize exactly once, but `ChatPrune` still concatenated its callback argument as a guaranteed string. Rule: whenever a callback gains a failure invocation or return shape, grep every consumer and add one real-entry-point test per terminal outcome; shared-producer tests do not prove consumer glue handles the new contract.
- **A bounded-work API must measure actual traversal/copying, not merely report a bounded logical row count.** A successful one-row structural replacement reported one row while deep-copying arrays proportional to the whole document, and reasoning openers each rescanned a suffix. Rule: performance tests must pin implementation-observable visits/sharing at multiple document sizes and adversarial repeated-marker fixtures; use persistent sharing and linear indexing where derived state is unchanged.
- **Canonical grammar ownership requires a repository shadow search, including private helpers.** Exporting the managed-footnote predicate did not prevent `chat_respond` from retaining a stricter untrimmed regex. Rule: after centralizing grammar, add an architecture search forbidding old helper names/patterns and test whitespace/edge parity through every consumer.

## 2026-07-10 (#177)
- **A durable plan filename must use the issue's exact canonical slug, not a shortened equivalent.** The first `sdlc change-code` review saw only #177's summary checklist because `workshop/plans/000177-sticky-issue-finder-query-plan.md` did not match the issue filename; the detailed plan existed but was undiscoverable. Rule: derive the plan path by appending `-plan.md` to the complete issue basename (`NNNNNN-<issue-slug>`), then confirm the gate's review prompt includes the separate plan before trusting its verdict.

## 2026-06-10
- A config→data mapping written as an inline IIFE/closure in glue code is invisible to tests — a dropped or typo'd key silently degrades behavior. Extract it to a small *pure* named helper (`f(cfg) -> data`) and unit-test the mapping. (#127: the `chat_boundaries` prefix list started as an inline closure in `chat_respond`; the boundary review flagged the untested surface.)
- Pure-but-IO-adjacent helpers belong in the *pure* module taking the config table as a param, not requiring config — keeps the core testable while quarantining the field-name knowledge in one place.
- A template placeholder added for one creation path must be rendered through a shared helper before touching call sites. #135 added `{{status}}` to `ISSUE_TEMPLATE` and updated `create_issue`, but `cmd_issue_decompose` still called the template directly; the boundary review caught child issues that would be written with literal `status: {{status}}`. Rule: when a template gains a placeholder, grep every direct template use, extract one renderer, and test the renderer with a non-default/fake value so every creation path proves it uses the same substitution.

## 2026-06-26
- Any tool that shells out with LLM-controlled inputs must use argv-list execution and typed validation for every field before process launch. Shell-quoting only some fields is not enough: unquoted numeric/count fields can reintroduce command injection even when pattern/path strings are quoted. After hardening one shell-out family, run a sibling-tool sweep for `vim.fn.system(<string>)` and either fold matching tools into scope or file a follow-up immediately.

## 2026-05-30
- **A "line-bounded" parser's line bound is often a load-bearing blast-radius cap, not just a limitation.** `parse_markers` was line-bounded only because it fed `parse_marker_sections` one line at a time — `find_matching_bracket` itself already scanned across `\n` (drill_in relied on that). So "make it multi-line" was really "stop slicing per-line + add a bound back in." Before removing a bound that looks accidental, ask what it was silently protecting: here, an unmatched `🤖{` could only ruin one line; unbounded it would swallow to EOF. The fix kept the protection as an explicit per-section newline budget (#125).
- **Extend a shared parser via an optional opts arg that defaults to the historical behavior — then existing callers are provably untouched.** `find_matching_bracket(text, start, open, close, opts)` with `opts.budget`/`opts.is_excluded`; `opts or {}` → `budget == nil` → unbounded, exactly as before. Only the new caller (`parse_markers`) opts in. This sidesteps the lesson-#7 trap (2-arg call sites silently losing a new return) because there's no new *return* and no signature change at the call sites — highlighter and drill_in still pass 3 args. Grep-confirm the call sites anyway.
- **When a per-iteration budget resets, the per-marker total ≠ the budget.** A reviewer caught that the 50-line ceiling resets at each opening bracket, so a well-formed `🤖<…>[…]{…}` can span ~150 lines even though each *section* is ≤50. The runaway guarantee (a single *stray* opener is bounded) still holds, but the comment/docs claiming "~50 lines per marker" were wrong. Name the unit precisely in comments ("per section") and pin it with a test so nobody "tightens" it into a per-marker cap later.

## 2026-05-07
- **A parser shared across two semantic layers can hide an ambiguity for months.** The `🤖` marker family was used by two features (review skill / drill-in) with overlapping syntax (`🤖{T}[Q]` vs `🤖{agent}[user]`). The parser couldn't distinguish them, so each caller patched its own "is this drill-in?" heuristic (drill_in: "first section is non-empty `{}`?"). When you spot a caller-side disambiguator like that, a *third syntactic slot* (here: `<>`) is usually cleaner than a smarter heuristic. #123 introduced `<T>` as the unambiguous quoted-body marker; the heuristic disappeared and the whole strip pipeline simplified. Rule: if two callers of the same parser need to read the same parsed shape differently, the grammar is wrong, not the callers.
- **`find_matching_bracket` only depth-tracks one bracket pair.** When extending a bracket-based grammar with a new pair (`<>`), test cross-pair interactions: `🤖<a [b> c]` parses with quoted = "a [b" because the `>` inside `[]` still closes the `<>`. If that's acceptable, **pin the behavior with a test** so a future "fix" doesn't silently change it. If not, write a parser that maintains a stack across all bracket kinds.
- **Normalize empty-vs-absent at one boundary.** Parser produced `quoted = { text = "" }` for `🤖<>[U]`. Every downstream consumer (gather/strip/format/resolve) had to choose: treat empty as a real quote or ignore it? Picking *one* normalization site (drill_in.M.parse → `quoted = nil` when empty) lets every caller stay simple. Doing it at the parser level would be wrong (review may want to see the empty `<>` as parser truth); doing it at each consumer is duplicated logic. Drill-in is the *interpretation* layer — that's where the normalization belongs.
- **Adding a third return value to a shared API is silently lossy at 2-arg call sites.** `_parse_marker_sections` went from `(sections, end_pos)` to `(sections, end_pos, quoted)`. Lua truncates extra returns at assignment sites, so existing callers (`local sections, end_pos = parse(...)`) keep compiling and silently miss the new info. Grep every caller and decide explicitly whether to ignore or consume the new return. Caught the highlighter via grep; missing it would have meant `<T>` spans never highlighted.

## 2026-05-04
- **Vim ex-commands that take an implicit current-buffer arg (`:undojoin`, `:write`, `:edit`, etc.) silently target the wrong buffer when called from async/scheduled callbacks.** `helpers.undojoin(buf)` accepted a buf param but called `vim.cmd.undojoin` directly — `:undojoin` operates on the current buffer, ignoring the param. The streaming path looked like it worked because users stay focused on the chat buffer during streaming; the longer-cadence spinner timer was more likely to fire during transient focus changes (autocmds, window switches), and its joins silently went to the wrong buffer. Fix: wrap in `vim.api.nvim_buf_call(buf, function() vim.cmd.undojoin() end)`. Rule: any helper that takes a `buf` parameter and dispatches a Vim ex-command must use `nvim_buf_call` — passing the param to the helper without enforcing buffer context is a contract the helper isn't actually upholding. Spotted in #80 second-pass debugging.
- **Sanitized snapshot in `M.get_agent` (init.lua:3570) is an allow-list, not a passthrough.** Every new field added to the agent config schema must also be appended to this snapshot, or it is silently dropped before `agent_info.resolve` ever sees it. This bit #81 (tools/max_tool_iterations/tool_result_max_bytes) and bit #118 again (synthetic_system_prompt/synthetic_system_prompt_ack) — same vector. Rule: when adding a new agent-config field, grep for `M.get_agent = function` and add it there too; ship a regression test that walks `agent record → get_agent → get_agent_info → final usage` (see `tests/unit/config_tools_spec.lua` "get_agent forwards synthetic_system_prompt config" for the pattern).

## 2026-04-27
- **`string.gsub` returns 2 values; `table.insert(t, str:gsub(...))` blows up.** Lua expands the last argument of a call to all its return values. So `table.insert(out, "abc":gsub("c","d"))` passes three args (`out`, `"abd"`, `1`) and triggers `bad argument #2 to 'insert' (number expected, got string)` because the 3-arg form expects `(table, pos, value)`. The bug is silent in single-value contexts (`local x = s:gsub(...)`, concat with `..`) but bites the moment you pass the result through a variadic-aware API. Fix: bind to a local first (`local out = s:gsub(...); return out`) or wrap in parens (`return (s:gsub(...))`). Same shape applies to any function returning multiple values that ends a call's argument list.

## 2026-04-11
- **AGENTS.md overrides skill boilerplate.** The `writing-plans` skill template includes "REQUIRED: Use superpowers:subagent-driven-development" in plan headers. AGENTS.md explicitly says "Do NOT default to skills like `superpowers:subagent-driven-development`." User instructions are highest priority per the skill priority chain. Always check AGENTS.md for conflicts before copying skill boilerplate into artifacts.
- **In autocmd callbacks, use `nvim_buf_get_name(buf)` not `ev.file`.** `ev.file` can be a relative path when the user opened the file with a relative path (e.g. `nvim workshop/file.md`). `nvim_buf_get_name(buf)` always returns the absolute path. This caused `not_chat()` to fail silently because `find_chat_root` couldn't match the relative path against configured roots.
- **After `nvim_buf_set_name` + rename, do `write!` then `edit!`.** `nvim_buf_set_name` marks the buffer as a "new file" at the new path. Without `edit!` to reload, the next manual `:w` warns "file already exists". The `write!` forces the initial write, and `edit!` clears the new-file flag.

## 2026-04-10
- **The exchange_model is the ONLY source of truth for buffer positions.** NEVER compute positions by scanning lines, using foldexpr with backward lookups, or querying `foldlevel()`. The model knows every block's kind, size, start, and end. Any feature that needs positional information (folding, highlighting, insertion, deletion) MUST use the model. This was violated 4 times in one session: foldexpr with backward scan, foldlevel() dependency, `last_content_line()` for prompt append, re-parsing buffer on recursive calls. Every time, the model-based approach was simpler and correct.
- **Don't commit before user tests.** When fixing a bug that requires manual verification (especially buffer layout, margins, folding), wait for user confirmation before committing. Premature commits require reverts and pollute git history.
- **Lua empty table `{}` encodes as JSON `[]` (array), not `{}` (object).** Use `vim.empty_dict()` when an empty dict is required (e.g., Anthropic tool_use.input). This bit us when `parse_call` returned empty input for condensed tool blocks.
- **Parser's `line_start`/`line_end` must not include margins.** Trailing and leading blank lines are margins owned by the model, not block content. The parser must trim them so `from_parsed_chat` computes correct sizes. Also applies to `🧠:`/`📝:` lines — they must be fed to `cb_append_line` so the content_blocks state machine tracks them.

## 2026-04-09
- Parley test files hardcode `/tmp/parley-*` paths (`dispatcher_spec.lua:7`, `tree_export_spec.lua:22`, etc.). Under Claude Code sandbox, `/tmp` is narrowed to `/tmp/claude` regardless of user `allowWrite` config, so all these tests fail at setup with `Vim:E739: Cannot create directory`. Fix: use `vim.fn.tempname()` or `os.getenv("TMPDIR")` instead of hardcoded `/tmp/` — it's both sandbox-friendly AND more portable. Tracked for future cleanup (not in #81 scope).
- When adding ONLY new files (no modifications to existing code), regression risk in untouched modules is zero. A full `make test` regression gate is belt-and-suspenders, not load-bearing — individual file verification suffices if you can't run the full suite.
- **Never have two code paths (legacy + new) coexisting in the same function for the same operation.** #90 attempted to add a model-based insert path alongside the legacy absolute-line path in `chat_respond.M.respond`. The two paths shared closure variables (`response_line`, `progress_line`) and produced conflicting buffer states. THREE rounds of "targeted fix" attempts each made things worse. Rule: if you're replacing an algorithm, REPLACE it — don't add a parallel path gated by a condition. The old path must be deleted, not left as a fallback.
- **Use SIZE not POSITION for tracking buffer layout.** Absolute line numbers are invalidated by any insert/delete. Size-based models (exchange_model.lua) compute positions on demand from accumulated sizes, so they're always correct regardless of concurrent edits. When building buffer-mutation infrastructure, make the model the single source of truth and have callers ask "where does section K go?" rather than computing offsets themselves.
- **When adding a new state to code that already has fragile line-offset arithmetic, refactor first — don't stack another branch.** #81 M2 Task 2.7 needed to insert a tool-loop recursion branch into `chat_respond.M.respond`'s imperative line-position chain (`response_line / response_block_lines / progress_line / response_start_line / raw_request_offset`). Each new branch added an `if recursion then +1 else +3` magic-number offset. Three manual test rounds, three distinct offset bugs (progress_line mismatch, stuck-spinner cleanup failure, suspected buffer-state corruption causing an Anthropic "assistant message prefill" rejection on a payload that looked spec-correct). The third bug was the trigger to stop patching and refactor — filed #90 to extract a pure `exchange → lines` + `positions` layer with a single mutation entry point. Rule: when you notice you're adding the Nth `+K vs +M` branch to the same code path, stop and refactor. The cost of one refactor < the cost of N+1 offset patches + the debug sessions between them.
- **Integration tests at the wiring layer catch bugs unit tests cannot.** During #81 M1 Task 1.8 manual verification, `M.get_agent()` was found to return a sanitized agent snapshot without the `tools`/`max_tool_iterations`/`tool_result_max_bytes` fields. Each hop was unit-tested in isolation (`get_agent_info` with a fake agent table that already had `tools`; `prepare_payload` with an explicit `agent_tools` arg) but no test exercised the full chain `M.agents → get_agent → get_agent_info → prepare_payload`. The bug was caught only by inspecting a real query cache JSON after a real user interaction. Rule: for any multi-hop data flow through module boundaries, write at least one test that exercises the FULL chain with the actual modules wired up, not just mocks at each hop. For any field added to an entity (here: `agent.tools`), grep all the read-sides (functions that build derived objects from the entity) and verify each forwards the field.

## 2026-03-07
- No escaped-quote init in Makefile recipes — use newline-producing helpers + `for` loops
- Run new Make targets against real inputs before closing

## 2026-03-08
- Run `make test-changed` after spec doc changes
- Verify provider capabilities against provider's own docs
- Capability rules go in `provider_params.lua`, not transport code
- Write plan in `tasks/todo.md` before non-trivial work
- Run `make lint` after every change; warnings = failures

## 2026-03-09
- Fast-event callbacks: no direct `nvim_*` APIs — use `vim.schedule`
- Progress UI must handle `reasoning_content` not just tool events
- Normalize provider progress events to shared shape (`kind`/`phase`/`message`)
- Propagate raw progress text for display, not just coarse labels
- `git stash` changing behavior = strong causality signal — diff the stash
- Prefer semantic header keys (`system_prompt`) over overloaded ones (`role`)
- Global whitespace trim can eat required terminal newlines — handle post-trim
- When one path is fixed, narrow focus to remaining failures
- Bottom-anchored picker: verify `scrolloff` + buffer line count, not just window height
- Separate initial placement logic from keyboard navigation scrolling

## 2026-03-11
- UI bugs in live-only: add runtime tracing, don't stop at unit tests
- Bottom-anchored pickers: verify visual-row vs logical-index mapping

## 2026-03-13
- ChatFinder move bugs: instrument full lifecycle in live path, not just helpers

## 2026-03-25
- Read the full existing implementation before adding a variant
- Always handle `~/` expansion in file path resolution
- Strip empty-content messages before sending to LLM — Anthropic rejects them
- Sanitize inputs when extracting reusable functions (strip `cache_control`, etc.)
- Programmatic buffer inserts don't fire `BufEnter` — trigger renders manually
- `x or {}` default eats `nil` — use sentinel if nil has meaning
- Cross-file picker nav: use `edit` not `split`, clamp cursor to line count
- After `edit`, use `nvim_get_current_buf()` not stale buffer variable

## 2026-03-28
- Float picker is insert-mode — only `<C-*>` and arrow keys work as actions
- Don't nil-guard broken state — fix the caller instead
- Chat file paths must be relative to containing file, not cwd — use `:t` not `:~:.`
- New keybindings must use config-driven mechanism (`chat_shortcut_*` in config.lua + `M.cmd.*`) — don't copy hardcoded patterns

## 2026-03-29
- Picker tests: don't assert mappings by numeric index (`mappings[2]`) — indices shift when new mappings are added. Look up by key name instead
- `GROUPS` is a bash built-in variable (user's group IDs) — never use it as a custom variable name. Same caution for `RANDOM`, `SECONDS`, `LINENO`, etc.
- `flock` is Linux-only — use `mkdir` for cross-platform locking (atomic on macOS and Linux)
- `claude -p` in background/piped processes needs `< /dev/null` to avoid stdin timeout warnings
- `claude -p` without `--permission-mode bypassPermissions` may silently fail when tools need approval but no TTY is available
- Parallel agents sharing a git working directory: don't use `git status` diff to detect changes from one agent — other concurrent agents may have modified files too
- `timeout` is GNU coreutils — not on macOS. Use `perl -e 'alarm shift; exec @ARGV'` as portable fallback
- `wait -n` requires bash 4.3+ — macOS ships bash 3.2. Use `kill -0` polling instead
- When a subprocess fails silently and its empty stdout is treated as "success", the feature appears to work but does nothing — always check exit codes or validate output isn't vacuous

## 2026-04-06
- Don't use `git stash` mid-task to "verify lint baseline." Pre-existing stashes in the sandbox can collide with the pop and corrupt unrelated files (Makefile got merge markers, broke `make`). To check whether warnings/errors are pre-existing, run lint on a clean clone in /tmp or just compare the warning *count* against `git show HEAD:<file>` — never disturb the working tree.

## 2026-06-17
- **When deleting/renaming a module, the atlas-sync merge gate catches stale refs a name-grep misses — reconcile EVERY atlas page, including behavioral descriptors.** Across #128 M2/M3/M4 the `sdlc merge` atlas-sync judge blocked 4× on stale atlas text that survived a `grep <module-name> atlas/`. The misses were *behavior* lines, not the module name: `atlas/modes/review.md` still said "pre/post hooks" / "shared pipeline" / ":checktime reload" after those were deleted, and `traceability.yaml` listed phantom specs (`tools_builtin_glob_spec`) renamed long ago. Rule: when a change deletes/renames a surface, grep `atlas/` for BOTH the old name AND the behaviors/tools it owned (`hooks`, `pipeline`, the old tool name, the reload verb), and walk every mode-specific page + the `## Key Files` / traceability lists — not just the primary atlas doc. Cheaper to sweep up-front than to round-trip the merge gate.

## 2026-06-30 (#116)
- **A sandbox push/network failure is NOT "can't push" — retry with the sandbox DISABLED.** `git push`/`sdlc pr`/`sdlc merge` failing with `nc: authentication method negotiation failed` (or any SSH/network/auth error) is the Claude Code sandbox blocking the *transport*, not a hard limit. Per the Bash-tool rule, retry the network op with the sandbox off (`dangerouslyDisableSandbox`) — it uses the real network/auth. This session I treated repeated push failures as a hard block and tried to hand the whole merge back to the operator; the moment I retried `git push` unsandboxed it worked, and the full `sdlc pr → merge` flow completed. Don't conclude "can't" from a sandbox network error; the *filesystem* sandbox is narrow (see the `/tmp` lesson) but network is retryable unsandboxed.
- **Read `sdlc --help` (the workflow contract) UP FRONT — CLAUDE.md says "Read it NOW," and most SDLC surprises come from skipping it.** It lays out the whole arc (claim → `change-code` → implement → `milestone-close` per Mx → `close` → `pr` → `merge`) and the exact gotchas: PUBLISH is **`sdlc pr` → `sdlc merge`** (merge is server-side `gh pr merge` of *origin's* tip, so it needs a pushed branch AND an existing PR), and "a verb's errors are next-action specs" (e.g. `merge` "no upstream" → run `sdlc pr` first). This session I tried `sdlc merge` before `sdlc pr` and was surprised the merge was server-side — all answered in the contract I hadn't read.
- **`sdlc milestone-close` runs the boundary review; `sdlc close --milestone Mx` does NOT** (it's the documented no-auto-judge escape). For a *reviewed* milestone close, use `milestone-close`. This session I ran `close --milestone` first — it ticked the box + logged but silently skipped the mandatory fresh-context review. (Lives only in `sdlc close --help`, not the top-level contract.)
- **Merge CODE at issue close, not per milestone — and never reuse a branch name that already has a merged PR.** The normal model (cf. #133's seven milestones on one branch) is one branch per issue, all milestones on it, a single `sdlc pr → merge` at the end; `milestone-close` is a *local* review boundary (+ issue-sync of the tracker to main), NOT a code merge. #116 deviated: M1 shipped early via PR #95 (a prior session, to unblock #128), so when M2/M3 reused the same issue-slug branch name months later, `sdlc merge` found the merged #95 and "resumed post-merge cleanup" (switched to main, deleted the branch) WITHOUT merging the 16 new commits — they were safe on `origin`, absent from main. Rule: don't merge per milestone; if a milestone genuinely must ship early (cross-issue unblock), the continuation needs a FRESH branch name. After any merge, `git rev-list --left-right --count main...origin/<branch>` to confirm main actually advanced.

## 2026-07-01 (#155)
- **When two code paths feed a shared, tested core, the per-path GLUE still needs its own coverage — a shared-core test does not cover the seam.** #155 consolidated two message emitters into one pure `_emit_content_blocks_as_messages` and I tested it thoroughly (6 direct cases) plus the parse path (1 integration). But `build_messages_from_model` (the live/recursion path) has its own *normalization seam* — buffer read + `serialize.parse_call`/`parse_result` + malformed→text degrade — that I left with **zero** coverage, reasoning "the invariant is tested in the emitter." The close review flagged it Important: a regression in that seam (a dropped/mis-ordered block never reaching the emitter) would ship silently. Rule: after extracting a shared tested core, enumerate every *caller's* normalization/glue seam and give each an end-to-end test through the real entry point (for the live path: build a real buffer + `exchange_model` with positions driven by the model's own `block_start`, call the entry fn, assert the payload). ARCH-PURPOSE covers the core; the seams are separate deliverables.
- **De-duplicating two parallel implementations surfaces latent divergences — treat each difference as a suspected bug, not noise.** The two emitters diverged on empty tool input: the model path coerced `{}`→`vim.empty_dict()` (JSON `{}`) while the parse path emitted a bare `{}` (JSON `[]`, which Anthropic rejects for `input`). The divergence *was* a latent bug; consolidating to one source fixed it for free. When you unify copy-paste siblings, diff their behavior line-by-line and fix the discrepancy at the single source rather than picking one arbitrarily.
- **Never `git add -A` / `git add .` in a shared working tree — stage explicit paths.** In #157 `git add -A` swept an unrelated *untracked* user-WIP issue stub (`000158-…`) into my refit commit; the `sdlc merge` instance-conformance gate then blocked on that stub's empty `## Plan`/`## Done when`. The user (and peer agents) leave untracked files in `workshop/issues/` mid-session, so a blanket add captures work that isn't yours. Recovery: `git rm --cached <file>` + a removal commit keeps the file locally (untracked, WIP preserved) while dropping it from the branch's net `base..HEAD` diff so the gate passes. Rule: stage the exact paths you changed (`git add lua/... tests/... workshop/issues/<your-issue>.md`), and before committing run `git status --short` to eyeball for `??` files you didn't create. (Same "commit only my files" care the #155 ariadne-side commit needed.)

## 2026-07-05 (#160)
- **Run the FULL `make test` (lint + unit + integration) before claiming "suite green" in `--verified` — running specs individually skips the lint gate.** This session I ran each `PlenaryBustedFile` spec directly (all green) and wrote "go test/full suite green" in the close evidence — but never ran `make test`, whose FIRST target is `lint` (luacheck). A new `while pos <= #line do` (every branch returns → luacheck 542 "loop executed at most once") failed luacheck, so `make test` was RED at the gate while my Log claimed green. The boundary review caught it (FIX-THEN-SHIP), but nothing *prevented* the premature claim. Rule: the evidence for "green" is a full `make test` exit 0, not a hand-picked set of specs; individual `PlenaryBustedFile` runs are for the red→green TDD loop, not the final gate. (Bonus: luacheck flags a `while` whose body always returns — use `if` and let the iterator's repeated closure-calls do the looping.)
- **A decoration-provider highlight's column math deserves a pure, tested helper — don't bury `col_start=s-1, col_end=e-1` inline in an untestable local.** The `push_artifact_refs` extmark columns (off-`iter_refs`' one-past `e`) were an off-by-one-prone conversion inside a `local function` in `highlighter.lua` (ephemeral extmarks, awkward to assert). The review flagged it Important. Fix: extract `artifact_ref.highlight_spans(line)` (pure, returns the exact 0-indexed `{col_start,col_end}`) and unit-test the columns against the literal ref text (`line:sub(col_start+1, col_end) == "ariadne#11"`, incl. the interior-space `#15 M4`); the highlighter consumes it. Pure col math + a direct assertion beats trying to test the decoration provider's redraw output.

## 2026-07-07 (#161)
- **A pure helper that consumes another module's output must have ONE test against that module's REAL output, not only synthetic inputs.** `define.context_for_selection` reads `parse_chat` fields (`ex.question.line_start`, `ex.answer.line_end`). I unit-tested it thoroughly — but only with a *synthetic* `parsed_chat` table + an injected `finder`, and the one integration test that reached the real `parse_chat` used a buffer with no exchanges (so it hit the whole-buffer fallback, never the sliced-exchange branch). Net: the field-name contract with the live parser had zero coverage — a rename in `parse_chat` would silently degrade define to whole-buffer context with green tests. The boundary review flagged it Important. Rule: injecting a dependency (finder/parser) to keep a helper pure is right, but add exactly one end-to-end case that feeds the helper the REAL producer's output and asserts the field access still works. (Same shape as the #155 "shared core tested, caller's glue seam untested" lesson — the seam here is the field-name contract.)
- **Raw `nvim_buf_set_text` is arch-forbidden (empty allow-list in `tests/arch/buffer_mutation_spec.lua`); `nvim_buf_set_lines` is allowed in `init.lua`.** #90's buffer-mutation boundary confines span edits to `buffer_edit.lua` (set_text allow-list is `{}` = zero uses). My first R1 cut used `nvim_buf_set_text` for the `[term]` wrap → `make test` red on the arch spec (lint was clean, so I only caught it at the full-suite run, not the unit loop). Fix: wrap via `nvim_buf_set_lines` (rewrite the affected whole line(s)) — the same primitive `drill_in_visual` already uses to wrap a selection, and it's on the set_lines allow-list for `init.lua`. Rule: before reaching for `nvim_buf_set_text`/`set_lines` in a non-`buffer_edit` file, check `tests/arch/buffer_mutation_spec.lua` — prefer the set_lines whole-line rewrite that existing wrappers use.
- **To make a decoration-only action undoable, anchor it to a text edit + reuse `projection` — `u` reverts text, never extmarks/diagnostics.** The operator wanted the define highlight+diagnostic undoable; native `u` can't touch pure decorations (review's are undoable only because a round edits text). Resolution: a minimal text edit (now the durable `[^id]` footnote reference/footer) as the anchor + reuse `skills/review/projection.lua` (`record_empty_for(pre)` + `record(post)` + `ensure_watch`). `skill_render.snapshot`/`apply_snapshot` now preserve both whole-line highlights and column spans, so the projection can restore exact term/reference decorations. In headless tests, `:undo` does NOT fire `TextChanged` — `nvim_exec_autocmds("TextChanged", {buffer=buf})` to drive the projection watcher deterministically.

## 2026-07-08 (#166)
- **Any action that can be repeated on its own output needs an idempotence test, not only an update test for the secondary data.** #166 tested that re-defining a term updated the managed footnote line, but the selected text transform still blindly appended `[^id]`, so selecting `ASIN` in `ASIN[^asin]` produced `ASIN[^asin][^asin]`. The close review caught the gap. Rule: when a feature creates both an inline reference and an external/durable record, add a repeat-on-rendered-output test that proves the inline reference is not duplicated while the external record updates.

## 2026-07-08 (#167)
- **A behavior-only fix can still require atlas if an atlas page explicitly describes that behavior.** #167 changed define highlights from whole-line to span-scoped and taught projection snapshots to preserve columns; the code and tests were right, but `atlas/chat/inline_define.md` still said whole-line/line-granular. Rule: before using `--no-atlas`, grep atlas for the feature name and the old behavior terms (`whole-line`, `line-granular`, helper names, key data fields). If any atlas page states the old behavior, update it in the same commit even when no new module or command was added.

## 2026-07-08 (#169)
- **When centralizing a policy, delete caller-local defaults that can bypass it.** #169 routed review and define diagnostics through `skill_render.format_diagnostic_message`, but `define.format_definition` still passed `width or 80`, preserving an old fallback and weakening the shared width policy. Rule: after adding a shared formatter/config helper, grep every caller for old fallback constants and add a test for the nil/default path so future callers inherit the central behavior.

## 2026-07-08 (#174)
- **`virt_lines_leftcol = true` means gutter/window-left anchoring, not buffer text-column anchoring.** #173 used it to escape Neovim's stock diagnostic-column indentation on long wrapped prose, but the follow-up screenshot showed the block starting in the line-number/sign gutter. For diagnostic text that should align with paragraph content, place the extmark at column 0 and omit `virt_lines_leftcol`; test the extmark options directly so "visible" does not regress into "misaligned."

## 2026-07-08 (#175)
- **Shared diagnostic display needs source-specific visibility predicates when sources mean different things.** Review diagnostics span an edit region and should show anywhere inside `lnum..end_lnum`; footnote diagnostics point at a precise `term[^id]` anchor and should show only when the cursor is inside `col..end_col`. A single "current line" predicate was too broad for footnotes. Rule: when multiple diagnostic sources share one renderer, test each source's visibility contract explicitly.

## 2026-07-08 (#176)
- **README snippets are consumers of user-facing UI behavior, not marketing fluff.** #176 updated atlas when footnote definitions moved from virtual lines to a centered float, but the close review caught README still saying "grey pop-under" for visual `<M-CR>`. Rule: when changing a visible command/keybinding behavior, grep README for the command, keybinding, and old UI nouns alongside atlas.

## 2026-07-08 (#171)
- **A new `config.highlight.*` override is user-facing even when it is optional.** #171 added `config.highlight.footnote` support in the highlighter and documented the highlight group in atlas, but the close review caught that the default config/reference table still omitted the key. Rule: whenever code reads a new config override key, update `lua/parley/config.lua`'s defaults in the same commit and grep README/atlas for config snippets that mirror those defaults.
- **Generated SDLC review sidecars are still committed artifacts.** The #171 close sidecar captured trailing whitespace from the review transcript and made `git diff --check base..HEAD` fail even though source files were clean. Rule: after any `sdlc close`/review sidecar generation, run `git diff --check <base>..HEAD -- workshop/plans/<issue>-*-review.md` (or strip trailing whitespace on the sidecar) before committing the close artifact.

## 2026-07-08 (#178)
- **After changing a shared parser rule, grep for every shadow parser before close.** #178 changed `define.managed_footnote_footer_range`, but `chat_parser.lua` still had a local footer scanner at close review. Rule: for grammar or boundary-policy changes, grep the old predicates/terms and route all consumers through shared helpers before boundary review.

## 2026-07-12 (#170)
- **Core-concept tables must name greppable code entities and classify the whole named boundary, not its pure subset.** #170 called conceptual `PerfSampleSet`/`PerfReport` entities PURE even though their shared harness also owned the clock, timestamp, and Neovim JSON encoder. The close review correctly treated the contradiction as architectural. Rule: before close, resolve every Core-concept row to an actual symbol/module and inspect all side effects at that location; name a deterministic function separately from its INTEGRATION shell instead of assigning purity to a conceptual bundle.
- **A synchronous event contract must be tested through the production registration path, not an already-installed callback.** #170's lifecycle tests manually called `setup(buf)` before `BufEnter`, masking that the production classifier itself used `vim.schedule_wrap` and returned before setup; making entry direct then exposed a scheduled unload cleanup erasing classification after numeric handle reuse. Rule: for first-entry hydration, create a fresh unowned buffer, fire the real registered event, and assert state immediately on return; audit both setup and teardown wrappers for scheduling and exercise handle reuse before claiming synchronous convergence.
- **When making a shared event callback synchronous, classify each side effect by the contract that needs synchronization.** #170 needed immediate classification, diagnostics, and structure, but moving branch-reference topic refresh with them changed timer ownership/order and broke the timer-race oracle. Rule: trace every callback side effect before changing scheduling; keep unrelated timer/UI work deferred and add the full integration suite to the synchronization change's GREEN gate.

## 2026-07-13 (#182)
- **A public callback is an untrusted lifecycle boundary: complete cleanup independently, contain exceptions, and keep diagnostics bounded.** Task 2's first transport review found that throwing readers and terminal callbacks could skip pipe closure, handle removal, or completion events; the follow-up found that raw tracebacks could still create huge notifications or expose callback input. Rule: protect each independently promised callback surface, make resource cleanup unconditional, test a throwing callback at every lifecycle seam, and log only a generic or explicitly truncated diagnostic. Never include provider bodies, stderr, or arbitrary exception text in ordinary user-facing logs.
- **Call a process test “real” only when it actually crosses the OS process boundary.** A dispatcher test drove a captured tasker terminal callback but was named “real process failure,” obscuring that the real curl/SSE fixture belongs to a later boundary. Rule: reserve “real process” for tests that spawn the executable/fixture; name callback-driven coverage after the simulated terminal it exercises.
- **A state transition must retire every timer owned only by the state being left, including transitions that bypass the visible state.** Task 3 canceled playful timers for `showing → released` but missed the fast `waiting → released` path, leaking the startup idle timer; its frame tick also checked buffer validity but not lease ownership. Rule: enumerate every source phase for each destination and assert the complete live-timer set after the transition. Every recurring timer callback must revalidate both resource validity and logical ownership before touching UI.
- **Publish an object in a global ownership registry only after construction and injected validation succeed atomically.** Task 3 registered a chat session before its clock, verb chooser, and reducer initialization ran, so an initializer exception left an uncancellable half-object that blocked retries and crashed global cleanup. Rule: build and validate privately, install all terminal methods, then publish; test constructor exceptions followed by both retry and global cleanup.
- **A one-shot timer callback can arrive before a higher-resolution logical deadline; ignoring it without rearming strands the state forever.** Task 4's real curl stress run intermittently completed the provider response while the minimum-visible extmark remained forever because libuv's millisecond timer fired fractionally before an `hrtime` deadline. Rule: use one coherent clock for timers and deadlines or, whenever a deadline callback observes `now < due`, rearm the remaining duration. Stress the real process path repeatedly; one green timing run is not evidence.
- **Ending a presentation controller is not the same as completing its caller's lifecycle.** Task 4 initially let cancel/stale/invalid finish the extmark controller while skipping the chat shell collapse, lifecycle finalization, and lease release; the later transport error was correctly ignored and therefore could not rescue cleanup. Rule: every terminal class needs an explicit exact-once owner at each layer. UI discard hooks must release caller-owned resources without surfacing staged output or errors.
- **Ownership conflicts must be rejected before durable mutation, including force/bypass paths.** Task 4's force respond bypassed the busy guard, inserted a second response shell, began a lease, and only then collided with the existing per-buffer presentation registry. Rule: preflight every independently owned resource before transcript/model writes; tests for force or bypass flags must assert both the error result and byte-for-byte unchanged durable state.
- **A centralized `finish` closure provides no safety unless every fallible operation before it is protected and converges into it.** Task 5 made skill terminals exact-once, but malformed tool decoding/execution could still throw inside the scheduled completion pipeline before `finish`, stranding `_in_flight`, detached progress, and Definition's inline spinner. Rule: wrap the whole asynchronous completion body—not only callbacks—in a protected boundary; on exception log bounded metadata and call the same terminal owner. Test with malformed provider output that reaches real decode/dispatch code.
- **A generic lifecycle test does not prove a consumer-owned transient UI seam.** Task 5's invocation table covered source failure, no agent, buffer deletion, and no-tool output, but the first Definition suite did not assert its inline spinner/timer and footnote state on those same terminals. Rule: for every consumer that supplies an `on_terminal` cleanup hook, run each materially distinct terminal through the real consumer entry and assert its owned UI/resource is gone; keep one late/repeated delivery case at that seam.
- **Registering a terminal owner turns every later synchronous setup operation into part of that lifecycle.** The #182 close review found that payload assembly, decoration clearing, root-policy construction, or progress startup could throw after `skill_invoke` installed Definition cleanup but before dispatch, leaking the inline spinner and ownership registry. Rule: once terminal ownership is published, run the entire remaining synchronous setup region inside one protected boundary that converges through the terminal; add a real consumer-entry test with an injected setup throw, not only async completion failures.
- **A failed review sidecar must not make its own re-review window unreviewable.** #182's generated REWORK sidecar embedded the full prompt, diff, and test output; committing its 11,000 lines put that transcript back into the next whole-window diff and exhausted the reviewer before it could emit a verdict. Rule: before committing a failed-review sidecar that will be included in the immediate re-review window, compact generated bulk to durable metadata, actionable findings, resolutions, and evidence while preserving the verdict; let the successful re-review append its fresh record.
- **An extmark update must repaint at the mark's live tracked position, not its creation coordinates.** #182 correctly used extmarks for transient progress, but each animation tick passed the original row/column back to `nvim_buf_set_extmark`, snapping marks backward after edits above their anchors. Rule: creation owns initial coordinates; every later repaint first resolves `nvim_buf_get_extmark_by_id`, stops on missing/invalid marks, and updates at the returned position. Test by moving text before the live mark and then forcing a frame or semantic repaint.

## 2026-07-13 (#183)

- **Repair authorization for a writer-invalidated UI anchor must be established immediately before mutation and consumed in the same uninterrupted callback.** #183 intentionally placed progress on the mutable stream tip, whose replacement invalidates its extmark. A first implementation repaired any missing mark afterward, which could revive one invalidated earlier by an external edit. Rule: validate the live mark immediately before the write, grant a one-use authorization, then mutate and relocate synchronously; never infer the cause of invalidation after the fact. Test both expected writer invalidation and pre-existing external invalidation through the real queued stream path.
- **Normalize generated boundary-review sidecars before committing them.** The #183 re-review produced an 18,000-line raw terminal transcript with ANSI escapes and trailing whitespace, obscuring the actual verdict and failing `git diff --check`. Rule: retain durable metadata, findings, resolutions, and evidence in a concise sidecar; discard terminal plumbing and run `git diff --check` on the whole review window before publishing.

## 2026-07-13 (#184)

- **An “exactly once” requirement needs a cardinality oracle, not a presence oracle.** The folded-recursion regression proved staged output appeared after the spinner minimum, but `buffer_contains` would also pass if the release duplicated that output. Rule: when the contract says once/exactly-once/idempotent, count occurrences or assert the exact resulting sequence after the terminal transition.

## 2026-07-14 (#168)

- **A mapped native operation needs production assertions for every promised count/direction seam and for its ordering boundary.** Unit policy tests proved confirmation choices, while the first production cut only counted undo and checked cleanup after uncounted confirmation. That left counted redo and mutation-before-retirement unenforced. Rule: when thin keymap glue captures counts or uses different execution mechanisms per direction, drive each mapping with counts, assert the exact history result, and observe state inside the next lifecycle stage—not only after the transaction returns.
- **Resource cleanup and operation success are separate results.** The scoped tasker stop correctly partitioned handles even when signaling failed, but `pcall` discarded the failure, preventing the guarded transaction from surfacing its bounded generic error. Rule: complete deterministic ownership cleanup, then propagate a sanitized failure signal to the protected orchestration boundary; never equate “record removed” with “external operation succeeded.”
- **A protected external call must test both exceptions and the API's documented failure return.** The first scoped-stop regression modeled `kill` throwing, but real libuv returns `nil, message, code` for `EPERM`/`ESRCH`; `pcall` therefore succeeded and the failure stayed hidden. Rule: inspect the production API's success sentinel inside the protected call and test a non-throwing failure tuple as well as an exception.

## 2026-07-14 (#186)

- **Durable plan checkboxes are boundary evidence, not optional bookkeeping.** The implementation, tests, issue Plan, and Log were complete, but the close review correctly refused to ship while the detailed plan still presented every step as pending. Rule: immediately before `sdlc close`, reconcile every durable-plan checkbox against commits and verification; leave only genuinely pending boundary or publish work unchecked.
- **Core-concept tables must name symbols a reviewer can grep at their stated locations.** #186 described accurate architectural roles but labeled them with conceptual CamelCase entities that did not exist in Lua, making the plan/code cross-check fail despite correct behavior. Rule: name actual module exports, scoped entry points, local helpers, or state paths in the table; keep explanatory concepts in the prose below it.

## 2026-07-15 (#188)

- **A close-gate checkbox must describe readiness/invocation, while the revision
  log records the verdict chronology.** `sdlc close` requires every plan box to
  be checked before it dispatches the review, so wording such as “successfully
  crossed” creates an impossible truth window and can contradict an earlier
  REWORK revision. Rule: name the pre-gate step “prepare and invoke the close
  boundary”; after the verdict, append the outcome and status transition instead
  of making historical revision prose sound like current state.

## 2026-07-16 (#189)

- **UI teardown and lifecycle dismissal are different operations.** A picker
  can disappear through window invalidation or its public close method without
  traversing the keyboard cancel path. Rule: every non-selection destruction
  must notify the lifecycle owner exactly once; reserve raw teardown only for
  successful selection or an action that explicitly owns completion.
- **Suppressing a late IO callback does not dispose resources created by that
  callback.** Cancellation may fail while `fs_open` later succeeds, so dropping
  the result leaks its descriptor. Rule: resource-producing queued operations
  need an idempotent late-completion disposer; test the documented cancellation
  failure return followed by a successful completion.
- **A picker-open guard must belong to the picker lifetime, not the launch
  stack.** Resetting `opened` after starting async discovery admits a second
  picker while the first is loading or settled. Rule: release the guard only at
  selection, cancellation, or an action-owned close/reopen transition, and test
  duplicate invocation both before and after settlement.
- **Do not relinquish resource ownership merely because cleanup was queued.** A
  saturated operation queue can discard a pending close during cancellation.
  Rule: retain the descriptor until the close operation actually starts, so
  cancellation can close it directly if the queued job never runs; test cancel
  in the queued-but-not-started window.
- **An action-owned close is safe only after loading ownership has settled.**
  Recency/view mappings legitimately close and reopen a settled picker without
  cancellation, but the same raw teardown during `scanning…` strands the old
  subscription or acquisition. Rule: at the shared picker boundary, route
  mapping closes through dismissal while status is active and through raw
  teardown only after settlement; test every action-only loading consumer.
- **A loading shell may use a provisional title, but settlement must restore
  title semantics promised by the existing UI.** Migrating Vision to immediate
  open preserved its rows and actions while silently dropping the initiative
  count from the window title. Rule: inventory titles alongside mappings and
  queries during async ports; if settled data determines a title, make it an
  explicit settlement field and test empty plus nonempty outcomes.
- **When flipping a shared helper's semantics, grep tests for the pinned
  *behavior*, not just the symbol.** #192's plan initially missed
  `tool_loop_spec.lua` (asserted the old ordered-roots fallthrough) and
  `build_messages_spec.lua` (asserted `format_tool_context`'s old wording) —
  neither names the changed function. Rule: before rewriting a helper, grep
  for its error strings and output phrases across `lua/ tests/ atlas/`.
- **Error-message text is part of a resolver's API here.** Specs assert
  `matches(...)` on messages throughout; a plan changing a resolver must state
  the new message contract explicitly per case (and remember `assert.matches`
  takes Lua patterns — tmpdir names contain magic `-`).
- **Module-local one-shot flags persist across `it` blocks** (e.g.
  `cmp_registered` in neighborhood.lua) within a plenary spec-file run. Tests
  asserting registration/setup counts must assert deltas, reload the module,
  or expose a reset — never absolute counts on a fresh stub.
