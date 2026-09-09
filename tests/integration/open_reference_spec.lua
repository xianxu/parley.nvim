-- Characterisation + target tests for the reference-opening chain (#225).
--
-- `OpenFileUnderCursor` has historically had TWO chains — one for markdown
-- buffers (`M.open_chat_reference`) and one for chat buffers, inline in the
-- command. They are not duplicates: four capabilities live in exactly one of
-- them (issue #225 measures them). These tests pin each capability in the
-- buffer type that has it today, so the extraction that unifies the chains
-- cannot silently drop an arm.

local tmp_dir = vim.fn.tempname() .. "-parley-open-ref"
local chat_dir = tmp_dir .. "/chats"
local src_root = tmp_dir .. "/src"
local docs_dir = tmp_dir .. "/docs"
vim.fn.mkdir(chat_dir, "p")
vim.fn.mkdir(src_root, "p")
vim.fn.mkdir(docs_dir, "p")

local parley = require("parley")
parley.setup({
    chat_dir = chat_dir,
    state_dir = tmp_dir .. "/state",
    src_root = src_root,
    providers = {},
    api_keys = {},
})

-- Build a real chat file (timestamp name + headers, so `not_chat` returns nil).
local function write_chat(basename, body)
    local path = chat_dir .. "/" .. basename
    local lines = {
        "---",
        "topic: Fixture",
        "file: " .. basename,
        "model: test-model",
        "provider: openai",
        "---",
        "",
        "💬: hello",
        "",
        "🤖:[Agent] hi",
    }
    for _, l in ipairs(body or {}) do
        table.insert(lines, l)
    end
    vim.fn.writefile(lines, path)
    return path
end

local function write_markdown(basename, body)
    local path = docs_dir .. "/" .. basename
    vim.fn.writefile(body, path)
    return path
end

-- Open `path` in the current window, put the cursor on the line whose text is
-- `needle`, at column `col` (1-indexed), then run OpenFileUnderCursor with
-- `vim.cmd` and `open_buf` spied. Returns { opened = <open_buf arg>, cmds = {} }.
local function open_at(path, needle, col)
    vim.cmd("silent! %bwipeout!")
    vim.cmd("edit " .. vim.fn.fnameescape(path))
    local buf = vim.api.nvim_get_current_buf()
    local target
    for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
        if line == needle then
            target = i
            break
        end
    end
    assert(target, "fixture line not found: " .. needle)
    vim.api.nvim_win_set_cursor(0, { target, (col or 1) - 1 })

    local rec = { cmds = {}, opened = nil, warnings = {} }
    local real_cmd, real_open, real_warn = vim.cmd, parley.open_buf, parley.logger.warning
    vim.cmd = function(c)
        table.insert(rec.cmds, tostring(c))
    end
    parley.open_buf = function(p)
        rec.opened = p
    end
    parley.logger.warning = function(msg)
        table.insert(rec.warnings, tostring(msg))
    end
    local ok, err = pcall(parley.cmd.OpenFileUnderCursor)
    vim.cmd, parley.open_buf, parley.logger.warning = real_cmd, real_open, real_warn
    assert(ok, err)
    return rec
end

local function joined(cmds)
    return table.concat(cmds, "\n")
end

-- On macOS $TMPDIR is a symlink (/tmp -> /private/tmp), and which form comes
-- back depends on whether the path went through `nvim_buf_get_name`. Compare
-- resolved paths so the tests are not asserting on that accident.
local function same_path(expected, actual)
    assert.equals(vim.fn.resolve(expected or ""), vim.fn.resolve(actual or ""))
end

describe("reference opening: the three-valued contract", function()
    -- Migrated from tests/unit/open_chat_reference_spec.lua, which drove
    -- `M.open_chat_reference` — the markdown-only chain the extraction deleted.
    it("a wrapped @@chat-file@@ reference opens and reports \"opened\"", function()
        local chat = write_chat("2026-03-24.11-00-00.010_wrapped.md")
        local line = "@@" .. chat .. "@@"
        local md = write_markdown("wrapped.md", { "# Doc", "", line })

        local opened
        local real_open = parley.open_buf
        parley.open_buf = function(path) opened = path end
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(buf, md)
        local outcome = parley._open_reference_under_cursor(buf, line, 1, false)
        parley.open_buf = real_open

        assert.equals("opened", outcome)
        same_path(chat, opened)
    end)
end)

describe("reference opening: capabilities that live in only one chain", function()
    it("D1 — a src: link opens, in markdown", function()
        local target = src_root .. "/lib/thing.lua"
        vim.fn.mkdir(src_root .. "/lib", "p")
        vim.fn.writefile({ "-- target" }, target)

        local line = "see [thing](src:/lib/thing.lua) here"
        local md = write_markdown("d1.md", { "# Doc", "", line })
        local rec = open_at(md, line, 12)

        same_path(target, rec.opened)
    end)

    it("D2 — the @@path: topic form opens, in markdown", function()
        local chat = write_chat("2026-03-24.11-00-00.001_d2.md")
        local line = "@@" .. chat .. ": Some Topic"
        local md = write_markdown("d2.md", { "# Doc", "", line })
        local rec = open_at(md, line, 3)

        same_path(chat, rec.opened)
    end)

    it("D3 — a bare chat filename resolves against the chat roots, in markdown", function()
        local chat = write_chat("2026-03-24.11-00-00.003_d3.md")
        local line = "@@2026-03-24.11-00-00.003_d3.md@@"
        local md = write_markdown("d3.md", { "# Doc", "", line })
        local rec = open_at(md, line, 3)

        same_path(chat, rec.opened)
    end)

    it("D4 — a directory reference opens in Explore, in chat", function()
        local dir = tmp_dir .. "/somedir"
        vim.fn.mkdir(dir, "p")
        local line = "@@" .. dir .. "/@@"
        local chat = write_chat("2026-03-24.11-00-00.004_d4.md", { "", line })
        local rec = open_at(chat, line, 3)

        assert.is_truthy(joined(rec.cmds):match("Explore"))
        assert.is_truthy(joined(rec.cmds):match(vim.pesc(dir)))
    end)

    -- The NEGATIVE half, and the one that matters most: the Spec calls D4 "the
    -- one that must NOT be flattened", and without this the `is_chat` gate can
    -- be deleted with the whole suite staying green. Asserted by mutation.
    it("D4 — a directory reference does NOT Explore in a markdown buffer", function()
        local dir = tmp_dir .. "/somedir3"
        vim.fn.mkdir(dir, "p")
        local line = "@@" .. dir .. "/@@"
        local md = write_markdown("d4-negative.md", { "# Doc", "", line })
        local rec = open_at(md, line, 3)

        assert.is_nil(joined(rec.cmds):match("Explore"))
        assert.is_nil(rec.opened)
        -- It is a recognised reference we could not open, so it reports and
        -- must not degrade into a gf attempt on a directory.
        assert.is_truthy(table.concat(rec.warnings, "\n"):match("not found"))
    end)

    it("D4 — the directory Explore prefers the other window in a two-split layout", function()
        local dir = tmp_dir .. "/somedir2"
        vim.fn.mkdir(dir, "p")
        local line = "@@" .. dir .. "/@@"
        local chat = write_chat("2026-03-24.11-00-00.005_d4b.md", { "", line })

        vim.cmd("silent! %bwipeout!")
        vim.cmd("only")
        vim.cmd("edit " .. vim.fn.fnameescape(chat))
        vim.cmd("vsplit")
        vim.cmd("wincmd h")
        local origin_win = vim.api.nvim_get_current_win()
        local buf = vim.api.nvim_get_current_buf()
        local target
        for i, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
            if l == line then target = i break end
        end
        vim.api.nvim_win_set_cursor(0, { target, 2 })

        local cmds = {}
        local real_cmd = vim.cmd
        vim.cmd = function(c) table.insert(cmds, tostring(c)) end
        local ok, err = pcall(parley.cmd.OpenFileUnderCursor)
        local landed_win = vim.api.nvim_get_current_win()
        vim.cmd = real_cmd
        vim.cmd("only")
        assert(ok, err)

        assert.is_truthy(table.concat(cmds, "\n"):match("Explore"))
        assert.are_not.equals(origin_win, landed_win)
    end)
end)

describe("reference opening: the inline [🌿:…](file) arm", function()
    -- The one member of the tri-state conversion with no test through the
    -- chain (#225 round 4 I3). `try_open_inline_branch_link` went from
    -- true|false to "opened"|"failed"|nil in this window, and the bug the gap
    -- hid is specific: had the success arm returned nil, the chain would keep
    -- walking, reach the @@ step, answer "none", and the caller would run
    -- ResolveRefOrGotoFile AFTER open_buf had already navigated — two
    -- navigations per keypress, with a green suite.
    for _, bt in ipairs({ "chat", "markdown" }) do
        it("opens the linked chat and stops there, in " .. bt, function()
            local target = write_chat("2026-03-24.18-00-00.001_inline-" .. bt .. ".md")
            local line = "as shown in [🌿:the child](" .. target .. ") above"
            local origin = bt == "chat"
                and write_chat("2026-03-24.18-10-00.001_inline-src-" .. bt .. ".md", { "", line })
                or write_markdown("inline-src-" .. bt .. ".md", { "# Doc", "", line })

            local gf_calls = 0
            local real = parley.cmd.ResolveRefOrGotoFile
            parley.cmd.ResolveRefOrGotoFile = function() gf_calls = gf_calls + 1 end
            local rec = open_at(origin, line, 20)
            parley.cmd.ResolveRefOrGotoFile = real

            same_path(target, rec.opened)
            -- "opened" is terminal. A nil here would fall through to gf on top
            -- of a navigation that already happened.
            assert.equals(0, gf_calls)
        end)
    end

    it("a missing inline target reports and does not fall through", function()
        local line = "see [🌿:gone](2026-01-01.00-00-00.998_nope.md) here"
        local chat = write_chat("2026-03-24.18-20-00.001_inline-missing.md", { "", line })

        local gf_calls = 0
        local real = parley.cmd.ResolveRefOrGotoFile
        parley.cmd.ResolveRefOrGotoFile = function() gf_calls = gf_calls + 1 end
        local rec = open_at(chat, line, 8)
        parley.cmd.ResolveRefOrGotoFile = real

        assert.is_nil(rec.opened)
        assert.equals(0, gf_calls)
        assert.is_truthy(table.concat(rec.warnings, "\n"):match("not found"))
    end)
end)

describe("reference opening: the @@ forms", function()
    it("a path containing an @ survives", function()
        -- Chat's chain was greedy (`^@@(.+)@@`) and markdown's was not
        -- (`^@@%s*([^@]+)@@`). Adopting markdown's wholesale silently made
        -- `@@/tmp/a@b/c.md@@` unopenable — a fifth divergence, resolved the
        -- wrong way and not tabulated with the other four (#225 review).
        local weird_dir = tmp_dir .. "/a@b"
        vim.fn.mkdir(weird_dir, "p")
        local target = weird_dir .. "/c.md"
        vim.fn.writefile({ "# c" }, target)

        local line = "@@" .. target .. "@@"
        local chat = write_chat("2026-03-24.16-00-00.001_at.md", { "", line })
        local rec = open_at(chat, line, 3)

        same_path(target, rec.opened)
    end)

    it("a line carrying two references is not swallowed whole", function()
        -- The guard on the greedy branch: `@@x@@ and @@y@@` must not resolve
        -- to the path `x@@ and @@y`.
        local target = write_chat("2026-03-24.16-00-00.002_two-a.md")
        local other = write_chat("2026-03-24.16-00-00.003_two-b.md")
        local line = "@@" .. target .. "@@ and @@" .. other .. "@@"
        local chat = write_chat("2026-03-24.16-00-00.004_two.md", { "", line })
        local rec = open_at(chat, line, 3)

        same_path(target, rec.opened)
    end)
end)

describe("reference opening: the union, in chat buffers", function()
    -- The operator's release surface is chat (#225, 2026-09-08): markdown is
    -- experimental ariadne-stack polish. All three of these worked in markdown
    -- and NOT in chat, which is to say the omissions were all on the side that
    -- ships.

    it("D1 — a src: link opens, in chat", function()
        local target = src_root .. "/lib/chat_thing.lua"
        vim.fn.mkdir(src_root .. "/lib", "p")
        vim.fn.writefile({ "-- target" }, target)

        local line = "see [thing](src:/lib/chat_thing.lua) here"
        local chat = write_chat("2026-03-24.12-00-00.001_u1.md", { "", line })
        local rec = open_at(chat, line, 13)

        same_path(target, rec.opened)
    end)

    it("D2 — the @@path: topic form opens, in chat", function()
        local target = write_chat("2026-03-24.12-00-00.002_u2-target.md")
        local line = "@@" .. target .. ": Some Topic"
        local chat = write_chat("2026-03-24.12-00-00.003_u2.md", { "", line })
        local rec = open_at(chat, line, 3)

        same_path(target, rec.opened)
    end)

    it("D3 — a bare chat filename resolves instead of creating a duplicate", function()
        -- The old chat chain did not resolve bare names, so `filereadable`
        -- failed, the timestamp pattern matched, and it CREATED a second empty
        -- chat beside the one being referenced. Assert the existing file is
        -- opened, and that nothing new appeared.
        local target = write_chat("2026-03-24.12-00-00.004_u3-target.md")
        local before = #vim.fn.glob(chat_dir .. "/*.md", false, true)

        local line = "@@2026-03-24.12-00-00.004_u3-target.md@@"
        local chat = write_chat("2026-03-24.12-00-00.005_u3.md", { "", line })
        local rec = open_at(chat, line, 3)

        same_path(target, rec.opened)
        assert.equals(before + 1, #vim.fn.glob(chat_dir .. "/*.md", false, true))
    end)
end)

describe("reference opening: the fall-through to gf", function()
    local function with_resolve_spy(fn)
        local calls = 0
        local real = parley.cmd.ResolveRefOrGotoFile
        parley.cmd.ResolveRefOrGotoFile = function() calls = calls + 1 end
        local ok, err = pcall(fn)
        parley.cmd.ResolveRefOrGotoFile = real
        assert(ok, err)
        return calls
    end

    it("a plain word falls through, in chat", function()
        local line = "just some ordinary prose here"
        local chat = write_chat("2026-03-24.13-00-00.001_gf.md", { "", line })
        local calls, rec
        calls = with_resolve_spy(function() rec = open_at(chat, line, 12) end)

        assert.equals(1, calls)
        assert.is_nil(rec.opened)
        assert.same({}, rec.warnings)
    end)

    it("a plain word falls through, in markdown", function()
        local line = "just some ordinary prose here"
        local md = write_markdown("gf.md", { "# Doc", "", line })
        local calls, rec
        calls = with_resolve_spy(function() rec = open_at(md, line, 12) end)

        assert.equals(1, calls)
        assert.is_nil(rec.opened)
    end)

    it("a recognised reference whose file is missing reports and does NOT fall through", function()
        -- "failed", not "none". Handing gf a path we already know is absent
        -- would trade a precise diagnostic for a vague one.
        local line = "🌿: 2026-01-01.00-00-00.999_gone.md: Vanished"
        local chat = write_chat("2026-03-24.13-00-00.002_missing.md", { "", line })
        local calls, rec
        calls = with_resolve_spy(function() rec = open_at(chat, line, 5) end)

        assert.equals(0, calls)
        assert.is_truthy(table.concat(rec.warnings, "\n"):match("not found"))
    end)
end)

describe("open_buf prefers the other split", function()
    -- BR-6 moved this logic into `focus_other_split`; the review noted the
    -- CALL SITE was left unpinned — reverting open_buf to open in the current
    -- window would have kept the suite green. The netrw arm exercises the
    -- helper, not open_buf's use of it.
    it("opens in the other window when the tab has exactly two", function()
        local target = write_chat("2026-03-24.17-00-00.001_split.md")
        local origin = write_chat("2026-03-24.17-00-00.002_origin.md")

        vim.cmd("silent! %bwipeout!")
        vim.cmd("only")
        vim.cmd("edit " .. vim.fn.fnameescape(origin))
        vim.cmd("vsplit")
        vim.cmd("wincmd h")
        local origin_win = vim.api.nvim_get_current_win()

        parley.open_buf(target)
        local landed_win = vim.api.nvim_get_current_win()
        local landed_name = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
        vim.cmd("only")

        assert.are_not.equals(origin_win, landed_win)
        same_path(target, landed_name)
    end)

    it("stays in the current window when ChatFinder asked for it", function()
        local target = write_chat("2026-03-24.17-00-00.003_finder.md")
        local origin = write_chat("2026-03-24.17-00-00.004_finder-origin.md")

        vim.cmd("silent! %bwipeout!")
        vim.cmd("only")
        vim.cmd("edit " .. vim.fn.fnameescape(origin))
        vim.cmd("vsplit")
        vim.cmd("wincmd h")
        local origin_win = vim.api.nvim_get_current_win()

        parley.open_buf(target, true)
        local landed_win = vim.api.nvim_get_current_win()
        vim.cmd("only")

        assert.equals(origin_win, landed_win)
    end)
end)

describe("reference opening: one fall-through, one owner per key", function()
    it("the gf fall-through has exactly one call site", function()
        -- The whole point of the extraction: appending the fall-through to each
        -- chain would have been two copies, and the divergence #225 removes is
        -- exactly what two copies grow back into.
        local src = table.concat(vim.fn.readfile("lua/parley/init.lua"), "\n")
        local body = src:match("M%.cmd%.OpenFileUnderCursor = function%(%)(.-)\nend\n")
        assert.is_truthy(body, "could not locate OpenFileUnderCursor")
        local n = select(2, body:gsub("ResolveRefOrGotoFile", ""))
        assert.equals(1, n)
    end)

    it("<M-o> is open_file and <M-s> is the skill picker", function()
        local reg = require("parley.keybinding_registry")
        local function keys(id)
            for _, e in ipairs(reg.entries) do
                if e.id == id then return reg.resolve_keys(e, parley.config) end
            end
        end
        assert.same({ "<M-o>", "<C-g>o" }, keys("open_file"))
        assert.same({ "<M-s>" }, keys("review_menu"))
    end)
end)

describe("reference opening: the fall-through reaches artifact resolution", function()
    -- The delegation tests above stub `ResolveRefOrGotoFile` and so prove only
    -- that it is called. This one lets the whole production chain run —
    -- `parse_ref_at_cursor` -> `run_resolve` (argv construction, the default
    -- runner, JSON decode) -> `dispatch_resolve_result` -> `open_buf` — and
    -- fakes the ONE thing that must not happen for real: the subprocess.
    --
    -- #225 BR-3: the first version replaced `artifact_ref.run_resolve` itself,
    -- so test flow and production flow shared no boundary. `vim.system` IS the
    -- boundary. (`goto_ref_at_cursor` also now accepts `opts.runner`, which is
    -- the same seam one level up, reachable for callers that have an opts
    -- table; `OpenFileUnderCursor` does not, hence faking the OS call here.)
    it("an ariadne artifact ref under the cursor resolves and opens", function()
        local target = docs_dir .. "/000015-something.md"
        vim.fn.writefile({ "# issue" }, target)

        local line = "as decided in #15, we ship it"
        local chat = write_chat("2026-03-24.15-00-00.001_ref.md", { "", line })

        vim.cmd("silent! %bwipeout!")
        vim.cmd("edit " .. vim.fn.fnameescape(chat))
        local buf = vim.api.nvim_get_current_buf()
        local target_line
        for i, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
            if l == line then target_line = i break end
        end
        assert(target_line, "fixture line not found")
        vim.api.nvim_win_set_cursor(0, { target_line, 16 })

        local spawned, opened
        local real_system, real_open = vim.system, parley.open_buf
        vim.system = function(argv, _opts, on_complete)
            spawned = table.concat(argv, " ")
            on_complete({
                stdout = vim.json.encode({ files = { { path = target, kind = "issue" } } }),
                code = 0,
                stderr = "",
            })
            return { wait = function() end }
        end
        parley.open_buf = function(path) opened = path end
        local ok, err = pcall(parley.cmd.OpenFileUnderCursor)
        vim.wait(200, function() return opened ~= nil end)
        vim.system, parley.open_buf = real_system, real_open
        assert(ok, err)

        assert.is_truthy(spawned, "no subprocess was attempted")
        assert.is_truthy(spawned:match("resolve"), "argv is not an sdlc resolve: " .. spawned)
        assert.is_truthy(spawned:match("#15"), "argv does not carry the ref: " .. spawned)
        same_path(target, opened)
    end)
end)

describe("reference opening: landing mode follows the destination", function()
    -- A chat reference is somewhere you went to WRITE; a gf destination is
    -- source you went to READ. The split is the policy, so both halves assert.
    local function open_from_insert(path, needle, col, resolve_stub)
        vim.cmd("silent! %bwipeout!")
        vim.cmd("edit " .. vim.fn.fnameescape(path))
        local buf = vim.api.nvim_get_current_buf()
        local target
        for i, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
            if l == needle then target = i break end
        end
        assert(target, "fixture line not found: " .. needle)
        vim.api.nvim_win_set_cursor(0, { target, col - 1 })

        local cmds = {}
        local real_cmd, real_open, real_mode = vim.cmd, parley.open_buf, vim.api.nvim_get_mode
        local real_resolve = parley.cmd.ResolveRefOrGotoFile
        vim.cmd = function(c) table.insert(cmds, tostring(c)) end
        parley.open_buf = function() end
        vim.api.nvim_get_mode = function() return { mode = "i", blocking = false } end
        if resolve_stub then parley.cmd.ResolveRefOrGotoFile = resolve_stub end
        local ok, err = pcall(parley.cmd.OpenFileUnderCursor)
        -- `startinsert` is scheduled, so the spy has to outlive the callback.
        -- Restoring first is why the first version of this test saw nothing.
        vim.wait(50, function() return false end)
        vim.cmd, parley.open_buf, vim.api.nvim_get_mode = real_cmd, real_open, real_mode
        parley.cmd.ResolveRefOrGotoFile = real_resolve
        assert(ok, err)
        return table.concat(cmds, "\n")
    end

    -- Parameterised over BOTH buffer types on purpose. The landing-mode
    -- unification was a SIXTH silently-resolved divergence: markdown used to
    -- return before the shared `startinsert` tail, so `<M-o>` from insert in a
    -- markdown doc landed in normal. It conforms to the stated policy, so the
    -- resolution is right — but it was found by the fifth review round rather
    -- than by a red test, because every landing case drove a chat buffer.
    -- Differences should be discovered here, not in review (#225 round 3).
    local buffer_types = {
        { name = "chat", make = function(n, body) return write_chat(n .. ".md", body) end },
        { name = "markdown", make = function(n, body)
            return write_markdown(n .. ".md", vim.list_extend({ "# Doc", "" }, body))
        end },
    }

    for _, bt in ipairs(buffer_types) do
        it("a reference restores insert, in " .. bt.name, function()
            local target = write_chat("2026-03-24.14-00-00.001_land-" .. bt.name .. ".md")
            local line = "@@" .. target .. "@@"
            local origin = bt.make("2026-03-24.14-10-00.001_land-from-" .. bt.name, { "", line })

            local cmds = open_from_insert(origin, line, 3)
            assert.is_truthy(cmds:match("startinsert"), "no startinsert in " .. bt.name)
            assert.is_nil(cmds:match("stopinsert"))
        end)

        it("the gf fall-through lands in normal, in " .. bt.name, function()
            local line = "just some ordinary prose here"
            local origin = bt.make("2026-03-24.14-20-00.001_land-gf-" .. bt.name, { "", line })

            local cmds = open_from_insert(origin, line, 12, function() end)
            assert.is_truthy(cmds:match("stopinsert"), "no stopinsert in " .. bt.name)
            assert.is_nil(cmds:match("startinsert"))
        end)
    end
end)
