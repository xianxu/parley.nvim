local M = {}

local function button_specs(tags)
    local all_active = true
    local none_active = true
    for _, tag in ipairs(tags) do
        if tag.enabled then
            none_active = false
        else
            all_active = false
        end
    end

    local buttons = {
        { text = "ALL", kind = "action", label = "all", active = all_active },
        { text = "NONE", kind = "action", label = "none", active = none_active },
    }
    for _, tag in ipairs(tags) do
        table.insert(buttons, {
            text = "[" .. tag.label .. "]",
            kind = "facet",
            label = tag.label,
            enabled = tag.enabled,
        })
    end
    return buttons
end

local function segment_for(button, row, byte_start, byte_end, cell_start, cell_end)
    return {
        kind = button.kind,
        label = button.label,
        enabled = button.enabled,
        active = button.active,
        row = row,
        byte_start = byte_start,
        byte_end = byte_end,
        cell_start = cell_start,
        cell_end = cell_end,
    }
end

function M.build(tags, content_width, text_ops)
    local width = math.max(1, content_width)
    local lines = { " " }
    local segments = {}
    local row_has_segment = false

    local function display_width(text, start_cell)
        return text_ops.width(text, start_cell or 0)
    end

    local function append_text(text)
        local row = #lines - 1
        local line = lines[#lines]
        local byte_start = #line
        local cell_start = display_width(line)
        lines[#lines] = line .. text
        return row, byte_start, #lines[#lines], cell_start, cell_start + display_width(text, cell_start)
    end

    local function append_segment(button, text)
        local row, byte_start, byte_end, cell_start, cell_end = append_text(text)
        table.insert(segments, segment_for(button, row, byte_start, byte_end, cell_start, cell_end))
        row_has_segment = true
    end

    local function next_row()
        table.insert(lines, " ")
        row_has_segment = false
    end

    local function append_split(button)
        local units = text_ops.units(button.text)
        local unit_index = 1
        while unit_index <= #units do
            local chunk = ""
            local line_width = display_width(lines[#lines])

            while unit_index <= #units do
                local unit = units[unit_index]
                local candidate = chunk .. unit
                local candidate_width = display_width(candidate, line_width)
                if chunk ~= "" and line_width + candidate_width > width then
                    break
                end
                chunk = candidate
                unit_index = unit_index + 1
                if line_width + candidate_width > width then
                    break
                end
            end

            append_segment(button, chunk)
            if unit_index <= #units then
                next_row()
            end
        end
    end

    for index, button in ipairs(button_specs(tags)) do
        local gap = index == 1 and "" or (index == 3 and "  " or " ")
        local line_width = display_width(lines[#lines])
        local prefix = row_has_segment and gap or ""
        local prefix_width = display_width(prefix, line_width)
        local whole_width = display_width(button.text, line_width + prefix_width)

        if line_width + prefix_width + whole_width <= width then
            if prefix ~= "" then
                append_text(prefix)
            end
            append_segment(button, button.text)
        else
            if row_has_segment then
                next_row()
            end
            line_width = display_width(lines[#lines])
            whole_width = display_width(button.text, line_width)
            if line_width + whole_width <= width then
                append_segment(button, button.text)
            else
                append_split(button)
            end
        end
    end

    return { lines = lines, segments = segments, height = #lines }
end

function M.hit(model, row0, cell0)
    for _, segment in ipairs(model.segments) do
        if segment.row == row0 and cell0 >= segment.cell_start and cell0 < segment.cell_end then
            return segment
        end
    end
    return nil
end

return M
