-- #233: the request context is the chat tree in depth-first pre-order, cut at
-- the exchange being submitted. Pure: hand-built parses and a table loader.
local Tree = require("parley.chat_tree")

-- A parsed file: `spec` lists its exchanges and branches in line order, e.g.
-- { "R1", { branch = "a.md" }, "R2" } — a branch after R1 has after_exchange 1.
local function file(spec, parent)
    local parsed = { exchanges = {}, branches = {}, parent_link = parent and { path = parent } or nil }
    for _, entry in ipairs(spec) do
        if type(entry) == "string" then
            parsed.exchanges[#parsed.exchanges + 1] = { question = { content = entry }, answer = { content = entry .. "a" } }
        else
            parsed.branches[#parsed.branches + 1] = { path = entry.branch, after_exchange = #parsed.exchanges }
        end
    end
    return parsed
end

local function deps(files, loads)
    return {
        resolve = function(ref) return "/c/" .. ref end,
        load = function(abs)
            if loads then loads[#loads + 1] = abs end
            return files[abs:gsub("^/c/", "")]
        end,
    }
end

-- The questions the walk emits, in order, for a submission of exchange `cut`
-- of file `name`.
local function walk(files, name, cut, loads)
    local d = deps(files, loads)
    local items = Tree.linearize(Tree.path_up("/c/" .. name, files[name], d), cut, d)
    local out = {}
    for _, item in ipairs(items) do out[#out + 1] = item.exchange.question.content end
    return out, items
end

describe("chat_tree.linearize (#233)", function()
    it("sends an <M-i> aside to the next question in the parent: R1, A1, R2", function()
        local files = {
            ["root.md"] = file({ "R1", { branch = "a.md" }, "R2" }),
            ["a.md"] = file({ "A1" }, "root.md"),
        }
        assert.same({ "R1", "A1", "R2" }, walk(files, "root.md", 2))
    end)

    it("includes a left sibling's whole subtree before the path's branch point", function()
        local files = {
            ["root.md"] = file({ "R1", { branch = "a.md" }, "R2", { branch = "b.md" }, "R3" }),
            ["a.md"] = file({ "A1", { branch = "aa.md" }, "A2" }, "root.md"),
            ["aa.md"] = file({ "AA1" }, "a.md"),
            ["b.md"] = file({ "B1", "B2" }, "root.md"),
        }
        assert.same({ "R1", "A1", "AA1", "A2", "R2", "B1", "B2" }, walk(files, "b.md", 2))
    end)

    it("sends nothing to the right of the cut", function()
        local files = {
            ["root.md"] = file({ "R1", { branch = "b.md" }, { branch = "c.md" }, "R2" }),
            ["b.md"] = file({ "B1", "B2" }, "root.md"),
            ["c.md"] = file({ "C1" }, "root.md"),
        }
        local loads = {}
        assert.same({ "R1", "B1" }, walk(files, "b.md", 1, loads)) -- not B2, C1 or R2
        assert.is_nil(vim.tbl_contains(loads, "/c/c.md") or nil, "a right sibling was read")
    end)

    it("leaves out the children of the exchange being regenerated", function()
        local files = {
            ["root.md"] = file({ "R1", { branch = "a.md" }, "R2" }),
            ["a.md"] = file({ "A1" }, "root.md"),
        }
        assert.same({ "R1" }, walk(files, "root.md", 1))
    end)

    it("emits branches written before the first question ahead of it", function()
        local files = {
            ["root.md"] = file({ { branch = "a.md" }, "R1" }),
            ["a.md"] = file({ "A1" }, "root.md"),
        }
        assert.same({ "A1", "R1" }, walk(files, "root.md", 1))
    end)

    it("marks only the current file's exchanges as current, and names each file", function()
        local files = {
            ["root.md"] = file({ "R1", { branch = "a.md" } }),
            ["a.md"] = file({ "A1" }, "root.md"),
        }
        local _, items = walk(files, "a.md", 1)
        assert.same({ { "/c/root.md", false }, { "/c/a.md", true } },
            vim.tbl_map(function(i) return { i.file, i.current } end, items))
    end)

    -- #352: off the path = from a subtree, an aside or a chat nested under one.
    it("marks subtree items off the path, and the path's files on it", function()
        local files = {
            ["root.md"] = file({ "R1", { branch = "a.md" }, "R2", { branch = "b.md" }, "R3" }),
            ["a.md"] = file({ "A1", { branch = "aa.md" } }, "root.md"),
            ["aa.md"] = file({ "AA1" }, "a.md"),
            ["b.md"] = file({ "B1", { branch = "bb.md" }, "B2" }, "root.md"),
            ["bb.md"] = file({ "BB1" }, "b.md"),
        }
        local _, items = walk(files, "b.md", 2)
        local off = {}
        for _, item in ipairs(items) do off[item.exchange.question.content] = item.off_path == true end
        assert.same({ R1 = false, A1 = true, AA1 = true, R2 = false, B1 = false, BB1 = true, B2 = false }, off)
    end)

    it("emits a file reached twice once, and survives a cycle", function()
        local files = {
            ["root.md"] = file({ "R1", { branch = "a.md" }, { branch = "a.md" }, "R2" }),
            ["a.md"] = file({ "A1", { branch = "root.md" } }, "root.md"),
        }
        assert.same({ "R1", "A1", "R2" }, walk(files, "root.md", 2))
    end)

    it("skips a branch whose file cannot be read", function()
        local files = { ["root.md"] = file({ "R1", { branch = "gone.md" }, "R2" }) }
        assert.same({ "R1", "R2" }, walk(files, "root.md", 2))
    end)
end)

describe("chat_tree.path_up (#233)", function()
    it("stops at a parent that does not link back to the child", function()
        local files = {
            ["grand.md"] = file({ "G1", { branch = "root.md" } }),
            ["root.md"] = file({ "R1" }, "grand.md"), -- links nowhere down to a.md
            ["a.md"] = file({ "A1" }, "root.md"),
        }
        local d = deps(files)
        local path = Tree.path_up("/c/a.md", files["a.md"], d)
        assert.same({ "/c/a.md" }, vim.tbl_map(function(n) return n.file end, path))
    end)

    it("records the branch each ancestor descends through", function()
        local files = {
            ["root.md"] = file({ "R1", { branch = "x.md" }, { branch = "a.md" } }),
            ["a.md"] = file({ "A1" }, "root.md"),
        }
        local path = Tree.path_up("/c/a.md", files["a.md"], deps(files))
        assert.equals(2, path[1].stop_branch)
    end)

    it("stops at the depth cap", function()
        local files = {}
        for i = 0, 30 do
            files["f" .. i .. ".md"] = file({ "Q" .. i, { branch = "f" .. (i + 1) .. ".md" } },
                i > 0 and ("f" .. (i - 1) .. ".md") or nil)
        end
        local path = Tree.path_up("/c/f30.md", files["f30.md"], deps(files))
        assert.equals(21, #path) -- the current file and 20 ancestors
    end)
end)

describe("chat_tree.root and files (#349)", function()
    local function names(list)
        local out = {}
        for _, item in ipairs(list) do out[#out + 1] = item.file:gsub("^/c/", "") end
        return out
    end

    it("finds the root through every linked ancestor", function()
        local files = {
            ["root.md"] = file({ "R1", { branch = "a.md" } }),
            ["a.md"] = file({ "A1", { branch = "aa.md" } }, "root.md"),
            ["aa.md"] = file({ "AA1" }, "a.md"),
        }
        assert.equals("/c/root.md", Tree.root("/c/aa.md", deps(files)))
    end)

    it("makes an orphaned child its own root: the parent no longer lists it", function()
        local files = {
            ["root.md"] = file({ "R1" }),
            ["a.md"] = file({ "A1" }, "root.md"),
        }
        assert.equals("/c/a.md", Tree.root("/c/a.md", deps(files)))
    end)

    it("makes an unloadable file its own root", function()
        assert.equals("/c/gone.md", Tree.root("/c/gone.md", deps({})))
    end)

    it("lists the tree depth-first, each file once, skipping unloadable ones", function()
        local files = {
            ["root.md"] = file({ "R1", { branch = "a.md" }, "R2", { branch = "b.md" }, { branch = "gone.md" } }),
            ["a.md"] = file({ "A1", { branch = "aa.md" }, { branch = "root.md" } }, "root.md"),
            ["aa.md"] = file({ "AA1" }, "a.md"),
            ["b.md"] = file({ "B1" }, "root.md"),
        }
        local list = Tree.files("/c/root.md", deps(files))
        assert.same({ "root.md", "a.md", "aa.md", "b.md" }, names(list))
        assert.equals(files["a.md"], list[2].parsed)
    end)

    it("stops at the depth cap", function()
        local files = {}
        for i = 0, 30 do files["f" .. i .. ".md"] = file({ "Q" .. i, { branch = "f" .. (i + 1) .. ".md" } }) end
        assert.equals(21, #Tree.files("/c/f0.md", deps(files)))
    end)
end)
