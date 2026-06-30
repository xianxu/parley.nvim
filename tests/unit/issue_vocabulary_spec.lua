local vocab = require("parley.issue_vocabulary")

local function generated_status_values()
    local lines = vim.fn.readfile("construct/generated/vocabulary/issue.json")
    local raw = vim.json.decode(table.concat(lines, "\n"))
    local out = {}
    for _, category in ipairs({ "open", "active", "terminal" }) do
        vim.list_extend(out, raw.categories[category])
    end
    return out
end

local function sample_vocab()
    return {
        categories = {
            open = { "open" },
            active = { "working", "blocked" },
            terminal = { "done", "wontfix", "punt" },
        },
        lifecycle = {
            { from = "open", to = "working", event = "claim", guards = {} },
            { from = "working", to = "blocked", event = "block", guards = {} },
            { from = "working", to = "punt", event = "defer", guards = {} },
            { from = "blocked", to = "done", event = "close", guards = {} },
        },
    }
end

describe("issue_vocabulary", function()
    it("derives status values from categories", function()
        local model = vocab.from_table(sample_vocab())

        assert.are.same({ "open", "working", "blocked", "done", "wontfix", "punt" }, model:status_values())
        assert.is_true(model:is_active("working"))
        assert.is_true(model:is_terminal("punt"))
        assert.is_false(model:is_terminal("working"))
    end)

    it("cycles by first lifecycle transition in generated order", function()
        local model = vocab.from_table(sample_vocab())

        assert.equals("working", model:next_status("open"))
        assert.equals("blocked", model:next_status("working"))
    end)

    it("sorts statuses by category order", function()
        local model = vocab.from_table(sample_vocab())

        assert.equals(1, model:sort_rank("open"))
        assert.equals(2, model:sort_rank("working"))
        assert.equals(4, model:sort_rank("done"))
        assert.is_true(model:sort_rank("unknown") > model:sort_rank("punt"))
    end)

    it("exposes status as an enumerable frontmatter field", function()
        local model = vocab.from_table(sample_vocab())

        assert.are.same({ "open", "working", "blocked", "done", "wontfix", "punt" }, model:enumerable_values("status"))
        assert.are.same({}, model:enumerable_values("deps"))
    end)

    it("loads the generated issue vocabulary from the repo", function()
        vocab.reset_for_tests()
        local model = vocab.default()

        assert.are.same(generated_status_values(), model:status_values())
        assert.equals("working", model:next_status("open"))
    end)

    it("keeps parley issue helpers covering every generated status", function()
        vocab.reset_for_tests()
        local issues = require("parley.issues")
        local model = vocab.default()
        local completed = {}

        for _, transition in ipairs(model.raw.lifecycle) do
            completed[transition.from] = true
        end

        local completions = issues.complete_frontmatter_values("status", "")
        assert.are.same(model:status_values(), issues.status_values())
        assert.are.same(model:status_values(), completions)

        for _, status in ipairs(model:status_values()) do
            assert.is_true(issues.complete_frontmatter_values("status", status)[1] == status)
            assert.is_true(model:sort_rank(status) < model:sort_rank("unknown"))
            assert.is_true(completed[status] or model:is_terminal(status))
        end
    end)

    -- #116 M2: issue home sourced from the cue `discovery` block (relative).
    local function vocab_with_discovery(home)
        local v = sample_vocab()
        v.discovery = { home = home, glob = "*.md" }
        return v
    end

    it("home() returns the exact relative discovery.home from the cue model", function()
        assert.equals("workshop/issues", vocab.home(vocab.from_table(vocab_with_discovery("workshop/issues"))))
    end)

    it("home() returns nil when discovery is absent", function()
        assert.is_nil(vocab.home(vocab.from_table(sample_vocab())))
    end)

    it("home() returns nil for an empty discovery.home", function()
        assert.is_nil(vocab.home(vocab.from_table(vocab_with_discovery(""))))
    end)

    it("home() returns nil (not raise) when the generated vocab can't load", function()
        local orig = vocab.default
        vocab.default = function() error("no generated vocab (fresh clone / pre-weave)") end
        local ok, result = pcall(vocab.home)
        vocab.default = orig
        assert.is_true(ok) -- the raising loader was caught, not propagated
        assert.is_nil(result)
    end)
end)
