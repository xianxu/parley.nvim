-- Filesystem integration: v4 manifest/body files in a portable temporary folder.
-- Briefs are task context, without behavior flags or editorial ordering.
local loaded, brief = pcall(require, "parley.skills.review.brief")
local dir
local function write(path, text)
    vim.fn.writefile(vim.split(text, "\n", { plain = true }), path)
end
local function manifest(members)
    write(dir .. "/export.json", vim.json.encode({
        schema = "ariadne/universal-review-export", version = 4, members = members,
    }))
end
local function member(name)
    return { role = "brief", name = name, path = "briefs/" .. name .. ".md" }
end

describe("review.brief", function()
    it("provides the brief module", function()
        assert.is_true(loaded, tostring(brief))
    end)
    before_each(function()
        dir = vim.fn.tempname()
        vim.fn.mkdir(dir .. "/briefs", "p")
        manifest({ member("zeta"), member("alpha") })
        write(dir .. "/briefs/zeta.md", "---\nname: zeta\n---\nZeta body.\n\n---\n\nEnd.")
        write(dir .. "/briefs/alpha.md", "---\nname: alpha\n---\nAlpha body.")
    end)
    after_each(function()
        vim.fn.delete(dir, "rf")
    end)

    it("lists manifest order and ignores unexported files", function()
        write(dir .. "/briefs/stray.md", "---\nname: stray\n---\nStray.")
        assert.are.same({ "zeta", "alpha" }, brief.list(dir))
    end)
    it("loads only name and body, preserving body fences", function()
        local value, err = brief.load(dir, "zeta")
        assert.is_nil(err)
        assert.are.same({ name = "zeta", body = "Zeta body.\n\n---\n\nEnd." }, value)
    end)
    it("assembles each brief as named task context in manifest order", function()
        local text, err = brief.context(dir)
        assert.is_nil(err)
        assert.is_truthy(text:find("## zeta\nZeta body.", 1, true))
        assert.is_truthy(text:find("## alpha\nAlpha body.", 1, true))
        assert.is_true(text:find("## zeta", 1, true) < text:find("## alpha", 1, true))
    end)
    it("refuses missing, unknown and unsafe names", function()
        for _, name in ipairs({ "../export", "stray", "", "Alpha" }) do
            local value, err = brief.load(dir, name)
            assert.is_nil(value)
            assert.is_truthy(err)
        end
        vim.fn.delete(dir .. "/briefs/alpha.md")
        local value, err = brief.load(dir, "alpha")
        assert.is_nil(value)
        assert.is_truthy(err)
        assert.is_nil(brief.context(dir))
    end)
    it("refuses non-name frontmatter rather than inferring flags", function()
        for _, header in ipairs({ "name: wrong", "name: alpha\nscope: whole-doc",
            "name: alpha\nfrontier: on", "name: alpha\ndeletions: apply",
            "name: alpha\norder: 1", "name: alpha\nname: alpha", "name: alpha\nother: x" }) do
            write(dir .. "/briefs/alpha.md", "---\n" .. header .. "\n---\nBody.")
            local value, err = brief.load(dir, "alpha")
            assert.is_nil(value, header)
            assert.is_truthy(err, header)
        end
    end)
    it("refuses invalid manifests and retired metadata", function()
        for _, changes in ipairs({ { path = "../alpha.md" }, { name = "../alpha" },
            { order = 1 }, { scope = "whole-doc" }, { frontier = "on" }, { deletions = "apply" } }) do
            local row = vim.tbl_extend("force", member("alpha"), changes)
            manifest({ row })
            local names, err = brief.list(dir)
            assert.is_nil(names)
            assert.is_truthy(err)
        end
        manifest({ member("alpha"), member("alpha") })
        assert.is_nil(brief.list(dir))
        write(dir .. "/export.json", "bad json")
        assert.is_nil(brief.list(dir))
    end)
    it("loads all five shipped flagless briefs without an upstream checkout", function()
        local root = vim.fn.getcwd() .. "/lua/parley/skills/review"
        assert.are.same({ "copy-editing", "developmental", "fact-check", "line-editing", "proofreading" }, brief.list(root))
        for _, name in ipairs(brief.list(root)) do
            local value, err = brief.load(root, name)
            assert.is_nil(err)
            local keys = vim.tbl_keys(value)
            table.sort(keys)
            assert.are.same({ "body", "name" }, keys)
            assert.is_true(#value.body > 20)
        end
    end)
end)
