# M3 — `<M-S-CR>` as a redirected submission (Implementation Plan)

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `<M-S-CR>` (and its aliases `<M-i>` / `<C-g>i`) performs the submission `<M-CR>` would perform, into a new child chat, leaving a `🌿:` reference where `<M-CR>`'s output would have appeared.

**Architecture:** The *decision* — which of four cases applies, what text the child is seeded with, and which parent line the reference follows — is a pure function over `(parsed_chat, cursor_line, markers)`. It lives in a new `lua/parley/branch_submit.lua` and is unit-testable with hand-built inputs and no buffer. The *effects* — creating the child, stripping markers, deleting a replaced answer, inserting the reference, saving the parent — stay in `init.lua`'s existing `branch_inserters`, which already owns the durability rule M1 established.

**Tech Stack:** Lua, Neovim buffer APIs, plenary/busted. Reuses `chat_parser` (line spans), `drill_in` (marker gather + block formatting), `buffer_edit` (text edits), `create_child_chat`.

---

## Core concepts

### Pure entities

> **The issue's `## Core concepts` is the DELIVERED record; this one is the
> DESIGN record.** They are separate tables and the arch guard accepts an entity
> in either, which is how they drifted — three entities M3 shipped were in the
> issue and not here (#214). Rows added after the fact are marked *(as built)*.

| Name | Lives in | Status |
|------|----------|--------|
| `plan_submission` | `lua/parley/branch_submit.lua` | new |
| `seed_question` | `lua/parley/branch_submit.lua` | new |
| `topic_for_selection` | `lua/parley/branch_ref.lua` | modified |
| `ref_block` | `lua/parley/branch_ref.lua` | new *(as built)* |
| `chat_gather_opts` | `lua/parley/drill_in.lua` | new *(as built)* |
| `is_annotation` | `lua/parley/annotation.lua` | new *(as built)* |
| `inline_links` | `lua/parley/annotation.lua` | new *(as built)* |
| `survivors` | `lua/parley/annotation.lua` | new *(as built)* |

- **`plan_submission`** — `(parsed_chat, cursor_line, markers) -> plan`. Decides
  whether there is anything to rearrange and where the reference goes; performs
  no IO and touches no buffer.

  > **As shipped (#214 BR-59), narrower than planned here.** Two operator
  > revisions on first use — the reference lands at the cursor, and the chord
  > never deletes — collapsed this to the quotes case alone:
  >
  > ```lua
  > --- @return table|nil plan, string|nil reason
  > --- plan = { case = "quotes", ref_after = integer, strip_markers = true }
  > ```
  >
  > `case = "question"`, `question`, `topic` and `delete_lines` do not exist. The
  > Task 3 steps below still describe the planned shape and their assertions are
  > not in the tree; they are left as the record of what was designed, with this
  > note as the correction. See ## Revisions, "M3 placement reversed by the operator" in the issue.

- **`seed_question`** — `(case, payload) -> string`. The child's first question: `tell me more about "<selection>"` for a visual selection, the formatted quote blocks for case 2, the question text verbatim for case 3.
  - **DRY rationale:** one place that knows how a payload becomes a prompt; three call sites would otherwise each invent wording.

- **`topic_for_selection`** — **modified.** Returns the selected text itself rather than `what is "<selected>"`, so the child's `topic:` header (and therefore its filename slug) names the subject instead of embedding a question form. The question wording moves to `seed_question`.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `branch_inserters` | `lua/parley/init.lua` | modified | buffer writes, child creation, parent `:write` |
| `flatten_lines` | `lua/parley/helper.lua` | new *(as built)* | `vim.fn.writefile`'s NUL encoding |
| `delete_answer` | `lua/parley/buffer_edit.lua` | modified *(as built)* | the resubmit's answer removal |

- **`is_annotation`** — one owner for "is this line a `🌿:`/`🔒:` annotation".
  Three places needed the answer — the parser's trailing-span trim, the
  resubmit's survivor filter, and the arch guard — and a predicate spelled three
  times is the shape that lets a fourth caller get it subtly wrong.
- **`delete_answer`** — a resubmit replaces the MODEL's output, so it now keeps
  the user's annotations. #214 made those lines part of the answer's span (they
  used to truncate it), which turned a plain range delete into a destroyer of the
  reference `<M-i>` had just inserted — orphaning a child chat on disk (BR-75).
- **`branch_inserters`** — gains an `n`/`i` path that consults `plan_submission` and executes the returned plan. The existing durability rule is unchanged and load-bearing: create the child, commit the parent, *then* navigate — so a `:q!` between steps cannot orphan the child (#214 BR-19).
  - **Injected into:** nothing; it is the effect layer. `plan_submission` is called *by* it and receives already-parsed inputs, so the decision stays testable with no buffer.
  - **Future extensions:** the markdown (`owns_file == false`) path stays as it is — parley must not `:write` a document it does not own, so it cannot make a reference durable there and therefore creates no child.

**ARCH-ORDER — the transition and what can interrupt it.** The effect sequence is: *(1)* strip markers or delete the replaced answer, *(2)* insert the `🌿:` line, *(3)* create the child on disk, *(4)* `:write` the parent, *(5)* open the child. Steps 1–2 are buffer-only and undoable as one edit. The event that must not be mishandled is **process death or `:q!` between (3) and (4)** — the child exists on disk and the only pointer to it is unsaved — which is exactly BR-19. It is handled by ordering: (4) precedes (5), and if (4) fails we do not navigate, so the user is left looking at the unsaved reference. There is no concurrent actor: this runs synchronously on the keypress, before any async response begins. A pending response on the parent is the one true concurrency case — see Task 6.

---

## Chunk 1: the pure decision

### Task 1: `topic_for_selection` names the subject, not the question

**Files:**
- Modify: `lua/parley/branch_ref.lua`
- Test: `tests/unit/branch_ref_spec.lua`

- [x] **Step 1: Update the failing test**

```lua
it("topic is the selected text, so the slug names the subject", function()
    assert.are.equal("monad transformers", br.topic_for_selection("monad transformers"))
end)

it("collapses whitespace and trims, so the slug stays clean", function()
    assert.are.equal("monad transformers", br.topic_for_selection("  monad\n  transformers  "))
end)
```

- [x] **Step 2: Run it and watch it fail**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/branch_ref_spec.lua" -c "qa!"`
Expected: FAIL — currently returns `what is "monad transformers"`.

- [x] **Step 3: Implement**

```lua
--- The child's `topic:` header for a selection. The topic becomes the filename
--- slug, so it names the SUBJECT; the question wording lives in
--- `branch_submit.seed_question` (#214 M3).
function M.topic_for_selection(selected)
    return (selected:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end
```

- [x] **Step 4: Run the test — expect PASS**
- [x] **Step 5: Commit** — `git commit -m "#214 M3: the child's topic names the subject, not the question"`

### Task 2: `seed_question`

**Files:**
- Create: `lua/parley/branch_submit.lua`
- Test: `tests/unit/branch_submit_spec.lua`

- [x] **Step 1: Write the failing test**

```lua
local bs = require("parley.branch_submit")

describe("seed_question", function()
    it("a visual selection asks to expand on it", function()
        assert.are.equal('tell me more about "monad transformers"',
            bs.seed_question("define", "monad transformers"))
    end)

    it("quotes are passed through verbatim — they are already a prompt", function()
        local blocks = "> [some quoted text]\n\nwhat about this?"
        assert.are.equal(blocks, bs.seed_question("quotes", blocks))
    end)

    it("a question is passed through verbatim", function()
        assert.are.equal("how does X work?", bs.seed_question("question", "how does X work?"))
    end)

    it("a selection containing a quote mark does not break the wording", function()
        assert.are.equal('tell me more about "the \\"hard\\" problem"',
            bs.seed_question("define", 'the "hard" problem'))
    end)
end)
```

- [x] **Step 2: Run it — expect FAIL** (module does not exist)
- [x] **Step 3: Implement the minimum**
- [x] **Step 4: Run — expect PASS**
- [x] **Step 5: Commit**

### Task 3: `plan_submission` — the four cases

**Files:**
- Modify: `lua/parley/branch_submit.lua`
- Test: `tests/unit/branch_submit_spec.lua`

The fixture is a parsed chat built by hand, so the test needs no buffer:

```lua
local function chat(exchanges) return { exchanges = exchanges } end
local function ex(q_start, q_end, a_start, a_end)
    return {
        question = { line_start = q_start, line_end = q_end },
        answer = a_start and { line_start = a_start, line_end = a_end } or nil,
    }
end
```

> **The Task 3 steps below are the DESIGN record, not a delivered checklist**
> (#214 BR-59). Six of their assertions — `p.delete_lines`, `case == "question"`,
> `p.question` — describe the pre-narrowing `plan_submission` and are not in
> `tests/unit/branch_submit_spec.lua`. What shipped is the quotes case alone; see
> the correction under Core concepts above and ## Revisions, "M3 placement reversed by the operator" in the issue.

- [x] **Step 1: Write the failing tests — one per row of the issue's table**

```lua
describe("plan_submission", function()
    -- 3a: the composing case. Ref goes where the answer would have been.
    it("an unanswered question at the cursor is copied, ref after the question", function()
        local p = bs.plan_submission(chat({ ex(5, 5, 7, 11), ex(13, 13) }), 13, {}, "how does X work?")
        assert.are.equal("question", p.case)
        assert.are.equal("how does X work?", p.question)
        assert.are.equal(13, p.ref_after)
        assert.is_nil(p.delete_lines)
    end)

    -- 3b: resubmit. <M-CR> deletes the old answer; so do we.
    it("an answered question deletes the answer, ref lands where it was", function()
        local p = bs.plan_submission(chat({ ex(5, 5, 7, 11) }), 5, {}, "first question")
        assert.are.equal("question", p.case)
        assert.are.equal(5, p.ref_after)
        assert.same({ 7, 11 }, p.delete_lines)
    end)

    -- 2a: markers inside a past exchange -> that exchange's own end.
    it("markers in a past exchange put the ref after THAT answer", function()
        local p = bs.plan_submission(chat({ ex(5, 5, 7, 11), ex(13, 13, 15, 19) }), 9,
            { { exchange = 1 } }, nil)
        assert.are.equal("quotes", p.case)
        assert.are.equal(11, p.ref_after)
        assert.is_true(p.strip_markers)
    end)

    -- 2b: markers elsewhere -> the buffer's last exchange.
    it("markers outside any cursor exchange put the ref at the last exchange", function()
        local p = bs.plan_submission(chat({ ex(5, 5, 7, 11), ex(13, 13, 15, 19) }), 1,
            { { exchange = 2 } }, nil)
        assert.are.equal(19, p.ref_after)
    end)

    -- the ref never lands inside the answer it follows
    it("ref_after is never inside a span the plan also deletes", function()
        local p = bs.plan_submission(chat({ ex(5, 5, 7, 11) }), 5, {}, "q")
        assert.is_true(p.ref_after < p.delete_lines[1])
    end)

    it("declines with a reason when there is nothing to submit", function()
        local p, reason = bs.plan_submission(chat({}), 1, {}, nil)
        assert.is_nil(p)
        assert.is_truthy(reason)
    end)
end)
```

- [x] **Step 2: Run — expect FAIL**
- [x] **Step 3: Implement `plan_submission`**
- [x] **Step 4: Run — expect PASS**
- [x] **Step 5: Commit**

---

## Chunk 2: the effects

### Task 4: wire `n`/`i` to the plan

**Files:**
- Modify: `lua/parley/init.lua` (`branch_inserters`)
- Test: `tests/integration/branch_child_spec.lua`

- [x] **Step 1: Write the failing integration tests** — driving the real keymap callback on a real chat buffer, per the round-11 lesson (test the transition, not the sub-step):

```lua
it("copies the trailing question into the child and leaves a ref behind", function()
    local buf, path = chat_with({ "💬: first question", "", "🤖:[A]", "", "answer", "",
                                  "📝: sum", "", "💬: how does X work?" })
    vim.api.nvim_win_set_cursor(0, { 9, 0 })
    parley._branch_inserters(buf, false, true).n()

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    -- the question STAYS; the ref follows it with one blank line
    assert.are.equal("💬: how does X work?", lines[9])
    assert.are.equal("", lines[10])
    assert.is_truthy(lines[11]:match("^🌿:"))
    -- and the child was seeded with it
    local child = read_child(lines[11])
    assert.is_truthy(table.concat(child, "\n"):find("how does X work?", 1, true))
end)

it("deletes the answer being replaced, and the ref takes its place", function() ... end)
it("routes pending <M-q> quotes into the child and strips them from the parent", function() ... end)
it("puts the ref after the summary, so the summary stays in the exchange model", function() ... end)
```

- [x] **Step 2: Run — expect FAIL**
- [x] **Step 3: Implement the `n`/`i` path**
- [x] **Step 4: Run — expect PASS**
- [x] **Step 5: Verify by reversion** — revert the `ref_after` computation to "cursor line" and confirm the summary-placement test goes red.
- [x] **Step 6: Commit**

### Task 5: the visual path's seeded question

**Files:**
- Modify: `lua/parley/init.lua` (`insert_inline`)
- Test: `tests/integration/branch_child_spec.lua`

- [x] **Step 1: Test that the child is seeded `tell me more about "<selection>"` and its topic is the selection**
- [x] **Step 2–4: red → implement → green**
- [x] **Step 5: Commit**

### Task 6: refuse while a response is pending

**Files:**
- Modify: `lua/parley/init.lua`
- Test: `tests/integration/branch_child_spec.lua`

The one real concurrency case named in ARCH-ORDER above: a streaming response owns the parent's exchange model and a chat lease. Deleting the answer under it (case 3b) would fight the lease.

- [x] **Step 1: Test that `<M-S-CR>` declines with a message while the buffer has a pending response, and changes nothing**
- [x] **Step 2–4: red → implement → green**
- [x] **Step 5: Commit**

---

## Chunk 3: agreement and docs

### Task 7: pin the chord against `<M-CR>`'s documented rules

> **NOT DELIVERED as written (#214 BR-60).** The check built here compared
> `plan_submission`'s exchange resolution against `find_exchange_at_line`
> line-by-line. When the operator narrowed the chord to the quotes case, that
> resolution was removed as dead code — and the test went with it, leaving this
> box ticked over nothing. The equivalence it was meant to guard was also false
> in two ways review had to find rather than the test: `<M-i>` hardcoded
> `bracket = true` against `<M-CR>`'s `mark_reference_span`, and the two gather
> at different scopes.
>
> What replaced it: `drill_in.chat_gather_opts` is now the single owner of the
> gather options, with a test asserting neither call site rebuilds them; and the
> scope difference is stated as deliberate in the README, the atlas and the
> module header rather than claimed away.

### Task 8: atlas + README

**Files:**
- Modify: `atlas/chat/inline_branch_links.md`, `atlas/chat/drill_in.md`, `README.md`, `atlas/traceability.yaml`

- [x] **Step 1: Document the one rule** and the four rows, including the measured reason the ref follows `📝:`.
- [x] **Step 2: Route the new spec** in `atlas/traceability.yaml` — the guard added in M2 fails otherwise.
- [x] **Step 3: Commit**

### Task 9: close

- [x] `make test` green, `luacheck` clean.
- [x] Mutation ledger from `git diff <M2 boundary> -- lua/`, each deliverable seen red.
- [x] `sdlc milestone-close --issue 214 --milestone M3 --actual <measured> --verified '<evidence>'`

---

## Open risks

- **`<M-CR>`'s rules live in prose, not in a shared function.** Task 7 pins the two against the atlas rather than against each other; a genuine unification of `chat_respond`'s branching with `plan_submission` is deliberately out of scope — that is a refactor of a 700-line function inside a milestone that is otherwise additive, and M1 cost five review rounds for exactly that kind of bundling.
- **Case 2b's "last exchange" is a choice, not a derivation.** `<M-CR>` appends the new turn at the buffer end; the ref follows the last exchange. If a future `<M-CR>` change moves that, the two drift — Task 7's check is what should catch it.

---

## Deviations from this plan, and why

0. **The `question` case was removed entirely.** The plan's `plan_submission`
   returns `case = "quotes" | "question"` with `question`, `topic` and
   `delete_lines`, mirroring `<M-CR>`'s resubmit. Two operator revisions on first
   use — the reference lands at the cursor, and the chord never deletes — left
   only the quotes case, and `exchange_at` plus its conformance test went with
   it. The tables above are corrected in place; this entry is the record that the
   removal happened rather than the design being wrong on paper (#214 BR-59).


1. **`seed_question` does not escape quote marks in a selection.** The draft test
   expected `tell me more about "the \"hard\" problem"`. Backslash escaping is a
   code convention leaking into chat prose, and the model reads either form; the
   selection is passed through instead. What the test now pins is that it does
   not crash or mangle — including a `%`, which is the live hazard (BR-21) at any
   site where the value later reaches `gsub` as a replacement.

2. **Task 7 was NOT delivered.** The plan proposed reading the case list out of
   `atlas/chat/drill_in.md`; I replaced it with a line-by-line comparison of
   `plan_submission`'s exchange resolution against `find_exchange_at_line`. Then
   the operator's narrowing removed that resolution as dead code and the test
   went with it — leaving the step checked off over nothing, which is worse than
   leaving it unchecked (#214 BR-60). No such test is in the tree.

   What stands in its place, and why it is the better guard: the equivalence
   Task 7 was meant to protect turned out to be **already false** in two ways a
   prose or resolution check would never have caught. `<M-i>` hardcoded
   `bracket = true` against `<M-CR>`'s `config.mark_reference_span`, so the two
   keys stripped differently under that option — now both call one
   `drill_in.chat_gather_opts`, with a test that neither call site rebuilds the
   options. And the two gather at different **scopes** (buffer-wide vs the
   cursor's exchange), which is deliberate and is now stated in the README, the
   atlas and the module header instead of being claimed away.

3. **Declining falls back rather than stopping.** The plan implied `plan_submission`
   returning nil meant "do nothing". Building it that way regressed M1's
   "make me a side chat" affordance and broke the BR-1 sentinel test — a chat with
   no exchanges, or a cursor in the frontmatter, got no branch at all. Nothing to
   submit now falls through to the pre-M3 plain reference. The chord is never a
   no-op. (The pending-response refusal is the one case that does NOT fall back:
   the fallback would also edit the buffer under the lease.)

4. **The child's topic stays `?`, and the reference carries a `label`.** The plan
   had `plan.topic` naming the subject. Wiring it that way regressed BR-1: a real
   topic disables auto-titling *and* the slug rename. The child keeps the sentinel
   so the lifecycle runs; the question text became `plan.label`, which is what the
   parent's `🌿:` line displays. Two jobs, two fields.

## Mutation ledger

Generated from `git diff d5ba3eb -- lua/`, not recall. Each deliverable reverted,
seen red, restored.

| deliverable | mutation | red |
|---|---|---|
| topic names the subject | revert to `what is "X"` | 3 unit + 1 integration |
| ~~case 3b deletes the replaced answer~~ | *removed with the never-delete narrowing* | — |
| markers win over the question case | disable the marker branch | 4 unit + 3 integration |
| pending-response guard | remove it | 1 integration |
| ~~ref lands after `📝:`~~ | *superseded: the reference lands at the cursor* | — |
| `seed_question` instructs | return the bare selection | 4 unit + 1 integration |
| ~~planner agrees with `find_exchange_at_line`~~ | *removed with `exchange_at`* | — |
| reference survives the strip (BR-58) | keep the pre-strip line number | 2 integration |
| one owner for gather options (BR-60) | rebuild them inline | 1 unit |
| annotations are single-line | the pre-fix parser | 4 unit |
