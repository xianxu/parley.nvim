# M3 — `<M-S-CR>` as a redirected submission (Implementation Plan)

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `<M-S-CR>` (and its aliases `<M-i>` / `<C-g>i`) performs the submission `<M-CR>` would perform, into a new child chat, leaving a `🌿:` reference where `<M-CR>`'s output would have appeared.

**Architecture:** The *decision* — which of four cases applies, what text the child is seeded with, and which parent line the reference follows — is a pure function over `(parsed_chat, cursor_line, markers)`. It lives in a new `lua/parley/branch_submit.lua` and is unit-testable with hand-built inputs and no buffer. The *effects* — creating the child, stripping markers, deleting a replaced answer, inserting the reference, saving the parent — stay in `init.lua`'s existing `branch_inserters`, which already owns the durability rule M1 established.

**Tech Stack:** Lua, Neovim buffer APIs, plenary/busted. Reuses `chat_parser` (line spans), `drill_in` (marker gather + block formatting), `buffer_edit` (text edits), `create_child_chat`.

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `plan_submission` | `lua/parley/branch_submit.lua` | new |
| `seed_question` | `lua/parley/branch_submit.lua` | new |
| `topic_for_selection` | `lua/parley/branch_ref.lua` | modified |

- **`plan_submission`** — `(parsed_chat, cursor_line, markers) -> plan`. Decides which case applies and returns a description of the work; performs no IO and touches no buffer.

  ```lua
  --- @return table|nil plan, string|nil reason
  --- plan = {
  ---   case         = "quotes" | "question",
  ---   question     = string,          -- what the child is seeded with
  ---   topic        = string,          -- the child's `topic:` header
  ---   ref_after    = integer,         -- 1-indexed parent line the 🌿: block follows
  ---   strip_markers= boolean,         -- case 2: apply drill_in's marker edits first
  ---   delete_lines = { first, last } | nil,  -- case 3b: the answer being replaced
  --- }
  ```

  - **Relationships:** 1:1 with a keypress. Consumes `chat_parser` output (N exchanges) and `drill_in.parse` output (N markers); owns neither.
  - **DRY rationale:** `<M-CR>` decides the same four cases inside `chat_respond.respond`. Re-deriving them at the `<M-S-CR>` call site is how the two chords would drift — and the whole point of the chord is that it *matches* `<M-CR>`. The rules are stated once here, and Task 5 pins them against the atlas that documents `<M-CR>`'s behaviour.
  - **Future extensions:** a `case = "define"` row for the visual path, if the inline splice ever needs the same planning treatment. Deliberately **not** built now (YAGNI): the visual path takes no cursor-based decision.

- **`seed_question`** — `(case, payload) -> string`. The child's first question: `tell me more about "<selection>"` for a visual selection, the formatted quote blocks for case 2, the question text verbatim for case 3.
  - **DRY rationale:** one place that knows how a payload becomes a prompt; three call sites would otherwise each invent wording.

- **`topic_for_selection`** — **modified.** Returns the selected text itself rather than `what is "<selected>"`, so the child's `topic:` header (and therefore its filename slug) names the subject instead of embedding a question form. The question wording moves to `seed_question`.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `branch_inserters` | `lua/parley/init.lua` | modified | buffer writes, child creation, parent `:write` |

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

- [ ] **Step 1: Update the failing test**

```lua
it("topic is the selected text, so the slug names the subject", function()
    assert.are.equal("monad transformers", br.topic_for_selection("monad transformers"))
end)

it("collapses whitespace and trims, so the slug stays clean", function()
    assert.are.equal("monad transformers", br.topic_for_selection("  monad\n  transformers  "))
end)
```

- [ ] **Step 2: Run it and watch it fail**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/branch_ref_spec.lua" -c "qa!"`
Expected: FAIL — currently returns `what is "monad transformers"`.

- [ ] **Step 3: Implement**

```lua
--- The child's `topic:` header for a selection. The topic becomes the filename
--- slug, so it names the SUBJECT; the question wording lives in
--- `branch_submit.seed_question` (#214 M3).
function M.topic_for_selection(selected)
    return (selected:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end
```

- [ ] **Step 4: Run the test — expect PASS**
- [ ] **Step 5: Commit** — `git commit -m "#214 M3: the child's topic names the subject, not the question"`

### Task 2: `seed_question`

