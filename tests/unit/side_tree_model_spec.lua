local model = require("parley.side_tree_model")

-- nodes: path -> { parent = path|nil, tree = bool }; reads are counted.
local function reader(nodes)
    local counter = { reads = 0 }
    counter.read = function(path)
        counter.reads = counter.reads + 1
        return nodes[path]
    end
    return counter
end

local function line(n)
    local nodes = { ["/0"] = { tree = true } }
    for i = 1, n do nodes["/" .. i] = { parent = "/" .. (i - 1), tree = false } end
    return nodes
end

describe("side_tree_model.chain (#391)", function()
    it("returns the parent chain root to leaf, whatever reached it", function()
        local nodes = {
            ["/A"] = { tree = true },
            ["/B1"] = { parent = "/A", tree = true }, ["/B2"] = { parent = "/A", tree = true },
            ["/C1"] = { parent = "/B1" }, ["/C2"] = { parent = "/B2" },
        }
        local r = reader(nodes)
        assert.are.same({ version = 1, paths = { "/A", "/B1", "/C1" }, omitted = 0 }, model.chain("/C1", r.read))
        assert.are.same({ "/A", "/B2", "/C2" }, model.chain("/C2", r.read).paths)
    end)

    it("leaves files outside every tree to the trail", function()
        local r = reader({ ["/plain"] = { tree = false } })
        assert.is_nil(model.chain("/plain", r.read))
        assert.is_nil(model.chain("/unreadable", r.read))
        assert.are.same({ "/root" }, model.chain("/root", reader({ ["/root"] = { tree = true } }).read).paths)
    end)

    it("ends a missing parent, a cycle and an over-deep chain with a marker", function()
        local missing = model.chain("/C", reader({ ["/C"] = { parent = "/gone" } }).read)
        assert.are.same({ version = 1, paths = { "/C" }, omitted = 0, marker = "missing" }, missing)

        local cycle = model.chain("/a", reader({ ["/a"] = { parent = "/b" }, ["/b"] = { parent = "/a" } }).read)
        assert.are.same({ "/b", "/a" }, cycle.paths)
        assert.are.equal("cycle", cycle.marker)
        local self = model.chain("/s", reader({ ["/s"] = { parent = "/s" } }).read)
        assert.are.same({ "/s" }, self.paths)
        assert.are.equal("cycle", self.marker)

        local deep = model.chain("/10", reader(line(10)).read, 3)
        assert.are.same({ "/7", "/8", "/9", "/10" }, deep.paths)
        assert.are.equal("depth", deep.marker)
    end)

    it("reads each ancestor once: depth N costs N+1 reads, 2N costs 2N+1", function()
        for _, n in ipairs({ 8, 16 }) do
            local r = reader(line(n))
            local value = model.chain("/" .. n, r.read)
            assert.are.equal(n + 1, #value.paths)
            assert.are.equal(n + 1, r.reads)
        end
        local r = reader(line(100))
        model.chain("/100", r.read)
        assert.are.equal(model.CAP + 1, r.reads)
    end)

    it("parses top-level frontmatter keys only, resolving parent against the doc's directory", function()
        assert.are.same({ tree = false }, model.parse({ "# no frontmatter", "parent: ../a.md" }, "/r/a.side"))
        assert.are.same({ tree = true, parent = "/r/a.md" },
            model.parse({ "---", "parent: \"../a.md\"", "discussions:", "  - doc: b.side/c.md", "    parent: x.md", "---", "parent: y.md" }, "/r/a.side"))
        assert.are.same({ tree = false, parent = "/abs/p.md" }, model.parse({ "---", "parent: '/abs/p.md'", "---" }, "/r"))
        assert.are.same({ tree = false }, model.parse({ "---", "parent:", "---" }, "/r"))
        assert.are.same({ tree = false }, model.parse({ "---", "parent: a.md" }, "/r"))
    end)
end)
