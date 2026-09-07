local base_tmp_dir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-keybindings-" .. os.time()
local parley = require("parley")

local function has_line(lines, shortcut, description)
    for _, line in ipairs(lines) do
        if line:find(shortcut, 1, true) and line:find(description, 1, true) then
            return true
        end
    end
    return false
end

local function setup_parley(extra)
    local opts = vim.tbl_extend("force", {
        chat_dir = base_tmp_dir .. "/chat",
        state_dir = base_tmp_dir .. "/state",
        providers = {},
        api_keys = {},
    }, extra or {})
    parley.setup(opts)
end

describe("key bindings help", function()
    it("other context shows global keys only", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("other")
        assert.is_true(has_line(lines, "<C-g>?", "Show key bindings"))
        assert.is_true(has_line(lines, "<C-g>f", "Open chat finder"))
        assert.is_true(has_line(lines, "<C-n>f", "Open note finder"))
        -- Should NOT include chat buffer, repo, or finder keys
        assert.is_false(has_line(lines, "<C-g><C-g>", "Respond"))
        assert.is_false(has_line(lines, "<C-a>", "Cycle recency window left"))
        assert.is_false(has_line(lines, "<C-y>f", "Open issue finder"))
    end)

    it("chat context shows global + repo + buffer + chat keys", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("chat")
        assert.is_true(has_line(lines, "<C-g>?", "Show key bindings"))
        assert.is_true(has_line(lines, "<C-g><C-g>", "Respond"))
        assert.is_true(has_line(lines, "<C-g>d", "Delete chat"))
        assert.is_true(has_line(lines, "<C-g>w", "Toggle web_search"))
        assert.is_true(has_line(lines, "<C-g>o", "Open file reference"))
        -- #160: smart-gf binding (resolve ref, else native gf) — a parley_buffer key
        assert.is_true(has_line(lines, "gf", "fall back to Vim"))
        -- Should NOT include markdown or finder keys
        assert.is_false(has_line(lines, "<C-a>", "Cycle recency window left"))
        assert.is_false(has_line(lines, "<C-g>ve", "Apply review marker"))
    end)

    it("chat_finder context shows only finder keys", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("chat_finder")
        assert.is_true(has_line(lines, "<C-a>", "Cycle recency window left"))
        assert.is_true(has_line(lines, "<Tab>", "Cycle recency window left"))
        assert.is_true(has_line(lines, "<C-s>", "Cycle recency window right"))
        assert.is_true(has_line(lines, "<S-Tab>", "Cycle recency window right"))
        assert.is_true(has_line(lines, "<C-d>", "Delete selected chat"))
        assert.is_true(has_line(lines, "<C-x>", "Move selected chat"))
        -- Should NOT include global or chat buffer keys
        assert.is_false(has_line(lines, "<C-g>?", "Show key bindings"))
        assert.is_false(has_line(lines, "<C-g><C-g>", "Respond"))
    end)

    it("note_finder context shows only finder keys", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("note_finder")
        assert.is_true(has_line(lines, "<C-a>", "Cycle recency window left"))
        assert.is_true(has_line(lines, "<C-d>", "Delete selected note"))
        assert.is_false(has_line(lines, "<C-g>?", "Show key bindings"))
    end)

    it("issue_finder context shows only finder keys", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("issue_finder")
        assert.is_true(has_line(lines, "<C-s>", "Cycle issue status"))
        assert.is_true(has_line(lines, "<Tab>", "Cycle view (issues/history)"))
        assert.is_true(has_line(lines, "<C-a>", "Cycle view (issues/history)"))
        assert.is_true(has_line(lines, "<C-d>", "Delete selected issue"))
        assert.is_false(has_line(lines, "<C-g>?", "Show key bindings"))
    end)

    it("markdown context shows global + repo + buffer + markdown keys", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("markdown")
        assert.is_true(has_line(lines, "<C-g>?", "Show key bindings"))
        assert.is_true(has_line(lines, "<C-g>o", "Open file reference"))
        assert.is_true(has_line(lines, "<C-g>d", "Delete file"))
        assert.is_true(has_line(lines, "<C-g>ve", "Apply review marker"))
        -- Should NOT include chat-specific keys
        assert.is_false(has_line(lines, "<C-g><C-g>", "Respond"))
    end)

    it("issue context shows global + repo + buffer + markdown + issue keys", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("issue")
        assert.is_true(has_line(lines, "<C-g>?", "Show key bindings"))
        assert.is_true(has_line(lines, "<C-y>c", "New issue"))
        assert.is_true(has_line(lines, "<C-y>f", "Open issue finder"))
        assert.is_true(has_line(lines, "<C-g>o", "Open file reference"))
        assert.is_true(has_line(lines, "<C-y>s", "Cycle issue status"))
        -- Should NOT include chat-specific keys
        assert.is_false(has_line(lines, "<C-g><C-g>", "Respond"))
    end)

    it("note context shows global + repo + buffer + markdown + note keys", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("note")
        assert.is_true(has_line(lines, "<C-g>?", "Show key bindings"))
        assert.is_true(has_line(lines, "<C-n>i", "Enter interview mode"))
        assert.is_true(has_line(lines, "<C-g>o", "Open file reference"))
        -- Should NOT include chat-specific keys
        assert.is_false(has_line(lines, "<C-g><C-g>", "Respond"))
    end)

    it("title reflects context", function()
        setup_parley()

        local chat_lines = parley._keybinding_help_lines("chat")
        assert.is_true(chat_lines[1]:find("(Chat)", 1, true) ~= nil)

        local other_lines = parley._keybinding_help_lines("other")
        assert.is_nil(other_lines[1]:find("(", 1, true))

        local finder_lines = parley._keybinding_help_lines("chat_finder")
        assert.is_true(finder_lines[1]:find("(Chat Finder)", 1, true) ~= nil)
    end)

    it("uses configured shortcut for key bindings help", function()
        setup_parley({
            global_shortcut_keybindings = { modes = { "n" }, shortcut = "<C-g>k" },
        })

        local lines = parley._keybinding_help_lines("other")
        assert.is_true(has_line(lines, "<C-g>k", "Show key bindings"))
    end)

    -- #214 flipped the <leader> copy maps to opt-in, so the help must NOT
    -- advertise them by default — and must advertise them once configured.
    -- (Before #214 the help printed entry.default_key whenever resolution came
    -- back empty, so it would have shown these regardless of what was bound.)
    it("global section omits the opt-in copy shortcuts by default", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("other")
        assert.is_false(has_line(lines, "<leader>cl", "Copy location"))
        assert.is_false(has_line(lines, "<leader>cc", "Copy context"))
    end)

    it("global section shows copy shortcuts once the user opts in", function()
        setup_parley({
            global_shortcut_copy_location = { modes = { "n", "v" }, shortcut = "<leader>cl" },
            global_shortcut_copy_context = { modes = { "n", "v" }, shortcut = "<leader>cc" },
        })

        local lines = parley._keybinding_help_lines("other")
        assert.is_true(has_line(lines, "<leader>cl", "Copy location"))
        assert.is_true(has_line(lines, "<leader>cc", "Copy context"))
    end)

    it("repo scope includes issue and vision finders", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("repo")
        assert.is_true(has_line(lines, "<C-y>f", "Open issue finder"))
        assert.is_true(has_line(lines, "<C-j>f", "Open vision finder"))
        -- Should NOT include chat-specific keys
        assert.is_false(has_line(lines, "<C-g><C-g>", "Respond"))
    end)

    it("chat context uses branch mnemonic and omits unconfigured tool folds", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("chat")
        -- #214: prune moved to the alt family as <M-p>, keeping <C-g>b as a
        -- legacy alias. The help shows the PRIMARY, so it now reads <M-p>.
        assert.is_true(has_line(lines, "<M-p>", "Prune"))
        assert.is_false(has_line(lines, "<M-p>", "Toggle tool folds"))
        assert.is_false(has_line(lines, "", "Toggle tool folds"))
    end)

    it("shows a configured tool-fold shortcut through the shared registry", function()
        setup_parley({
            chat_shortcut_toggle_tool_folds = { modes = { "n" }, shortcut = "<leader>tf" },
        })

        local lines = parley._keybinding_help_lines("chat")
        assert.is_true(has_line(lines, "<leader>tf", "Toggle tool folds"))
    end)

    it("treats an empty configured shortcut as unbound", function()
        setup_parley({
            chat_shortcut_toggle_tool_folds = { modes = { "n" }, shortcut = "" },
        })

        local lines = parley._keybinding_help_lines("chat")
        assert.is_false(has_line(lines, "", "Toggle tool folds"))
    end)

    it("markdown context includes review shortcuts", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("markdown")
        assert.is_true(has_line(lines, "<C-g>ve", "Apply review marker"))
        assert.is_true(has_line(lines, "<C-g>vf", "Review finder"))
    end)

    it("issue context includes vision shortcuts via repo ancestry", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("issue")
        assert.is_true(has_line(lines, "<C-j>f", "Open vision finder"))
    end)

    it("review finder shows in global scope", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("other")
        assert.is_true(has_line(lines, "<C-g>vf", "Review finder"))
    end)
end)

