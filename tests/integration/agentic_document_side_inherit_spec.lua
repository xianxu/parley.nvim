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
    -- Put the cursor on `line` of the parent and press the buffer's Alt+o.
    local function follow(line)
        vim.api.nvim_set_current_buf(buf)
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
            "FAKE_COUCH_REGISTRY_MODE", "FAKE_COUCH_ACTORS", "FAKE_COUCH_EXIT", "FAKE_COUCH_SLEEP", "FAKE_COUCH_STATUS" }) do
            saved.env[name] = vim.env[name] or false
        end
        vim.env.PATH = root .. "/bin:" .. vim.env.PATH
        vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = "side-inherit", "pane"
        vim.env.FAKE_COUCH_REGISTRY, vim.env.FAKE_COUCH_REGISTRY_MODE = root .. "/registry.json", nil
        vim.env.FAKE_COUCH_EXIT, vim.env.FAKE_COUCH_SLEEP, vim.env.FAKE_COUCH_STATUS = "0", nil, nil
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
end)
