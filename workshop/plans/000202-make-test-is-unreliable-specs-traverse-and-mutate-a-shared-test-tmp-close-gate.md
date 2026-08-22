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

## Open findings

- **BR-1** [Important] `unquoted-path-expansion` test-clean-env rm -rf word-splits on unquoted LEGACY_TEST_DIRS, targeting paths outside the repo
- **BR-2** [Important] `invariant-without-regression-guard` The scratch-placement invariant the whole issue rests on can be reverted with nothing going red
- **BR-3** [Important] `claim-without-failing-test` Done-when item 3 claims atomic port publishing, but no test fails without publish_ready
- **BR-4** [Important] `stale-restatement-of-moved-source` tests/perf/chat_typing.lua still hand-restates the pre-202 in-repo scratch path
- **BR-5** [Minor] `stale-restatement-of-moved-source` TOOLING.md perf section says "see Test scratch directories below" but that section is above it
- **BR-6** [Minor] `makefile-expansion-cost` TEST_ENV_ROOT ?= is recursively expanded, so cksum forks on every expansion of TEST_ENV/TEST_TMP
- **BR-7** [Minor] `rationale-duplicated-across-surfaces` The same scratch-placement rationale paragraph is restated in four files
- **BR-8** [Minor] `invariant-without-regression-guard` Atlas omits that nvim's tempdir fallback chain ends at cwd, so an unwritable TMPDIR puts scratch back in-tree
- **BR-9** [Minor] `stale-restatement-of-moved-source` make test now wipes the documented default PERF_OUTPUT location, which TOOLING.md does not mention
