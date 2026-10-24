-- PURE policy over a single Markdown structural snapshot. No editor APIs.
local M = {}
local values = require("parley.skills.review.collaboration_value")
local retired = { "presentation", "presentation-mode", "process-instruction", "processing-instruction", "processing-mode" }
local retired_set = {}
for _, key in ipairs(retired) do retired_set[key] = true end
local unread = "frontmatter could not be read, so any legacy mode keys in it were not read"
local function trim(s)
    local first, last = 1, #s
    while first <= last and s:sub(first, first):match("%s") do first = first + 1 end
    while last >= first and s:sub(last, last):match("%s") do last = last - 1 end
    return s:sub(first, last)
end
local function normalized(s)
    return trim((trim(s:lower()):gsub("%s+", " "):gsub("%s*%([^()]*%)$", "")))
end
local function quote(s)
    return '"' .. s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\t", "\\t"):gsub("\r", "\\r") .. '"'
end

function M.scan(lines, facts)
    local scan = { sections = {}, headings = facts.headings, tags = {}, misplaced = {}, notices = {},
        row_section = {}, legacy_comments = {}, facts = facts, work = #lines }
    local function notice(s) scan.notices[#scan.notices + 1] = s end
    local whole, names, wanted = false, {}, {}
    local evidence = facts.legacy_evidence
    if not facts.legacy_read then evidence = values.evidence(lines) end
    if not evidence then notice(unread)
    else
        local cm = evidence.collaboration
        if type(cm) == "string" then
            if cm == "chat" then
                whole = true
                notice("collaboration-mode: chat is a legacy key; read as @@chat@@ for the whole document")
            elseif cm == "" then notice("collaboration-mode is empty or malformed; ignored")
            else notice("collaboration-mode: " .. cm .. " is retired and ignored: one collaborative mode applies") end
        elseif type(cm) == "table" then
            notice("collaboration-mode map is a legacy key; its chat sections are read as @@chat@@")
            if cm.default == "chat" then whole = true
            elseif cm.default ~= nil then notice("collaboration-mode map default: " .. cm.default .. " is retired and ignored") end
            names = cm.chat or {}
            if type(names) == "string" then names = { names } end
        end
        local found = {}
        for _, key in ipairs(retired) do if evidence.fields[key] then found[#found + 1] = key end end
        if #found > 0 then notice("retired keys ignored: " .. table.concat(found, ", ")) end
    end
    local nonascii, nonascii_noticed = {}, false
    for _, name in ipairs(names) do
        if name:find("[\128-\255]") then
            nonascii[name] = true
            if not nonascii_noticed then
                notice("legacy chat map entry not matched; use @@chat@@")
                nonascii_noticed = true
            end
        else
            local key = normalized(name)
            wanted[key] = wanted[key] or {}
            wanted[key][#wanted[key] + 1] = name
        end
    end
    local endings, stack, atx = {}, {}, {}
    for index, heading in ipairs(facts.headings) do
        while #stack > 0 and facts.headings[stack[#stack]].level >= heading.level do
            endings[table.remove(stack)] = heading.line - 1
            scan.work = scan.work + 1
        end
        stack[#stack + 1] = index
        if heading.kind == "atx" then atx[heading.line] = true end
        scan.work = scan.work + 1
    end
    for _, index in ipairs(stack) do endings[index] = #lines end
    local tags = {}
    for row = facts.body_start, #lines do
        if trim(lines[row]) == "@@chat@@" and not (facts.literal_lines or facts.code_lines)[row] then
            if atx[row + 1] then tags[row] = true; scan.tags[#scan.tags + 1] = row
            else scan.misplaced[#scan.misplaced + 1] = row end
        end
    end
    if whole then scan.sections[1] = { heading = 0, finish = #lines, source = "legacy-scalar", legacy = true } end
    local matched = {}
    for index, heading in ipairs(facts.headings) do
        local source, legacy = tags[heading.line - 1] and "tag" or nil, false
        local raw = lines[heading.line + 1] or ""
        local comment = raw:match("^<!%-%-%s*(.-)%s*%-%->%s*$")
        if comment then
            local chat, mode = false, false
            for part in (comment .. ";"):gmatch("(.-);") do
                local key, value = part:match("^%s*([^:]+):%s*(.-)%s*$")
                key = key and trim(key)
                if key == "collaboration-mode" or retired_set[key] then
                    mode = true
                    chat = chat or key == "collaboration-mode" and value == "chat"
                end
            end
            if mode then
                scan.legacy_comments[#scan.legacy_comments + 1] = heading.line + 1
                notice(trim(raw) .. " at line " .. (heading.line + 1) .. (chat
                    and " is a legacy key; read as @@chat@@" or " is retired and ignored"))
                if chat then legacy = true; source = source or "legacy-comment" end
            end
        end
        local matches = wanted[normalized(heading.name)]
        if matches then
            if not matches.matched then
                for _, name in ipairs(matches) do matched[name] = true end
                matches.matched = true
            end
            legacy = true
            source = source or "legacy-map"
        end
        if source and not whole then
            scan.sections[#scan.sections + 1] = { heading = heading.line, finish = endings[index], source = source, legacy = legacy }
        end
    end
    for _, name in ipairs(names) do
        if not matched[name] and not nonascii[name] then notice("collaboration-mode map name " .. quote(name) .. " matches no heading") end
    end
    -- Laminar sections: every row and each section enters/leaves this stack once.
    local open, index = {}, 1
    for row = 1, #lines do
        while #open > 0 and open[#open].finish < row do table.remove(open); scan.work = scan.work + 1 end
        while scan.sections[index] and scan.sections[index].heading < row do
            local section = scan.sections[index]
            if section.finish >= row then open[#open + 1] = section end
            index = index + 1
            scan.work = scan.work + 1
        end
        scan.row_section[row] = open[#open]
    end
    return scan
end

local function indent(line)
    local count = 0
    for i = 1, #line do
        local c = line:sub(i, i)
        if c == " " then count = count + 1
        elseif c == "\t" then count = count + 4 - count % 4
        else break end
    end
    return count
end

function M.items(lines, scan)
    local shallow, candidates = {}, {}
    for row, line in ipairs(lines) do
        local section = scan.row_section[row]
        if section and not scan.facts.code_lines[row] then
            local text = line:gsub("^[ \t]*", "")
            if text:match("^%d+%.%s") or section.legacy and text:match("^[%-%*]%s") then
                local depth = indent(line)
                candidates[row] = depth
                shallow[section] = math.min(shallow[section] or depth, depth)
            end
        end
    end
    local items, current, previous, blank, positions = {}, nil, nil, false, {}
    for row, line in ipairs(lines) do
        local section = scan.row_section[row]
        if section ~= previous then current, blank = nil, false end
        local code = scan.facts.code_lines[row]
        if section then
            if trim(line) == "" and not code then blank = true
            elseif candidates[row] == shallow[section] and candidates[row] ~= nil then
                positions[section] = (positions[section] or 0) + 1
                current = { line = row, finish = row, section = section, pos = positions[section], lines = {}, answered = false }
                items[#items + 1] = current
                blank = false
            elseif current and blank and not code and indent(line) <= shallow[section] then current, blank = nil, false
            else blank = false end
            if current and trim(line) ~= "" then
                current.finish = row
                if not code and (line:match("→%s*%[answer%]%([^)]*%)%s*$") or line:match("→%s*done:")) then current.answered = true end
            end
        end
        previous = section
    end
    for _, item in ipairs(items) do
        for row = item.line, item.finish do item.lines[#item.lines + 1] = lines[row] end
    end
    return items
end
return M
