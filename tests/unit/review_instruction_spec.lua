-- #316: `process-instruction: [mode] free text` — the grammar, the mode
-- expansion (knobs included) and the completion words, over the real modes.
local instruction = require("parley.skills.review.instruction")
local mode = require("parley.skills.review.mode")

local function modes()
    local dir = vim.api.nvim_get_runtime_file("lua/parley/skills/review/modes", false)[1]
    return mode.list(dir)
end

local function names(ms)
    local out = {}
    for _, m in ipairs(ms) do out[#out + 1] = m.name end
    return out
end

describe("instruction.parse", function()
    it("splits leading [names] from the free text", function()
        assert.same({ names = { "copy-edit", "fact-check" }, text = "keep the voice" },
            instruction.parse("[copy-edit][fact-check] keep the voice"))
        assert.same({ names = { "a" }, text = "b [c]" }, instruction.parse("  [a]  b [c] "))
        assert.same({ names = {}, text = "just text" }, instruction.parse("just text"))
        assert.same({ names = {}, text = "" }, instruction.parse(nil))
    end)
end)

describe("instruction.expand", function()
    it("[copy-edit] expands to the copy-editing brief, its knobs, and the addition", function()
        local e = assert(instruction.expand("[copy-edit] keep the voice", modes()))
        assert.same({ "copy-editing" }, names(e.modes))
        assert.equals("keep the voice", e.text)
        local brief = instruction.brief(e.modes, e.text)
        assert.truthy(brief:find("## Review mode: copy-editing\nCopy edit.", 1, true))
        -- copy-editing's knobs: whole-doc, propose-strike, frontier on.
        assert.truthy(brief:find("Scope: edit the whole document", 1, true))
        assert.truthy(brief:find("propose each as a 🤖~old~{new} strike marker", 1, true))
        assert.truthy(brief:find("Reading frontier", 1, true))
        assert.truthy(brief:find("## Operator instruction\nkeep the voice", 1, true))
    end)

    it("no [name] means free-form", function()
        local e = assert(instruction.expand("what do you think?", modes()))
        assert.same({ "free-form" }, names(e.modes))
        assert.falsy(instruction.brief(e.modes, e.text):find("Reading frontier", 1, true))
    end)

    it("several modes add their briefs; the first one's knobs govern", function()
        local e = assert(instruction.expand("[proofreading][copy-editing] x", modes()))
        assert.same({ "proofreading", "copy-editing" }, names(e.modes))
        local brief = instruction.brief(e.modes, e.text)
        assert.truthy(brief:find("## Review mode: copy-editing", 1, true))
        assert.equals(1, select(2, brief:gsub("## How to apply this round", "")))
        local first = e.modes[1]
        assert.truthy(brief:find(mode.directives(first), 1, true))
    end)

    it("refuses an unknown or ambiguous name, naming the known ones", function()
        local e, err = instruction.expand("[nope] x", modes())
        assert.is_nil(e)
        assert.truthy(err:find("[nope] is not a stock prompt", 1, true))
        assert.truthy(err:find("copy-editing", 1, true))
        local _, amb = instruction.resolve({ "x" }, { { name = "xa" }, { name = "xb" } })
        assert.truthy(amb:find("ambiguous", 1, true))
    end)
end)

describe("instruction.complete", function()
    it("offers every mode file's name, closed", function()
        local words = instruction.complete(modes())
        assert.equals(#modes(), #words)
        assert.truthy(vim.tbl_contains(words, "copy-editing]"))
        assert.truthy(vim.tbl_contains(words, "free-form]"))
    end)
end)
