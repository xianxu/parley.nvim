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

-- Neovim reports mapping lhs in ITS canonical spelling (<C-g> comes back as
-- <C-G>), so both sides must be normalised before comparison — otherwise every
-- <C-g> binding looks simultaneously leaked and missing.
local function canon(lhs)
    local ok, out = pcall(function()
        return vim.fn.keytrans(vim.api.nvim_replace_termcodes(lhs, true, true, true))
    end)
    return ok and out or lhs
end

local MODES = { "n", "i", "v", "x" }

-- Snapshot of every buffer-local mapping, keyed mode+lhs.
local function keymap_snapshot(buf)
    local out = {}
    for _, mode in ipairs(MODES) do
        for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, mode)) do
            out[mode .. " " .. canon(m.lhs)] = m.desc or ""
        end
    end
    return out
end

-- Pre-prep snapshots, keyed by buffer, recorded by the fixtures below.
local BEFORE = {}

-- What parley ADDED to `buf`, as { canon(lhs) = desc }.
--
-- #214 BR-39: this used to filter by `m.desc:lower():find("parley")`. 46 of 81
-- registry entries carry a desc with no "parley" in it ("Create New Chat",
-- "Delete selected chat", …); they happen to all be non-buffer_local today,
-- which is the ONLY reason that oracle worked, and nothing asserted it. A
-- hand-rolled keymap with no desc — precisely the leak the guard exists to
-- catch — was invisible to it. Diffing a before/after snapshot depends on no
-- convention at all: whatever appeared is parley's, by construction.
local function parley_maps(buf)
    local before = BEFORE[buf] or {}
    local out = {}
    for key, desc in pairs(keymap_snapshot(buf)) do
        if before[key] == nil then
            out[key:match("^%S+ (.*)$")] = desc
        end
    end
    return out
end

-- A real markdown buffer, prepped through the production path. C1 lived here:
-- the chat-only spec could not see the review skill's hand-rolled installs.
-- `suffix` lands BEFORE the .md so a caller can build a real `*.parley-journal.md`
-- sidecar name; appending the random id after it silently produced an ordinary
-- markdown file and the sidecar assertion passed for the wrong reason.
-- The snapshot must be taken on a buffer parley has NOT touched. `:edit` fires
-- BufEnter, which preps the buffer, so a snapshot taken after it already
-- contains parley's maps and the diff comes back half-empty. Create the buffer
-- detached, snapshot, and only then show it and prep.
local function detached_buffer(path, lines)
    vim.fn.writefile(lines, path)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_name(buf, path)
    BEFORE[buf] = keymap_snapshot(buf)
    vim.api.nvim_win_set_buf(0, buf)
    return buf
end

local function prepped_markdown(suffix)
    local dir = parley.config.chat_dir
    vim.fn.mkdir(dir, "p")
    local path = dir .. "/doc-" .. math.random(1e6) .. (suffix or "") .. ".md"
    local buf = detached_buffer(path, { "# doc", "", "some prose" })
    parley.setup_markdown_keymaps(buf)
    return buf, path
end

-- A real chat buffer, prepped through the production path.
local function prepped_chat()
    local dir = parley.config.chat_dir
    vim.fn.mkdir(dir, "p")
    local path = dir .. "/2026-03-01-agree-" .. math.random(1e6) .. ".md"
    local buf = detached_buffer(path, { "# topic: agree", "- file: agree.md", "---", "", "💬: hi" })
    parley.prep_chat(buf, path)
    return buf, path
end

