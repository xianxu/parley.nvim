# Lessons

## 2026-08-22 (#203)

- **A span-based text edit is only as safe as the boundary you assume — and an
  empty span is catastrophic, not a no-op.** Twice this session an edit computed
  `s[index(A):index(B)]` where B occurred somewhere unexpected. Once it swallowed
  a whole `## Done when` section; once B landed *before* A, the slice came back
  empty, and `str.replace("", new)` inserted the replacement between every
  character of the file — 409,224 lines from a 78-line issue. Rule: replace an
  exact known block and assert it matches exactly once; never a range between two
  landmarks you have not just verified are ordered and unique. **Write the
  guarded helper and then actually use it** — this happened a THIRD time in the
  same session, after the helper existed, because `s.index` is the thing the
  fingers reach for. The anchor that bit last was `--- @param lines string[]`,
  whose first match was a different function's docblock two definitions up.
- **Green means "ran nothing" more often than it means "held" — break the
  invariant and watch it fail, every time.** Three separate guards this session
  were vacuous when written: the producer guard skipped every case because
  `tools.get` returned nil without `register_builtins`; the corpus-skip report
  used `print`, which `RUN_SPEC` discards on a pass; and the five marker pins
  asserted an exchange count that was identical with and without the rule. Each
  was caught only by deliberately deleting the thing under test. Rule: a guard is
  not finished when it is green — it is finished when you have seen it red for
  the right reason.

- **A test that skips is not a test that passes.** The producer guard for #203
  was green on HEAD and *still green* with the invariant it guards deliberately
  broken: `tools.get` returns nil without `register_builtins()`, and the guard's
  `if not def then return end` skipped every case. Rule: after writing a guard,
  break the thing it guards and watch it go red. A guard that has never failed
  has never been tested — and "skip when absent" is the most common way to make
  one permanently vacuous (`ARCH-PURPOSE`).
- **Check whether a rejected option was rejected for a true reason.** #203 was
  deferred because "declining when the body holds a question defeats M2's
  headline case, because `read_file` on a transcript produces exactly that" — and
  two tests were observed going red. `read_file` emits `"%5d  %s"`; it cannot
  produce that shape. The tests encoded a fixture that modelled the tool
  incorrectly, while their own siblings modelled `grep` correctly two cases
  below. Rule: when a plan says an approach was tried and failed, verify the
  premise before building the expensive alternative — the failure may belong to
  the fixture, not the approach.
- **A fixture is a claim about the world and can be wrong.** The same file
  modelled `grep` faithfully (prefixed) and `read_file` unfaithfully
  (unprefixed), and the unfaithful half drove a design decision for two issues.
  Rule: when a fixture stands in for a real producer, derive its shape from that
  producer's code, and say in the fixture which producer it models.


## 2026-08-21 (#202)

- **A destructive recipe may only remove paths the tool itself constructed and
  can name literally, each quoted individually — and you verify it by reading
  the expansion, not the source.** This cost two Important review findings in
  one issue. `test-clean-env` first shipped `rm -rf "$(TEST_ENV_ROOT)"
  $(LEGACY_TEST_DIRS)`: the unquoted list word-splits, so a checkout at
  `~/my code/parley.nvim` expands to `rm -rf ~/my`; and `TEST_ENV_ROOT` is a
  *documented override* that propagates to the sub-make, so
  `make test TEST_ENV_ROOT=/some/where` expands to `rm -rf /some/where`. Both
  are invisible in the source line and obvious in `make -n`. The recipe now
  removes only the leaves `PREP_TEST_ENV` creates, and
  `tests/arch/destructive_recipe_spec.lua` asserts it against the *expansion*.
  Rule: before shipping any `rm -rf` in a recipe, print the expansion under a
  path containing a space and under every documented override
  (`ARCH-PURPOSE`, Root Cause).
- **A guard must assert the invariant it names, not a proxy that rejects the
  shapes already seen.** My first guard for the rule above checked "every
  removed path is inside the repo or the scratch root" — and `$(CURDIR)` is
  inside `$(CURDIR)`, so a recipe deleting the entire working tree passed 2/2
  green. It now compares the removed set against the exact set the harness
  builds. Rule: after writing a fitness function, ask what *else* satisfies the
  assertion besides the correct code; if a catastrophic input passes, the
  assertion is a proxy (`ARCH-PURPOSE`).
