-- Integration tests for lua/parley/discovery/init.lua (RegistryBuilder)
--
-- Composes the effective registry for the current parley mode:
--   global      → base only
--   repo        → base ∪ local(repo_root)
--   super-repo  → base ∪ union(local over members), deduped (base wins ties)
-- and performs the multi-root MERGE: repo-relative locate globs are expanded
-- across [repo_root] + members; absolute globs pass through unchanged.
--
-- Mode context is INJECTED ({repo_root, super_repo_members}) so the tests do
-- not depend on real cwd.

local builder = require("parley.discovery")
local base = require("parley.discovery.base")
local config = require("parley.config")

local function names_of(reg)
    local n = reg:names()
    table.sort(n)
    return n
end

local function base_names()
    local n = {}
    for _, d in ipairs(base.descriptors) do
        table.insert(n, d.name)
    end
    table.sort(n)
    return n
end

local function write_type(dir, file, type_value)
    vim.fn.mkdir(dir, "p")
    vim.fn.writefile({ "---", "type: " .. type_value, "---" }, dir .. "/" .. file)
end

describe("discovery.build — global mode", function()
    it("returns the base registry only (no repo_root)", function()
        local reg = builder.build({})
        assert.are.same(base_names(), names_of(reg))
    end)
end)

describe("discovery.build — repo mode", function()
    local root = vim.fn.tempname() .. "-parley-builder-repo"

    before_each(function()
        write_type(root, "x.md", "widget")
        write_type(root, "y.md", "gadget")
    end)
    after_each(function()
        vim.fn.delete(root, "rf")
    end)

    it("is base ∪ local(repo_root)", function()
        local reg = builder.build({ repo_root = root })
        local want = base_names()
        table.insert(want, "widget")
        table.insert(want, "gadget")
        table.sort(want)
        assert.are.same(want, names_of(reg))
    end)

    it("expands repo-relative locate globs under repo_root", function()
        local reg = builder.build({ repo_root = root })
        -- issue's repo-relative glob becomes <repo_root>/<glob>
        assert.are.same({ root .. "/" .. config.issues_dir .. "/*.md" }, reg:get("issue").locate)
    end)

    it("passes absolute globs (global chat_dir) through unchanged", function()
        local reg = builder.build({ repo_root = root })
        -- chat carries repo_chat_dir (relative, expanded) + chat_dir (absolute, passthrough)
        local chat_locate = reg:get("chat").locate
        local found_abs = false
        for _, g in ipairs(chat_locate) do
            if g == config.chat_dir .. "/*.md" then
                found_abs = true
            end
        end
        assert.is_true(found_abs, "absolute chat_dir glob should pass through: " .. vim.inspect(chat_locate))
    end)
end)

describe("discovery.build — super-repo mode", function()
    local m1 = vim.fn.tempname() .. "-parley-builder-m1"
    local m2 = vim.fn.tempname() .. "-parley-builder-m2"

    before_each(function()
        write_type(m1, "a.md", "widget")
        write_type(m1, "b.md", "gadget")
        write_type(m2, "c.md", "widget") -- duplicate across members → once
        write_type(m2, "d.md", "chat") -- collides with a BASE name → base wins
    end)
    after_each(function()
        vim.fn.delete(m1, "rf")
        vim.fn.delete(m2, "rf")
    end)

    it("unions local over members, deduping by name", function()
        local reg = builder.build({
            super_repo_members = { { path = m1, name = "m1" }, { path = m2, name = "m2" } },
        })
        local want = base_names()
        table.insert(want, "widget")
        table.insert(want, "gadget")
        table.sort(want)
        assert.are.same(want, names_of(reg))
    end)

    it("base wins ties: a member's `type: chat` does not shadow the base chat", function()
        local reg = builder.build({
            super_repo_members = { { path = m1, name = "m1" }, { path = m2, name = "m2" } },
        })
        -- base chat is frontmatter_present; a local would be frontmatter type=chat
        assert.are.equal("frontmatter_present", reg:get("chat").matcher.kind)
    end)

    it("expands repo-relative globs across all members", function()
        local reg = builder.build({
            super_repo_members = { { path = m1, name = "m1" }, { path = m2, name = "m2" } },
        })
        assert.are.same({
            m1 .. "/" .. config.issues_dir .. "/*.md",
            m2 .. "/" .. config.issues_dir .. "/*.md",
        }, reg:get("issue").locate)
    end)
end)
