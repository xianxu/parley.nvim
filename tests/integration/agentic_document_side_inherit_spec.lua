-- #378: Alt+o from a registered parent onto a side doc registers the child to
-- the parent's effective owner, through the real opener (OpenFileUnderCursor →
-- open_buf → setup_markdown_keymaps → attach) and the persistent fake registry.
-- The pane's actor is parley.nvim:1 throughout, so a child that lands on ops:0
-- can only have inherited it.
local arrival = require("tests.helpers.arrival")
describe("side docs inherit the parent's owner (#378)", function()
    local root, parent, side, other, buf, saved, p, document
    local function await(predicate, why)
        assert.is_true(vim.wait(arrival.MS, predicate, 10), why or "side-doc inheritance did not settle")
    end
    local function lookup(path)
        local result
        require("parley.document_registry").request("lookup", { path }, {}, function(value) result = value end)
        await(function() return result ~= nil end)
        return result
    end
    local function register(path, owner)
        local result
        require("parley.document_registry").request("register", { path, owner }, {}, function(value) result = value end)
        await(function() return result ~= nil end)
        assert.equals("registered", result.kind)
    end
    local function sends()
        return vim.fn.filereadable(root .. "/sent") == 1 and #vim.fn.readfile(root .. "/sent") or 0
    end
    -- Put the cursor on `line` of the parent (or `from`) and press its Alt+o.
    local function follow(line, from)
        vim.api.nvim_set_current_buf(from or buf)
        vim.api.nvim_win_set_cursor(0, { line, 2 })
        local mapping = vim.fn.maparg("<M-o>", "n", false, true)
        assert.equals(1, mapping.buffer)
        mapping.callback()
        return vim.api.nvim_get_current_buf()
    end
    local function settled(child)
        local status = document.status(child)
        return status and not status.operation and status.phase ~= "probing" and status.phase ~= "busy"
    end

    before_each(function()
        root = vim.fn.resolve(vim.fn.tempname()); vim.fn.mkdir(root .. "/parent.side", "p")
        parent, side, other = root .. "/parent.md", root .. "/parent.side/child.md", root .. "/other.md"
        vim.fn.writefile({ "# Parent", "[side](parent.side/child.md)", "[other](other.md)" }, parent)
        vim.fn.writefile({ "# A side doc written by hand, no frontmatter" }, side)
        vim.fn.writefile({ "# Not a side doc" }, other)
        require("tests.helpers.fake_couch").write(root, root .. "/sent", root .. "/argv")
        p, document = require("parley"), require("parley.agentic_document")
        saved = { env = {}, state_dir = p.config.state_dir }
        for _, name in ipairs({ "PATH", "COUCH_THREAD_SCOPE", "COUCH_THREAD_TAG", "FAKE_COUCH_REGISTRY",
            "FAKE_COUCH_REGISTRY_MODE", "FAKE_COUCH_ACTORS", "FAKE_COUCH_EXIT", "FAKE_COUCH_SLEEP", "FAKE_COUCH_STATUS",
            "FAKE_COUCH_REGISTRY_DELAY", "FAKE_COUCH_REGISTRY_DELAY_OPS" }) do
            saved.env[name] = vim.env[name] or false
        end
        vim.env.PATH = root .. "/bin:" .. vim.env.PATH
        vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = "side-inherit", "pane"
        vim.env.FAKE_COUCH_REGISTRY, vim.env.FAKE_COUCH_REGISTRY_MODE = root .. "/registry.json", nil
        vim.env.FAKE_COUCH_EXIT, vim.env.FAKE_COUCH_SLEEP, vim.env.FAKE_COUCH_STATUS = "0", nil, nil
        vim.env.FAKE_COUCH_REGISTRY_DELAY, vim.env.FAKE_COUCH_REGISTRY_DELAY_OPS = nil, nil
        vim.env.FAKE_COUCH_ACTORS = vim.json.encode({ Code = "ok", Actors = {
            { Binding = { Slot = "parley.nvim:1", Scope = "side-inherit", Tag = "pane" } },
        } })
        p.config.state_dir = root .. "/state"
        register(parent, "ops:0")
        -- The BufEnter handler parley.setup installs, so every buffer, the
        -- child included, is attached by the product path and not by the spec.
        p.setup_buf_handler()
        vim.cmd("edit " .. vim.fn.fnameescape(parent))
        buf = vim.api.nvim_get_current_buf()
        await(function() return document.identity(buf) ~= nil end, "the parent never registered")
    end)
    after_each(function()
        for _, owned in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(owned) and vim.api.nvim_buf_get_name(owned):sub(1, #root + 1) == root .. "/" then
                document.detach(owned)
                vim.api.nvim_buf_delete(owned, { force = true })
            end
        end
        require("parley.document_registry").shutdown()
        for name, value in pairs(saved.env) do vim.env[name] = value or nil end
        p.config.state_dir = saved.state_dir
        vim.fn.delete(root, "rf")
    end)

    it("registers an absent side child to the parent's owner, sending nothing", function()
        local child = follow(2)
        assert.equals(side, vim.fn.resolve(vim.api.nvim_buf_get_name(child)))
        await(function() return document.identity(child) ~= nil end, "the side child did not inherit")
        assert.equals("ops:0", document.identity(child).Owner)
        assert.equals("ops:0", lookup(side).registration.Owner)
        assert.equals("ops:0", lookup(parent).registration.Owner)
        assert.equals(0, sends())
    end)

    it("keeps a side child that is already registered", function()
        register(side, "ops:7")
        local child = follow(2)
        await(function() return document.identity(child) ~= nil and settled(child) end)
        assert.equals("ops:7", document.identity(child).Owner)
        assert.equals("ops:7", lookup(side).registration.Owner)
        assert.equals(0, sends())
    end)

    it("registers nothing for a link that is not a side doc", function()
        local child = follow(3)
        await(function() return document.status(child) and document.status(child).phase == "plain" end)
        assert.equals("absent", lookup(other).kind)
        assert.equals(0, sends())
    end)

    it("refuses while Couch cannot answer, then a later navigation inherits", function()
        vim.env.FAKE_COUCH_REGISTRY_MODE = "malformed"
        local child = follow(2)
        await(function() return settled(child) end)
        assert.is_nil(document.identity(child))
        vim.env.FAKE_COUCH_REGISTRY_MODE = nil
        assert.equals("absent", lookup(side).kind, "an unanswered navigation must not guess an owner")
        follow(2)
        await(function() return document.identity(child) ~= nil end, "the later navigation did not inherit")
        assert.equals("ops:0", lookup(side).registration.Owner)
        assert.equals(0, sends())
    end)

    it("offers nothing to inherit from a parent with no registration", function()
        local loose = root .. "/loose.md"
        vim.fn.mkdir(root .. "/loose.side", "p")
        vim.fn.writefile({ "# Loose", "[side](loose.side/child.md)" }, loose)
        vim.fn.writefile({ "# Side of an unregistered parent" }, root .. "/loose.side/child.md")
        vim.cmd("edit " .. vim.fn.fnameescape(loose))
        local from = vim.api.nvim_get_current_buf()
        await(function() return document.status(from) and document.status(from).phase == "plain" end)
        local child = follow(2, from)
        await(function() return settled(child) end)
        assert.is_nil(document.identity(child))
        assert.equals("absent", lookup(root .. "/loose.side/child.md").kind)
        assert.equals(0, sends())
    end)

    -- The review's repro: Alt+Return lands while the inheritance is still out.
    -- It must wait for it and submit once, never be dropped.
    describe("an Alt+Return pressed during inheritance", function()
        before_each(function()
            vim.env.FAKE_COUCH_REGISTRY_DELAY, vim.env.FAKE_COUCH_REGISTRY_DELAY_OPS = "0.4", "lookup"
        end)

        it("submits once, to the inherited owner, when pressed at the parent check", function()
            local child = follow(2)
            await(function()
                local op = document.status(child) and document.status(child).operation
                return op and op.witness.operation == "confirm_parent"
            end, "inheritance never reached the parent check")
            document.submit(child)
            await(function() return sends() == 1 and settled(child) end, "the queued press was dropped")
            assert.equals("ops:0", document.identity(child).Owner)
            assert.equals("ops:0", lookup(side).registration.Owner)
        end)

        -- Anything else drops the press: the inheritance never authorized a
        -- submit as the pane's actor, and the band offers that as a deliberate
        -- second press instead.
        local function forget_parent()
            local forgotten
            require("parley.document_registry").request("forget", { parent }, {}, function(value) forgotten = value end)
            await(function() return forgotten ~= nil end)
        end
        local function dropped(child)
            await(function() return settled(child) end)
            vim.wait(600) -- a dropped press must stay dropped, not arrive late
            assert.equals(0, sends())
            assert.is_nil(document.identity(child))
            assert.equals("absent", lookup(side).kind)
            local winbar = vim.wo[vim.fn.bufwinid(child)].winbar
            assert.truthy(winbar:find(require("parley.document_session").NOT_INHERITED, 1, true), winbar)
        end
        -- BR-6: a file reload during inheritance must never deliver the held
        -- press. For an ordinary side doc the reload unloads the buffer, so the
        -- ending is a detach, and the model must drop there (a flush would send
        -- to the pane's actor). The `changed` ending is walked in
        -- document_session_spec's settle table.
        it("never delivers the press after the file reloads during inheritance", function()
            local autoread = vim.o.autoread
            vim.o.autoread = true
            local child = follow(2)
            document.submit(child)
            assert.truthy(document.status(child).queued, "the press was not held")
            vim.fn.writefile({ "# Edited outside the editor" }, side)
            vim.uv.fs_utime(side, os.time() + 5, os.time() + 5)
            vim.api.nvim_buf_call(child, function() vim.cmd("checktime") end)
            vim.o.autoread = autoread
            await(function() return not document.status(child).queued end, "the reload left the press held")
            await(function() return settled(child) end)
            vim.wait(1500) -- the retry lookup must not deliver it later either
            assert.equals(0, sends())
            assert.is_nil(document.identity(child))
        end)

        for _, case in ipairs({
            { name = "the parent was forgotten", setup = forget_parent },
            { name = "the parent changed owner", setup = function() forget_parent(); register(parent, "ops:9") end },
        }) do
            it("drops the press, sending nothing, when " .. case.name, function()
                case.setup()
                local child = follow(2)
                document.submit(child)
                dropped(child)
            end)
        end
    end)
end)
