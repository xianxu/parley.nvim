---
gate: boundary-review
issue: 202
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-08-21T23:23:29-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Important
          title: test-clean-env rm -rf word-splits on unquoted LEGACY_TEST_DIRS, targeting paths outside the repo
          detail: |-
            Makefile.parley:223 quotes "$(TEST_ENV_ROOT)" but not $(LEGACY_TEST_DIRS). Reproduced with a copy of
            the makefile under a directory named 'space test': the recipe expands to rm -rf on
            '<parent>/space' plus relative 'test/.test-home' words. On a checkout at '~/my code/parley.nvim'
            this deletes '~/my'. The pre-diff version quoted all three paths, and this target now runs first in
            every make test. Fix by quoting each: "$(CURDIR)/.test-home" "$(CURDIR)/.test-xdg" "$(CURDIR)/.test-tmp".
          family: unquoted-path-expansion
          round: 1
        - id: BR-2
          severity: Important
          title: The scratch-placement invariant the whole issue rests on can be reverted with nothing going red
          detail: |-
            Nothing fails if TEST_ENV_ROOT moves back inside $(CURDIR) (Makefile.parley:37) or if
            tests/minimal_init.vim:24 repoints directory into the tree; the suite would just resume flaking.
            Non-goals correctly rejects a lint over spec traversal roots, but a guard on the writer has no
            false-positive problem: a tests/arch spec asserting vim.fn.tempname() and vim.o.directory are not
            under vim.fn.getcwd() is green today and red on regression (ARCH-PURPOSE).
          family: invariant-without-regression-guard
          round: 1
        - id: BR-3
          severity: Important
          title: Done-when item 3 claims atomic port publishing, but no test fails without publish_ready
          detail: |-
            tests/fixtures/fake_sse_server:57 adds staging-write plus os.replace, and atlas/infra/test_harness.md
            states it as a rule, yet reverting it leaves the suite green because the consumer guard absorbs it.
            Log entry 2 already describes a deterministic probe: spawn the fixture and spin on stat of the ready
            path, failing if it is ever observed zero-length. That reproduced the old bug on the first attempt and
            cannot false-positive against the fixed publisher.
          family: claim-without-failing-test
          round: 1
        - id: BR-4
          severity: Important
          title: tests/perf/chat_typing.lua still hand-restates the pre-202 in-repo scratch path
          detail: |-
            chat_typing.lua:352 falls back to ".test-tmp/perf/parley-chat-typing.json", writing into the repo tree
            whenever start() runs without PERF_OUTPUT (only make perf sets it). TOOLING.md:47 now claims the report
            lands in $(TEST_TMP)/perf/, which is true only via make. This is the one surviving consumer that does
            not derive from the relocated source (ARCH-PURPOSE shadow-sweep, ARCH-DRY); derive it from
            vim.env.TMPDIR instead.
          family: stale-restatement-of-moved-source
          round: 1
        - id: BR-5
          severity: Minor
          title: TOOLING.md perf section says "see Test scratch directories below" but that section is above it
          family: stale-restatement-of-moved-source
          round: 1
        - id: BR-6
          severity: Minor
          title: TEST_ENV_ROOT ?= is recursively expanded, so cksum forks on every expansion of TEST_ENV/TEST_TMP
          detail: |-
            Makefile.parley:37. Hoist the key into a := variable (TEST_ENV_KEY := $(shell ...)) and reference it
            from the ?= default, so the subshell runs once per make invocation.
          family: makefile-expansion-cost
          round: 1
        - id: BR-7
          severity: Minor
          title: The same scratch-placement rationale paragraph is restated in four files
          detail: |-
            Makefile.parley:26-35, tests/minimal_init.vim:19-22, TOOLING.md:25-33 and
            atlas/infra/test_harness.md:27-36 each carry a near-identical version (ARCH-DRY, prose). The two code
            comments could point at the atlas entry instead of restating it.
          family: rationale-duplicated-across-surfaces
          round: 1
        - id: BR-8
          severity: Minor
          title: Atlas omits that nvim's tempdir fallback chain ends at cwd, so an unwritable TMPDIR puts scratch back in-tree
          detail: |-
            Observed during review: with $TMPDIR set but unwritable, vim.fn.tempname() returned
            /Users/xianxu/workspace/parley.nvim/nvim.xianxu/... . PREP_TEST_ENV's mkdir -p aborts the run first
            under make, so the invariant holds there, but the dependency on that loud failure is worth one line in
            atlas/infra/test_harness.md.
          family: invariant-without-regression-guard
          round: 1
        - id: BR-9
          severity: Minor
          title: make test now wipes the documented default PERF_OUTPUT location, which TOOLING.md does not mention
          family: stale-restatement-of-moved-source
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-08-21T23:50:30-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: 'Verified at the expansion: make -n test-clean-env emits four separately-quoted words.'
          round: 2
        - id: BR-2
          disposition: addressed
          note: tests/arch/scratch_placement_spec.lua verified 6/6 green at HEAD, 6/6 red with scratch repointed into the repo.
          round: 2
        - id: BR-3
          disposition: addressed
          note: fixture_ready_publish_spec verified red on both revert shapes; the honored-delay assertion catches hook deletion.
          round: 2
        - id: BR-4
          disposition: addressed
          note: Derivation from vim.env.TMPDIR evaluated directly and correct; shadow-sweep finds no other live restatement.
          round: 2
        - id: BR-5
          disposition: addressed
          note: TOOLING.md:47 now reads "see Test Scratch Directories above".
          round: 2
        - id: BR-6
          disposition: addressed
          note: TEST_ENV_KEY hoisted to := at Makefile.parley:35.
          round: 2
        - id: BR-7
          disposition: addressed
          note: Makefile.parley:26-28 and minimal_init.vim:19-21 now point at the atlas entry instead of restating it.
          round: 2
        - id: BR-8
          disposition: addressed
          note: atlas/infra/test_harness.md records the cwd fallback and why the guard asserts produced paths.
          round: 2
        - id: BR-9
          disposition: addressed
          note: TOOLING.md now warns that make test wipes the scratch root and a default-path perf report with it.
          round: 2
      findings:
        - id: BR-10
          severity: Important
          title: make test rm -rf's a caller-supplied TEST_ENV_ROOT wholesale, and TOOLING.md advertises that override
          detail: |-
            Second blast-radius defect in the same one-line recipe as BR-1, so fix the rule, not the instance.
            Makefile.parley:224 wipes "$(TEST_ENV_ROOT)" verbatim, test-clean-env now runs first in every make
            test, and command-line overrides propagate to the sub-make. Verified with make -n test
            TEST_ENV_ROOT=/tmp/claude-501/rootprobe, which expands to rm -rf on that whole directory; TOOLING.md:22
            tells readers to pass TEST_ENV_ROOT=/some/where. Rule - test-clean-env may only delete paths the harness
            itself constructs and can name literally, never a caller-supplied path used verbatim, and each quoted.
            Concretely, remove the three leaves PREP_TEST_ENV creates instead of the root - rm -rf "$(TEST_HOME)"
            "$(TEST_XDG)" "$(TEST_TMP)" $(LEGACY_TEST_DIRS) - or always append $(TEST_ENV_KEY) to the override.
          family: unbounded-destructive-wipe
          round: 2
        - id: BR-11
          severity: Minor
          title: The new pre-run wipe makes a second concurrent make test in the same checkout destructive
          detail: |-
            Reproduced - with make test-unit in flight, make test-clean-env deleted most of the live scratch tree
            and exited 1 with "rm - .../tmp - Directory not empty"; the running suite survived by luck. Pre-202 the
            root was shared but never auto-wiped, so the hazard is new. Fails loudly rather than silently, hence
            Minor; a per-run suffix or a lock file would close it.
          family: shared-scratch-across-concurrent-runs
          round: 2
        - id: BR-12
          severity: Minor
          title: fixture_ready_publish_spec copy-pastes the env-building and spawn scaffolding from chat_progress_process_spec
          detail: |-
            fixture_ready_publish_spec.lua:34-40 duplicates the vim.fn.environ() fold, PYTHONDONTWRITEBYTECODE=1,
            uv.spawn and close-on-exit block from chat_progress_process_spec.lua:33-38 (ARCH-DRY). tests/helpers/
            now exists and is the natural home for a spawn_fixture(mode, ready_file) shared by both.
          family: copy-pasted-spec-scaffolding
          round: 2
      blocked: true
    - "n": 3
      timestamp: "2026-08-22T00:08:30-07:00"
      agent: claude
      dispose:
        - id: BR-10
          disposition: addressed
          note: Verified at the expansion under the advertised override - make -n test TEST_ENV_ROOT=/tmp/rootprobe emits only the three leaves plus quoted legacy dirs; repo-wide sweep finds no other non-compliant destructive recipe.
          round: 3
        - id: BR-11
          disposition: addressed
          note: Hazard accepted rather than eliminated, but documented in TOOLING.md and the atlas with both escape hatches and the rejected per-run-suffix alternative - an adequate disposition for a Minor.
          round: 3
        - id: BR-12
          disposition: addressed
          note: vim.fn.environ() and PYTHONDONTWRITEBYTECODE now occur in exactly one file; both fixture specs consume the helper and the publisher guard still goes red on both revert shapes after the refactor.
          round: 3
      findings:
        - id: BR-13
          severity: Important
          title: The test-clean-env blast-radius rule is defended only by a comment, after producing two Important findings
          detail: |-
            Third finding in this family (BR-2, BR-8 preceded it), so per the repeat protocol the fix is the rule,
            not the instance - an invariant this gate has had to enforce gets an executable guard in the same commit,
            because a comment is not a guard. Makefile.parley:225-229 and atlas/infra/test_harness.md:53-61 state the
            rule in prose; nothing goes red if the next edit re-introduces either shape. Prototyped a 15-line guard
            that re-expands the recipe under a probe root, word-splits with eval set -- exactly as the shell would,
            and rejects any argument that is not a harness-built leaf. Verified - green on HEAD (6 args, all
            harness-owned), red on BR-10's shape (bare root) and red on BR-1's shape (4 word-split fragments). No
            false-positive surface, since it inspects the expansion rather than source text. tests/arch/ is the home.
          family: invariant-without-regression-guard
          round: 3
        - id: BR-14
          severity: Important
          title: The rm -rf rule that produced BR-1 and BR-10 never reached workshop/lessons.md
          detail: |-
            AGENTS.md section 4 requires review-found mistakes to become rules in workshop/lessons.md. The 2026-08-21
            (#202) block records four round-0 design lessons but neither of the two bugs the reviews actually found -
            the unquoted rm -rf path list and the rm -rf of a caller-supplied root. The rule lives only in
            atlas/infra/test_harness.md, which is the right place for the harness instance but is not the file read
            at session start; the defect recurred within this very issue because the rule was site-local. One bullet -
            a destructive recipe may only remove paths the tool itself constructed and can name literally, each quoted
            individually, verified by reading the expansion rather than the source.
          family: rule-not-recorded-in-lessons
          round: 3
        - id: BR-15
          severity: Minor
          title: fixture_process.spawn appends extra_env instead of replacing, so a same-named parent variable wins
          detail: |-
            tests/helpers/fixture_process.lua:25-27 appends caller entries after the vim.fn.environ() fold. libuv
            passes duplicate keys straight through (verified - a child printed both DUPKEY=first and DUPKEY=second),
            and the fixture's os.environ.get resolves the parent's entry. Reproduced - with PARLEY_PUBLISH_DELAY=0
            exported in the shell, fixture_ready_publish_spec fails with "port appeared after 47ms;
            PARLEY_PUBLISH_DELAY=300ms was not honored", a spurious red whose message points at the fixture rather
            than the helper. Fold into a keyed map before flattening (~3 lines) so extra_env is authoritative; this is
            new internal API other specs will consume.
          family: override-not-authoritative
          round: 3
        - id: BR-16
          severity: Minor
          title: Makefile help and the test target comment still claim integration tests run sequentially
          detail: |-
            4th finding in this family, so state the rule rather than patch the wording - a surface that restates a
            fact the code owns goes stale, and BR-7 already applied the fix shape by pointing at the atlas.
            Makefile.parley:9, 11 and 52 all say integration runs sequentially; the recipe has used xargs -P $(JOBS)
            since 752c8e0, and the new atlas page correctly documents the parallel fan-out. Line 52 is the context
            line immediately above this window's edit to the test target. The help block should name what to run and
            let atlas/infra/test_harness.md own the execution model.
          family: stale-restatement-of-moved-source
          round: 3
      blocked: true
---

# Gate ledger — parley.nvim#202 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-08-21T23:23:29-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `unquoted-path-expansion` test-clean-env rm -rf word-splits on unquoted LEGACY_TEST_DIRS, targeting paths outside the repo
  Makefile.parley:223 quotes "$(TEST_ENV_ROOT)" but not $(LEGACY_TEST_DIRS). Reproduced with a copy of
  the makefile under a directory named 'space test': the recipe expands to rm -rf on
  '<parent>/space' plus relative 'test/.test-home' words. On a checkout at '~/my code/parley.nvim'
  this deletes '~/my'. The pre-diff version quoted all three paths, and this target now runs first in
  every make test. Fix by quoting each: "$(CURDIR)/.test-home" "$(CURDIR)/.test-xdg" "$(CURDIR)/.test-tmp".
- **BR-2** [Important] `invariant-without-regression-guard` The scratch-placement invariant the whole issue rests on can be reverted with nothing going red
  Nothing fails if TEST_ENV_ROOT moves back inside $(CURDIR) (Makefile.parley:37) or if
  tests/minimal_init.vim:24 repoints directory into the tree; the suite would just resume flaking.
  Non-goals correctly rejects a lint over spec traversal roots, but a guard on the writer has no
  false-positive problem: a tests/arch spec asserting vim.fn.tempname() and vim.o.directory are not
  under vim.fn.getcwd() is green today and red on regression (ARCH-PURPOSE).
- **BR-3** [Important] `claim-without-failing-test` Done-when item 3 claims atomic port publishing, but no test fails without publish_ready
  tests/fixtures/fake_sse_server:57 adds staging-write plus os.replace, and atlas/infra/test_harness.md
  states it as a rule, yet reverting it leaves the suite green because the consumer guard absorbs it.
  Log entry 2 already describes a deterministic probe: spawn the fixture and spin on stat of the ready
  path, failing if it is ever observed zero-length. That reproduced the old bug on the first attempt and
  cannot false-positive against the fixed publisher.
- **BR-4** [Important] `stale-restatement-of-moved-source` tests/perf/chat_typing.lua still hand-restates the pre-202 in-repo scratch path
  chat_typing.lua:352 falls back to ".test-tmp/perf/parley-chat-typing.json", writing into the repo tree
  whenever start() runs without PERF_OUTPUT (only make perf sets it). TOOLING.md:47 now claims the report
  lands in $(TEST_TMP)/perf/, which is true only via make. This is the one surviving consumer that does
  not derive from the relocated source (ARCH-PURPOSE shadow-sweep, ARCH-DRY); derive it from
  vim.env.TMPDIR instead.
- **BR-5** [Minor] `stale-restatement-of-moved-source` TOOLING.md perf section says "see Test scratch directories below" but that section is above it
- **BR-6** [Minor] `makefile-expansion-cost` TEST_ENV_ROOT ?= is recursively expanded, so cksum forks on every expansion of TEST_ENV/TEST_TMP
  Makefile.parley:37. Hoist the key into a := variable (TEST_ENV_KEY := $(shell ...)) and reference it
  from the ?= default, so the subshell runs once per make invocation.
- **BR-7** [Minor] `rationale-duplicated-across-surfaces` The same scratch-placement rationale paragraph is restated in four files
  Makefile.parley:26-35, tests/minimal_init.vim:19-22, TOOLING.md:25-33 and
  atlas/infra/test_harness.md:27-36 each carry a near-identical version (ARCH-DRY, prose). The two code
  comments could point at the atlas entry instead of restating it.
- **BR-8** [Minor] `invariant-without-regression-guard` Atlas omits that nvim's tempdir fallback chain ends at cwd, so an unwritable TMPDIR puts scratch back in-tree
  Observed during review: with $TMPDIR set but unwritable, vim.fn.tempname() returned
  /Users/xianxu/workspace/parley.nvim/nvim.xianxu/... . PREP_TEST_ENV's mkdir -p aborts the run first
  under make, so the invariant holds there, but the dependency on that loud failure is worth one line in
  atlas/infra/test_harness.md.
- **BR-9** [Minor] `stale-restatement-of-moved-source` make test now wipes the documented default PERF_OUTPUT location, which TOOLING.md does not mention

## Round 2 — 2026-08-21T23:50:30-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — addressed — Verified at the expansion: make -n test-clean-env emits four separately-quoted words.
- BR-2 — addressed — tests/arch/scratch_placement_spec.lua verified 6/6 green at HEAD, 6/6 red with scratch repointed into the repo.
- BR-3 — addressed — fixture_ready_publish_spec verified red on both revert shapes; the honored-delay assertion catches hook deletion.
- BR-4 — addressed — Derivation from vim.env.TMPDIR evaluated directly and correct; shadow-sweep finds no other live restatement.
- BR-5 — addressed — TOOLING.md:47 now reads "see Test Scratch Directories above".
- BR-6 — addressed — TEST_ENV_KEY hoisted to := at Makefile.parley:35.
- BR-7 — addressed — Makefile.parley:26-28 and minimal_init.vim:19-21 now point at the atlas entry instead of restating it.
- BR-8 — addressed — atlas/infra/test_harness.md records the cwd fallback and why the guard asserts produced paths.
- BR-9 — addressed — TOOLING.md now warns that make test wipes the scratch root and a default-path perf report with it.

### Raised

- **BR-10** [Important] `unbounded-destructive-wipe` make test rm -rf's a caller-supplied TEST_ENV_ROOT wholesale, and TOOLING.md advertises that override
  Second blast-radius defect in the same one-line recipe as BR-1, so fix the rule, not the instance.
  Makefile.parley:224 wipes "$(TEST_ENV_ROOT)" verbatim, test-clean-env now runs first in every make
  test, and command-line overrides propagate to the sub-make. Verified with make -n test
  TEST_ENV_ROOT=/tmp/claude-501/rootprobe, which expands to rm -rf on that whole directory; TOOLING.md:22
  tells readers to pass TEST_ENV_ROOT=/some/where. Rule - test-clean-env may only delete paths the harness
  itself constructs and can name literally, never a caller-supplied path used verbatim, and each quoted.
  Concretely, remove the three leaves PREP_TEST_ENV creates instead of the root - rm -rf "$(TEST_HOME)"
  "$(TEST_XDG)" "$(TEST_TMP)" $(LEGACY_TEST_DIRS) - or always append $(TEST_ENV_KEY) to the override.
- **BR-11** [Minor] `shared-scratch-across-concurrent-runs` The new pre-run wipe makes a second concurrent make test in the same checkout destructive
  Reproduced - with make test-unit in flight, make test-clean-env deleted most of the live scratch tree
  and exited 1 with "rm - .../tmp - Directory not empty"; the running suite survived by luck. Pre-202 the
  root was shared but never auto-wiped, so the hazard is new. Fails loudly rather than silently, hence
  Minor; a per-run suffix or a lock file would close it.
- **BR-12** [Minor] `copy-pasted-spec-scaffolding` fixture_ready_publish_spec copy-pastes the env-building and spawn scaffolding from chat_progress_process_spec
  fixture_ready_publish_spec.lua:34-40 duplicates the vim.fn.environ() fold, PYTHONDONTWRITEBYTECODE=1,
  uv.spawn and close-on-exit block from chat_progress_process_spec.lua:33-38 (ARCH-DRY). tests/helpers/
  now exists and is the natural home for a spawn_fixture(mode, ready_file) shared by both.

## Round 3 — 2026-08-22T00:08:30-07:00 (claude) — BLOCKED

### Disposed

- BR-10 — addressed — Verified at the expansion under the advertised override - make -n test TEST_ENV_ROOT=/tmp/rootprobe emits only the three leaves plus quoted legacy dirs; repo-wide sweep finds no other non-compliant destructive recipe.
- BR-11 — addressed — Hazard accepted rather than eliminated, but documented in TOOLING.md and the atlas with both escape hatches and the rejected per-run-suffix alternative - an adequate disposition for a Minor.
- BR-12 — addressed — vim.fn.environ() and PYTHONDONTWRITEBYTECODE now occur in exactly one file; both fixture specs consume the helper and the publisher guard still goes red on both revert shapes after the refactor.

### Raised

- **BR-13** [Important] `invariant-without-regression-guard` The test-clean-env blast-radius rule is defended only by a comment, after producing two Important findings
  Third finding in this family (BR-2, BR-8 preceded it), so per the repeat protocol the fix is the rule,
  not the instance - an invariant this gate has had to enforce gets an executable guard in the same commit,
  because a comment is not a guard. Makefile.parley:225-229 and atlas/infra/test_harness.md:53-61 state the
  rule in prose; nothing goes red if the next edit re-introduces either shape. Prototyped a 15-line guard
  that re-expands the recipe under a probe root, word-splits with eval set -- exactly as the shell would,
  and rejects any argument that is not a harness-built leaf. Verified - green on HEAD (6 args, all
  harness-owned), red on BR-10's shape (bare root) and red on BR-1's shape (4 word-split fragments). No
  false-positive surface, since it inspects the expansion rather than source text. tests/arch/ is the home.
- **BR-14** [Important] `rule-not-recorded-in-lessons` The rm -rf rule that produced BR-1 and BR-10 never reached workshop/lessons.md
  AGENTS.md section 4 requires review-found mistakes to become rules in workshop/lessons.md. The 2026-08-21
  (#202) block records four round-0 design lessons but neither of the two bugs the reviews actually found -
  the unquoted rm -rf path list and the rm -rf of a caller-supplied root. The rule lives only in
  atlas/infra/test_harness.md, which is the right place for the harness instance but is not the file read
  at session start; the defect recurred within this very issue because the rule was site-local. One bullet -
  a destructive recipe may only remove paths the tool itself constructed and can name literally, each quoted
  individually, verified by reading the expansion rather than the source.
- **BR-15** [Minor] `override-not-authoritative` fixture_process.spawn appends extra_env instead of replacing, so a same-named parent variable wins
  tests/helpers/fixture_process.lua:25-27 appends caller entries after the vim.fn.environ() fold. libuv
  passes duplicate keys straight through (verified - a child printed both DUPKEY=first and DUPKEY=second),
  and the fixture's os.environ.get resolves the parent's entry. Reproduced - with PARLEY_PUBLISH_DELAY=0
  exported in the shell, fixture_ready_publish_spec fails with "port appeared after 47ms;
  PARLEY_PUBLISH_DELAY=300ms was not honored", a spurious red whose message points at the fixture rather
  than the helper. Fold into a keyed map before flattening (~3 lines) so extra_env is authoritative; this is
  new internal API other specs will consume.
- **BR-16** [Minor] `stale-restatement-of-moved-source` Makefile help and the test target comment still claim integration tests run sequentially
  4th finding in this family, so state the rule rather than patch the wording - a surface that restates a
  fact the code owns goes stale, and BR-7 already applied the fix shape by pointing at the atlas.
  Makefile.parley:9, 11 and 52 all say integration runs sequentially; the recipe has used xargs -P $(JOBS)
  since 752c8e0, and the new atlas page correctly documents the parallel fan-out. Line 52 is the context
  line immediately above this window's edit to the test target. The help block should name what to run and
  let atlas/infra/test_harness.md own the execution model.

## Open findings

- **BR-13** [Important] `invariant-without-regression-guard` The test-clean-env blast-radius rule is defended only by a comment, after producing two Important findings
- **BR-14** [Important] `rule-not-recorded-in-lessons` The rm -rf rule that produced BR-1 and BR-10 never reached workshop/lessons.md
- **BR-15** [Minor] `override-not-authoritative` fixture_process.spawn appends extra_env instead of replacing, so a same-named parent variable wins
- **BR-16** [Minor] `stale-restatement-of-moved-source` Makefile help and the test target comment still claim integration tests run sequentially
