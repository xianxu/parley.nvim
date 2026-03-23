-- parley/notes.lua — note creation operations extracted from init.lua
local M = {}

-- _parley holds the full parley module so we always read M.config, M.logger, etc. dynamically
-- (tests modify M.config directly and also mock M._create_note_file via the init.lua passthrough)
local _parley = nil

M.setup = function(parley)
    _parley = parley
end

-- Internal helper: create a note file with a title and metadata (array of {key, value})
-- NOTE: routes through _parley._create_note_file so tests can mock it via M._create_note_file
M.create_note_file = function(filename, title, metadata, template_content)
    return _parley._create_note_file(filename, title, metadata, template_content)
end

-- Low-level implementation used by the init.lua passthrough M._create_note_file
M._create_note_file_impl = function(filename, title, metadata, template_content)
    local lines = {}

    if template_content then
        -- Generate lines from template_content (string or table), preserving empty lines
        local tlines = {}
        if type(template_content) == "string" then
            -- Split string on newline, keep empty entries
            tlines = vim.split(template_content, "\n", true, false)
        elseif type(template_content) == "table" then
            tlines = template_content
        end
        -- Process each line: replace placeholders
        for _, raw in ipairs(tlines) do
            local ln = raw
            -- Replace title placeholder
            ln = ln:gsub("{{title}}", title)
            -- Replace metadata placeholders
            for _, kv in ipairs(metadata) do
                ln = ln:gsub("{{" .. kv[1]:lower() .. "}}", kv[2])
            end
            table.insert(lines, ln)
        end
    else
        -- Default note format
        table.insert(lines, "# " .. title)
        table.insert(lines, "")
        for _, kv in ipairs(metadata) do
            table.insert(lines, kv[1] .. ": " .. kv[2])
            table.insert(lines, "")
        end
    end

    vim.fn.writefile(lines, filename)
    local buf = _parley.open_buf(filename)
    vim.api.nvim_command("normal! G")
    vim.api.nvim_command("startinsert")
    return buf
end

-- Local helper: try to create a top-level note with {folder} syntax
local function try_create_top_level_note(subject, current_date, template_content)
    if subject == "{}" or subject:match("^%{%}%s+") then
        return nil, "Bare {} is reserved for Note Finder filters and cannot be used during note creation"
    end

    local folder, rest = subject:match("^%{([^{}%s/]+)%}%s+(.+)$")

    if not folder or not rest then
        return nil, nil
    end
    if rest:match("^%b{}%s+") then
        return nil, "Only a single leading {dir} segment is supported during note creation"
    end

    local target_dir = _parley.config.notes_dir .. "/" .. folder
    _parley.helpers.prepare_dir(target_dir)
    local slug = rest:gsub("%s+", "-")
    local filename = target_dir .. "/" .. slug .. ".md"
    local y = string.format("%04d", current_date.year)
    local mon = string.format("%02d", current_date.month)
    local d = string.format("%02d", current_date.day)
    return M.create_note_file(
        filename,
        rest,
        { { "Date", y .. "-" .. mon .. "-" .. d } },
        template_content
    )
end

-- Create default templates in the templates directory
M.create_default_templates = function(template_dir)
    -- Meeting Notes template
    local meeting_template = [[# {{title}}

**Date:** {{date}}
**Week:** {{week}}

## Attendees
-
-

## Agenda
1.
2.

## Notes


## Action Items
- [ ]
- [ ]

## Next Steps

]]

    -- Daily Note template
    local daily_template = [[# {{title}}

**Date:** {{date}}
**Week:** {{week}}

## Today's Goals
- [ ]
- [ ]
- [ ]

## Notes


## Tomorrow's Priorities
-
-

## Reflection

]]

    -- Interview template (for the interview mode feature)
    local interview_template = [[# {{title}}

**Date:** {{date}}
**Week:** {{week}}

:00min Interview started

## Interview Notes


## Key Points


## Follow-up Actions
- [ ]
- [ ]

]]

    -- Basic template
    local basic_template = [[# {{title}}

**Date:** {{date}}
**Week:** {{week}}

]]

    -- Write template files
    vim.fn.writefile(vim.split(meeting_template, "\n"), template_dir .. "/meeting-notes.md")
    vim.fn.writefile(vim.split(daily_template, "\n"), template_dir .. "/daily-note.md")
    vim.fn.writefile(vim.split(interview_template, "\n"), template_dir .. "/interview.md")
    vim.fn.writefile(vim.split(basic_template, "\n"), template_dir .. "/basic.md")
end