- **Verify a harness-sensitive spec through the harness, not a hand-built env.**
  The exact-set guard passed every hand-rolled `nvim -u tests/minimal_init.vim`
  run and failed all ten `make test` runs: under the harness `$TMPDIR` is
  `/tmp/claude-501/...`, and make reports `$(CURDIR)` as the *physical* path, so
  `/tmp/...` never equalled `/private/tmp/...`. Rule: when a spec's subject is
  the build environment, the only run that proves anything is the real one — and
  ask the authority under test (`pwd -P`) rather than canonicalizing by hand,
  since probe paths may not exist yet.
- **`eval set -- $args` is not "split like the shell would" — it parses twice.**
  The first guard I wrote for the rule above reported a false violation on a
  correctly quoted recipe, because `sh` consumes the quotes parsing the `eval`
  line and `eval` then re-splits `"a b"` into two words. `make` hands a recipe
  to `sh -c`, which parses it *once*, so `set -- $args` is the faithful model.
  Rule: when a test models a shell behavior, count the parses.


- **A test that must not be affected by shared mutable state is fixed at the
  writer, not at every reader.** The suite's scratch tree lived in `$(CURDIR)`,
  so eight parallel jobs churned the very directory the `find`/`grep`/`ack` tool
  specs traverse; the first plan scoped one spec's traversal away and added an
  arch rule to police the rest. That rule would have failed three legitimate
  specs — including `grep`'s "defaults missing path to cwd", whose whole subject
  *is* traversing cwd. Rule: when N readers race one writer, count the readers.
  If the invariant needs a lint to hold, you are defending it in the wrong place
  — move the writer out of the readers' reach and the lint becomes unnecessary
  (`ARCH-DRY`, Root Cause).
- **Readiness signalled by file existence is a torn read waiting to happen.**
  The fake SSE server `open()`ed its ready file and wrote the port digits at
  close, so the path was readable while zero bytes long; the poller waited on
  `filereadable()`, read nothing, and crashed concatenating nil into a URL. The
  filed diagnosis blamed a bind failure — but the bind completes inside the
  `TCPServer` constructor, before any readiness is published, so retrying it
  would have changed nothing. Rule: publish a readiness signal atomically
  (write a sibling path, rename onto it) *and* have the consumer wait on a
  parseable value rather than on existence. Verify a suspected race by
  reproducing the window, not by reasoning about which step "looks" racy.
- **"Ten runs agreed" is weak evidence for a race fix; construct the failing
  state instead.** The empty-then-filled, absent, and non-numeric signals are
  all constructible directly, so the guard gets deterministic tests with no race
  to win, and the soak proves only what a soak can — that nothing else broke
  (`ARCH-PURPOSE`).
- **A gate that raises a better design has done its job — take the redesign, not
  the patch.** The round-1 plan-quality findings turned a per-spec workaround
  into a one-site placement fix that also cleared an unrelated sandbox `git
  init` failure. Rule: when a review names an alternative you rejected
  implicitly, either adopt it or write down why in Non-goals; an unstated
  rejection is indistinguishable from not having considered it.


## 2026-07-19 (#196)

- **A value cached at attach/init goes stale when its inputs are recognized
  later; if a sibling path recomputes the same value live, the two silently
  diverge.** Path typeahead froze the neighborhood policy in
  `vim.b[buf].parley_root_policy` at completion-attach, while tool execution
  recomputed `policy_for_buf` fresh each submit — so once the repo was
  recognized *after* attach, completion offered a narrower root than submission
  resolved. Rule: when two consumers must agree on a derived value, have them
  share the derivation *at use time*, not a snapshot; only cache a derivation
  whose inputs are immutable after capture, else invalidate on the exact inputs
  that change it (here `config.repo_root` / `chat_roots`). One owner, evaluated
  consistently (`ARCH-DRY`).
- **A regression test that plants the very state the fix removes guards the
  implementation line, not the behavior.** The first #196 test set
  `parley_root_policy` directly — a var production no longer reads — so it
  pinned one code path and would miss a freeze re-added under a different name.
  Rule: drive the real state transition through the production entry point
  (attach-before-recognition → recognize → assert the live result), so the test
  survives refactors of *how* the value is derived (`ARCH-PURPOSE`).

## 2026-07-17 (#194)

- **A revision that changes a contract must update the normative Spec, not only
  append historical rationale.** #195 intentionally made initial hydration the
  sole `zE` boundary, but the original Spec still said Parley never clears
  document-wide folds. Rule: after every behavioral plan revision, shadow-sweep
  the Spec, Done-when, plan goal, atlas, and header comments for superseded
  absolutes (`ARCH-PURPOSE`).

