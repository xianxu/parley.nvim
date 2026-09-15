-- Pure semantic transitions over the shared lexical grammar. Lookahead belongs
-- to the index: a missing fact never means a negative result.
local M = {}
local lexical = require('parley.document.lexical')
local function copy(t)
    local out={}; for k,v in pairs(t or {}) do out[k]=v end; return out
end
M.lex_start = lexical.lex_start
M.lex_step = lexical.lex_step
M.lexer_retained_bytes = lexical.lexer_retained_bytes

function M.summary(t)
    local flags={row=true}
    flags[t.kind]=true
    flags.nonblank=not t.blank or nil
    flags.structural=lexical.is_structural_kind(t.kind) or nil
    flags.reasoning_boundary=(flags.structural or t.kind=='reasoning_end') or nil
    flags.divider=t.divider or nil; flags.preface=t.preface_tag or nil
    flags.ordinary_open=t.ordinary_open_width~=nil or nil
    flags.bare_close=t.bare_close_width~=nil or nil
    return {flags=flags,close_min=t.bare_close_width,close_max=t.bare_close_width}
end

-- Fixed predicate inventory shared by indexed summaries, selective fact
-- certificates, and dependency invalidation. No consumer restates predicates.
M.CHANNELS = { 'row', 'divider', 'footnote', 'nonblank', 'bare_close',
    'structural', 'reasoning_end', 'ordinary_open', 'user' }
function M.channels(t)
    local out = {}
    if not t then return out end
    local flags = M.summary(t).flags
    for _, name in ipairs(M.CHANNELS) do if flags[name] then out[name] = true end end
    return out
end

function M.select(t,selector)
    if selector.kind=='bare_close' then return t.bare_close_width==selector.width end
    return M.summary(t).flags[selector.kind]==true
end
function M.may_contain(summary,selector)
    if not summary or not summary.flags then return true end
    if selector.kind=='bare_close' then
        return summary.close_min~=nil and selector.width>=summary.close_min and selector.width<=summary.close_max
    end
    return summary.flags[selector.kind]==true
end
function M.merge_summary(a,b)
    local out={flags={}}
    for k,v in pairs((a or {}).flags or {}) do if v then out.flags[k]=true end end
    for k,v in pairs((b or {}).flags or {}) do if v then out.flags[k]=true end end
    for _,s in ipairs({a or {},b or {}}) do
        if s.close_min then out.close_min=math.min(out.close_min or s.close_min,s.close_min) end
        if s.close_max then out.close_max=math.max(out.close_max or s.close_max,s.close_max) end
    end
    return out
end


M.combine = M.merge_summary
function M.empty_summary() return {flags={}} end
function M.same_token(a,b)
    local derived={bytes=true,provenance=true,row=true,diagnostic_utc_candidate=true,diagnostic_reference_candidate=true}
    for k,v in pairs(a) do
        if not derived[k] and b[k]~=v then return false end
    end
    for k,v in pairs(b) do
        if not derived[k] and a[k]~=v then return false end
    end
    return true
end

function M.initial()
    return {render={in_question=false,in_code=false,in_reasoning=false,
        reasoning_explicit_end=false,in_tool=false}, memo_code=false}