-- Create a new note with given subject
M.new_note = function(subject)
    -- Get current date
    local current_date = os.date("*t")
    local year = current_date.year
    local month = current_date.month
    local day = current_date.day

    -- Parse date from subject if provided in one of the formats:
    -- "YYYY-MM-DD subject" or "MM-DD subject" or "DD subject"
    do
        local top_level_note, top_level_note_err = try_create_top_level_note(subject, current_date)
        if top_level_note_err then
            vim.notify(top_level_note_err, vim.log.levels.WARN)
            return nil
        end
        if top_level_note then
            return top_level_note
        end
    end
    local date_pattern1 = "^(%d%d%d%d)%-(%d%d)%-(%d%d)%s+(.+)$" -- YYYY-MM-DD
    local date_pattern2 = "^(%d%d)%-(%d%d)%s+(.+)$" -- MM-DD
    local date_pattern3 = "^(%d%d)%s+(.+)$" -- DD

    local parsed_year, parsed_month, parsed_day, parsed_subject

    if subject:match(date_pattern1) then
        -- Full date format: YYYY-MM-DD subject
        parsed_year, parsed_month, parsed_day, parsed_subject = subject:match(date_pattern1)
        year = tonumber(parsed_year)
        month = tonumber(parsed_month)
        day = tonumber(parsed_day)
        subject = parsed_subject
        _parley.logger.info("Using date from full pattern: " .. year .. "-" .. month .. "-" .. day)
    elseif subject:match(date_pattern2) then
        -- Month-day format: MM-DD subject
        parsed_month, parsed_day, parsed_subject = subject:match(date_pattern2)
        month = tonumber(parsed_month)
        day = tonumber(parsed_day)
        subject = parsed_subject
        _parley.logger.info("Using date from MM-DD pattern: " .. year .. "-" .. month .. "-" .. day)
    elseif subject:match(date_pattern3) then
        -- Day only format: DD subject
        parsed_day, parsed_subject = subject:match(date_pattern3)
        day = tonumber(parsed_day)
        subject = parsed_subject
        _parley.logger.info("Using date from day pattern: " .. year .. "-" .. month .. "-" .. day)
    end

    -- Validate and format date components with fallbacks
    if not month or type(month) ~= "number" then
        month = os.date("*t").month
    end
    if not day or type(day) ~= "number" then
        day = os.date("*t").day
    end
    month = string.format("%02d", month)
    day = string.format("%02d", day)

    -- Create directory structure if it doesn't exist
    local year_dir = _parley.config.notes_dir .. "/" .. year
    local month_dir = year_dir .. "/" .. month

    -- Calculate week number and create week folder
    local date_str = year .. "-" .. month .. "-" .. day
    local week_number = _parley.helpers.get_week_number_sunday_based(date_str)
    if not week_number or type(week_number) ~= "number" then
        week_number = 1
    end
    local week_folder = "W" .. string.format("%02d", week_number)
    local week_dir = month_dir .. "/" .. week_folder

    _parley.helpers.prepare_dir(year_dir)
    _parley.helpers.prepare_dir(month_dir)
    _parley.helpers.prepare_dir(week_dir)

    -- Replace spaces with dashes in subject
    subject = subject:gsub(" ", "-")

    -- Create filename
    local filename = week_dir .. "/" .. day .. "-" .. subject .. ".md"

    -- Create note stub with date and week metadata
    local title = subject:gsub("-", " ")
    local note_date = year .. "-" .. month .. "-" .. day
    return M.create_note_file(filename, title, { { "Date", note_date }, { "Week", week_folder } })
end

