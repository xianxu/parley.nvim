-- Pure UI state: no provider bytes, write admission, or completion callbacks.
local M={}
local function copy(state)local out={};for k,v in pairs(state)do out[k]=v end;return out end
function M.initial(opts)
    local verbs={};for i,v in ipairs(assert(opts.verbs))do verbs[i]=v end
    local index=assert(opts.verb_index);assert(verbs[index],'invalid verb')
    return {phase='waiting',verbs=verbs,verb_index=index,verb=verbs[index],
        reveal_at=opts.now_ms+1000,verb_due_at=opts.now_ms+15000}
end
function M.transition(state,event)
    if state.phase=='finished' then return state,{} end
    local kind=event.type
    if kind=='complete' or kind=='cancel' or kind=='stale' or kind=='invalid' or kind=='failure' then
        local next_state=copy(state);next_state.phase='finished';return next_state,{{type='hide'}}
    end
    if kind=='written' then
        local next_state=copy(state);next_state.phase='released';return next_state,{{type='hide'}}
    end
    if kind=='progress' then
        local next_state=copy(state);next_state.phase='released'
        return next_state,{{type='hide'},{type='render_status',message=event.message}}
    end
    if kind=='reveal_due' and state.phase=='waiting' and event.now_ms>=state.reveal_at then
        local next_state=copy(state);next_state.phase='showing'
        return next_state,{{type='show_playful',verb=next_state.verb}}
    end
    if (kind=='activity' or kind=='idle' and event.now_ms>=state.verb_due_at)
        and (state.phase=='waiting' or state.phase=='showing') then
        local next_state=copy(state);next_state.verb_due_at=event.now_ms+15000
        if state.phase=='showing' then
            local index=((tonumber(event.verb_index) or state.verb_index)-1)%#state.verbs+1
            if index==state.verb_index then index=index%#state.verbs+1 end
            next_state.verb_index=index;next_state.verb=state.verbs[index]
            return next_state,{{type='show_playful',verb=next_state.verb}}
        end
        return next_state,{}
    end
    return state,{}
end

local function bounded(text,limit)
    if type(text)~='string' then return text end
    local last=math.min(#text,limit or 4096)
    while last>0 and text:byte(last+1) and text:byte(last+1)>=128 and text:byte(last+1)<192 do last=last-1 end
    return text:sub(1,last)
end
M.bounded_message=bounded
-- #266: what a generation held behind the write turn shows instead of looking
-- frozen. `line` is the 1-based row of the holder's question, `phase` its
-- generation phase; either may be unknown.
local waiting_reasons={preparing='preparing',requesting='streaming',executing_tools='running tools',
    draining='finishing',finalizing='finishing',stopping='stopping'}
local function holder(line)return line and ('the answer to line '..line) or 'another answer' end
function M.waiting_message(line,phase)
    return 'Waiting for '..holder(line)..' ('..(waiting_reasons[phase] or 'writing')..'); :ParleyStop there stops it'
end
-- #266 M2: a round's tools run at once but their blocks land one at a time, in
-- declared order, so the transcript can lag them. This is what shows they run —
-- and, once every outcome is in, that the round is waiting on cleanup rather
-- than finished (`tools` is the generation snapshot's {total, finished, settled}).
function M.tools_message(tools)
    if tools.finished>=tools.total and tools.settled<tools.total then
        return 'Tools finished; waiting for '..(tools.total-tools.settled)..' to clean up'
    end
    return 'Running tools: '..tools.finished..' of '..tools.total..' finished'
end
-- An overflow stops the response on purpose: dropping bytes would lose provider
-- output. `line` is set when it overflowed while held behind another answer.
function M.overflow_message(line)
    return 'Response stopped: its output passed the staging budget'
        ..(line and ' while waiting for '..holder(line) or '')
end
-- Accumulate one provider detail stream and derive its meaningful status text.
M.progress_message = function(detail_state, event)
    local detail = bounded(event.text)
    if type(detail) ~= "string" or detail == "" then
        return {}, bounded(event.message)
    end

    local detail_key = table.concat({
        bounded(tostring(event.phase or ""),256),
        bounded(tostring(event.kind or ""),256),
        bounded(tostring(event.tool or ""),256),
        bounded(tostring(event.block_type or ""),256),
    }, ":")
    local accumulated = detail
    if detail_state.key == detail_key then
        accumulated = ((detail_state.text or "") .. detail):sub(-4096)
    end

    while accumulated:byte(1) and accumulated:byte(1)>=128 and accumulated:byte(1)<192 do accumulated=accumulated:sub(2) end
    local next_state = { key = detail_key, text = accumulated }
    local compact = accumulated:gsub("%s+", " "):gsub("^%s+", "")
    if compact == "" then
        return next_state, event.message
    end
    if event.kind == "reasoning" then
        return next_state, bounded("Reasoning: " .. compact)
    end
    local base = type(event.message) == "string" and event.message ~= "" and bounded(event.message) or "Working..."
    return next_state, bounded(base .. " " .. compact)
end

return M
