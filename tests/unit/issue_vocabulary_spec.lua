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

    describe("validation and unavailable cache", function()
        local scratch
        before_each(function()
            scratch = vim.fn.tempname()
            vocab.reset_for_tests()
        end)
        after_each(function()
            vim.fn.delete(scratch, "rf")
            vocab.reset_for_tests()
        end)

        it("rejects malformed categories and transitions", function()
            local changes = {
                function(v) v.categories.open = {} end,
                function(v) v.categories.open = { [2] = "open" } end,
                function(v) v.categories.active = { "working", 3 } end,
                function(v) v.categories.active = { "open" } end,
                function(v) v.categories.active = { "working", "working" } end,
                function(v) v.categories.open.extra = "open" end,
                function(v) v.lifecycle = { [2] = v.lifecycle[1] } end,
                function(v) v.lifecycle[1].from = "unknown" end,
                function(v) v.lifecycle[1].to = false end,
                function(v) v.lifecycle[1] = "transition" end,
            }
            for _, change in ipairs(changes) do
                local raw = sample_vocab()
                change(raw)
                assert.has_error(function() vocab.from_table(raw) end)
            end
        end)

        it("accepts unknown metadata and derives the fallback from the open category", function()
            local raw = sample_vocab()
            raw.categories.open = { "queued" }
            raw.lifecycle[1].from = "queued"
            raw.future_metadata = { flag = true }
            assert.equals("queued", vocab.from_table(raw):next_status("unrecognized"))
        end)

        it("strictly rejects missing, directory, oversized, and malformed JSON files", function()
            assert.has_error(function() vocab.load({ path = scratch }) end)
            vim.fn.mkdir(scratch)
            assert.has_error(function() vocab.load({ path = scratch }) end)
            vim.fn.delete(scratch, "d")
            vim.fn.writefile({ vim.json.encode(sample_vocab()) .. string.rep(" ", 1024 * 1024) }, scratch)
            assert.has_error(function() vocab.load({ path = scratch }) end)
            vim.fn.writefile({ "{" }, scratch)
            assert.has_error(function() vocab.load({ path = scratch }) end)
            vim.fn.writefile({ vim.json.encode(sample_vocab()) }, scratch)
            assert.equals("working", vocab.load({ path = scratch }):next_status("open"))
        end)

        it("rejects growth beyond the cap before attempting JSON decode", function()
            vim.fn.writefile({ vim.json.encode(sample_vocab()) .. string.rep(" ", 1024 * 1024) }, scratch)
            local original_stat, original_fstat = vim.loop.fs_stat, vim.loop.fs_fstat
            local original_decode = vim.json.decode
            local decoded = false
            -- Both metadata snapshots precede a concurrent append. The bounded
            -- read must still detect excess bytes independently of those sizes.
            vim.loop.fs_stat = function() return { type = "file", size = 1 } end
            vim.loop.fs_fstat = function() return { type = "file", size = 1 } end
            vim.json.decode = function(json)
                decoded = true
                return original_decode(json)
            end
            local ok, err = pcall(vocab.load, { path = scratch })
            vim.loop.fs_stat, vim.loop.fs_fstat = original_stat, original_fstat
            vim.json.decode = original_decode
            assert.is_false(ok)
            assert.is_truthy(tostring(err):find("exceeds 1 MiB", 1, true))
            assert.is_false(decoded)
        end)

        it("caches unavailable and ready results until explicit reload", function()
            local model, reason = vocab.reload({ path = scratch })
            assert.is_nil(model)
            assert.equals("string", type(reason))
            vim.fn.writefile({ vim.json.encode(sample_vocab()) }, scratch)
            local cached, cached_reason = vocab.default()
            assert.is_nil(cached)
            assert.equals(reason, cached_reason)
            local ready = vocab.reload({ path = scratch })
            assert.equals("working", ready:next_status("open"))
            vim.fn.writefile({ "{" }, scratch)
            assert.equals(ready, vocab.default())
            assert.is_nil(vocab.reload({ path = scratch }))
            assert.is_nil(vocab.home())
        end)

        it("anchors the default path to the loaded plugin rather than cwd or runtime shadow", function()
            local old_cwd = vim.fn.getcwd()
            local old_rtp = vim.o.runtimepath
            vim.fn.mkdir(scratch .. "/construct/generated/vocabulary", "p")
            vim.fn.writefile({ "{}" }, scratch .. "/construct/generated/vocabulary/issue.json")
            vim.cmd("cd " .. vim.fn.fnameescape(scratch))
            vim.opt.runtimepath:prepend(scratch)
            local ok, model = pcall(vocab.load)
            vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
            vim.o.runtimepath = old_rtp
            assert.is_true(ok)
            assert.equals("working", model:next_status("open"))
        end)
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