- **A checked plan edge-case list must map to explicit production tests, not
  merely to helper-level coverage or nearby happy paths.** The close review
  found that end submission promised no/one/multiple trailing blanks and a
  final-line marker, while its integration tests instantiated only the first
  two shapes. Rule: before ticking a plan step, enumerate every named fixture
  variant against the production entry-point tests; adjacent coverage does not
  satisfy a promised slice (`ARCH-PURPOSE`).
- **Whole-buffer replacement is observable UI state destruction even when the
  resulting text is identical.** Neovim manual folds are attached to buffer
  ranges, so rewriting the transcript can erase or migrate folds into unrelated
  questions. Rule: plan semantic transforms as original-coordinate edits and
  apply them bottom-to-top through bounded buffer mutations; test both fold text
  and gutter visibility through the production entry point (`ARCH-PURE`).

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

## 2026-07-17 (#193)

- **Neovim manual folds do not reliably grow with streamed tail replacement.**
  Replacing the last line of a folded range can shrink the fold to its opener,
  so model growth alone does not maintain the visible fold. Rule: after a
  foldable streaming write, recreate only the active semantic model range;
  never clear the window's fold tree, and pin both the shrink and unrelated-fold
  preservation behavior in a real headless Neovim integration test.

## 2026-08-01 (#197)

- **A fixture set that only covers the case where two namespaces coincide cannot
  catch confusing them.** #197 queried cliproxy credential health with a *login
  provider* where a *channel* is required. The two are the same string for
  `claude` and only for `claude` (`gemini`/`gemini-cli`/`aistudio` all collapse to
  `google`), so a healthy credential read as "missing" and prompted a spurious
  login — through 100+ green assertions, because every fixture used `claude`.
  Rule: when two identifier spaces map many-to-one, the test set must include a
  member where they *differ*; a passing suite over the degenerate case is no
  evidence at all.
- **When a refactor deletes a `pcall`, the replacement inherits the obligation.**
  The old auth hook was called inside `pcall`; the new seam was not, and it runs
  synchronously (filesystem + `vim.system`) before returning. A throw then
  skipped both the error delivery and the timeout arming, and `tasker`'s
  `call_safely` swallowed it — stranding the chat leg with no message, strictly
  worse than the code replaced. Rule: grep the deleted call site for `pcall`/
  `xpcall` before declaring a seam migration complete.
- **A "claim" contract makes every early return a leak.** Once a hook signals it
  owns a failure, the UI stays open until it settles. Rule: when a callback takes
  ownership, audit *every* path out — including ones inside a `vim.ui.select`
  callback, where a raising `vim.cmd` skips the settle — and pin it with a test
  that throws from the riskiest step.
- **Two timeouts on the same path must be related by construction, not by
  eyeball.** The recovery backstop (15s) was shorter than the repair it guards
  (≤16s worst case), so a slow repair would be declared timed-out one second
  before succeeding, discarding a correct diagnosis. Rule: itemize the inner
  budget in a comment, derive the outer from it, and note that changing one
  requires re-checking the other.
- **Don't log a condition on a shared path that cannot distinguish the cases.**
  `finish_stdout` runs for successes *and* failures, so logging "response is
  empty" there announced a misleading error ahead of every real diagnosis — the
  exact symptom the issue existed to remove. Rule: record the fact where it is
  observed, report it where the outcome is known.
- **Broad error-matching patterns need a status gate, and the gate needs a
  property test.** Patterns like `authentication_error` match ordinary assistant
  prose — a chat *about* an auth bug would have popped a login dialog. Rule: gate
  classification on a non-2xx status and pin it with `bodies × 2xx → nil`, not a
  list of hand-picked cases.
- **A test that spawns a real external binary can reach the operator's live
  credentials.** `cliproxyapi` on `/opt/homebrew/bin` made `discover_binary` find
  the real binary, and `ensure_running` spawned it with no `auth-dir` — i.e.
  against `~/.cli-proxy-api`, starting a refresh loop on the operator's real
  OAuth token (rotating refresh tokens; this is what broke the credential in the
  first place). Rule: specs that exercise binary discovery must pin `PATH` to
  system dirs, and any spec booting a real proxy must use a throwaway auth-dir
  with a fabricated credential.
- **Comparing timestamps across representations is wrong, not merely fragile.**
  #197 M2 compared a UTC `…Z` string against cliproxy's local-offset RFC3339 with
  a plain `>`. The same instant renders as `…T18:35:01Z` and `…T11:35:01-07:00`,
  and `"Z" > "-"` is true while `"1" > "8"` is false — so the answer depended on
  the operator's timezone: always-stale west of UTC, dead rung east of it. Rule:
  normalize to epoch seconds at the IO seam and let pure code compare numbers;
  never let a string compare stand in for a time compare.
