-- #214 M2: registry/reality agreement, in both directions, against a REAL
-- prepped chat buffer — not a hand-mirrored key list.
--
-- Direction 1 (no leaks): every parley-owned mapping on the buffer is either
-- registry-derived or a declared `native_overrides` entry. The allowance list is
-- CLOSED, so a new hand-rolled `vim.keymap.set` fails here instead of quietly
-- claiming a key nobody can rebind.
--
-- Direction 2 (no ghosts): every registry entry that resolves to a key under the
-- shipped config is actually mapped on the buffer — the failure the pre-#214
-- help float could not detect, because it printed `default_key` whenever
-- resolution came back empty.

local parley = require("parley")
local reg = require("parley.keybinding_registry")

local base_tmp_dir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-kbagree-" .. os.time()

local function setup(extra)
    parley.setup(vim.tbl_extend("force", {
        chat_dir = base_tmp_dir .. "/chat",
        state_dir = base_tmp_dir .. "/state",
        providers = {},
        api_keys = {},
    }, extra or {}))
end

-- A real chat buffer, prepped through the production path.
local function prepped_chat()
    local dir = parley.config.chat_dir
    vim.fn.mkdir(dir, "p")
    local path = dir .. "/2026-03-01-agree-" .. math.random(1e6) .. ".md"
    vim.fn.writefile({ "# topic: agree", "- file: agree.md", "---", "", "💬: hi" }, path)
    vim.cmd("edit " .. vim.fn.fnameescape(path))
    local buf = vim.api.nvim_get_current_buf()
    parley.prep_chat(buf, path)
    return buf, path
end

local function cleanup(buf, path)
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    parley._prepared_bufs[buf] = nil
    vim.fn.delete(path)
end

-- Neovim reports mapping lhs in ITS canonical spelling (<C-g> comes back as
-- <C-G>), so both sides must be normalised before comparison — otherwise every
-- <C-g> binding looks simultaneously leaked and missing.
local function canon(lhs)
    local ok, out = pcall(function()
        return vim.fn.keytrans(vim.api.nvim_replace_termcodes(lhs, true, true, true))
    end)
    return ok and out or lhs
end

-- Every buffer-local mapping carrying a parley desc, as { canon(lhs) = desc }.
local function parley_maps(buf)
    local out = {}
    for _, mode in ipairs({ "n", "i", "v", "x" }) do
        for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, mode)) do
            if m.desc and m.desc:lower():find("parley", 1, true) then
                out[canon(m.lhs)] = m.desc
            end
        end
    end
    return out
end

describe("keybinding registry vs. reality (#214 M2)", function()
    it("no leaks — every parley map is registry-derived or a declared override", function()
        setup()
        local buf, path = prepped_chat()

        local known = {}
        for _, e in ipairs(reg.entries) do
            for _, k in ipairs(reg.resolve_keys(e, parley.config) or {}) do known[canon(k)] = true end
        end
        for k in pairs(reg.native_overrides) do known[canon(k)] = true end

        local leaked = {}
        for lhs, desc in pairs(parley_maps(buf)) do
            if not known[lhs] then leaked[#leaked + 1] = lhs .. " (" .. desc .. ")" end
        end
        cleanup(buf, path)
        assert.same({}, leaked)
    end)

    it("no ghosts — every resolved chat-scope key is really mapped", function()
        setup()
        local buf, path = prepped_chat()
        local live = parley_maps(buf)

        local missing = {}
        for _, e in ipairs(reg.entries) do
            if e.buffer_local and not e.help_only
                and (e.scope == "chat" or e.scope == "parley_buffer") then
                for _, k in ipairs(reg.resolve_keys(e, parley.config) or {}) do
                    if not live[canon(k)] then missing[#missing + 1] = e.id .. " => " .. k end
                end
            end
        end
        cleanup(buf, path)
        assert.same({}, missing)
    end)

    -- The headline gesture, asserted on the buffer rather than in the resolver,
    -- because M2's whole hazard was a config edit revoking it a layer away.
    it("<M-q> and <M-t> survive M2's new config defaults", function()
        setup()
        local buf, path = prepped_chat()
        local live = parley_maps(buf)
        cleanup(buf, path)
        assert.is_truthy(live[canon("<M-q>")], "<M-q> (quote/drill-in) is not mapped")
        assert.is_truthy(live[canon("<C-g>q")], "<C-g>q alias is not mapped")
        assert.is_truthy(live[canon("<M-t>")], "<M-t> (outline) is not mapped")
    end)

    it("native overrides are mapped, and each one is documented", function()
        setup()
        local buf, path = prepped_chat()
        local live = parley_maps(buf)
        cleanup(buf, path)
        for key, meta in pairs(reg.native_overrides) do
            assert.is_truthy(live[canon(key)], "native override not mapped: " .. key)
            assert.is_truthy(meta.why and #meta.why > 0, "no rationale recorded for " .. key)
            assert.is_truthy(meta.where and #meta.where > 0, "no location recorded for " .. key)
        end
    end)

    -- Done-when: "one documented switch disabling the whole default keymap,
    -- verified by :map showing no parley mapping."
    it("default_keymaps = false leaves no parley mapping on the buffer", function()
        setup({ default_keymaps = false })
        local buf, path = prepped_chat()
        local live = parley_maps(buf)
        cleanup(buf, path)
        assert.same({}, vim.tbl_keys(live))
    end)

    -- The README promises "every feature stays reachable as a :Parley* command"
    -- when the switch is off. A promise in user-facing docs gets a test.
    it("features stay reachable as commands with the keymaps off", function()
        setup({ default_keymaps = false })
        local buf, path = prepped_chat()
        local cmds = vim.api.nvim_get_commands({})
        cleanup(buf, path)
        for _, name in ipairs({ "ParleyChatRespond", "ParleyChatFinder", "ParleyKeyBindings",
                               "ParleyToggleToolFolds" }) do
            assert.is_truthy(cmds[name], "command missing under default_keymaps = false: " .. name)
        end
    end)

    it("and the switch is reversible within one session", function()
        setup({ default_keymaps = false })
        local b1, p1 = prepped_chat()
        assert.same({}, vim.tbl_keys(parley_maps(b1)))
        cleanup(b1, p1)

        setup()
        local b2, p2 = prepped_chat()
        local live = parley_maps(b2)
        cleanup(b2, p2)
        assert.is_truthy(live[canon("<M-q>")], "bindings did not come back after re-enabling")
    end)
end)
