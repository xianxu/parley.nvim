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

-- #214 BR-50: the global-map baseline must come from a state parley has not
-- touched. Taken inside a test it already contained ~13 earlier setup() calls,
-- so a global map planted OUTSIDE the registry sat in the baseline too and the
-- "installs no global map" assertion stayed green over it. Captured at module
-- load — plenary runs each spec file in its own nvim, so this is pristine.
local function global_snapshot()
    local out = {}
    for _, mode in ipairs(MODES) do
        for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
            out[mode .. " " .. canon(m.lhs)] = m.desc or ""
        end
    end
    return out
end

local PRISTINE_GLOBALS = global_snapshot()

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

-- #214 BR-41/BR-47/N2. These drive `enter()`/`exit()` — the transitions a user
-- actually triggers with <C-n>i / <C-n>I — not the `setup_keymap`/`remove_keymap`
-- sub-steps the fix edited. Driving the sub-step cannot observe the state the
-- transition carries, and that is exactly what hid N2: entering interview mode
-- put a libuv timer handle in `_state`, so every later `refresh_state` (i.e.
-- opening any chat file) raised "Cannot deepcopy object of type userdata".
--
-- The defect is teardown, not scope: `vim.keymap.del` cannot
-- tell "mine" from "theirs", so leaving interview mode deleted whatever owned
-- the <CR> slot. Narrowing to buffer-local (round 9) MOVED that collision onto
-- spell typeahead's own buffer-local <CR> and confined session state to one
-- buffer. The map is global again — matching the session state it serves, and
-- the base_cr delegation spell already implements — and teardown restores what
-- it shadowed.
describe("interview <CR> restores what it shadowed (#214 BR-41/BR-47)", function()
    local interview = require("parley.interview")
    local spell = require("parley.spell")

    local function global_cr()
        for _, m in ipairs(vim.api.nvim_get_keymap("i")) do
            if m.lhs == "<CR>" then return m end
        end
    end

    after_each(function()
        pcall(interview.exit)
        pcall(vim.keymap.del, "i", "<CR>")
        interview._saved_cr = nil
    end)

    it("a pre-existing global <CR> is restored, not deleted", function()
        vim.keymap.set("i", "<CR>", "<Ignore>", { desc = "user's own accept key" })
        interview.enter()
        assert.are.equal("Insert timestamp on new line in interview mode", global_cr().desc)

        interview.exit()
        local back = global_cr()
        assert.is_truthy(back, "leaving interview mode deleted the user's <CR> map")
        assert.are.equal("user's own accept key", back.desc)
    end)

    it("a user's Lua-callback <CR> survives too", function()
        vim.keymap.set("i", "<CR>", function() return "<CR>" end,
            { expr = true, desc = "user's lua accept key" })
        interview.enter()
        interview.exit()
        local back = global_cr()
        assert.is_truthy(back, "the callback map was lost")
        assert.are.equal("user's lua accept key", back.desc)
    end)

    it("with no previous map, the slot is left clean", function()
        assert.is_nil(global_cr(), "fixture is not clean")
        interview.enter()
        interview.exit()
        assert.is_nil(global_cr(), "interview left its own map behind")
    end)

    it("re-entering does not save our own map as the thing to restore", function()
        vim.keymap.set("i", "<CR>", "<Ignore>", { desc = "user's own accept key" })
        interview.enter()
        interview.enter()   -- re-enter without leaving
        interview.exit()
        assert.are.equal("user's own accept key", global_cr().desc)
    end)

    -- BR-47's measured regression: interview must not destroy parley's OWN
    -- buffer-local <CR>, which is the map that delegates back to it (#134).
    it("spell typeahead's buffer-local <CR> is untouched", function()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(buf)
        spell.attach(buf, { enable = true, typeahead = true, base_cr = interview.cr_keys })

        local function buf_cr()
            for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "i")) do
                if m.lhs == "<CR>" then return m end
            end
        end
        assert.is_truthy(buf_cr(), "fixture did not install spell's map")

        interview.enter()
        interview.exit()

        assert.is_truthy(buf_cr(),
            "interview mode destroyed spell typeahead's <CR> for this buffer")
        vim.api.nvim_buf_delete(buf, { force = true })
    end)

    -- The other half of BR-47: interview mode is session state, so its effect
    -- must not be confined to the buffer it was entered from.
    it("the mapping applies in every buffer, not only where it was entered", function()
        local b1 = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(b1)
        interview.enter()

        local b2 = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(b2)
        assert.is_truthy(global_cr(),
            "interview <CR> does not apply in a buffer opened after entering the mode")

        interview.exit()
        vim.api.nvim_buf_delete(b1, { force = true })
        vim.api.nvim_buf_delete(b2, { force = true })
    end)