describe("keybinding registry", function()
    it("every entry has required fields", function()
        local reg = require("parley.keybinding_registry")
        for _, entry in ipairs(reg.entries) do
            assert.is_not_nil(entry.id, "entry missing id")
            -- #214 M2 tightened this from `default_key or config_key`. That OR
            -- was satisfied by the default_key arm alone, which is how nine
            -- entries shipped with no way to rebind or disable them. config_key
            -- IS the rebindable-ness, so it is required outright; default_key
            -- stays optional (an entry may ship deliberately unbound — see
            -- keybinding_registry.opt_in).
            assert.is_not_nil(
                entry.config_key,
                "entry " .. entry.id .. " has no config_key, so it cannot be rebound or disabled"
            )
            assert.is_not_nil(entry.default_modes, "entry " .. entry.id .. " missing default_modes")
            assert.is_not_nil(entry.scope, "entry " .. entry.id .. " missing scope")
            assert.is_not_nil(entry.desc, "entry " .. entry.id .. " missing desc")
        end
    end)

    it("all entry ids are unique", function()
        local reg = require("parley.keybinding_registry")
        local seen = {}
        for _, entry in ipairs(reg.entries) do
            assert.is_nil(seen[entry.id], "duplicate entry id: " .. entry.id)
            seen[entry.id] = true
        end
    end)

    it("all scopes are valid", function()
        local reg = require("parley.keybinding_registry")
        -- Use scope_labels as the canonical set of valid scopes
        for _, entry in ipairs(reg.entries) do
            assert.is_not_nil(reg.scope_labels[entry.scope], "invalid scope '" .. entry.scope .. "' for entry " .. entry.id)
        end
    end)

    it("ancestor scopes for issue includes repo", function()
        local reg = require("parley.keybinding_registry")
        local scopes = reg.get_ancestor_scopes("issue")
        local has_repo = false
        for _, s in ipairs(scopes) do
            if s == "repo" then has_repo = true end
        end
        assert.is_true(has_repo)
    end)

    it("derives migrated bindings from exposed config without registry literals", function()
        setup_parley()
        local reg = require("parley.keybinding_registry")
        local by_id = {}
        for _, entry in ipairs(reg.entries) do by_id[entry.id] = entry end

        -- #214: `keys` is the FULL resolved list. chat_prune gained <M-p> with
        -- <C-g>b kept as a legacy alias, so this asserts the list, not a single
        -- key — an assertion that took only keys[1] would have stayed green
        -- while the alias silently vanished.
        for _, expected in ipairs({
            { id = "super_repo_toggle", keys = { "<C-g>p" }, modes = { "n", "i" } },
            { id = "chat_prune", keys = { "<M-p>", "<C-g>b" }, modes = { "n" } },
        }) do
            local entry = by_id[expected.id]
            assert.is_nil(entry.default_key)
            local keys, modes = reg.resolve_keys(entry, parley.config)
            assert.same(expected.keys, keys)
            assert.same(expected.modes, modes)
        end

        assert.is_nil(by_id.chat_toggle_tool_folds.default_key)
        local tool_keys = reg.resolve_keys(by_id.chat_toggle_tool_folds, parley.config)
        assert.is_nil(tool_keys)
        assert.is_true(has_line(parley._keybinding_help_lines("other"), "<C-g>p", "super-repo"))
        assert.is_true(has_line(parley._keybinding_help_lines("chat"), "<M-p>", "Prune"))
    end)

    it("registers tool folds only when a non-empty shortcut is configured", function()
        local reg = require("parley.keybinding_registry")
        local calls = {}
        local callbacks = { chat_toggle_tool_folds = function() end }
        local function set_keymap(_, mode, key)
            table.insert(calls, { mode = mode, key = key })
        end

        reg.register_buffer({ "chat" }, 1, {}, callbacks, set_keymap)
        assert.same({}, calls)

        reg.register_buffer({ "chat" }, 1, {
            chat_shortcut_toggle_tool_folds = { modes = { "n" }, shortcut = "<leader>tf" },
        }, callbacks, set_keymap)
        assert.same({ { mode = "n", key = "<leader>tf" } }, calls)
    end)
end)

