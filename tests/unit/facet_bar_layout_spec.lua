local layout = require("parley.facet_bar_layout")

local ascii_ops = {
    width = function(text)
        return #text
    end,
    units = function(text)
        local units = {}
        for index = 1, #text do
            table.insert(units, text:sub(index, index))
        end
        return units
    end,
}

local tabstop_ops = {
    units = ascii_ops.units,
    width = function(text, start_cell)
        local cell = start_cell or 0
        local start = cell
        for index = 1, #text do
            if text:sub(index, index) == "\t" then
                cell = cell + (8 - (cell % 8))
            else
                cell = cell + 1
            end
        end
        return cell - start
    end,
}

local function injected_ops(unit_widths)
    local injected = {}
    for unit in pairs(unit_widths) do
        table.insert(injected, unit)
    end
    table.sort(injected, function(left, right)
        return #left > #right
    end)

    local function units(text)
        local result = {}
        local byte = 1
        while byte <= #text do
            local matched
            for _, unit in ipairs(injected) do
                if text:sub(byte, byte + #unit - 1) == unit then
                    matched = unit
                    break
                end
            end

            if matched then
                table.insert(result, matched)
                byte = byte + #matched
            else
                local first = text:byte(byte)
                local length = first < 0x80 and 1 or (first < 0xE0 and 2 or (first < 0xF0 and 3 or 4))
                table.insert(result, text:sub(byte, byte + length - 1))
                byte = byte + length
            end
        end
        return result
    end

    return {
        units = units,
        width = function(text)
            local width = 0
            for _, unit in ipairs(units(text)) do
                width = width + (unit_widths[unit] or 1)
            end
            return width
        end,
    }
end

describe("facet bar layout", function()
    it("builds the canonical one-row model with semantic spans", function()
        local model = layout.build({
            { label = "alpha", enabled = true },
            { label = "beta", enabled = false },
        }, 40, ascii_ops)

        assert.same({ " ALL NONE  [alpha] [beta]" }, model.lines)
        assert.equals(1, model.height)
        assert.same({
            {
                kind = "action",
                label = "all",
                active = false,
                row = 0,
                byte_start = 1,
                byte_end = 4,
                cell_start = 1,
                cell_end = 4,
            },
            {
                kind = "action",
                label = "none",
                active = false,
                row = 0,
                byte_start = 5,
                byte_end = 9,
                cell_start = 5,
                cell_end = 9,
            },
            {
                kind = "facet",
                label = "alpha",
                enabled = true,
                row = 0,
                byte_start = 11,
                byte_end = 18,
                cell_start = 11,
                cell_end = 18,
            },
            {
                kind = "facet",
                label = "beta",
                enabled = false,
                row = 0,
                byte_start = 19,
                byte_end = 25,
                cell_start = 19,
                cell_end = 25,
            },
        }, model.segments)
    end)

    it("marks ALL and NONE active only for their complete states", function()
        local all = layout.build({
            { label = "alpha", enabled = true },
            { label = "beta", enabled = true },
        }, 40, ascii_ops)
        local none = layout.build({
            { label = "alpha", enabled = false },
            { label = "beta", enabled = false },
        }, 40, ascii_ops)

        assert.is_true(all.segments[1].active)
        assert.is_false(all.segments[2].active)
        assert.is_false(none.segments[1].active)
        assert.is_true(none.segments[2].active)
    end)

    it("hits each button by zero-based display cell and misses whitespace", function()
        local model = layout.build({
            { label = "alpha", enabled = true },
            { label = "beta", enabled = false },
        }, 40, ascii_ops)

        assert.equals("all", layout.hit(model, 0, 1).label)
        assert.equals("none", layout.hit(model, 0, 8).label)
        assert.equals("alpha", layout.hit(model, 0, 12).label)
        assert.equals("beta", layout.hit(model, 0, 24).label)

        for _, cell in ipairs({ 0, 4, 9, 10, 18, 25 }) do
            assert.is_nil(layout.hit(model, 0, cell))
        end
        assert.is_nil(layout.hit(model, 1, 1))
    end)

    it("moves an intact button without carrying its old group gap", function()
        local model = layout.build({
            { label = "alpha", enabled = true },
        }, 13, ascii_ops)

        assert.same({ " ALL NONE", " [alpha]" }, model.lines)
        assert.same({
            row = 1,
            byte_start = 1,
            byte_end = 8,
            cell_start = 1,
            cell_end = 8,
        }, {
            row = model.segments[3].row,
            byte_start = model.segments[3].byte_start,
            byte_end = model.segments[3].byte_end,
            cell_start = model.segments[3].cell_start,
            cell_end = model.segments[3].cell_end,
        })
    end)

    it("splits an overwide button maximally across three rows", function()
        local model = layout.build({
            { label = "abcdefghijklmnop", enabled = false },
        }, 9, ascii_ops)

        assert.same({
            " ALL NONE",
            " [abcdefg",
            " hijklmno",
            " p]",
        }, model.lines)
        assert.equals(4, model.height)
        assert.equals(5, #model.segments)

        for index = 3, 5 do
            local segment = model.segments[index]
            assert.equals("facet", segment.kind)
            assert.equals("abcdefghijklmnop", segment.label)
            assert.is_false(segment.enabled)
            assert.equals(segment, layout.hit(model, segment.row, segment.cell_start))
            assert.is_nil(layout.hit(model, segment.row, 0))
        end
    end)

    it("records multibyte byte spans separately from display-cell spans", function()
        local ops = injected_ops({ ["界"] = 2 })
        local model = layout.build({ { label = "界", enabled = true } }, 40, ops)
        local facet = model.segments[3]

        assert.same({ " ALL NONE  [界]" }, model.lines)
        assert.equals(11, facet.byte_start)
        assert.equals(16, facet.byte_end)
        assert.equals(11, facet.cell_start)
        assert.equals(15, facet.cell_end)
        assert.equals(facet, layout.hit(model, 0, 13))
        assert.is_nil(layout.hit(model, 0, 15))
    end)

    it("measures contextual-width units from their actual starting cell", function()
        local model = layout.build({ { label = "a\tb", enabled = true } }, 18, tabstop_ops)
        local facet = model.segments[3]

        assert.same({ " ALL NONE  [a\tb]" }, model.lines)
        assert.equals(11, facet.cell_start)
        assert.equals(18, facet.cell_end)
        assert.equals(facet, layout.hit(model, 0, 17))
        assert.is_nil(layout.hit(model, 0, 18))
    end)

    it("keeps every injected extended grapheme unit indivisible", function()
        local fixtures = {
            { name = "combining", unit = "é", width = 1 },
            { name = "ZWJ", unit = "👩‍💻", width = 2 },
            { name = "regional flag", unit = "🇺🇸", width = 2 },
            { name = "emoji modifier", unit = "👍🏽", width = 2 },
            { name = "keycap", unit = "1️⃣", width = 2 },
            { name = "Indic", unit = "क्ष", width = 1 },
        }

        for _, fixture in ipairs(fixtures) do
            local row_width = fixture.width + 1
            local model = layout.build(
                { { label = fixture.unit, enabled = true } },
                row_width,
                injected_ops({ [fixture.unit] = fixture.width })
            )
            local facet_segments = {}
            for _, segment in ipairs(model.segments) do
                if segment.kind == "facet" then
                    table.insert(facet_segments, segment)
                end
            end

            assert.same({ " [", " " .. fixture.unit, " ]" }, {
                model.lines[#model.lines - 2],
                model.lines[#model.lines - 1],
                model.lines[#model.lines],
            }, fixture.name)
            assert.equals(3, #facet_segments, fixture.name)
            assert.equals(fixture.unit, facet_segments[2].label, fixture.name)
            assert.equals(fixture.width + 1, facet_segments[2].cell_end, fixture.name)
            assert.equals(facet_segments[2], layout.hit(model, facet_segments[2].row, 1), fixture.name)
        end
    end)

    it("emits a first unit wider than the usable row alone", function()
        local emoji = "👩‍💻"
        local model = layout.build(
            { { label = emoji, enabled = true } },
            2,
            injected_ops({ [emoji] = 2 })
        )

        assert.same({ " [", " " .. emoji, " ]" }, {
            model.lines[#model.lines - 2],
            model.lines[#model.lines - 1],
            model.lines[#model.lines],
        })
        local emoji_segment = model.segments[#model.segments - 1]
        assert.equals(1, emoji_segment.cell_start)
        assert.equals(3, emoji_segment.cell_end)
    end)

    it("normalizes nonpositive content width to one", function()
        local tags = { { label = "x", enabled = true } }

        assert.same(layout.build(tags, 1, ascii_ops), layout.build(tags, 0, ascii_ops))
    end)
end)
