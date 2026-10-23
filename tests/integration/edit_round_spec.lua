-- edit_round (#383): the agent's last round, fetched from the Couch fake and
-- drawn under the document's presentation. Row numbers are the S4 design's
-- state rows (ops design.side/10-s4-edit-path.md).
local arrival = require("tests.helpers.arrival")
local fake_couch = require("tests.helpers.fake_couch")

describe("edit_round", function()
    local root, saved, file, buf, edit_round, skill_render

    local function marks()
        return vim.api.nvim_buf_get_extmarks(buf, vim.api.nvim_create_namespace("parley_round_hl"), 0, -1,
            { details = true })
    end

    local function messages()
        local out = {}
        for _, d in ipairs(vim.diagnostic.get(buf, { namespace = skill_render.diag_namespace() })) do
            if (d.user_data or {}).parley_kind == "round" then out[#out + 1] = d.message end
        end
        return out
    end

    local function open(lines)
        vim.fn.writefile(lines, file)
        vim.cmd("noswapfile edit! " .. vim.fn.fnameescape(file))
        buf = vim.api.nvim_get_current_buf()
    end

    local function seed(spans, at)
        fake_couch.round(vim.env.FAKE_COUCH_REGISTRY, file, { base_hash = "aaaaaaaaaaaaaaaa",
            result_hash = vim.fn.sha256(table.concat(vim.fn.readfile(file), "\n") .. "\n"):sub(1, 16),
            at = at or "2020-01-01T00:00:00Z", presentation = "highlight", spans = spans })
    end

    local function span(line, col, new, explain)
        return { start = { line, col }, ["end"] = { line, col + #new }, old = "old", new = new, explain = explain }
    end

    local function refreshed(want)
        edit_round.refresh(buf)
        return vim.wait(arrival.MS, function() return #marks() == want end, 10)
    end

    before_each(function()
        root = vim.fn.tempname()
        vim.fn.mkdir(root, "p")
        fake_couch.write(root, root .. "/sent", root .. "/argv")
        saved = { path = vim.env.PATH, state = vim.env.FAKE_COUCH_REGISTRY,
            delay = vim.env.FAKE_COUCH_REGISTRY_REPLY_DELAY, ops = vim.env.FAKE_COUCH_REGISTRY_REPLY_DELAY_OPS }
        vim.env.PATH = root .. "/bin:" .. vim.env.PATH
        vim.env.FAKE_COUCH_REGISTRY = root .. "/registry.json"
        file = root .. "/doc.md"
        package.loaded["parley.document_registry"] = nil
        edit_round = require("parley.edit_round")
        skill_render = require("parley.skill_render")
    end)

    after_each(function()
        if buf and vim.api.nvim_buf_is_valid(buf) then
            edit_round.forget(buf)
            vim.api.nvim_buf_delete(buf, { force = true })
        end
        require("parley.document_registry").shutdown()
        vim.env.PATH, vim.env.FAKE_COUCH_REGISTRY = saved.path, saved.state
        vim.env.FAKE_COUCH_REGISTRY_REPLY_DELAY, vim.env.FAKE_COUCH_REGISTRY_REPLY_DELAY_OPS = saved.delay, saved.ops
        vim.fn.delete(root, "rf")
    end)

    it("warns visibly and highlights for an unknown canonical presentation", function()
        open({ '---', 'presentation-mode: typo', 'presentation: direct', '---', 'first change' })
        seed({ span(4, 0, 'first') })
        local notify, notices = vim.notify, {}
        vim.notify = function(message) notices[#notices + 1] = message end
        local ok, err = pcall(function()
            assert.is_true(refreshed(1))
            assert.truthy(table.concat(notices, ';'):find('unknown value typo', 1, true))
        end)
        vim.notify = notify
        assert.is_true(ok, tostring(err))
    end)

    for _, header in ipairs({ { "metadata:", "  topic: notes" }, { "metadata: [one, two]" } }) do
        it("clears previous highlights and names the unsupported header line " .. header[1], function()
            open({ "# Doc", "first change" })
            seed({ span(1, 0, "first", "tighter") })
            assert.is_true(refreshed(1))
            local document = { "---" }
            vim.list_extend(document, header)
            vim.list_extend(document, { "presentation-mode: highlight", "---", "first change" })
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, document)
            local notify, notices = vim.notify, {}
            vim.notify = function(message) notices[#notices + 1] = message end
            local ok, err = pcall(function()
                edit_round.refresh(buf)
                assert.equals(0, #marks(), "unsupported presentation must clear, not fall back to highlight")
                assert.same({}, messages())
                assert.truthy(table.concat(notices, ";"):find("line 2", 1, true), vim.inspect(notices))
                assert.same(document, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
            end)
            vim.notify = notify
            assert.is_true(ok, tostring(err))
        end)
    end

    it("names an unsupported header introduced after a real round request before its reply is drawn", function()
        open({ "# Doc", "first change" })
        seed({ span(1, 0, "first", "tighter") })
        assert.is_true(refreshed(1))
        local registry = require("parley.document_registry")
        local request, notify, release, notices = registry.request, vim.notify, nil, {}
        registry.request = function(op, args, witness, callback, options)
            return request(op, args, witness, function(result)
                if op == "round" then release = function() callback(result) end
                else callback(result) end
            end, options)
        end
        vim.notify = function(message) notices[#notices + 1] = message end
        local ok, err = pcall(function()
            edit_round.refresh(buf)
            assert.is_true(vim.wait(arrival.MS, function() return release ~= nil end, 10))
            local document = { "---", "metadata: [one, two]", "presentation-mode: highlight", "---", "first change" }
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, document)
            release()
            assert.equals(0, #marks(), "the reply must not draw under an unreadable current header")
            assert.same({}, messages())
            assert.truthy(table.concat(notices, ";"):find("line 2", 1, true), vim.inspect(notices))
            assert.same(document, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
        end)
        registry.request, vim.notify = request, notify
        assert.is_true(ok, tostring(err))
    end)

    it("draws each span with its reason, or 'changed by the agent' without one (rows 29, 33b)", function()
        open({ "# Doc", "first change", "second change" })
        seed({ span(1, 0, "first", "tighter"), span(2, 0, "second") })
        assert.is_true(refreshed(2))
        assert.is_true(vim.wait(arrival.MS, function() return #messages() == 2 end, 10))
        assert.same({ "tighter", "changed by the agent" }, messages())
    end)

    it("moves the highlight and its diagnostic when a line is inserted above (row 30)", function()
        open({ "# Doc", "first change" })
        seed({ span(1, 0, "first", "tighter") })
        assert.is_true(refreshed(1))
        vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "inserted" })
        assert.equals(2, marks()[1][2])
        assert.is_true(vim.wait(arrival.MS, function()
            local d = vim.diagnostic.get(buf, { namespace = skill_render.diag_namespace() })[1]
            return d and d.lnum == 2
        end, 10))
    end)

    for _, case in ipairs({ { "direct", "34" }, { "propose", "33" } }) do
        it(("draws nothing under presentation: %s (row %s)"):format(case[1], case[2]), function()
            local lines = { "---", "presentation: " .. case[1], "---", "🤖~old~{first} change" }
            open(lines)
            seed({ span(3, 0, "🤖~old~{first}") })
            edit_round.refresh(buf)
            vim.wait(200, function() return false end, 10)
            assert.equals(0, #marks())
            assert.same(lines, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
        end)
    end

    it("draws nothing for a round a later submit cleared, and stays cleared on reopen (row 32)", function()
        open({ "# Doc", "first change" })
        seed({ span(1, 0, "first") })
        assert.is_true(refreshed(1))
        fake_couch.owe(vim.env.FAKE_COUCH_REGISTRY, file, "msg-1")
        assert.is_true(refreshed(0))
        vim.api.nvim_buf_delete(buf, { force = true })
        open({ "# Doc", "first change" })
        edit_round.refresh(buf)
        vim.wait(200, function() return false end, 10)
        assert.equals(0, #marks())
    end)

    it("drops a reply a clear overtook, and draws one that came first", function()
        open({ "# Doc", "first change" })
        seed({ span(1, 0, "first") })
        vim.env.FAKE_COUCH_REGISTRY_REPLY_DELAY, vim.env.FAKE_COUCH_REGISTRY_REPLY_DELAY_OPS = "0.5", "round"
        local done
        local registry = require("parley.document_registry")
        local request = registry.request
        registry.request = function(op, args, witness, callback, options)
            return request(op, args, witness, function(result) callback(result); done = true end, options)
        end
        local ok, err = pcall(function()
            edit_round.refresh(buf)
            edit_round.clear(buf)
            assert.is_true(vim.wait(arrival.MS, function() return done end, 10))
            vim.wait(50, function() return false end, 10)
            assert.equals(0, #marks())
            done = nil
            edit_round.refresh(buf)
            assert.is_true(vim.wait(arrival.MS, function() return done end, 10))
            assert.is_true(vim.wait(arrival.MS, function() return #marks() == 1 end, 10))
        end)
        registry.request = request
        assert.is_true(ok, tostring(err))
    end)

    it("re-anchors a span when the buffer changed while the request ran", function()
        open({ "# Doc", "first change" })
        seed({ span(1, 0, "first", "why") })
        vim.env.FAKE_COUCH_REGISTRY_REPLY_DELAY, vim.env.FAKE_COUCH_REGISTRY_REPLY_DELAY_OPS = "0.3", "round"
        edit_round.refresh(buf)
        vim.api.nvim_buf_set_lines(buf, 1, 1, false, { "typed meanwhile" })
        assert.is_true(vim.wait(arrival.MS, function() return #marks() == 1 end, 10))
        assert.same({ 2, 0 }, { marks()[1][2], marks()[1][3] })
    end)

    -- The per-keystroke path coalesces: N keystrokes before the scheduler runs
    -- cost one re-derive, not N.
    it("re-derives once per batch of keystrokes, at 8 and at 16", function()
        open({ "# Doc", "first change" })
        seed({ span(1, 0, "first") })
        assert.is_true(refreshed(1))
        vim.wait(50, function() return false end, 10)
        for _, n in ipairs({ 8, 16 }) do
            local before = edit_round.stats.rederives
            for i = 1, n do vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "k" .. i }) end
            vim.wait(50, function() return false end, 10)
            assert.equals(1, edit_round.stats.rederives - before)
        end
    end)

    it("says once when a round has more spans than it draws", function()
        open({ "# Doc", "x" })
        local spans = {}
        for i = 1, require("parley.presentation").MAX_SPANS + 1 do spans[i] = span(1, 0, "x") end
        seed(spans)
        local notices, notify = {}, vim.notify
        vim.notify = function(message, level) notices[#notices + 1] = { message, level } end
        local ok, err = pcall(function()
            assert.is_true(refreshed(200))
            assert.is_true(refreshed(200))
        end)
        vim.notify = notify
        assert.is_true(ok, tostring(err))
        assert.same({ { "parley: showing 200 of 201 agent changes", vim.log.levels.WARN } }, notices)
    end)
end)
