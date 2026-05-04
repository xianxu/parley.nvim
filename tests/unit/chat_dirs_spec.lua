local parley = require("parley")

-- Issue #117 M2: chat roots are derived from config.chat_dir + repo
-- mode + super-repo, never freeform-mutated and never persisted to
-- state.json. The previous freeform-add/remove/rename API and its
-- backing picker UI have been deleted; these tests guard the new
-- contract.

describe("chat roots: derivation and persistence contract", function()
    local base_dir
    local primary_dir
    local state_dir

    local function read_state()
        local state_file = state_dir .. "/state.json"
        if vim.fn.filereadable(state_file) == 0 then
            return {}
        end
        return parley.helpers.file_to_table(state_file) or {}
    end

    before_each(function()
        base_dir = vim.fn.tempname() .. "-parley-chat-dirs"
        primary_dir = base_dir .. "/primary"
        state_dir = base_dir .. "/state"

        parley._state = {}

        parley.setup({
            chat_dir = primary_dir,
            state_dir = state_dir,
            providers = {},
            api_keys = {},
        })
    end)

    after_each(function()
        if base_dir then
            vim.fn.delete(base_dir, "rf")
        end
    end)

    it("get_chat_roots returns config.chat_dir as the only root in plain mode", function()
        local roots = parley.get_chat_roots()
        assert.equals(1, #roots)
        assert.equals(vim.fn.resolve(primary_dir), vim.fn.resolve(roots[1].dir))
        assert.is_true(roots[1].is_primary)
    end)

    it("does not write chat_roots / chat_dirs to state.json", function()
        parley.refresh_state()
        local persisted = read_state()
        assert.is_nil(persisted.chat_roots,
            "chat_roots must not be persisted (issue #117)")
        assert.is_nil(persisted.chat_dirs,
            "chat_dirs must not be persisted (issue #117)")
    end)

    it("ignores chat_roots / chat_dirs when loading from state.json", function()
        -- Simulate an old state file written by a pre-#117 version that
        -- carried freeform additions.
        vim.fn.mkdir(state_dir, "p")
        local stale_state = state_dir .. "/state.json"
        local stray_dir = base_dir .. "/stray-old-freeform-add"
        local fh = assert(io.open(stale_state, "w"))
        fh:write(vim.json.encode({
            chat_dirs = { vim.fn.resolve(primary_dir), stray_dir },
            chat_roots = {
                { dir = vim.fn.resolve(primary_dir), label = "main", is_primary = true, role = "primary" },
                { dir = stray_dir, label = "stray", is_primary = false, role = "extra" },
            },
        }))
        fh:close()

        parley._state = {}
        parley.setup({
            chat_dir = primary_dir,
            state_dir = state_dir,
            providers = {},
            api_keys = {},
        })

        -- The stale entries from the file are not loaded — only
        -- config.chat_dir survives.
        assert.same({ vim.fn.resolve(primary_dir) }, parley.get_chat_dirs())
    end)

    it("removes chat_roots / chat_dirs from state.json on next persist", function()
        -- Pre-seed state.json with stale chat keys; verify that after a
        -- refresh_state cycle they are gone.
        vim.fn.mkdir(state_dir, "p")
        local stale_state = state_dir .. "/state.json"
        local fh = assert(io.open(stale_state, "w"))
        fh:write(vim.json.encode({
            chat_dirs = { vim.fn.resolve(primary_dir), base_dir .. "/stray" },
            chat_roots = { { dir = vim.fn.resolve(primary_dir), label = "main" } },
            agent = "Claude",
        }))
        fh:close()

        parley._state = {}
        parley.setup({
            chat_dir = primary_dir,
            state_dir = state_dir,
            providers = {},
            api_keys = {},
        })
        parley.refresh_state()

        local persisted = read_state()
        assert.is_nil(persisted.chat_dirs)
        assert.is_nil(persisted.chat_roots)
    end)
end)