-- #214 M1. The chords live in config.lua, not in the registry's default_key:
-- resolve_keys returns the config `shortcut` and ignores default_key entirely
-- once a config_key exists, so a registry-side edit would have been inert for
-- chat_prune and revoked later for branch_ref.
describe("branch/prune chords (#214 M1)", function()
    local parley = require("parley")
    local reg = require("parley.keybinding_registry")

    local function entry(id)
        for _, e in ipairs(reg.entries) do if e.id == id then return e end end
    end

    before_each(function() parley.setup({}) end)

    it("branch_ref resolves the portable key FIRST, then mnemonic, then legacy", function()
        local keys = reg.resolve_keys(entry("branch_ref"), parley.config)
        assert.same({ "<M-i>", "<M-S-CR>", "<C-g>i" }, keys)
    end)

    it("the help float advertises a key that works in a plain terminal", function()
        -- <C-g>? renders only keys[1]. Leading with <M-S-CR> would advertise a
        -- chord most terminals cannot distinguish from <CR>.
        local lines = parley._keybinding_help_lines("chat")
        local shown
        for _, l in ipairs(lines) do
            if l:find("branch", 1, true) or l:find("Insert branch", 1, true) then shown = l end
        end
        assert.is_truthy(shown, "branch_ref missing from the chat help")
        assert.is_falsy(shown:find("<M-S-CR>", 1, true),
            "help leads with the non-portable chord: " .. tostring(shown))
    end)

    it("prune keeps <C-g>b as a legacy alias alongside <M-p>", function()
        assert.same({ "<M-p>", "<C-g>b" }, reg.resolve_keys(entry("chat_prune"), parley.config))
    end)

    it("branch_ref has a config_key, so M2 cannot revoke these chords", function()
        assert.are.equal("chat_shortcut_branch_ref", entry("branch_ref").config_key)
    end)

    -- BR-3: the tests above read parley.config, which is the MERGED table — so
    -- they stayed green with the shipped default deleted, because resolve_keys
    -- falls back to default_key. Assert the SHIPPED file carries the list.
    it("config.lua itself ships both chord lists", function()
        local shipped = dofile("lua/parley/config.lua")
        assert.same({ "<M-i>", "<M-S-CR>", "<C-g>i" },
            shipped.chat_shortcut_branch_ref.shortcut)
        assert.same({ "<M-p>", "<C-g>b" }, shipped.chat_shortcut_prune.shortcut)
    end)

    -- BR-12: asserting only the ABSENCE of <M-S-CR> would pass with <C-g>i first.
    it("the help float leads with the portable alt key specifically", function()
        local lines = parley._keybinding_help_lines("chat")
        local shown
        for _, l in ipairs(lines) do
            if l:find("branch", 1, true) or l:find("Insert branch", 1, true) then shown = l end
        end
        assert.is_truthy(shown, "branch_ref missing from the chat help")
        assert.is_truthy(shown:find("<M-i>", 1, true),
            "help must lead with <M-i>, got: " .. tostring(shown))
    end)
end)

