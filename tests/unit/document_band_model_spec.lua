local ops = require("parley.display_text")
local function compose(view, paths, width)
    local ok, model = pcall(require, "parley.document_band_model")
    assert.is_true(ok, "shared composition model must exist")
    return model.compose(view, paths and { version = 1, paths = paths, omitted = 0 }, width or 120, ops)
end
local function text(result)
    return result.winbar:gsub("%%#[^#]+#", ""):gsub("%%=", ""):gsub("%%%%", "%%")
end

describe("document band composition", function()
    it("keeps each lock cell first and exactly nine columns", function()
        for _, item in ipairs({ { "free", "free     " }, { "operator", "yours ●  " },
            { "stale", "stale    " }, { "owed", "agent…   " }, { "unknown", "unknown  " },
            { "violated", "stale    " } }) do
            local result = compose({ state = item[1], unsent = true, hl = "Lock", label = "" })
            assert.equals(item[2], text(result))
            assert.equals(9, ops.width(text(result)))
            assert.equals("StatusLine:Lock", result.winhighlight)
        end
    end)
    it("does not invent an unsent dot for an unknown acquisition baseline", function()
        assert.equals("yours    ", text(compose({ state = "operator", unsent = false, hl = "Held" })))
    end)
    it("retains the operator lock colour while showing error or success feedback", function()
        for _, highlight in ipairs({ "DiagnosticError", "DiagnosticOk" }) do
            local result = compose({ state = "operator", unsent = true, hl = "Held",
                feedback = { label = "submit 100% failed", hl = highlight } }, { "/a.md", "/b.md" })
            assert.equals("yours ●   a › b · submit 100% failed", text(result))
            assert.equals("StatusLine:Held", result.winhighlight)
            assert.truthy(result.winbar:find("%#" .. highlight .. "#", 1, true))
            assert.truthy(result.winbar:find("100%%", 1, true))
        end
    end)
    it("reserves a blank lock cell for a plain path and no bar without one", function()
        assert.is_nil(compose({ state = "plain" }).winbar)
        assert.equals("          root", text(compose({ state = "plain" }, { "/root.md" })))
        assert.equals("          a › b", text(compose({ state = "plain" }, { "/a.md", "/b.md" })))
    end)
    it("keeps feedback visible ahead of old trail segments when width is tight", function()
        local result = compose({ state = "free", hl = "Free",
            feedback = { label = "submit failed", hl = "DiagnosticError" } },
            { "/root.md", "/middle.md", "/leaf.md" }, 25)
        assert.truthy(text(result):find("submit failed", 1, true))
        assert.is_true(ops.width(text(result)) <= 25)
    end)
    it("bounds every window width without splitting display units or interpreting percent text", function()
        for width = 1, 90 do
            local result = compose({ state = "operator", unsent = true, hl = "Held",
                feedback = { label = "failure %{2+2}\n界", hl = "DiagnosticError" } },
                { "/root.md", "/界/é.md", "/child%name.md" }, width)
            assert.is_true(ops.width(text(result)) <= width, "width " .. width)
            assert.is_nil(text(result):find("[\r\n]"))
            assert.is_nil(result.winbar:find("[^%%]%%{2%+2}"))
        end
    end)
end)
