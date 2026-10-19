local model = require("parley.breadcrumb_model")

local function trail(paths, omitted)
    return { version = 1, paths = paths, omitted = omitted or 0 }
end

local ops = require("parley.display_text")

describe("breadcrumb_model", function()
    it("transitions roots and follows immutably, retaining same-file trails", function()
        local root = model.transition(nil, { kind = "root", path = "/a.md" })
        local followed = model.transition(root, { kind = "follow", path = "/b.md" })
        assert.are.same(trail({ "/a.md" }), root)
        assert.are.same(trail({ "/a.md", "/b.md" }), followed)
        assert.are.same(followed, model.transition(followed, { kind = "follow", path = "/b.md" }))
        assert.are.same(trail({ "/c.md" }), model.transition(followed, { kind = "root", path = "/c.md" }))
        followed.paths[1] = "/changed"
        assert.are.equal("/a.md", root.paths[1])
    end)

    it("rejects malformed values and returns detached accepted values", function()
        local bad = {
            {}, { version = 2, paths = { "/a" }, omitted = 0 },
            trail({}), trail({ "relative" }), trail({ "/bad\npath" }),
            trail({ [1] = "/a", [3] = "/c" }), trail({ "/a", false }),
            trail({ "/a" }, -1), trail({ "/a" }, 0.5),
            trail({ "/" .. string.rep("a", 1024 * 1024) }),
        }
        local excess = {}
        for i = 1, 201 do excess[i] = "/" .. i end
        bad[#bad + 1] = trail(excess)
        for _, value in ipairs(bad) do
            local result, reason = model.validate(value)
            assert.is_nil(result)
            assert.are.equal("string", type(reason))
        end
        local original = trail({ "/a", "/b" })
        assert.is_nil(model.validate(original, "/other"))
        local accepted = assert(model.validate(original, "/b"))
        accepted.paths[1] = "/changed"
        assert.are.equal("/a", original.paths[1])
    end)

    it("bounds generated follow sequences while preserving root and newest path", function()
        local value
        for i = 1, 610 do
            local path = "/" .. (i % 213) .. ".md"
            local old = value and vim.deepcopy(value)
            local next_value = model.transition(value, { kind = i == 1 and "root" or "follow", path = path })
            assert.are.same(old, value)
            assert.are.equal(path, next_value.paths[#next_value.paths])
            assert.are.equal("/1.md", next_value.paths[1])
            assert.is_true(#next_value.paths <= 200)
            assert.is_not_nil(model.validate(next_value))
            value = next_value
        end
        assert.are.equal(410, value.omitted)
        local rejected, reason = model.transition(value, { kind = "follow", path = "/" .. string.rep("x", 1024 * 1024) })
        assert.is_nil(rejected)
        assert.are.equal("string", type(reason))
    end)

    it("strips date and markdown suffix and disambiguates equal parent names", function()
        assert.are.equal("a", model.project(trail({ "/2026-10-16-a.md" }), 100, ops))
        assert.are.equal("root › leaf", model.project(trail({ "/2026-10-16-root.md", "/leaf.md" }), 100, ops))
        assert.are.equal("a/shared/topic › b/shared/topic", model.project(trail({ "/a/shared/topic.md", "/b/shared/topic.md" }), 100, ops))
        assert.are.equal("same › same", model.project(trail({ "/same.md", "/same.md" }), 100, ops))
        assert.are.equal("100% › end", model.project(trail({ "/100%.md", "/end.md" }), 100, ops))
    end)

    it("shows a file's own path below its base as segments (#391)", function()
        local repo = model.path_value("/r/lua/parley/x.lua", "/r")
        assert.are.same({ version = 1, paths = { "/r/lua/parley/x.lua" }, omitted = 0,
            labels = { "lua", "parley", "x.lua" } }, repo)
        assert.are.equal("lua › parley › x.lua", model.project(repo, 100, ops))
        assert.are.equal("README", model.project(model.path_value("/r/README.md", "/r"), 100, ops))
        assert.are.equal("~ › notes › plan", model.project(model.path_value("/h/notes/2026-10-18-plan.md", "/h", "~"), 100, ops))
        assert.are.equal("etc › x", model.project(model.path_value("/etc/x.md", "/"), 100, ops))
        assert.are.equal("a › … › e › f", model.project(model.path_value("/r/a/b/c/d/e/f.md", "/r"), 14, ops))
        assert.is_true(model.visible(model.path_value("/r/README.md", "/r")))
    end)

    it("leads a side-doc tree path that stopped early with its marker (#391)", function()
        local function marked(paths, marker)
            local value = trail(paths)
            value.marker = marker
            return value
        end
        assert.are.equal("? › leaf", model.project(marked({ "/leaf.md" }, "missing"), 100, ops))
        assert.are.equal("↻ › b › a", model.project(marked({ "/b.md", "/a.md" }, "cycle"), 100, ops))
        assert.are.equal("… › p › leaf", model.project(marked({ "/p.md", "/leaf.md" }, "depth"), 100, ops))
    end)

    it("keeps raw names when stripping makes distinct full suffixes identical", function()
        assert.are.equal("/same/2026-10-16-note.md › /same/note.md", model.project(trail({
            "/same/2026-10-16-note.md", "/same/note.md",
        }), 100, ops))
    end)

    it("collapses middle segments, preserves omitted gaps and prioritizes the leaf", function()
        assert.are.equal("root › … › parent › leaf", model.project(trail({ "/root", "/extra-long-middle", "/parent", "/leaf" }), 24, ops))
        assert.are.equal("root › … › parent › leaf", model.project(trail({ "/root", "/parent", "/leaf" }, 2), 100, ops))
        assert.are.equal("…leaf", model.project(trail({ "/root", "/parent", "/leaf" }), 5, ops))
    end)

    it("shortens protected labels before dropping the immediate parent", function()
        assert.are.equal("root › … › veryl… › leaf", model.project(trail({
            "/root", "/extra-long-middle", "/verylongparent", "/leaf",
        }), 24, ops))
        assert.are.equal("long… › pare… › leaf", model.project(trail({
            "/longroot", "/parentlong", "/leaf",
        }), 20, ops))
    end)

    it("shortens an oversized leaf before removing protected ancestors", function()
        assert.are.equal("r… › … › p… › …789leaf", model.project(trail({
            "/root", "/extra-long-middle", "/parent", "/verylongleaf123456789leaf",
        }), 22, ops))
    end)

    it("retains protected Unicode and disambiguating parent context when shortened", function()
        assert.are.equal("根… › … › 親… › 葉", model.project(trail({
            "/根根根", "/extra-long-middle", "/親親親", "/葉",
        }), 18, ops))
        assert.are.equal("a/… › … › b/… › leaf", model.project(trail({
            "/a/same.md", "/extra-long-middle", "/b/same.md", "/leaf",
        }), 20, ops))
    end)

    it("retains complete base-plus-combining units when shortening either end", function()
        assert.equals("…é", model.project(trail({ "/root", "/éééé" }), 2, ops))
        assert.equals("éé… › leaf", model.project(trail({ "/éééé", "/leaf" }), 10, ops))
    end)

    it("obeys generated display budgets without splitting Unicode units", function()
        local examples = {
            trail({ "/root", "/界界界", "/é%leaf" }),
            trail({ "/a/same.md", "/b/same.md", "/long/2026-01-01-wide界.md" }, 3),
            trail({ "/ŕŕŕŕŕŕ", "/middle", "/ṕṕṕṕṕṕ", "/leaf" }),
            trail({ "/root", "/middle", "/parent", "/verylongleaf123456789leaf" }),
        }
        for _, value in ipairs(examples) do
            for budget = 0, 120 do
                local rendered = model.project(value, budget, ops)
                assert.is_true(ops.width(rendered) <= budget)
                assert.is_true(vim.str_utfindex(rendered) >= 0)
                assert.is_nil(rendered:find("\204$"))
            end
        end
    end)
end)