- **The degenerate-fixture trap repeats unless the test names the axis.** The
  staleness tests used `-07:00` on *both* sides — the identical mistake this file
  already recorded from M1's channel-vs-login bug, made again two milestones
  later while the rule was on the page. Rule: when a value has multiple valid
  representations, the test must enumerate them (`Z`, `+hh:mm`, `-hh:mm`,
  fractional seconds), not pick one and repeat it.
- **A "three axes" problem doesn't stop at two.** #197 fixed channel-vs-login,
  then shipped provider-vs-channel in the very commit claiming to remove that
  class of bug (`:ParleyProxy models google` reading health under `google` rather
  than gemini/gemini-cli/aistudio). Rule: when a fix reveals two identifier
  spaces, enumerate *all* the spaces in the system and check each consumer
  against the one it needs — the second confusion is not fixed by fixing the
  first.
- **Two copies of a repair sequence will diverge at the fix.** The `restart` rung
  re-implemented stop→ensure while omitting the port-release wait that an
  existing helper had — including its comment explaining why the wait is required
  and why no test can catch its absence. Rule: when adding a second caller for a
  sequence that already exists, extract the helper instead of retyping it.
- **A budget stated in a comment drifts; a budget asserted in a test cannot.**
  The recovery backstop vs repair-budget relationship was re-opened by two
  successive reviews because it lived only in prose that said "re-check the
  other". Rule: express the terms as data and assert the inequality in a spec.
- **A parser tested against itself is untested.** #197's RFC3339 parser was a
  full day off for every date in a leap year, and every staleness test passed —
  because each supplied the "disk" side as the parser's own output, so a
  systematic offset cancelled on both sides. Rule: date/number parsers get at
  least one assertion against an **external oracle** (absolute expected values
  computed elsewhere), plus the boundary cases the algorithm branches on (leap
  years, epoch, century/400-year rules).
- **Two rungs that end in the same call are indistinguishable to tests.** The
  `restart` and `retry` recovery rungs both finished with `retry()`, so a bug
  that made `restart` fire on every healthy failure — SIGTERMing a shared daemon
  — was invisible to integration and e2e alike. Rule: when branches converge on
  one observable outcome, assert on the branch's *side effect* (here: that
  `stop()` was not called), not just the outcome.
- **Prefix-matching a name against a namespace with hierarchical members is a
  bug waiting for the member to exist.** Globbing `<channel>-*.json` made
  `gemini` match `gemini-cli`'s credential file. Rule: when the source of truth
  already names the exact resource (the management record carries `path`), carry
  it through rather than reconstructing it from a naming convention.
- **`SO_REUSEADDR` makes a bind probe a liar.** Preflighting a port by binding it
  reports "free" while another socket is actively listening — precisely the case
  the preflight exists to catch. Rule: to detect a listener, *connect*.
- **A budget in a comment drifts; a budget summed from a hand-written table also
  drifts.** Three successive reviews re-opened the same timeout relationship.
  Rule: derive the terms from the constants the code actually uses, and assert
  the inequality — then the table cannot be right while the code is wrong.
