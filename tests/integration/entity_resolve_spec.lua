-- Real resolver subprocesses use a local filesystem-backed executable. Only
-- chooser callbacks are retained; parsing, argv, resolution and opening are real.
local parley = require("parley")
local fixture = vim.fn.getcwd() .. "/tests/fixtures/fake_sdlc"

describe("entity navigation with the sdlc executable", function()
    local dir, state, saved, picker, settled
    local env_names = { "PARLEY_FAKE_SDLC_STATE", "PARLEY_FAKE_SDLC_MODE" }
    local function write(name, lines)
        local path = dir .. "/" .. name
        vim.fn.writefile(lines or { "fixture" }, path)
        return path
    end
    local function seed(mapping)
        vim.fn.writefile({ vim.json.encode(mapping) }, state .. "/resolve.json")
    end
    local function complete_records(path)
        local out = {}
        local file = io.open(path, "rb")
        if not file then return out end
        local payload = file:read("*a")
        file:close()
        -- The producer may still be appending. Only newline-terminated records
        -- prove the complete JSON payload has arrived.
        for line in payload:gmatch("([^\n]+)\n") do out[#out + 1] = vim.json.decode(line) end
        return out
    end
    local function requests() return complete_records(state .. "/requests.jsonl") end
    local function wait_for(predicate, message)
        assert(vim.wait(4000, predicate, 10), message)
    end
    local function same_path(path)
        return vim.fn.resolve(vim.api.nvim_buf_get_name(0)) == vim.fn.resolve(path)
    end
    local function origin(lines)
        local path = write("origin.md", lines)
        vim.cmd("edit! " .. vim.fn.fnameescape(path))
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        return vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win(), path
    end
    local function release()
        vim.fn.writefile({ "ready" }, state .. "/release")
        wait_for(function() return #complete_records(state .. "/completed.jsonl") == 1 end, "fake did not finish")
        wait_for(function() return settled == 1 end, "resolver callback did not settle")
    end

    before_each(function()
        dir = vim.fn.tempname() .. "-entity-resolve"
        state = dir .. "/fake-state"
        vim.fn.mkdir(state, "p")
        saved = { config = parley.config, select = vim.ui.select, cwd = vim.fn.getcwd(),
            family_open = require("parley.float_picker").open, system = vim.system }
        for _, key in ipairs(env_names) do saved[key] = vim.env[key] end
        vim.env.PARLEY_FAKE_SDLC_STATE = state
        vim.env.PARLEY_FAKE_SDLC_MODE = nil
        parley.setup({ chat_dir = dir .. "/chats", state_dir = dir .. "/state",
            providers = {}, api_keys = {}, sdlc_cmd = fixture })
        picker = nil
        settled = 0
        -- Observe actual child completion while forwarding the real subprocess
        -- and its callback. The sentinel queues after production's scheduled
        -- result dispatch, so stale-result assertions cannot pass prematurely.
        vim.system = function(argv, opts, on_exit)
            if argv[1] ~= fixture or argv[2] ~= "resolve" or not on_exit then
                return saved.system(argv, opts, on_exit)
            end
            return saved.system(argv, opts, function(result)
                on_exit(result)
                vim.schedule(function() settled = settled + 1 end)
            end)
        end
        vim.ui.select = function(items, opts, callback)
            picker = { items = items, opts = opts, callback = callback }
        end
    end)

    after_each(function()
        local expected = #requests()
        if expected > 0 then
            wait_for(function() return settled == expected end, "subprocess callbacks did not drain")
        end
        vim.ui.select = saved.select
        vim.system = saved.system
        require("parley.float_picker").open = saved.family_open
        parley.config = saved.config
        for _, key in ipairs(env_names) do vim.env[key] = saved[key] end
        vim.cmd("silent! only!")
        vim.cmd("silent! %bwipeout!")
        vim.fn.chdir(saved.cwd)
        vim.fn.delete(dir, "rf")
    end)

    it("returns seeded resolve JSON and logs exact argv through vim.system", function()
        local target = write("target.md")
        seed({ ["#327"] = { files = { { path = target, kind = "issue" } } } })
        local result
        vim.system({ fixture, "resolve", "--json", "#327" }, { text = true }, function(value) result = value end)
        wait_for(function() return result ~= nil end, "fake subprocess did not finish")
        assert.equals(0, result.code)
        assert.same({ files = { { path = target, kind = "issue" } } }, vim.json.decode(result.stdout))
        assert.same({ { "resolve", "--json", "#327" } }, requests())
    end)

    it("opens only the chosen artifact occurrence beside an @@ destination", function()
        local target, other = write("artifact.md"), write("other.md")
        seed({ ["#327"] = { files = { { path = target } } }, ["#999"] = { files = { { path = other } } } })
        origin({ "1. question", "See @@" .. other .. "@@ and #327 and #999" })
        parley.cmd.OpenFileUnderCursor()
        assert.is_not_nil(picker)
        assert.equals(3, #picker.items)
        assert.equals(0, #requests())
        assert.equals("#327", picker.items[2].target)
        picker.callback(picker.items[2], 2)
        wait_for(function() return same_path(target) end, "selected artifact did not open")
        assert.same({ { "resolve", "--json", "#327" } }, requests())
    end)

    it("discards a family chooser callback after the source changes", function()
        local first, second = write("first.md"), write("second.md")
        seed({ ["#327"] = { files = { { path = first, kind = "issue" }, { path = second, kind = "plan" } } } })
        local family
        require("parley.float_picker").open = function(opts) family = opts end
        local buf, _, path = origin({ "1. question", "See #327" })
        parley.cmd.OpenFileUnderCursor()
        wait_for(function() return family ~= nil end, "family chooser did not open")
        assert.equals(2, #family.items)
        vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "1. changed" })
        family.on_select(family.items[1])
        family.on_select(family.items[2])
        assert.is_true(same_path(path))
        assert.same({ { "resolve", "--json", "#327" } }, requests())
    end)

    for _, invalidation in ipairs({ "edit", "window", "generation" }) do
        it("discards a delayed resolver result after " .. invalidation .. " invalidation", function()
            local target = write("stale.md")
            seed({ ["#327"] = { files = { { path = target } }, release = "release" } })
            local buf, win, path = origin({ "1. question", "See #327 and #999" })
            parley.cmd.OpenFileUnderCursor()
            assert.is_not_nil(picker)
            picker.callback(picker.items[1], 1)
            wait_for(function() return #requests() == 1 end, "resolver did not reach fake")
            if invalidation == "edit" then
                vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "1. edited question" })
            elseif invalidation == "window" then
                vim.cmd("vsplit")
            else
                parley.cmd.OpenFileUnderCursor()
                assert.is_not_nil(picker)
                picker.callback(nil, nil)
            end
            local active = vim.api.nvim_get_current_win()
            release()
            assert.is_true(same_path(path))
            assert.equals(active, vim.api.nvim_get_current_win())
            assert.equals(buf, vim.api.nvim_win_get_buf(win))
            assert.same({ { "resolve", "--json", "#327" } }, requests())
        end)
    end
end)