describe("config_key coverage + shipped-default superset (#214 M2)", function()
    local parley = require("parley")
    local reg = require("parley.keybinding_registry")
    local shipped = dofile("lua/parley/config.lua")

    local function as_list(k)
        if k == nil then return {} end
        if type(k) == "string" then return { k } end
        return k
    end

    before_each(function() parley.setup({}) end)

    -- The trap this milestone exists to avoid: adding a config_key whose
    -- SHIPPED default is a single string, for an entry whose registry
    -- default_key is a list. resolve_keys REPLACES rather than merges, so that
    -- silently revokes every key past the first — for chat_drill_in that is
    -- <M-q>, the headline quote gesture.
    it("each shipped default is a superset of the entry's registry keys", function()
        local lost = {}
        for _, e in ipairs(reg.entries) do
            local cfg = e.config_key and shipped[e.config_key]
            -- An opt-in entry ships off on purpose; that is not shrinkage. The
            -- test below proves it is in fact off, so this skip cannot hide one.
            if reg.opt_in[e.id] then cfg = nil end
            if cfg and type(cfg) == "table" and cfg.shortcut then
                local have = {}
                for _, k in ipairs(as_list(cfg.shortcut)) do have[k] = true end
                for _, k in ipairs(as_list(e.default_key)) do
                    if not have[k] then
                        lost[#lost + 1] = e.id .. " loses " .. k .. " via " .. e.config_key
                    end
                end
            end
        end
        assert.same({}, lost)
    end)

    -- Same guarantee measured through the seam users actually hit, so the
    -- assertion above cannot pass on a config the resolver never consults.
    it("resolve_keys returns every shipped key for the multi-key entries", function()
        assert.same({ "<C-g>t", "<M-t>" }, reg.resolve_keys(
            (function() for _, e in ipairs(reg.entries) do if e.id == "outline" then return e end end end)(),
            parley.config))
        assert.same({ "<C-g>q", "<M-q>" }, reg.resolve_keys(
            (function() for _, e in ipairs(reg.entries) do if e.id == "chat_drill_in" then return e end end end)(),
            parley.config))
    end)
end)

-- The resolve seam's full strategy table. Written from MEASURED behaviour, not
-- from reading the `or` chain: the pre-#214 code disabled nothing that carried
-- a default_key, while the tool-folds tests made it look like "" worked
-- generally. It only worked for the one entry shipping no default_key.
describe("resolve_keys config-vs-default strategy (#214 M2)", function()
    local reg = require("parley.keybinding_registry")

    local with_default = { id = "x", config_key = "k", default_key = { "<C-g>x", "<M-x>" },
        default_modes = { "n" } }
    local no_default = { id = "y", config_key = "k", default_modes = { "n" } }

    local function keys(entry, cfg) return (reg.resolve_keys(entry, cfg)) end

    it("config absent — falls back to the full default list", function()
        assert.same({ "<C-g>x", "<M-x>" }, keys(with_default, {}))
    end)

    it("table without `shortcut` — no opinion, still falls back", function()
        assert.same({ "<C-g>x", "<M-x>" }, keys(with_default, { k = { modes = { "v" } } }))
    end)

    it("table without `shortcut` still applies its `modes`", function()
        local _, modes = reg.resolve_keys(with_default, { k = { modes = { "v" } } })
        assert.same({ "v" }, modes)
    end)

    it("bare string config (not a table) — ignored, falls back", function()
        assert.same({ "<C-g>x", "<M-x>" }, keys(with_default, { k = "<M-z>" }))
    end)

    it("non-empty shortcut REPLACES the default list, it does not merge", function()
        assert.same({ "<M-z>" }, keys(with_default, { k = { shortcut = "<M-z>" } }))
    end)

    it('shortcut = "" DISABLES an entry that ships a default (BR-9)', function()
        assert.is_nil(keys(with_default, { k = { shortcut = "" } }))
    end)

    it("shortcut = {} disables too", function()
        assert.is_nil(keys(with_default, { k = { shortcut = {} } }))
    end)

    it("a list of empty strings is still a disable, not a fallback", function()
        assert.is_nil(keys(with_default, { k = { shortcut = { "", "" } } }))
    end)

    it("entry with no default_key is unbound until configured", function()
        assert.is_nil(keys(no_default, {}))
        assert.same({ "<M-z>" }, keys(no_default, { k = { shortcut = "<M-z>" } }))
    end)

    -- Done-when: every shipped binding must be BOTH rebindable and disableable.
    it("every registry entry can actually be disabled from config", function()
        local stuck = {}
        for _, e in ipairs(reg.entries) do
            if e.config_key and not e.config_key:find(".", 1, true) then
                local cfg = { [e.config_key] = { shortcut = "" } }
                if reg.resolve_keys(e, cfg) ~= nil then stuck[#stuck + 1] = e.id end
            end
        end
        assert.same({}, stuck)
    end)
end)

-- #214 M2: the opt-in set, closed in both directions. Shipping a binding off is
-- legitimate, but it has to be a decision someone wrote down — otherwise the
-- superset guard above can be defeated by simply emptying a shortcut.
describe("opt-in set is closed (#214 M2)", function()
    local reg = require("parley.keybinding_registry")
    local shipped = dofile("lua/parley/config.lua")

    it("every entry parley ships UNBOUND is a declared opt-in", function()
        local undeclared = {}
        for _, e in ipairs(reg.entries) do
            if not e.help_only and not e.config_key:find(".", 1, true) then
                if reg.resolve_keys(e, shipped) == nil and not reg.opt_in[e.id] then
                    undeclared[#undeclared + 1] = e.id
                end
            end
        end
        assert.same({}, undeclared)
    end)

    it("every declared opt-in really does ship unbound", function()
        local still_bound = {}
        for id in pairs(reg.opt_in) do
            local e
            for _, cand in ipairs(reg.entries) do if cand.id == id then e = cand end end
            assert.is_truthy(e, "opt_in names a non-existent entry: " .. id)
            local keys = reg.resolve_keys(e, shipped)
            if keys ~= nil then
                still_bound[#still_bound + 1] = id .. " => " .. table.concat(keys, ",")
            end
        end
        assert.same({}, still_bound)
    end)

    it("no <leader> key is claimed by the shipped config", function()
        local claimed = {}
        for _, e in ipairs(reg.entries) do
            if not e.config_key:find(".", 1, true) then
                for _, k in ipairs(reg.resolve_keys(e, shipped) or {}) do
                    if k:lower():find("<leader>", 1, true) then
                        claimed[#claimed + 1] = e.id .. " => " .. k
                    end
                end
            end
        end
        assert.same({}, claimed)
    end)

    it("turning one on is a one-line config change", function()
        local e
        for _, cand in ipairs(reg.entries) do if cand.id == "copy_context" then e = cand end end
        local cfg = vim.tbl_extend("force", shipped, {
            global_shortcut_copy_context = { modes = { "n", "v" }, shortcut = "<leader>cc" },
        })
        assert.same({ "<leader>cc" }, reg.resolve_keys(e, cfg))
    end)
end)

-- #214 M2: the master switch.
describe("default_keymaps master switch (#214 M2)", function()
    local reg = require("parley.keybinding_registry")
    local shipped = dofile("lua/parley/config.lua")

    it("ships ON, so the default experience is unchanged", function()
        assert.is_true(shipped.default_keymaps)
    end)

    it("false unbinds every registry entry, including the help float itself", function()
        local off = vim.tbl_extend("force", shipped, { default_keymaps = false })
        local bound = {}
        for _, e in ipairs(reg.entries) do
            if reg.resolve_keys(e, off) ~= nil then bound[#bound + 1] = e.id end
        end
        assert.same({}, bound)
    end)

    it("help goes quiet with it — help and reality cannot disagree", function()
        local off = vim.tbl_extend("force", shipped, { default_keymaps = false })
        for _, ctx in ipairs({ "chat", "markdown", "other", "issue" }) do
            for _, line in ipairs(reg.help_lines(ctx, off)) do
                assert.is_falsy(line:find("<C-g>", 1, true),
                    "help still advertises a key in context " .. ctx .. ": " .. line)
            end
        end
    end)
end)