**Files:**
- Create: `lua/parley/branch_submit.lua`
- Test: `tests/unit/branch_submit_spec.lua`

- [ ] **Step 1: Write the failing test**

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

- [ ] **Step 2: Run it — expect FAIL** (module does not exist)
- [ ] **Step 3: Implement the minimum**
- [ ] **Step 4: Run — expect PASS**
- [ ] **Step 5: Commit**

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

- [ ] **Step 1: Write the failing tests — one per row of the issue's table**

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

- [ ] **Step 2: Run — expect FAIL**
- [ ] **Step 3: Implement `plan_submission`**
- [ ] **Step 4: Run — expect PASS**
- [ ] **Step 5: Commit**

---

## Chunk 2: the effects

### Task 4: wire `n`/`i` to the plan

**Files:**
- Modify: `lua/parley/init.lua` (`branch_inserters`)
- Test: `tests/integration/branch_child_spec.lua`

- [ ] **Step 1: Write the failing integration tests** — driving the real keymap callback on a real chat buffer, per the round-11 lesson (test the transition, not the sub-step):

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

- [ ] **Step 2: Run — expect FAIL**
- [ ] **Step 3: Implement the `n`/`i` path**
- [ ] **Step 4: Run — expect PASS**
- [ ] **Step 5: Verify by reversion** — revert the `ref_after` computation to "cursor line" and confirm the summary-placement test goes red.
- [ ] **Step 6: Commit**

### Task 5: the visual path's seeded question

**Files:**
- Modify: `lua/parley/init.lua` (`insert_inline`)
- Test: `tests/integration/branch_child_spec.lua`

- [ ] **Step 1: Test that the child is seeded `tell me more about "<selection>"` and its topic is the selection**
- [ ] **Step 2–4: red → implement → green**
- [ ] **Step 5: Commit**

### Task 6: refuse while a response is pending

**Files:**
- Modify: `lua/parley/init.lua`
- Test: `tests/integration/branch_child_spec.lua`

The one real concurrency case named in ARCH-ORDER above: a streaming response owns the parent's exchange model and a chat lease. Deleting the answer under it (case 3b) would fight the lease.

- [ ] **Step 1: Test that `<M-S-CR>` declines with a message while the buffer has a pending response, and changes nothing**
- [ ] **Step 2–4: red → implement → green**
- [ ] **Step 5: Commit**

---

## Chunk 3: agreement and docs

### Task 7: pin the chord against `<M-CR>`'s documented rules

**Files:**
- Test: `tests/unit/branch_submit_spec.lua`

The chord's whole promise is "what `<M-CR>` would submit". That promise is quantified over cases, so it needs a derived check rather than four hand-written examples — the family that produced five findings in M2.

- [ ] **Step 1: Assert every case the atlas documents for `<M-CR>` has a `plan_submission` row**, reading the case list out of `atlas/chat/drill_in.md` rather than a literal in the test.
- [ ] **Step 2–4: red → implement → green**
- [ ] **Step 5: Commit**

### Task 8: atlas + README

**Files:**
- Modify: `atlas/chat/inline_branch_links.md`, `atlas/chat/drill_in.md`, `README.md`, `atlas/traceability.yaml`

- [ ] **Step 1: Document the one rule** and the four rows, including the measured reason the ref follows `📝:`.
- [ ] **Step 2: Route the new spec** in `atlas/traceability.yaml` — the guard added in M2 fails otherwise.
- [ ] **Step 3: Commit**

### Task 9: close

- [ ] `make test` green, `luacheck` clean.
- [ ] Mutation ledger from `git diff <M2 boundary> -- lua/`, each deliverable seen red.
- [ ] `sdlc milestone-close --issue 214 --milestone M3 --actual <measured> --verified '<evidence>'`

---

## Open risks

- **`<M-CR>`'s rules live in prose, not in a shared function.** Task 7 pins the two against the atlas rather than against each other; a genuine unification of `chat_respond`'s branching with `plan_submission` is deliberately out of scope — that is a refactor of a 700-line function inside a milestone that is otherwise additive, and M1 cost five review rounds for exactly that kind of bundling.
- **Case 2b's "last exchange" is a choice, not a derivation.** `<M-CR>` appends the new turn at the buffer end; the ref follows the last exchange. If a future `<M-CR>` change moves that, the two drift — Task 7's check is what should catch it.
