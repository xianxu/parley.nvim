-- #236: every module under lua/ is reachable from a real entry point.
--
-- Walks the static require graph from what loads parley code at all:
--   * `parley` (the plugin), `parley.health` (:checkhealth) and `parley.starter`
--     (the packaged app's launcher, packaging/starter-config/init.lua);
--   * the builtin and optional tools, which tools/init.lua loads BY NAME from
--     BUILTIN_NAMES and OPTIONAL_NAMES (`require("parley.tools.builtin." .. name)`,
--     the one computed require);
--   * whatever packaging/ and scripts/ require: the app launcher and the
--     build scripts load parley modules from outside lua/;
--   * each skill directory, which skill_providers loads with `loadfile`.
-- An edge is a string-literal `require("x")`, `require('x')`, `pcall(require, "x")`
-- or `package.loaded["x"]` read. Every other require in lua/ takes a literal, so
-- the walk is complete for lua/.
--
-- Its LIMIT (ARCH-PURPOSE): it finds orphaned FILES. A module that is required
-- but whose result nobody uses (what discovery was before #236) is reached, and
-- passes. That needs a reader check, not a reachability one.
local arch = require("tests.arch.arch_helper")

local function module_of(file)
    local m = file:gsub("^lua/", ""):gsub("%.lua$", ""):gsub("/init$", ""):gsub("/", ".")
    return m
end

local EDGES = {
    'require%s*%(%s*"([^"]+)"%s*%)', "require%s*%(%s*'([^']+)'%s*%)",
    'pcall%s*%(%s*require%s*,%s*"([^"]+)"', "pcall%s*%(%s*require%s*,%s*'([^']+)'",
    'package%.loaded%["([^"]+)"%]', "package%.loaded%['([^']+)'%]",
}

--- Pure: the modules in `sources` (module -> text) not reached from `entries`.
local function unreached(sources, entries)
    local seen, queue = {}, {}
    for _, e in ipairs(entries) do
        if sources[e] and not seen[e] then seen[e] = true; queue[#queue + 1] = e end
    end
    while #queue > 0 do
        local m = table.remove(queue)
        for _, pat in ipairs(EDGES) do
            for target in sources[m]:gmatch(pat) do
                if sources[target] and not seen[target] then seen[target] = true; queue[#queue + 1] = target end
            end
        end
    end
    local out = {}
    for m in pairs(sources) do if not seen[m] then out[#out + 1] = m end end
    table.sort(out)
    return out
end

local function tree()
    local sources = {}
    for _, file in ipairs(arch.worktree_files({ "lua/**/*.lua" })) do
        sources[module_of(file)] = table.concat(vim.fn.readfile(file), "\n")
    end
    local entries = { "parley", "parley.health", "parley.starter" }
    local tools = require("parley.tools")
    for _, list in ipairs({ tools.BUILTIN_NAMES, tools.OPTIONAL_NAMES }) do
        for _, name in ipairs(list) do entries[#entries + 1] = "parley.tools.builtin." .. name end
    end
    for _, file in ipairs(arch.worktree_files({ "packaging/**/*.lua", "scripts/**/*.lua" })) do
        local text = table.concat(vim.fn.readfile(file), "\n")
        for _, pat in ipairs(EDGES) do
            for target in text:gmatch(pat) do entries[#entries + 1] = target end
        end
    end
    for _, dir in ipairs(vim.fn.globpath("lua/parley/skills", "*/init.lua", false, true)) do
        entries[#entries + 1] = module_of(dir)
    end
    return sources, entries
end

describe("arch: every lua/ module is reachable from an entry point (#236)", function()
    it("finds a planted orphan, and follows every edge form", function()
        local sources = {
            root = 'local a = require("a"); local ok = pcall(require, "b"); local c = package.loaded["c"]',
            a = "require('d')", b = "", c = "", d = "",
            orphan = 'require("a")', -- requiring others does not make it reached
        }
        assert.same({ "orphan" }, unreached(sources, { "root" }))
    end)

    it("leaves no module in lua/ unreached", function()
        local sources, entries = tree()
        assert.is_true(vim.tbl_count(sources) > 100, "selected too few modules: the scan is broken")
        assert.same({}, unreached(sources, entries),
            "an orphaned module: require it from where it is used, or delete it")
    end)
end)
