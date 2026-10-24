-- Thin snapshot integration; pure chat policy and local proposal validation own
-- semantics. Existing invocation/tool owners alone apply effects.
local M = {}
local policy = require('parley.skills.review.chat_policy')

local function positions(lines)
    local starts, offset = {}, 1
    for row, line in ipairs(lines) do starts[row], offset = offset, offset + #line + 1 end
    return starts, offset - 2
end

local function span(plan, first, last)
    if first <= last then plan.protected[#plan.protected + 1] = {first=first,last=last} end
end

-- Literal facts may arrive from separate inline trees. Index their document
-- byte intervals once rather than revisiting every literal for each marker.
local function literal_index(facts, starts, length)
    local intervals={}
    for _,literal in ipairs(facts.literal_ranges)do
        local first=(starts[literal.start_line] or length+1)+literal.start_col
        local last=(starts[literal.end_line] or length+1)+literal.end_col-1
        if first<=last then intervals[#intervals+1]={first=first,last=last} end
    end
    table.sort(intervals,function(a,b)
        if a.first==b.first then return a.last<b.last end
        return a.first<b.first
    end)
    local merged={}
    for _,interval in ipairs(intervals)do
        local previous=merged[#merged]
        if previous and interval.first<=previous.last+1 then previous.last=math.max(previous.last,interval.last)
        else merged[#merged+1]=interval end
    end
    return merged
end

local function intersects(intervals, first, last)
    local low,high=1,#intervals
    while low<=high do
        local middle=math.floor((low+high)/2)
        if intervals[middle].first<=last then low=middle+1 else high=middle-1 end
    end
    local candidate=intervals[high]
    return candidate~=nil and candidate.last>=first
end

function M.resolve(lines)
    local facts, err = require('parley.skills.review.chat_structure').snapshot(lines)
    if not facts then return nil, err end
    if facts.unread_legacy_map then
        return nil, 'frontmatter could not be read, so any legacy mode keys in it were not read; '
            ..'local source mutation refused for the declared collaboration map; use Couch review'
    end
    local scan = policy.scan(lines, facts)
    local starts, length = positions(lines)
    local plan = {scan=scan,lines=lines,starts=starts,length=length,protected={},warnings={},chat={},editable=true}
    for _, notice in ipairs(scan.notices) do plan.warnings[#plan.warnings+1]=notice end
    for _, row in ipairs(scan.misplaced) do
        plan.warnings[#plan.warnings+1]='`@@chat@@` at line '..row..' is not directly above a heading'
    end
    plan.literal_intervals=literal_index(facts,starts,length)
    if facts.protected_header_end then
        span(plan,1,(starts[facts.protected_header_end+1] or length+1)-1)
    end
    for _, row in ipairs(scan.tags) do
        span(plan,math.max(1,starts[row]-1),(starts[row+2] or length+1)-1)
    end
    for _, row in ipairs(scan.legacy_comments or {}) do
        span(plan,math.max(1,starts[row]-1),(starts[row+1] or length+1)-1)
    end
    for _, section in ipairs(scan.sections) do
        if section.heading > 0 then
            span(plan,math.max(1,starts[section.heading]-1),(starts[section.heading+1] or length+1)-1)
        end
        plan.chat[#plan.chat+1]=section.heading==0 and 'document' or tostring(section.heading)
    end
    return plan
end

function M.eligible(plan, markers)
    local out={}
    for _, marker in ipairs(markers) do
        local first=(plan.starts[marker.line+1] or plan.length+2)+marker.col
        local last=first+#(marker.raw or '')-1
        local allowed=marker.line+1>=plan.scan.facts.body_start
            and marker.line+1>(plan.scan.facts.protected_header_end or 0)
        if allowed and not intersects(plan.literal_intervals,first,last) then out[#out+1]=marker end
    end
    return out
end

-- Add each operator-owned item except its ready robot asks. A robot ask in a
-- chat section is ordinary collaborative work; the item's prose stays owned.
local function protect_items(plan, markers)
    local asks={}
    for _, marker in ipairs(markers) do
        if marker.ready then
            local first=plan.starts[marker.line+1]+marker.col
            asks[#asks+1]={first=first,last=first+#marker.raw-1}
        end
    end
    table.sort(asks,function(a,b)return a.first<b.first end)
    local index=1
    for _, item in ipairs(policy.items(plan.lines,plan.scan)) do
        local first=math.max(1,plan.starts[item.line]-1)
        local last=(plan.starts[item.finish+1] or plan.length+1)-1
        while asks[index] and asks[index].last<first do index=index+1 end
        local cursor,index_in=first,index
        while asks[index_in] and asks[index_in].first<=last do
            local ask=asks[index_in]
            if ask.first>=first and ask.last<=last then
                span(plan,cursor,ask.first-1);cursor=ask.last+1
            end
            index_in=index_in+1
        end
        span(plan,cursor,last)
    end
end

function M.validate_edits(snapshot,edits,input)
    local lines={}
    for line in (snapshot..'\n'):gmatch('(.-)\n')do lines[#lines+1]=line end
    local plan,err=M.resolve(lines)
    if not plan then return err end
    local markers=M.eligible(plan,require('parley.skills.review').parse_markers(lines))
    protect_items(plan,markers)
    return require('parley.skills.review.local_proposal').validate(snapshot,edits,input,
        {markers=markers,protected=plan.protected})
end
return M