- **Fixing a comparison three times without asking what it compares.** #197's
  staleness check was repaired on the timezone axis, then the calendar axis, and
  was still dead code — because both operands were the *same quantity* (the
  credential file's mtime, read two ways). Rule: when a comparison misbehaves,
  first name what each side measures and confirm they are different quantities;
  only then debug the comparison. A test that fabricates one operand can never
  ask this question, so reproduce the condition the way the system produces it.
- **"It's already covered" needs the deletion test.** A `_stray_spawned` sweep was
  added with a regression test that passed with the code deleted, because the
  existing `_spawned` table already held every pid. Rule: before adding a
  belt-and-braces mechanism, delete the candidate and run the test that
  supposedly pins it — if it still passes, the mechanism is dead weight.
- **Put the cheap guard before the expensive scan, not inside it.** A
  once-per-session warning called a blocking `ps ax` + `lsof` (~85ms) on every
  dispatch because the guard lived inside the function the scan fed. Rule: on a
  hot path, check the flag before doing the work it gates.
- **A "once per session" guard must latch on the WORK, not on having something to
  report.** #197's peer scan set its flag only when peers were found, so the
  healthy machine — the one that had just cleaned up, as the feature instructs —
  rescanned (~150ms blocking `ps`+`lsof`) on every request forever. Rule: set the
  latch where the expensive call happens, and test the zero-result path
  explicitly; it is the one the happy user lives in.
- **Don't read module state a collaborator resets.** A compound-repair guard read
  a flag that the repair itself cleared on success, before the decision that
  consulted it — so it was always false and the path it guarded ran anyway. Rule:
  when a guard must span one logical operation, scope it to that operation
  (a per-call local), not to the module.
- **`luv` returns `nil, err`; it does not raise.** `pcall(uv.kill, ...)` succeeds
  on ESRCH and EPERM alike, so a reap reported "stopped 5" having stopped none.
  Rule: for every `uv.*` call, check the returned code — a pcall around it tests
  nothing.
- **Latching a callback is not the same as silencing it.** An abandoned watcher
  whose `on_done` was latched still called `vim.notify`, telling an operator
  three minutes later that a login they had since completed "did not complete".
  Rule: put the latch around the whole side-effecting block, not just the
  continuation.
- **Substring matching keeps being the bug.** Within one issue it produced three
  distinct defects: a `ps` scan that would have killed a shell whose command line
  mentioned the binary, a credential glob where `gemini` matched `gemini-cli`,
  and a flag check where `-login` matched inside `-claude-login` — disabling the
  guard written for exactly that flag. Rule: when testing membership in a
  namespace, match the whole token (first argv element, exact filename, the
  usage line's leading flag), and write the test with a member that is a strict
  prefix or suffix of another.
- **Confirm-then-act must act on what was confirmed.** A reap prompt listed the
  processes it found, then called a function that re-scanned and killed a
  possibly different set. Rule: pass the confirmed collection into the mutating
  call; never let it re-derive its own targets after the user has agreed.
- **Bookkeeping deferred is bookkeeping compounded.** Plan checkboxes, an
  outdated decision table, and twelve missing entity rows were flagged in four
  consecutive reviews before being fixed, costing a review round each time. Rule:
  when a review names a documentation drift, fix it in that round — the cost only
  grows, and reviewers rightly keep re-raising it.
- **Two hand-maintained sets on one axis will drift; enforce the correspondence
  in a test.** `LOGIN_FLAGS` (7 entries) and `CHANNEL_LOGIN` (6 values) were both
  edited by hand, and `codex-device` fell through the gap — silently disabling a
  credential-watch filter whose comment promised it and dropping the account from
  the success notice. Rule: when one table's keys must all resolve through
  another, assert exactly that over the whole key set; deriving one from the
  other is better still.
- **A fake state no test drives is documentation, not a fixture.** Two of four
  modeled login modes were unreachable — one because the timeout it needed was
  hardcoded. Rule: every state a fake models needs a test that drives it, or the
  state should be deleted; add the injection seam that makes the branch reachable
  rather than leaving it as a comment.
- **`pcall(f, expr)` does not protect `expr`.** Arguments evaluate before the
  call, so `pcall(vim.json.decode, readfile(p))` leaves the *read* unguarded —
  and `vim.fn.readfile` raises (E17 on a directory, E484 on a vanished file). In
  an async poll with no outer guard that stranded a login watch entirely. Rule:
  wrap the whole expression in a closure — `pcall(function() … end)` — whenever
  any argument can itself throw.
- **Guarding the callback is not guarding the call.** `vim.ui.select` is replaced
  by UI plugins that can raise; a previous fix had guarded only the code *inside*
  its callback. The raise skipped the settle and latched the prompt-active flag
  on for the session, so no login was ever offered again. Rule: when a fix guards
  "the risky part", re-ask which call actually crosses into third-party code.
- **A conformance check can falsify your own comment — let it.** Pinning
  `updated_at` semantics against the real binary immediately disproved the stated
  premise ("a touch never advances it"): fsnotify sees attribute changes, so the
  proxy usually does reload. The code was right for a subtler reason than the
  comment claimed. Rule: assert the property the logic actually needs
  (independence of the two quantities), not the anecdote from one manual probe.

## 2026-08-15 (#198)

- **`vim.NIL` is truthy, so `if obj.field then` accepts an explicit JSON null.**
  `vim.json.decode` maps JSON `null` to a userdata sentinel, not to `nil`. In a
  streaming decoder that reads a field across chunks, a later chunk carrying
  `"id":null` therefore *overwrote* a correctly captured value with userdata,
  which then raised `attempt to concatenate a userdata value` two frames away —
  in code whose stated contract was "never raises, degrade instead". The tell
  was an asymmetry that was already visible in the same function: `arguments`
  was `type(...) == "string"`-guarded while `id`/`name` were truthiness-guarded.
  Rule: read every optional field out of decoded JSON through a typed accessor
  (`sse.str`), never a bare truthiness test — and when one field in a block is
  type-guarded and its siblings are not, treat the inconsistency as the bug.
- **A test that branches on its environment can assert nothing.** A spec for a
  config-level fallback did `if configured then assert.equals(configured, got)
  else assert.equals("none", got) end` — and in the unit process the config was
  never set, so it permanently took the else branch and green-lit the one
  behaviour the function existed to own. Rule: if a test needs ambient state,
  stub it explicitly; a conditional assertion is a skipped test that reports
  success. Corollary: an entity whose test needs that branch has an ambient
  input and is not as pure as its docstring says.
- **Splitting a milestone at a layer boundary can turn a loud failure into a
  silent one.** Landing encoders in M1 and decoders in M2 left a window where a
  tool agent built a valid request, decoded zero calls, and rendered an empty
  answer — replacing an explicit "tools not supported" raise. Rule: when
  sequencing milestones, ask what the intermediate state *does* for a user, not
  just what it contains; if a clear error becomes a wrong answer, record the
  no-merge constraint and order the milestone to close the exposure first.
- **"OpenAI-compatible" does not mean "shares the OpenAI payload builder."** A
  cross-cutting change was scoped to `openai.format_payload` on the assumption
  that the cliproxy OpenAI route and ollama delegated to it. They don't — each
  builds its own payload; only copilot and azure delegate. The change would
  have shipped with every unit test and golden green while missing the issue's
  own target agent, because the tests exercised `providers.get("openai")` and
  the target went through `cliproxy_openai_payload`. Rule: before installing a
  cross-cutting step in a "shared" function, grep for its actual callers and
  pick the seam with exactly one — here `dispatcher.prepare_payload`, the sole
  caller of `adapter.format_payload`. Corollary for tests: a regression test
  must exercise the path the ISSUE names, not the path that is easiest to
  construct.
- **Milestone-close is a long-running external process; do not race it.** A
  `sdlc milestone-close` exceeded the foreground timeout and was backgrounded.
  A hand-rolled liveness check (`pgrep` piped into `kill -0`) returned empty
  and so reported "finished" instantly, and a second close was launched while
  the first was still dispatching its review — the #172 re-close loop, caught
  only by reading the first run's output afterwards. Rule: for a long verb, use
  the harness's own backgrounding and wait for ITS completion signal; never
  infer "process died" from an empty `pgrep`, which is indistinguishable from
  "never matched".
- **In Lua a `local function` is not in scope for functions defined above it —
  and a `pcall` at the call site hides the consequence.** #200 defined
  `default_model_provider` below `reconcile_exchange`; inside the earlier
  function the name resolved to a nil *global*, so the drift re-derive path
  could never run. Because the call was `pcall(provider, buf)`, the failure
  was swallowed and the code took the "refuse" branch silently — tests still
  passed, since refusing looks identical to having nothing to fold. Lint caught
  it, not the suite. Rule: when a function is reached only through a `pcall`,
  the tests must assert the *success* branch was taken, not merely that nothing
  threw; and treat "accessing undefined variable" from the linter as a
  correctness finding, not style.
- **Widening a destructive operation demands widening its verification, not
  just the verification of what it creates.** #200 changed fold clearing from
  "delete at projected start rows" to "clear the whole exchange span", but
  verified only the fold ranges. The span came from the same stale model and
  went unchecked — and for an exchange with no foldable block the range list is
  empty, so range verification passed *vacuously* while the stale span deleted
  a neighbouring exchange's fold. Rule: when a diff widens what an operation can
  destroy, enumerate the inputs to the destruction separately from the inputs to
  the creation, and check that a vacuous input (empty list, nil span) fails
  closed rather than open.
- **A wall-clock assertion in the test suite measures the machine, not the
  algorithm.** #200's first scaling test passed alone and failed under full
  suite load (8.35ms vs 79.05ms) because both numbers inflated unequally under
  contention. Rule: to pin an algorithmic property, sample repeatedly and
  compare the MINIMUM of each size — the least-contended sample is the one that
  reflects the code — and name the test for the property it actually pins.
- **Deleted tests do not fail — verify the inventory, not just the result.**
  #200 replaced one test by slicing a spec file between two textual markers and
  removed nine regression tests with it, every pin from seven review rounds. The
  suite went green at 16 tests where it had been 25. Rule: after any structural
  edit to a spec (moving, replacing, or reordering blocks), diff the test
  inventory against `HEAD` — `comm -13` over the extracted `it("...")` names —
  before trusting the run. A shrinking green suite is the most convincing wrong
  signal available.
- **Prove a performance property by counting work, not by timing it.** #200's
  span-clearing test asserted wall-clock and flaked twice under suite load, once
  sending the author chasing a regression that was only contention. Exposing the
  clear loop's iteration count turned it into an exact assertion: a 16x longer
  span must cost no more iterations. If a property is algorithmic, find the
  countable quantity that expresses it; reach for a clock only when the thing
  under test really is latency.
- **A suite that fixes an environment setting cannot find bugs in the other
  setting.** #200's fold clearing silently no-opped under `nofoldenable` — `zj`
  will not navigate and `zD` will not delete — so a stale fold survived the
  reconcile meant to remove it, reproducing the issue's original symptom
  verbatim. It shipped because every fold spec set `foldenable = true` in setup,
  making the defect untestable by construction. Rule: when behaviour depends on
  an editor option or environment flag that users can flip (and that the product
  itself flips — parley has a fold-toggle shortcut), the suite must exercise both
  states, and code that depends on the option should save/force/restore it rather
  than assume.
- **Check the test inventory for duplicates, not only for shrinkage.** The
  companion rule above catches deleted tests by a falling count. #200 hit the
  mirror image: a botched edit left `describe("anchor verification")` in the file
  twice, so seven cases ran as copies and the count *rose*. Every fold-test total
  reported for four rounds was inflated by seven, and a growing green suite reads
  as progress. Rule: after any structural edit to a spec, run
  `grep -o 'it("[^"]*"' <spec> | sort | uniq -d` and require it to be empty, as
  well as diffing the count against `HEAD`.
- **When a guard encodes an assumption a later milestone will invalidate, write
  the fixture that will break it — do not just note the risk.** #200 M1 recorded,
  in the plan and in a code comment, that M2 would make an in-body `💬:`
  legitimate content and that any raw-prefix scan would then reject correct
  input. M2 duly broke it — in `verify_anchors`, the sibling of the function the
  note named — and *nothing in the suite noticed*, because the real corpus has no
  in-body markers at all. What caught it was the adversarial fixture, on the day
  it was added. Rule: a cross-milestone hazard is only recorded once a test
  exercises it; a comment predicting the break is documentation of a gap, not
  coverage of one.
- **`cat > file` on a path you assume is new is a silent overwrite — check
  existence, not intent.** #200 M2 created what it believed was a new
  `chat_parser_tools_spec.lua` and destroyed 11 pre-existing tests. The suite
  went green at 16 where it should have been 27. This is the *second* deletion
  of tests in the same issue, after a lessons entry had already been written
  about the first: that rule said "after any structural EDIT to a spec, diff the
  inventory against HEAD", and it was not applied because this felt like a
  creation, not an edit. Rule: before writing a spec file, `test -e` it — and
  diff the inventory against `HEAD` on creation as well as on edit, since a
  creation that lands on an existing path is the most destructive edit there is.
- **A tick, or a claim that a test pins a fix, may only be written by the action
  that produced its evidence — and for a regression test that evidence is the
  REVERT going red, not the suite going green.** #200 wrote "two tests pin it";
  reverting the module left one of them green, so it pinned nothing and was a
  characterization test wearing a fix-pin label. **Corollary: never tick a gate
  step from inside the gate.** The same issue ticked "sdlc milestone-close M2"
  and "sdlc close" in its plan while the milestone-close review was running, with
  no `closed M2` log line and status still `working`. This rule was written
  half-formed in the very commit that violated it; the revert half is the part
  that has teeth.
- **Never bulk-tick checkboxes.** #200 M2 ticked a plan's step list with a
  blanket replace, including "re-run the audit against the operator's live
  chat_dir" — which had not been run. A tick is a claim of evidence; applying it
  mechanically converts a plan into fiction. The audit was afterwards actually
  run (115 files, 1155 assertions, 0 violations) and its result recorded beside
  the tick. Rule: tick a step only in the same action that produced its
  evidence, and put the evidence next to the tick.
- **A spec-inventory diff proves NAMES survived, not PROPERTIES.** #200 removed
  five `tool_body` tests, added four `scan` tests, diffed the `it("...")` names
  against `HEAD`, and declared nothing lost. One property went with them:
  "a body opens on the line immediately after its marker". Patching the scanner
  to accept an opener anywhere still left the whole suite green, so a genuine
  user question could be marked as body — suppressing both the parser's
  classification and the fold guard — with nothing red. Rule: a change that
  removes tests must name the behavioural property each one pinned and show a
  replacement going red on the same revert. Counting names is not coverage.
- **An oracle's SUBJECT SELECTION may not consult the artifact under test —
  only its assertion may.** #200 added a raw-text sweep precisely because the
  existing harness enumerated subjects from the parse it was checking, and then
  selected that sweep's subjects with `fence.scan`, the function under test. A
  filter computed from the artifact exonerates exactly the rows the artifact got
  wrong. Rule: build the oracle's subject set from the rawest independent source
  available, and let it be cruder than the real grammar — cruder only means it
  checks more rows.

## Never run an integration spec bare — `make` owns the sandbox (#205)

`make test` / `make test-spec` export `HOME`, `XDG_*` and `TMPDIR` into a scratch
tree; a raw `nvim --headless -c "PlenaryBustedFile <spec>"` does not. During #205
that difference overwrote the operator's real
`~/.local/share/nvim/parley/cliproxy/config.yaml` with a spec's port and
`api-keys: ["testkey"]`. cliproxy watches that file, reloaded it, and the live
proxy began 401-ing the operator's own bearer — a working setup broken by a test
run, mid-session.

Two rules, both needed:

- **Run specs through `make`.** `make test-spec SPEC=<atlas-key>` (an atlas
  feature key from `atlas/traceability.yaml`, NOT a spec path) or `make test`.
  When a single file is genuinely faster to iterate on, export the same env
  `make -n test-clean-env` prints.
- **Every spec that can write a derived artifact redirects it itself**, e.g.
  `require("parley.cliproxy")._set_data_dir(vim.fn.tempname())` at file scope.
  Defence in depth: the harness redirect is the sandbox, the in-spec redirect is
  the seatbelt. As of #205 all `tests/integration/cliproxy_*` specs carry it.

The tell that this has happened: parley suddenly reports `client api-key
mismatch`, and the rendered config's `port`/`api-keys` do not match your setup.
`cliproxy.ensure_running` re-renders the file, and the watcher reloads it.

## Four recurring failures, and the checks that catch them (#205)

#205's boundary reviews ran thirteen rounds. Most findings were not new defects
but the same four failures repeating, so the rules matter more than the fixes:

- **A test that cannot fail is not coverage.** Five times on that issue a fix
  shipped green while the code it "covered" could be deleted or reverted with the
  suite passing: a spec that re-implemented the logic in its own body, one that
  stubbed the function under test, one that reused a just-killed port so a dying
  process answered, one asserting containment where order was the point, and an
  arch guard whose allowance was below the real count. **Check: break the code on
  purpose and watch the test go red, before claiming the fix is covered.** State
  the mutation in the close evidence — and make it the WRONG IMPLEMENTATION, not
  merely deletion. #205 claimed a mutation check on a selection fix having only
  deleted the block; the specific wrong version (resolving an index in the other
  coordinate space) still passed, because the fixture's target was the last row
  and the widget's clamp reached it from any out-of-range index.
- **Fix the class, not the site.** A finding names one instance; the deliverable
  is the enumeration. `free_port` was "swept" onto a shared helper while eight
  copies remained; a boundary guard was added to one spec while three lacked it;
  a referent check matched one definition form out of four. **Check: grep the
  whole tree for siblings before calling a sweep done, and paste the count.**
- **A sweep without a guard is a snapshot.** Two of that issue's consolidations
  had regressed before the boundary closed. **Check: a consolidation ships with
  an arch spec that fails when a new consumer diverges** —
  `tests/arch/single_source_sweeps_spec.lua` is the pattern.
- **A boundary whose diff touches `lua/` and no spec does not close.** Runtime
  behaviour changed in two modules with zero test changes in the same window.
  **Check: `git diff <boundary>..HEAD --stat -- lua/ tests/` before every
  milestone-close; if `lua/` moved and `tests/` did not, that is the finding.**

And one for evidence: **a Done-when is recorded in `## Log` with the output that
proves it**, not asserted in the close message. #205's live-pick e2e is the
shape — the payload, the response block types, and the answer, where a *correct*
answer distinguishes "the search ran" from "the request succeeded".

## A doc comment and a test title are assertions — sweep them with the code (#205)

Three findings on #205 were a comment or a test title still describing the
contract the same diff had just changed: a handle doc saying `update` takes an
INDEX after it started taking an identity, a test titled "addresses the filtered
list" after the meaning moved to the caller's list, and stacked doc blocks that
left the function below them undocumented.

They read as pedantry and are not. A stale comment is the most trusted wrong
answer in the file — the next reader believes it over the code, and the next
reviewer measures the code against it and files a finding either way.

**Check:** when a contract changes, `grep` the identifier across `lua/` and
`tests/` and fix every comment and test TITLE that states the old behaviour, in
the same commit as the change. An insertion goes after the preceding function's
body, never between a doc block and the function it documents.