-- Create a new note from template with given subject and template content
M.new_note_from_template = function(subject, template_content)
    -- Get current date
    local current_date = os.date("*t")
    local year = current_date.year
    local month = current_date.month
    local day = current_date.day

    -- Parse date from subject if provided in one of the formats (same logic as new_note)
    do
        local top_level_note, top_level_note_err = try_create_top_level_note(subject, current_date, template_content)
        if top_level_note_err then
            vim.notify(top_level_note_err, vim.log.levels.WARN)
            return nil
        end
        if top_level_note then
            return top_level_note
        end
    end

    -- Same date parsing logic as new_note function
    local date_pattern1 = "^(%d%d%d%d)%-(%d%d)%-(%d%d)%s+(.+)$" -- YYYY-MM-DD
    local date_pattern2 = "^(%d%d)%-(%d%d)%s+(.+)$" -- MM-DD
    local date_pattern3 = "^(%d%d)%s+(.+)$" -- DD

    local parsed_year, parsed_month, parsed_day, parsed_subject

    if subject:match(date_pattern1) then
        parsed_year, parsed_month, parsed_day, parsed_subject = subject:match(date_pattern1)
        year = tonumber(parsed_year)
        month = tonumber(parsed_month)
        day = tonumber(parsed_day)
        subject = parsed_subject
        _parley.logger.info("Using date from full pattern: " .. year .. "-" .. month .. "-" .. day)
    elseif subject:match(date_pattern2) then
        parsed_month, parsed_day, parsed_subject = subject:match(date_pattern2)
        month = tonumber(parsed_month)
        day = tonumber(parsed_day)
        subject = parsed_subject
        _parley.logger.info("Using date from MM-DD pattern: " .. year .. "-" .. month .. "-" .. day)
    elseif subject:match(date_pattern3) then
        parsed_day, parsed_subject = subject:match(date_pattern3)
        day = tonumber(parsed_day)
        subject = parsed_subject
        _parley.logger.info("Using date from day pattern: " .. year .. "-" .. month .. "-" .. day)
    end

    -- Validate and format date components with fallbacks
    if not month or type(month) ~= "number" then
        month = os.date("*t").month
    end
    if not day or type(day) ~= "number" then
        day = os.date("*t").day
    end
    month = string.format("%02d", month)
    day = string.format("%02d", day)

    -- Create directory structure (same logic as new_note)
    local year_dir = _parley.config.notes_dir .. "/" .. year
    local month_dir = year_dir .. "/" .. month

    -- Calculate week number and create week folder
    local date_str = year .. "-" .. month .. "-" .. day
    local week_number = _parley.helpers.get_week_number_sunday_based(date_str)
    if not week_number or type(week_number) ~= "number" then
        week_number = 1
    end
    local week_folder = "W" .. string.format("%02d", week_number)
    local week_dir = month_dir .. "/" .. week_folder

    _parley.helpers.prepare_dir(year_dir)
    _parley.helpers.prepare_dir(month_dir)
    _parley.helpers.prepare_dir(week_dir)

    -- Replace spaces with dashes in subject
    subject = subject:gsub(" ", "-")

    -- Create filename
    local filename = week_dir .. "/" .. day .. "-" .. subject .. ".md"

    -- Create note with template content
    local title = subject:gsub("-", " ")
    local note_date = year .. "-" .. month .. "-" .. day
    return M.create_note_file(filename, title, { { "Date", note_date }, { "Week", week_folder } }, template_content)
end

-- Command: prompt user for subject and create a new note
M.cmd_note_new = function()
    -- Prompt user for note subject
    vim.ui.input({ prompt = "Note subject: " }, function(subject)
        if subject and subject ~= "" then
            M.new_note(subject)
        end
    end)
end

-- Command: select a template and prompt for subject, then create a note from template
M.cmd_note_new_from_template = function()
    local template_dir = _parley.config.notes_dir .. "/templates"

    -- Check if template directory exists, create it if not
    if vim.fn.isdirectory(template_dir) == 0 then
        vim.notify("Creating templates directory: " .. template_dir, vim.log.levels.INFO)
        _parley.logger.info("Creating templates directory: " .. template_dir)

        -- Create the templates directory
        vim.fn.mkdir(template_dir, "p")

        -- Create some default templates
        M.create_default_templates(template_dir)

        vim.notify("Templates directory created with default templates", vim.log.levels.INFO)
    end

    -- Get all template files
    local template_files = {}
    local handle = vim.loop.fs_scandir(template_dir)
    if handle then
        local name, type
        repeat
            name, type = vim.loop.fs_scandir_next(handle)
            if name and type == "file" and name:match("%.md$") then
                table.insert(template_files, {
                    filename = name,
                    path = template_dir .. "/" .. name,
                    display = name:gsub("%.md$", ""),
                })
            end
        until not name
    end

    if #template_files == 0 then
        vim.notify("No template files found in: " .. template_dir, vim.log.levels.WARN)
        return
    end

    -- Use float picker to select template
    local items = {}
    for _, tfile in ipairs(template_files) do
        table.insert(items, { display = tfile.display, value = tfile })
    end

    _parley.float_picker.open({
        title = "Select Template",
        items = items,
        anchor = "top",
        on_select = function(item)
            -- Read template lines to preserve blank lines
            local template_lines = vim.fn.readfile(item.value.path)
            -- Prompt for note subject (command-line input)
            local subject = vim.fn.input("Note subject: ")
            -- Cancel if no title provided
            if not subject or subject == "" then
                return
            end
            M.new_note_from_template(subject, template_lines)
        end,
    })
end

return M