local function cleanup(buf, path)
    BEFORE[buf] = nil
    parley._prepared_bufs[buf] = nil
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    vim.fn.delete(path)
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
        for k in pairs(reg.feature_gated) do known[canon(k)] = true end

        local leaked = {}
        for lhs, desc in pairs(parley_maps(buf)) do
            if not known[lhs] then leaked[#leaked + 1] = lhs .. " (" .. desc .. ")" end
        end
        cleanup(buf, path)
        assert.same({}, leaked)
    end)

    -- BR-39: the docs bless feature-gated maps as a third category, but the
    -- closed list did not know about them — so turning on a documented opt-in
    -- reported its own map as a leak.
    it("no leaks with the opt-in spell typeahead switched on", function()
        setup({ chat_spell = { enable = true, typeahead = true } })
        local buf, path = prepped_chat()

        local known = {}
        for _, e in ipairs(reg.entries) do
            for _, k in ipairs(reg.resolve_keys(e, parley.config) or {}) do known[canon(k)] = true end
        end
        for k in pairs(reg.native_overrides) do known[canon(k)] = true end
        for k in pairs(reg.feature_gated) do known[canon(k)] = true end

        local leaked = {}
        for lhs, desc in pairs(parley_maps(buf)) do
            if not known[lhs] then leaked[#leaked + 1] = lhs .. " (" .. desc .. ")" end
        end
        cleanup(buf, path)
        assert.same({}, leaked)
    end)

    it("and the feature-gated key really is absent until the feature is on", function()
        setup()
        local buf, path = prepped_chat()
        local live = parley_maps(buf)
        cleanup(buf, path)
        assert.is_nil(live[canon("<CR>")],
            "the spell <CR> map is installed even though typeahead ships off")
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

    -- The README used to promise "every feature stays reachable as a :Parley*
    -- command". It is not true — 8 registry entries have no command, including
    -- chat_drill_in (<M-q>) — and the test that "verified" it hand-picked four
    -- names that happen to exist, which is an allowlist, not a check (#214 I1).
    -- The README now names these four specifically, so pin exactly those and
    -- let the explicit-binding tests below carry the general recovery story.
    it("the commands the README names by name exist", function()
        setup({ default_keymaps = false })
        local buf, path = prepped_chat()
        local cmds = vim.api.nvim_get_commands({})
        cleanup(buf, path)
        local readme = table.concat(vim.fn.readfile("README.md"), "\n")
        local named = {}
        for name in readme:gmatch(":(Parley%a+)") do named[name] = true end
        local missing = {}
        for name in pairs(named) do
            if not cmds[name] then missing[#missing + 1] = name end
        end
        table.sort(missing)
        assert.same({}, missing)
    end)

    -- Without this the switch is a one-way door: it would override the user's
    -- own setup{} choices too, so nothing could ever be bound back.
    it("a key the user sets explicitly survives the switch", function()
        setup({
            default_keymaps = false,
            chat_shortcut_drill_in = { modes = { "n" }, shortcut = "<M-q>" },
        })
        local buf, path = prepped_chat()
        local live = parley_maps(buf)
        cleanup(buf, path)
        assert.is_truthy(live[canon("<M-q>")], "an explicitly configured key was suppressed")
        -- and nothing else came along for the ride
        assert.is_nil(live[canon("<C-g><C-g>")], "the default set came back too")
        assert.is_nil(live[canon("<M-i>")], "the default set came back too")
    end)

    it("and the help float shows exactly the key that survived", function()
        setup({
            default_keymaps = false,
            chat_shortcut_drill_in = { modes = { "n" }, shortcut = "<M-q>" },
        })
        local shown = {}
        for _, line in ipairs(reg.help_lines("chat", parley.config)) do
            if line:find("<M-q>", 1, true) then shown.drill = true end
            if line:find("<C-g><C-g>", 1, true) then shown.respond = true end
        end
        assert.is_true(shown.drill == true, "help omits the key that IS bound")
        assert.is_nil(shown.respond, "help advertises a key the switch removed")
    end)

    -- The switch is sampled at INSTALL time, and `_prepared_bufs` makes that
    -- sample permanent per buffer. So "reversible" is true for buffers opened
    -- after the flip and false for ones already open — state the real rule and
    -- test both halves, rather than testing only the half that flatters it.
    it("re-enabling binds buffers opened AFTER the flip", function()
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

    it("but a buffer already prepared keeps the keymaps it was prepared with", function()
        setup()
        local buf, path = prepped_chat()
        assert.is_truthy(parley_maps(buf)[canon("<M-q>")], "fixture did not bind")

        -- flip the switch under an OPEN buffer and re-run prep
        setup({ default_keymaps = false })
        parley.prep_chat(buf, path)

        local live = parley_maps(buf)
        cleanup(buf, path)
        assert.is_truthy(live[canon("<M-q>")],
            "documented behaviour: an open buffer is not re-prepared, so its "
            .. "keymaps survive the flip until it is reopened")
    end)
end)

-- #214 C1: the same agreement, on the buffer type where the shadow installs
-- lived. `default_keymaps = false` left <C-g>ve/<M-o>/<M-CR> bound here, and a
-- `shortcut = ""` disable raised on every BufEnter, because the review skill
-- installed from raw config instead of through resolve_keys.
describe("markdown buffers obey the same registry contract (#214 C1)", function()
    it("no leaks — every markdown map is registry-derived", function()
        setup()
        local buf, path = prepped_markdown()

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

    it("no ghosts — every resolved markdown-scope key is really mapped", function()
        setup()
        local buf, path = prepped_markdown()
        local live = parley_maps(buf)

        local missing = {}
        for _, e in ipairs(reg.entries) do
            if e.buffer_local and not e.help_only and e.scope == "markdown" then
                for _, k in ipairs(reg.resolve_keys(e, parley.config) or {}) do
                    if not live[canon(k)] then missing[#missing + 1] = e.id .. " => " .. k end
                end
            end
        end
        cleanup(buf, path)
        assert.same({}, missing)
    end)

    it("the review keys are among them", function()
        setup()
        local buf, path = prepped_markdown()
        local live = parley_maps(buf)
        cleanup(buf, path)
        for _, k in ipairs({ "<C-g>ve", "<M-o>", "<M-CR>" }) do
            assert.is_truthy(live[canon(k)], k .. " is not mapped on a markdown buffer")
        end
    end)

    it("default_keymaps = false leaves no parley mapping on a markdown buffer", function()
        setup({ default_keymaps = false })
        local buf, path = prepped_markdown()
        local live = parley_maps(buf)
        cleanup(buf, path)
        assert.same({}, vim.tbl_keys(live))
    end)

    -- The second symptom, and the worse one: this raised on EVERY markdown
    -- BufEnter, not just when the disabled key was pressed.
    it('disabling one review key with shortcut = "" does not raise', function()
        setup({ review_shortcut_edit = { modes = { "n" }, shortcut = "" } })
        local dir = parley.config.chat_dir
        vim.fn.mkdir(dir, "p")
        local path = dir .. "/nocrash-" .. math.random(1e6) .. ".md"
        local buf = detached_buffer(path, { "# doc", "", "prose" })

        local ok, err = pcall(parley.setup_markdown_keymaps, buf)
        local live = parley_maps(buf)
        cleanup(buf, path)
        assert.is_true(ok, "markdown keymap setup raised: " .. tostring(err))
        assert.is_nil(live[canon("<C-g>ve")], "the disabled key is still bound")
        assert.is_truthy(live[canon("<M-o>")], "disabling one key took out its neighbours")
    end)

    -- Journal sidecars must never get review keys (#133 M3) — that rule used to
    -- live in the skill's own install path, so moving the install has to keep it.
    it("a journal sidecar still gets no review keys", function()
        setup()
        local buf, path = prepped_markdown(".md.parley-journal")
        local live = parley_maps(buf)
        cleanup(buf, path)
        for _, k in ipairs({ "<C-g>ve", "<M-o>" }) do
            assert.is_nil(live[canon(k)], k .. " leaked onto a journal sidecar")
        end
    end)
end)

-- #214 BR-41: parley's <CR> map for interview mode used to be GLOBAL, and
-- leaving interview mode did an unconditional vim.keymap.del("i", "<CR>") — so
-- it deleted whatever was there, which for most Neovim users is cmp/blink's
-- accept key. `del` cannot tell "mine" from "theirs"; a feature map scoped to a
-- buffer shadows and unshadows instead of destroying.
describe("interview <CR> does not destroy the user's map (#214 BR-41)", function()
    local interview = require("parley.interview")

    local function user_cr_map()
        for _, m in ipairs(vim.api.nvim_get_keymap("i")) do
            if m.lhs == "<CR>" and m.desc == "user's own accept key" then return m end
        end
    end

    after_each(function()
        pcall(vim.keymap.del, "i", "<CR>")
        interview._keymap_bufs = {}
    end)

    it("leaves a pre-existing global <CR> map intact across enter/exit", function()
        vim.keymap.set("i", "<CR>", "<Ignore>", { desc = "user's own accept key" })
        assert.is_truthy(user_cr_map(), "fixture did not install")

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(buf)
        interview.setup_keymap(buf)
        interview.remove_keymap()

        assert.is_truthy(user_cr_map(),
            "leaving interview mode deleted the user's own global <CR> map")
        vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("installs buffer-locally, so it shadows rather than replaces", function()
        vim.keymap.set("i", "<CR>", "<Ignore>", { desc = "user's own accept key" })
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(buf)
        interview.setup_keymap(buf)

        local found
        for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "i")) do
            if m.lhs == "<CR>" then found = m end
        end
        assert.is_truthy(found, "interview <CR> is not buffer-local")
        assert.is_truthy(user_cr_map(), "the global map was clobbered at install time")

        interview.remove_keymap()
        vim.api.nvim_buf_delete(buf, { force = true })
    end)
end)

-- #214 BR-38: `default_keymaps` is SAMPLED at three sites, and each is a place
-- the decision becomes durable state. Two are buffer-local and guarded by
-- `_prepared_bufs` (rule: governs buffers prepared after the flip). The third,
-- `register_global`, had no teardown at all — so `setup()` then
-- `setup({ default_keymaps = false })` left 43 global mappings live, and the
-- Done-when's own procedure (":map shows no parley mapping") failed in the most
-- natural way to try the switch. Measured desc-independently.
describe("the master switch is reversible for GLOBAL maps too (#214 BR-38)", function()
    local function global_snapshot()
        local out = {}
        for _, mode in ipairs(MODES) do
            for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
                out[mode .. " " .. canon(m.lhs)] = m.desc or ""
            end
        end
        return out
    end

    local function added_globals(before)
        local out = {}
        for key, desc in pairs(global_snapshot()) do
            if before[key] == nil then out[#out + 1] = key .. " :: " .. desc end
        end
        table.sort(out)
        return out
    end

    it("a fresh setup with the switch off installs no global map", function()
        local before = global_snapshot()
        setup({ default_keymaps = false })
        assert.same({}, added_globals(before))
    end)

    it("re-running setup with the switch off REVOKES the previous global maps", function()
        local before = global_snapshot()
        setup()
        assert.is_true(#added_globals(before) > 0, "fixture installed nothing to revoke")

        setup({ default_keymaps = false })
        assert.same({}, added_globals(before))
    end)

    it("and turning it back on reinstates them", function()
        local before = global_snapshot()
        setup({ default_keymaps = false })
        assert.same({}, added_globals(before))

        setup()
        assert.is_true(#added_globals(before) > 0, "globals did not come back")
    end)

    it("a key the user rebound after setup is not revoked", function()
        setup()
        -- user takes the key over afterwards, with their own description
        vim.keymap.set("n", "<C-g>c", "<Ignore>", { desc = "user's own mapping" })

        setup({ default_keymaps = false })

        local mine = vim.fn.maparg("<C-g>c", "n", false, true)
        assert.are.equal("user's own mapping", mine and mine.desc,
            "revoking parley's globals deleted a mapping the user had replaced")
        pcall(vim.keymap.del, "n", "<C-g>c")
    end)
end)