end)

-- #214 BR-48, and the fifth finding in the family "docs assert unverified
-- behavior". The README's prose makes claims quantified over sets — "every knob
-- is named in config.lua", "no <leader> key", "every binding is rebindable" —
-- and prose has never had a derived assertion, which is why the family keeps
-- recurring. These derive the set from the source; adding the missing members by
-- hand would fix the instance and leave the rule unpinned.
describe("the README's universal claims are derived, not typed (#214 BR-48)", function()
    local shipped_src = table.concat(vim.fn.readfile("lua/parley/config.lua"), "\n")

    it("every registry config_key is actually named in config.lua", function()
        local missing = {}
        for _, e in ipairs(reg.entries) do
            local leaf = e.config_key:match("([^.]+)$")
            local root = e.config_key:match("^([^.]+)")
            -- a dotted key needs its table AND its leaf present
            local ok = shipped_src:find(root, 1, true) and shipped_src:find(leaf, 1, true)
            if not ok then missing[#missing + 1] = e.id .. " (" .. e.config_key .. ")" end
        end
        table.sort(missing)
        assert.same({}, missing,
            "README says every knob is named in config.lua; these are not")
    end)
end)

-- #214 BR-38: `default_keymaps` is SAMPLED at three sites, and each is where the
-- decision becomes durable state. Two are buffer-local and guarded by
-- `_prepared_bufs`. The third, `register_global`, had no teardown at all — so
-- `setup()` then `setup({ default_keymaps = false })` left 43 global mappings
-- live, and the Done-when's own procedure (":map shows no parley mapping")
-- failed in the most natural way to try the switch.
describe("the master switch is reversible for GLOBAL maps too (#214 BR-38)", function()
    local function added_globals(before)
        local out = {}
        for key, desc in pairs(global_snapshot()) do
            if before[key] == nil then out[#out + 1] = key .. " :: " .. desc end
        end
        table.sort(out)
        return out
    end

    -- Measured against the PRISTINE baseline, so anything setup() installs
    -- globally OUTSIDE the registry shows up here too — which is the leak this
    -- assertion exists for (#214 BR-50).
    it("a fresh setup with the switch off installs no global map", function()
        setup({ default_keymaps = false })
        assert.same({}, added_globals(PRISTINE_GLOBALS))
    end)

    it("re-running setup with the switch off REVOKES the previous global maps", function()
        setup()
        assert.is_true(#added_globals(PRISTINE_GLOBALS) > 0, "fixture installed nothing to revoke")

        setup({ default_keymaps = false })
        assert.same({}, added_globals(PRISTINE_GLOBALS))
    end)

    it("and turning it back on reinstates them", function()
        setup({ default_keymaps = false })
        assert.same({}, added_globals(PRISTINE_GLOBALS))

        setup()
        assert.is_true(#added_globals(PRISTINE_GLOBALS) > 0, "globals did not come back")
    end)

    it("a key the user rebound after setup is not revoked", function()
        setup()
        vim.keymap.set("n", "<C-g>c", "<Ignore>", { desc = "user's own mapping" })

        setup({ default_keymaps = false })

        local mine = vim.fn.maparg("<C-g>c", "n", false, true)
        assert.are.equal("user's own mapping", mine and mine.desc,
            "revoking parley's globals deleted a mapping the user had replaced")
        pcall(vim.keymap.del, "n", "<C-g>c")
    end)
end)

-- #214 N2: the transition must survive the thing that happens right after it.
describe("interview mode's transitions are runnable (#214 N2)", function()
    local interview = require("parley.interview")

    after_each(function()
        pcall(interview.exit)
        pcall(vim.keymap.del, "i", "<CR>")
    end)

    it("refresh_state works while interview mode is on", function()
        setup()
        interview.enter()
        local ok, err = pcall(parley.refresh_state, { last_chat = "x.md" })
        assert.is_true(ok, "refresh_state raised during interview mode: " .. tostring(err))
    end)

    it("opening a chat file while interview mode is on does not raise", function()
        setup()
        interview.enter()
        local ok, err = pcall(function()
            local buf, path = prepped_chat()
            cleanup(buf, path)
        end)
        assert.is_true(ok, "BufEnter -> prep_chat raised during interview mode: " .. tostring(err))
    end)

    it("no libuv handle is parked in the serialisable state", function()
        setup()
        interview.enter()
        local offenders = {}
        for k, v in pairs(parley._state) do
            if type(v) == "userdata" then offenders[#offenders + 1] = k end
        end
        assert.same({}, offenders,
            "_state is deepcopied by refresh_state; a runtime handle there raises")
    end)
end)