end
local function marker(t) return t.provenance or t.row end
local function acquire(facts,key,origin,width,deps)
    local fact=facts[key]
    if not fact then return nil,{need={kind=key,origin=origin,width=width}} end
    assert(fact.value~=nil,'fact requires explicit value, including false')
    assert(fact.certificate~=nil,'fact requires a dependency certificate')
    deps[#deps+1]=fact.certificate
    return fact.value
end

function M.advance(state,t,facts)
    facts=facts or {}
    local s=copy(state); s.render=copy(state.render)
    local p=marker(t)
    assert(p~=nil,'token requires provenance')
    local deps,events={},{}
    local function need(key,width) return acquire(facts,key,p,width,deps) end
    local value,pending
    if not s.initialized then
        value,pending=need('header'); if pending then return pending end
        s.header_end=value and value.finish or nil
        value,pending=need('footer'); if pending then return pending end
        s.footer_start=value and value.start or nil
        s.content_end=value and value.content_start or nil
        s.initialized=true
    end
    local sem={kind=t.kind,role=s.role}
    if s.header_end then
        sem.header=true
        if p==s.header_end then s.header_end=nil end
        return {checkpoint=s,render_before=copy(s.render),semantic=sem,dependencies=deps,events=events}
    end
    if not s.body_start then s.body_start=p end
    if p==s.footer_start then s.footer=true end
    if p==s.content_end then s.content_ended=true end
    sem.footer=s.footer or false; sem.content_ended=s.content_ended or false
    -- A closed ordinary fence suppresses tool markers only. Questions inside
    -- it retain their parser meaning; render partitions have a separate rule.
    local in_tool=s.tool_close~=nil
    local in_ordinary=s.ordinary_close~=nil
    if in_tool then sem.kind='text'
    elseif in_ordinary and (t.kind=='tool_use' or t.kind=='tool_result') then sem.kind='text' end
    if not in_tool and not in_ordinary then
        if t.kind=='tool_use' or t.kind=='tool_result' then
            value,pending=need('tool_body'); if pending then return pending end
            if value then s.tool_close=value.close end
        elseif t.ordinary_open_width then
            value,pending=need('ordinary_close',t.ordinary_open_width); if pending then return pending end
            if value then s.ordinary_close=value end
        end
    end
    local explicit
    -- Render reasoning and semantic reasoning consume the same lookahead
    -- predicate, but role/section transitions below are intentionally distinct.
    if t.kind=='reasoning' then
        explicit,pending=need('reasoning'); if pending then return pending end
    end
    local preface=false
    if t.preface_tag then
        value,pending=need('preface'); if pending then return pending end
        preface=value and not s.memo_code
    end
    local r=s.render
    if s.footer then r.in_question=false; r.in_reasoning=false end
    lexical.reset_partition(r,t.token)
    local render_before=copy(r)
    lexical.advance(r,t.token,t.render_fence_width)
    if t.kind=='reasoning_end' then r.in_reasoning=false; r.reasoning_explicit_end=false
    elseif t.kind=='reasoning' then r.in_reasoning=true; r.reasoning_explicit_end=explicit
    elseif r.in_reasoning and t.blank and not r.reasoning_explicit_end then r.in_reasoning=false end
    -- Preface code containment uses the legacy backtick/tilde toggle dialect.
    if t.kind=='user' or t.kind=='assistant' or t.kind=='local' or t.kind=='branch' then
        s.memo_code=false
    elseif t.memo_fence_width then s.memo_code=not s.memo_code end
    if t.draft_open and not s.draft then s.draft=p; sem.draft_start=true
    elseif t.draft_end and s.draft then sem.draft_end=true; sem.draft_origin=s.draft; s.draft=nil end
    sem.draft=s.draft
    local k=sem.kind
    if preface then
        s.preface=p; sem.preface=true
    elseif k=='user' then
        s.exchange=p; s.role='question'; s.section=nil; s.reasoning=false
        sem.exchange_start=true; sem.preface_origin=s.preface; s.preface=nil
        events[#events+1]={kind='exchange_start',origin=p,preface=sem.preface_origin}
    elseif k=='assistant' then
        if not s.exchange then s.exchange=s.body_start; sem.exchange_start=true; sem.synthetic=true end
        s.role='answer'; s.section='text'; s.reasoning=false; sem.answer_start=true; sem.section_start=true
        events[#events+1]={kind='answer_start',origin=p,exchange=s.exchange}
    elseif k=='local' or k=='branch' then
        s.reasoning=false; s.section=s.role=='answer' and 'text' or nil; sem.annotation=true; sem.section_start=true
    elseif s.role=='answer' then
        if k=='tool_use' or k=='tool_result' then
            s.reasoning=false; s.section=k; sem.section_start=true
        elseif k=='summary' then
            s.reasoning=false; s.section='summary'; sem.section_start=true
        elseif k=='reasoning' then
            s.reasoning=true; s.semantic_explicit=explicit; s.section='thinking'; sem.section_start=true
        elseif k=='reasoning_end' and s.reasoning then
            s.reasoning=false; sem.section_kind='thinking'; s.section='text'
        elseif s.reasoning and t.blank and not s.semantic_explicit then
            s.reasoning=false; s.section='text'
        elseif s.section=='summary' then s.section='text'; sem.section_start=true
        end
    end
    sem.role=s.role; sem.exchange=s.exchange
    if in_tool and p==s.tool_close then s.tool_close=nil; s.section='text' end
    if in_ordinary and p==s.ordinary_close then s.ordinary_close=nil end
    return {checkpoint=s,render_before=render_before,semantic=sem,dependencies=deps,events=events}
end

-- The legacy section reducer scans only one confirmed answer body. Its fence
-- witnesses must stay inside that scope, independently of document-wide ones.
function M.initial_sections(scope)
    return {section='text',reasoning=false,scope_end=scope and scope['end']}
end
function M.advance_sections(state,t,facts)
    local s=copy(state)
    local deps={}
    local p=marker(t)
    assert(p~=nil,'token requires provenance')
    local function need(key,width)
        local value,pending=acquire(facts or {},key,p,width,deps)
        if pending and s.scope_end then pending.need.scope={['end']=s.scope_end} end
        return value,pending
    end
    local in_tool=s.tool_close~=nil
    local in_ordinary=s.ordinary_close~=nil
    local k=t.kind
    if in_tool then k='text'
    elseif in_ordinary and (k=='tool_use' or k=='tool_result') then k='text' end
    local value,pending
    if not in_tool and not in_ordinary then
        if k=='tool_use' or k=='tool_result' then
            value,pending=need('section_tool_body'); if pending then return pending end
            if value then s.tool_close=value.close end
        elseif t.ordinary_open_width then
            value,pending=need('section_ordinary_close',t.ordinary_open_width)
            if pending then return pending end
            if value then s.ordinary_close=value end
        end
    end
    local section={}
    if not in_tool then
        if k=='reasoning' then
            value,pending=need('reasoning'); if pending then return pending end
            s.section='thinking'; s.reasoning=true; s.explicit=value; section.start=true
        elseif k=='summary' then
            s.section='summary'; s.reasoning=false; section.start=true
        elseif k=='tool_use' or k=='tool_result' then
            s.section=k; s.reasoning=false; section.start=true
        -- Fence containment controls tool admission, but the original marker
        -- remains a boundary for reasoning and preceding tool/text sections.
        elseif lexical.is_structural_kind(t.kind) then
            s.section='text'; s.reasoning=false; section.start=true
        elseif k=='reasoning_end' and s.reasoning then
            section.kind='thinking'; s.reasoning=false; s.section='text'
        elseif s.reasoning and t.blank and not s.explicit then
            s.reasoning=false; s.section='text'
        elseif s.section=='summary' then s.section='text'; section.start=true end
    end
    section.kind=section.kind or s.section
    section.blank=t.blank
    if in_tool and p==s.tool_close then s.tool_close=nil; s.section='text' end
    if in_ordinary and p==s.ordinary_close then s.ordinary_close=nil end
    return {checkpoint=s,section=section,dependencies=deps}
end

function M.same_checkpoint(a,b)
    for k,v in pairs(a) do
        if k=='render' then
            for rk,rv in pairs(v) do if b.render[rk]~=rv then return false end end
            for rk,rv in pairs(b.render) do if v[rk]~=rv then return false end end
        elseif b[k]~=v then return false end
    end
    for k,v in pairs(b) do if k~='render' and a[k]~=v then return false end end
    return true
end

-- Evidence validation belongs to the index that issued the certificate. This
-- wrapper makes absence fail closed and never substitutes token equality.
function M.validate_certificate(certificate,validate)
    return certificate~=nil and type(validate)=='function' and validate(certificate)==true
end
return M
